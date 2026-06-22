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

local function fireDuelClient(player, data)
	if not DuelEvent or not player or not player.Parent then return end
	local ok, err = pcall(function()
		DuelEvent:FireClient(player, data)
	end)
	if not ok then
		warn("[DuelManager] Failed to fire DuelEvent:", err)
	end
end

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

local function serializeStats(duel, stats)
	local result = { players = {} }
	for _, player in ipairs({ duel.player1, duel.player2 }) do
		if player then
			local heroId = shared.LobbyManager and shared.LobbyManager.GetPlayerHero(player) or nil
			local pstat = stats and stats[player]
			table.insert(result.players, {
				userId = player.UserId,
				name = player.Name,
				team = player.Team and player.Team.Name or nil,
				heroId = heroId,
				kills = pstat and pstat.kills or 0,
				deaths = pstat and pstat.deaths or 0,
				damageDealt = pstat and math.floor(pstat.damage or 0) or 0,
			})
		end
	end
	return result
end

local function returnPlayerToLobby(player)
	if not player or not player.Parent then return end

	clearTeam(player)
	if shared.LobbyManager then
		shared.LobbyManager.SetPlayerState(player, "LOBBY")
		shared.LobbyManager.ClearPlayerHero(player)
	end
	fireDuelClient(player, { type = "return_lobby" })

	player:LoadCharacter()
	local character = player.Character
	local deadline = os.clock() + 5
	while not character and player.Parent and os.clock() < deadline do
		task.wait()
		character = player.Character
	end
	local rootPart = character and character:WaitForChild("HumanoidRootPart", 10)
	if rootPart then
		rootPart.CFrame = CFrame.new(LOBBY_SPAWN)
	end
end

-- ========== 对决生命周期 ==========
local function createDuel(player1, player2)
	if not player1 or not player1.Parent then return end
	if not player2 or not player2.Parent then return end
	if not shared.MatchSystem then
		warn("[DuelManager] MatchSystem not available; cancelling duel")
		if shared.LobbyManager then
			shared.LobbyManager.SetPlayerState(player1, "LOBBY")
			shared.LobbyManager.SetPlayerState(player2, "LOBBY")
		end
		local cancelData = { status = "cancelled", message = "MatchSystem unavailable" }
		local matchmakingEvent = ReplicatedStorage:FindFirstChild("MatchmakingEvent")
		if matchmakingEvent then
			matchmakingEvent:FireClient(player1, cancelData)
			matchmakingEvent:FireClient(player2, cancelData)
		end
		return
	end

	local duelId = nextDuelId
	nextDuelId = nextDuelId + 1

	activeDuels[duelId] = {
		player1 = player1,
		player2 = player2,
		active = true,
		started = false,
	}
	playerDuelMap[player1] = duelId
	playerDuelMap[player2] = duelId

	print(("[DuelManager] Duel #%d created: %s vs %s"):format(duelId, player1.Name, player2.Name))

	-- 获取英雄信息
	local hero1 = shared.LobbyManager and shared.LobbyManager.GetPlayerHero(player1) or "Unknown"
	local hero2 = shared.LobbyManager and shared.LobbyManager.GetPlayerHero(player2) or "Unknown"

	-- 通知: matched
	task.spawn(function()
		fireDuelClient(player1, {
			type = "matched",
			opponent = { name = player2.Name, heroId = hero2 },
		})
		fireDuelClient(player2, {
			type = "matched",
			opponent = { name = player1.Name, heroId = hero1 },
		})

		-- 倒计时
		for i = COUNTDOWN_SECONDS, 1, -1 do
			if not activeDuels[duelId] or not activeDuels[duelId].active then return end
			fireDuelClient(player1, { type = "countdown", seconds = i })
			fireDuelClient(player2, { type = "countdown", seconds = i })
			task.wait(1)
		end

		if not activeDuels[duelId] or not activeDuels[duelId].active then return end
		if not player1.Parent then
			endDuel(duelId, "BlueTeam", nil)
			return
		end
		if not player2.Parent then
			endDuel(duelId, "RedTeam", nil)
			return
		end

		-- 分配阵营
		assignTeam(player1, redTeam)
		assignTeam(player2, blueTeam)
		activeDuels[duelId].started = true

		-- 传送到竞技场
		local spawn1 = ARENA_CENTER + Vector3.new(-SPAWN_DISTANCE, 0, 0)
		local spawn2 = ARENA_CENTER + Vector3.new(SPAWN_DISTANCE, 0, 0)
		teleportPlayer(player1, spawn1)
		teleportPlayer(player2, spawn2)

		-- 通知: start
		fireDuelClient(player1, {
			type = "start",
			team = "RedTeam",
			arenaCenter = ARENA_CENTER,
		})
		fireDuelClient(player2, {
			type = "start",
			team = "BlueTeam",
			arenaCenter = ARENA_CENTER,
		})

		-- 启动 MatchSystem 战斗追踪
		shared.MatchSystem.StartBattle()

		print(("[DuelManager] Duel #%d started!"):format(duelId))

		-- 胜负为事件驱动：MatchSystem 达成击杀线时调用 DuelAPI.NotifyWin → endDuel。
		-- 掉线由 PlayerRemoving → OnPlayerDisconnect → endDuel 处理。无需轮询。
	end)
end

-- 结束对决
endDuel = function(duelId, winnerTeam, stats)
	local duel = activeDuels[duelId]
	if not duel or not duel.active then return end

	duel.active = false
	-- 未显式传入时（掉线/倒计时取消等），从 MatchSystem 拉取最终统计供结算面板使用
	stats = stats or (shared.MatchSystem and shared.MatchSystem.GetMatchStats()) or nil
	local player1 = duel.player1
	local player2 = duel.player2

	print(("[DuelManager] Duel #%d ended! Winner: %s"):format(duelId, winnerTeam))

	-- 停止战斗追踪
	if shared.MatchSystem then
		shared.MatchSystem.EndBattle()
	end

	-- 通知结算
	if DuelEvent then
		local statsPayload = serializeStats(duel, stats)
		local resultData = {
			type = "result",
			winner = winnerTeam,
			stats = statsPayload,
			players = statsPayload.players,
		}
		fireDuelClient(player1, resultData)
		fireDuelClient(player2, resultData)
	end

	-- 等待结算展示
	task.delay(RESULT_DISPLAY_TIME, function()
		returnPlayerToLobby(player1)
		returnPlayerToLobby(player2)

		-- 重置 MatchSystem
		if shared.MatchSystem then
			shared.MatchSystem.ResetMatch()
		end

		-- 清理对决记录
		playerDuelMap[player1] = nil
		playerDuelMap[player2] = nil
		activeDuels[duelId] = nil

		print(("[DuelManager] Duel #%d cleanup complete, players returned to lobby (avatar restoring)"):format(duelId))
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
function DuelAPI.IsPlayerInActiveBattle(player)
	local duelId = playerDuelMap[player]
	local duel = duelId and activeDuels[duelId]
	return duel ~= nil and duel.active == true and duel.started == true
end

function DuelAPI.NotifyWin(winner)
	if not winner then return end
	local duelId = playerDuelMap[winner]
	if not duelId then return end
	local duel = activeDuels[duelId]
	if not duel or not duel.active then return end
	local winnerTeam = winner.Team and winner.Team.Name
		or (duel.player1 == winner and "RedTeam" or "BlueTeam")
	endDuel(duelId, winnerTeam, nil)
end

shared.DuelManager = DuelAPI

print("[DuelManager] Duel system initialized!")
