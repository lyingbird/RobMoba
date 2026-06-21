-- ==========================================
-- LobbyManager.server.lua
-- 职责: 大厅状态管理、匹配队列、英雄切换、训练场模式进出
-- REQ-004: 自由大厅 + 匹配对决
-- REQ-002(重启): 游戏主流程重设计 — avatar漫游→模式选择→英雄选择
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- 等待 RemoteEventInit 创建完成
task.wait(0.5)

local MatchmakingEvent = ReplicatedStorage:WaitForChild("MatchmakingEvent", 10)
local HeroSwapEvent = ReplicatedStorage:WaitForChild("HeroSwapEvent", 10)
local DuelEvent = ReplicatedStorage:WaitForChild("DuelEvent", 10)
local TrainingModeEvent = ReplicatedStorage:WaitForChild("TrainingModeEvent", 10)

-- 英雄配置
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))

-- 被动 + 能量系统 (REQ-007)
local ServerScriptService = game:GetService("ServerScriptService")
local PassiveSystem = require(ServerScriptService.ServerModules:WaitForChild("PassiveSystem"))
local EnergySystem = require(ServerScriptService.ServerModules:WaitForChild("EnergySystem"))

-- ========== 数据结构 ==========
local playerStates = {}  -- { [Player] = "LOBBY" | "MATCHING" | "DUELING" | "TRAINING" }
local playerHeroes = {}  -- { [Player] = heroId | nil }
local matchQueue = {}    -- { Player, Player, ... } 有序数组

-- ========== 匹配区域参数 ==========
local ZONE_RADIUS = 15
local ZONE_CENTER = Vector3.new(-180, 62, 180) -- 出生点旁，后续可调
local DEBOUNCE_TIME = 0.5

-- ========== 工具函数 ==========
local function removeFromQueue(player)
	for i, p in ipairs(matchQueue) do
		if p == player then
			table.remove(matchQueue, i)
			return true
		end
	end
	return false
end

local function broadcastQueueSize()
	local size = #matchQueue
	for _, p in ipairs(matchQueue) do
		if p and p.Parent then
			MatchmakingEvent:FireClient(p, {
				status = "queued",
				queueSize = size,
			})
		end
	end
end

-- ========== 匹配逻辑 ==========
local function joinMatchmaking(player)
	local state = playerStates[player]
	if state ~= "LOBBY" then return end

	-- 必须已选英雄
	if not playerHeroes[player] then
		MatchmakingEvent:FireClient(player, {
			status = "cancelled",
			message = "请先选择英雄！",
		})
		return
	end

	playerStates[player] = "MATCHING"
	table.insert(matchQueue, player)
	broadcastQueueSize()
	print(("[LobbyManager] %s joined matchmaking (queue: %d)"):format(player.Name, #matchQueue))

	-- 检查是否可以匹配
	if #matchQueue >= 2 then
		local p1 = table.remove(matchQueue, 1)
		local p2 = table.remove(matchQueue, 1)

		if p1 and p1.Parent and p2 and p2.Parent then
			playerStates[p1] = "DUELING"
			playerStates[p2] = "DUELING"

			-- 通知双方匹配成功
			MatchmakingEvent:FireClient(p1, {
				status = "matched",
				opponent = { name = p2.Name, heroId = playerHeroes[p2] },
			})
			MatchmakingEvent:FireClient(p2, {
				status = "matched",
				opponent = { name = p1.Name, heroId = playerHeroes[p1] },
			})

			print(("[LobbyManager] Match found: %s vs %s"):format(p1.Name, p2.Name))

			-- 创建对决。DuelManager 会立即建立 playerDuelMap，避免 matched 后断线卡状态。
			if shared.DuelManager then
				shared.DuelManager.CreateDuel(p1, p2)
			else
				warn("[LobbyManager] DuelManager not available!")
				playerStates[p1] = "LOBBY"
				playerStates[p2] = "LOBBY"
				MatchmakingEvent:FireClient(p1, {
					status = "cancelled",
					message = "DuelManager unavailable",
				})
				MatchmakingEvent:FireClient(p2, {
					status = "cancelled",
					message = "DuelManager unavailable",
				})
			end

			broadcastQueueSize()
		end
	end
end

local function leaveMatchmaking(player)
	if playerStates[player] ~= "MATCHING" then return end

	playerStates[player] = "LOBBY"
	removeFromQueue(player)

	-- REQ-002: 取消匹配时恢复 avatar（清除英雄选择）
	playerHeroes[player] = nil
	player:SetAttribute("SelectedHero", nil)
	if player.Character then
		player.Character:SetAttribute("HeroId", nil)
	end
	PassiveSystem:UnregisterPassives(player)
	EnergySystem:RemovePlayer(player)
	task.delay(0.5, function()
		if player and player.Parent then
			player:LoadCharacter()
		end
	end)

	MatchmakingEvent:FireClient(player, {
		status = "cancelled",
	})

	broadcastQueueSize()
	print(("[LobbyManager] %s left matchmaking, restoring avatar"):format(player.Name))
end

-- ========== 英雄切换 ==========
local function onHeroSwap(player, data)
	if not data or not data.heroId then return end

	-- 对决中不能切换
	if playerStates[player] == "DUELING" then
		HeroSwapEvent:FireClient(player, {
			success = false,
			heroId = data.heroId,
			message = "对决中无法切换英雄",
		})
		return
	end

	-- 匹配中不能切换
	if playerStates[player] == "MATCHING" then
		HeroSwapEvent:FireClient(player, {
			success = false,
			heroId = data.heroId,
			message = "匹配中无法切换英雄",
		})
		return
	end

	-- 训练中不能切换
	if playerStates[player] == "TRAINING" then
		HeroSwapEvent:FireClient(player, {
			success = false,
			heroId = data.heroId,
			message = "训练中无法切换英雄，请先退出训练场",
		})
		return
	end

	-- 验证 heroId 合法
	if not HeroRegistry[data.heroId] then
		HeroSwapEvent:FireClient(player, {
			success = false,
			heroId = data.heroId,
			message = "无效的英雄ID",
		})
		return
	end

	playerHeroes[player] = data.heroId
	player:SetAttribute("SelectedHero", data.heroId)
	if player.Character then
		player.Character:SetAttribute("HeroId", data.heroId)
	end

	-- REQ-007: 被动 + 能量系统注册
	PassiveSystem:UnregisterPassives(player)
	PassiveSystem:RegisterPassives(player, data.heroId)
	EnergySystem:InitEnergy(player, data.heroId)

	HeroSwapEvent:FireClient(player, {
		success = true,
		heroId = data.heroId,
	})

	print(("[LobbyManager] %s switched to %s"):format(player.Name, data.heroId))
end

-- ========== REQ-002: 训练场模式进出 ==========
local function enterTraining(player)
	if playerStates[player] ~= "LOBBY" then
		if TrainingModeEvent then
			TrainingModeEvent:FireClient(player, { status = "error", message = "只能在大厅进入训练场" })
		end
		return
	end

	if not playerHeroes[player] then
		if TrainingModeEvent then
			TrainingModeEvent:FireClient(player, { status = "error", message = "请先选择英雄" })
		end
		return
	end

	playerStates[player] = "TRAINING"

	-- REQ-002: sync training panel visibility
	if shared.TrainingManager then
		shared.TrainingManager.SyncState(player)
	end

	if TrainingModeEvent then
		TrainingModeEvent:FireClient(player, { status = "entered" })
	end

	print(("[LobbyManager] %s entered TRAINING mode with hero %s"):format(player.Name, playerHeroes[player]))
end

local function leaveTraining(player)
	if playerStates[player] ~= "TRAINING" then return end

	-- 先恢复到大厅状态，避免训练状态清理过程中发出 panelVisible=true 的过期同步包
	playerStates[player] = "LOBBY"
	playerHeroes[player] = nil
	player:SetAttribute("SelectedHero", nil)
	if player.Character then
		player.Character:SetAttribute("HeroId", nil)
	end

	-- 清理训练状态
	if shared.TrainingManager then
		shared.TrainingManager.ResetTrainingState(player)
	end

	-- 清理被动 + 能量
	PassiveSystem:UnregisterPassives(player)
	EnergySystem:RemovePlayer(player)

	-- REQ-002: sync training panel visibility (hide)
	if shared.TrainingManager then
		shared.TrainingManager.SyncState(player)
	end

	-- 恢复 avatar
	task.delay(0.5, function()
		if player and player.Parent then
			player:LoadCharacter()
		end
	end)

	if TrainingModeEvent then
		TrainingModeEvent:FireClient(player, { status = "left" })
	end

	print(("[LobbyManager] %s left TRAINING mode, restoring avatar"):format(player.Name))
end

-- ========== RemoteEvent 监听 ==========
if MatchmakingEvent then
	MatchmakingEvent.OnServerEvent:Connect(function(player, data)
		if not data or not data.action then return end

		if data.action == "join" then
			joinMatchmaking(player)
		elseif data.action == "leave" then
			leaveMatchmaking(player)
		end
	end)
end

if HeroSwapEvent then
	HeroSwapEvent.OnServerEvent:Connect(function(player, data)
		onHeroSwap(player, data)
	end)
end

-- REQ-002: 训练场模式进出事件
if TrainingModeEvent then
	TrainingModeEvent.OnServerEvent:Connect(function(player, data)
		if not data or not data.action then return end

		if data.action == "enter" then
			enterTraining(player)
		elseif data.action == "leave" then
			leaveTraining(player)
		end
	end)
end

-- ========== 玩家加入/离开 ==========
local function onPlayerAdded(player)
	playerStates[player] = "LOBBY"
	playerHeroes[player] = nil
	print(("[LobbyManager] %s entered lobby"):format(player.Name))
end

local function onPlayerRemoving(player)
	-- 从匹配队列移除
	if playerStates[player] == "MATCHING" then
		removeFromQueue(player)
		broadcastQueueSize()
	end

	-- 通知 DuelManager 处理掉线
	if playerStates[player] == "DUELING" and shared.DuelManager then
		shared.DuelManager.OnPlayerDisconnect(player)
	end

	-- 训练中掉线清理
	if playerStates[player] == "TRAINING" and shared.TrainingManager then
		shared.TrainingManager.ResetTrainingState(player)
	end

	-- REQ-007: 清理被动 + 能量
	PassiveSystem:UnregisterPassives(player)
	EnergySystem:RemovePlayer(player)

	playerStates[player] = nil
	playerHeroes[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 处理脚本启动时已在服务器的玩家
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

-- ========== 匹配区域物理检测 ==========
local function createMatchZone()
	local zone = Instance.new("Part")
	zone.Name = "MatchmakingZone"
	zone.Shape = Enum.PartType.Cylinder
	zone.Size = Vector3.new(2, ZONE_RADIUS * 2, ZONE_RADIUS * 2)
	zone.CFrame = CFrame.new(ZONE_CENTER) * CFrame.Angles(0, 0, math.rad(90))
	zone.Transparency = 0.85
	zone.BrickColor = BrickColor.new("Bright blue")
	zone.Material = Enum.Material.Neon
	zone.CanCollide = false
	zone.Anchored = true
	zone.Parent = workspace

	-- 悬浮文字
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 10, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "⚔️ PvP 匹配"
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- 防抖记录
	local lastTouch = {}

	zone.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		if lastTouch[player] and tick() - lastTouch[player] < DEBOUNCE_TIME then return end
		lastTouch[player] = tick()

		if playerStates[player] == "LOBBY" then
			joinMatchmaking(player)
		end
	end)

	zone.TouchEnded:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		if lastTouch[player] and tick() - lastTouch[player] < DEBOUNCE_TIME then return end
		lastTouch[player] = tick()

		if playerStates[player] == "MATCHING" then
			leaveMatchmaking(player)
		end
	end)

	print("[LobbyManager] Matchmaking zone created at", ZONE_CENTER)
	return zone
end

local matchZone = createMatchZone()

-- ========== 对外 API ==========
local LobbyAPI = {}

function LobbyAPI.GetPlayerState(player)
	return playerStates[player] or "LOBBY"
end

function LobbyAPI.GetPlayerHero(player)
	return playerHeroes[player]
end

function LobbyAPI.SetPlayerState(player, state)
	playerStates[player] = state
end

--- 清除玩家英雄选择（对决结束恢复avatar时调用）
function LobbyAPI.ClearPlayerHero(player)
	playerHeroes[player] = nil
	player:SetAttribute("SelectedHero", nil)
	if player.Character then
		player.Character:SetAttribute("HeroId", nil)
	end
	PassiveSystem:UnregisterPassives(player)
	EnergySystem:RemovePlayer(player)
end

LobbyAPI.EnterTraining = enterTraining
LobbyAPI.LeaveTraining = leaveTraining

shared.LobbyManager = LobbyAPI

print("[LobbyManager] Lobby system initialized!")
