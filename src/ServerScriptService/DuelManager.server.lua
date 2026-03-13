-- ==========================================
-- DuelManager.server.lua
-- 职责: 对决生命周期管理 (阵营/传送/倒计时/战斗/结算)
-- REQ-004: 自由大厅 + 匹配对决
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

-- 等待 RemoteEventInit 创建完成
task.wait(0.5)

local DuelEvent = ReplicatedStorage:WaitForChild("DuelEvent", 10)

-- ========== 竞技场参数 ==========
local ARENA_CENTER = Vector3.new(0, 62, 0) -- 竞技场中心坐标，需根据地图调整
local SPAWN_DISTANCE = 40                   -- 各自距中心距离 (总间距80 studs)
local COUNTDOWN_SECONDS = 3
local RESULT_DISPLAY_TIME = 5
local KILLS_TO_WIN = 3
local LOBBY_SPAWN = Vector3.new(-197, 62.5, 204) -- 大厅出生点

-- ========== 阵营 ==========
local redTeam = Teams:FindFirstChild("RedTeam")
local blueTeam = Teams:FindFirstChild("BlueTeam")

-- 如果阵营不存在则创建
if not redTeam then
	redTeam = Instance.new("Team")
	redTeam.Name = "RedTeam"
	redTeam.TeamColor = BrickColor.new("Bright red")
	redTeam.AutoAssignable = false
	redTeam.Parent = Teams
end

if not blueTeam then
	blueTeam = Instance.new("Team")
	blueTeam.Name = "BlueTeam"
	blueTeam.TeamColor = BrickColor.new("Bright blue")
	blueTeam.AutoAssignable = false
	blueTeam.Parent = Teams
end

-- ========== 活跃对决 ==========
local activeDuels = {} -- { [duelId] = { player1, player2, active } }
local playerDuelMap = {} -- { [Player] = duelId }
local nextDuelId = 1

-- 前向声明
local endDuel

-- ========== 工具函数 ==========
local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.CFrame = CFrame.new(position)
	end
end

local function assignTeam(player, team)
	player.Team = team
end

local function clearTeam(player)
	player.Team = nil
end

-- ========== 对决生命周期 ==========
local function createDuel(player1, player2)
	if not player1 or not player1.Parent then return end
	if not player2 or not player2.Parent then return end

	local duelId = nextDuelId
	nextDuelId = nextDuelId + 1

	activeDuels[duelId] = {
		player1 = player1,
		player2 = player2,
		active = true,
	}
	playerDuelMap[player1] = duelId
	playerDuelMap[player2] = duelId

	print(("[DuelManager] Duel #%d created: %s vs %s"):format(duelId, player1.Name, player2.Name))

	-- 获取英雄信息
	local hero1 = shared.LobbyManager and shared.LobbyManager.GetPlayerHero(player1) or "Unknown"
	local hero2 = shared.LobbyManager and shared.LobbyManager.GetPlayerHero(player2) or "Unknown"

	-- 通知: matched
	if DuelEvent then
		DuelEvent:FireClient(player1, {
			type = "matched",
			opponent = { name = player2.Name, heroId = hero2 },
		})
		DuelEvent:FireClient(player2, {
			type = "matched",
			opponent = { name = player1.Name, heroId = hero1 },
		})
	end

	-- 倒计时
	for i = COUNTDOWN_SECONDS, 1, -1 do
		if not activeDuels[duelId] or not activeDuels[duelId].active then return end
		if DuelEvent then
			DuelEvent:FireClient(player1, { type = "countdown", seconds = i })
			DuelEvent:FireClient(player2, { type = "countdown", seconds = i })
		end
		task.wait(1)
	end

	if not activeDuels[duelId] or not activeDuels[duelId].active then return end

	-- 分配阵营
	assignTeam(player1, redTeam)
	assignTeam(player2, blueTeam)

	-- 传送到竞技场
	local spawn1 = ARENA_CENTER + Vector3.new(-SPAWN_DISTANCE, 0, 0)
	local spawn2 = ARENA_CENTER + Vector3.new(SPAWN_DISTANCE, 0, 0)
	teleportPlayer(player1, spawn1)
	teleportPlayer(player2, spawn2)

	-- 通知: start
	if DuelEvent then
		DuelEvent:FireClient(player1, {
			type = "start",
			team = "RedTeam",
			arenaCenter = ARENA_CENTER,
		})
		DuelEvent:FireClient(player2, {
			type = "start",
			team = "BlueTeam",
			arenaCenter = ARENA_CENTER,
		})
	end

	-- 启动 MatchSystem 战斗追踪
	if shared.MatchSystem then
		shared.MatchSystem.StartBattle()
	end

	print(("[DuelManager] Duel #%d started!"):format(duelId))

	-- 监听胜负 (轮询 MatchSystem)
	task.spawn(function()
		while activeDuels[duelId] and activeDuels[duelId].active do
			task.wait(0.5)

			-- 检查 MatchSystem 是否结束了 (matchActive=false 且有击杀数达标)
			if shared.MatchSystem then
				local killCount = shared.MatchSystem.GetKillCount()
				local p1Kills = killCount[player1] or 0
				local p2Kills = killCount[player2] or 0

				if p1Kills >= KILLS_TO_WIN then
					endDuel(duelId, "RedTeam", killCount)
					return
				elseif p2Kills >= KILLS_TO_WIN then
					endDuel(duelId, "BlueTeam", killCount)
					return
				end
			end

			-- 检查玩家是否还在
			if not player1 or not player1.Parent then
				endDuel(duelId, "BlueTeam", nil)
				return
			end
			if not player2 or not player2.Parent then
				endDuel(duelId, "RedTeam", nil)
				return
			end
		end
	end)
end

-- 结束对决
endDuel = function(duelId, winnerTeam, stats)
	local duel = activeDuels[duelId]
	if not duel or not duel.active then return end

	duel.active = false
	local player1 = duel.player1
	local player2 = duel.player2

	print(("[DuelManager] Duel #%d ended! Winner: %s"):format(duelId, winnerTeam))

	-- 停止战斗追踪
	if shared.MatchSystem then
		shared.MatchSystem.EndBattle()
	end

	-- 通知结算
	if DuelEvent then
		local resultData = {
			type = "result",
			winner = winnerTeam,
			stats = stats or {},
		}
		if player1 and player1.Parent then
			DuelEvent:FireClient(player1, resultData)
		end
		if player2 and player2.Parent then
			DuelEvent:FireClient(player2, resultData)
		end
	end

	-- 等待结算展示
	task.delay(RESULT_DISPLAY_TIME, function()
		-- 清除阵营
		if player1 and player1.Parent then
			clearTeam(player1)
			teleportPlayer(player1, LOBBY_SPAWN)
			if shared.LobbyManager then
				shared.LobbyManager.SetPlayerState(player1, "LOBBY")
			end
		end

		if player2 and player2.Parent then
			clearTeam(player2)
			teleportPlayer(player2, LOBBY_SPAWN)
			if shared.LobbyManager then
				shared.LobbyManager.SetPlayerState(player2, "LOBBY")
			end
		end

		-- 重置 MatchSystem
		if shared.MatchSystem then
			shared.MatchSystem.ResetMatch()
		end

		-- 清理对决记录
		playerDuelMap[player1] = nil
		playerDuelMap[player2] = nil
		activeDuels[duelId] = nil

		print(("[DuelManager] Duel #%d cleanup complete, players returned to lobby"):format(duelId))
	end)
end

-- ========== 掉线处理 ==========
local function onPlayerDisconnect(player)
	local duelId = playerDuelMap[player]
	if not duelId then return end

	local duel = activeDuels[duelId]
	if not duel or not duel.active then return end

	-- 对方获胜
	local winnerTeam
	if duel.player1 == player then
		winnerTeam = "BlueTeam"
	else
		winnerTeam = "RedTeam"
	end

	print(("[DuelManager] %s disconnected during duel #%d"):format(player.Name, duelId))
	endDuel(duelId, winnerTeam, nil)
end

-- ========== 对外 API ==========
local DuelAPI = {}
DuelAPI.CreateDuel = createDuel
DuelAPI.OnPlayerDisconnect = onPlayerDisconnect

shared.DuelManager = DuelAPI

print("[DuelManager] Duel system initialized!")
