-- ==========================================
-- 游戏流程管理器 (Game Manager)
-- 职责：游戏状态机、英雄选择协调、对局流程控制
-- 状态：WAITING → HERO_SELECT → LOADING → BATTLE → RESULT
-- ⚠️ 临时禁用：等待 REQ-004 游戏流程重设计（自由大厅+匹配区域）
-- ==========================================
print("[GameManager] ⏸️ Disabled — awaiting REQ-004 lobby system redesign")
do return end
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- ========== 配置（可扩展到3v3） ==========
-- 自动检测：Studio 测试时支持单人，线上要求2人
local RunService = game:GetService("RunService")
local IS_STUDIO = RunService:IsStudio()
local REQUIRED_PLAYERS = IS_STUDIO and 1 or 2  -- Studio单人测试=1，线上=2（3v3改6）
local KILLS_TO_WIN = 3           -- 先达到此击杀数获胜
local RESPAWN_TIME = 5           -- 死亡后重生倒计时（秒）
local HERO_SELECT_TIME = 30      -- 英雄选择倒计时（秒）
local BATTLE_COUNTDOWN = 3       -- 对战开始倒计时（秒）
local RESULT_DURATION = 15       -- 结算界面持续（秒）

-- ========== 状态定义 ==========
local GameState = {
	WAITING     = "WAITING",
	HERO_SELECT = "HERO_SELECT",
	LOADING     = "LOADING",
	BATTLE      = "BATTLE",
	RESULT      = "RESULT",
}

-- 合法状态转换
local TRANSITIONS = {
	[GameState.WAITING]     = { [GameState.HERO_SELECT] = true },
	[GameState.HERO_SELECT] = { [GameState.LOADING] = true, [GameState.WAITING] = true },
	[GameState.LOADING]     = { [GameState.BATTLE] = true },
	[GameState.BATTLE]      = { [GameState.RESULT] = true },
	[GameState.RESULT]      = { [GameState.WAITING] = true },
}

-- ========== 出生点 ==========
local SPAWN_POINTS = {
	RedTeam  = Vector3.new(-50, 5, 0),
	BlueTeam = Vector3.new(50, 5, 0),
}

-- ========== 创建 RemoteEvents ==========
local function createRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then return existing end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

local GameStateEvent   = createRemoteEvent("GameStateEvent")
local HeroSelectEvent  = createRemoteEvent("HeroSelectEvent")
local BattleStartEvent = createRemoteEvent("BattleStartEvent")
local MatchResultEvent = createRemoteEvent("MatchResultEvent")
local RematchEvent     = createRemoteEvent("RematchEvent")

-- 保留现有事件（由 MatchSystem 创建，这里等待获取引用）
local MatchStateEvent  = nil -- 延迟获取
local DeathTimerEvent  = nil -- 延迟获取

-- ========== 游戏数据 ==========
local gameData = {
	state = GameState.WAITING,
	players = {},            -- { [Player] = { team, heroId, locked, kills, deaths, damageDealt } }
	rematchReady = {},       -- { [Player] = true }
	heroSelectTimer = nil,   -- 选英雄倒计时 task
	resultTimer = nil,       -- 结算倒计时 task
}

-- ========== 英雄选择默认池 ==========
local DEFAULT_HEROES = { "Angela", "Lux", "HouYi", "LianPo" }

-- ========== Teams 引用（由 MatchSystem 创建） ==========
local redTeam = nil
local blueTeam = nil

local function waitForTeams()
	redTeam = Teams:WaitForChild("RedTeam", 10)
	blueTeam = Teams:WaitForChild("BlueTeam", 10)
	if not redTeam or not blueTeam then
		warn("[GameManager] Teams not found! Creating...")
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
	end
end

-- ========== 状态转换 ==========
local function canTransition(from, to)
	return TRANSITIONS[from] and TRANSITIONS[from][to] == true
end

local function setState(newState, data)
	local oldState = gameData.state
	if not canTransition(oldState, newState) then
		warn(("[GameManager] Invalid transition: %s → %s"):format(oldState, newState))
		return false
	end

	gameData.state = newState
	print(("[GameManager] State: %s → %s"):format(oldState, newState))

	-- 广播给所有客户端
	GameStateEvent:FireAllClients({
		state = newState,
		data = data or {},
	})

	return true
end

-- ========== 工具函数 ==========
local function getPlayerCount()
	local count = 0
	for p, _ in pairs(gameData.players) do
		if p and p.Parent then
			count = count + 1
		end
	end
	return count
end

local function getActivePlayers()
	local list = {}
	for p, _ in pairs(gameData.players) do
		if p and p.Parent then
			table.insert(list, p)
		end
	end
	return list
end

local function allPlayersLocked()
	for p, pData in pairs(gameData.players) do
		if p and p.Parent and not pData.locked then
			return false
		end
	end
	return true
end

-- ========== WAITING 阶段 ==========
local function enterWaiting()
	-- 清理上一局数据
	gameData.rematchReady = {}
	for p, pData in pairs(gameData.players) do
		if p and p.Parent then
			pData.heroId = nil
			pData.locked = false
			pData.kills = 0
			pData.deaths = 0
			pData.damageDealt = 0
			pData.team = nil
			p.Team = nil
		end
	end

	-- 清理角色
	for p, _ in pairs(gameData.players) do
		if p and p.Parent and p.Character then
			p.Character:Destroy()
		end
	end

	-- 如果人数已够直接进入 HERO_SELECT
	if getPlayerCount() >= REQUIRED_PLAYERS then
		task.defer(function()
			enterHeroSelect()
		end)
	end
end

-- ========== HERO_SELECT 阶段 ==========
local function assignTeams()
	local activePlayers = getActivePlayers()
	-- 按加入顺序交替分配（1→红, 2→蓝, 3→红...）
	for i, p in ipairs(activePlayers) do
		local pData = gameData.players[p]
		if pData then
			if i % 2 == 1 then
				pData.team = "RedTeam"
				p.Team = redTeam
			else
				pData.team = "BlueTeam"
				p.Team = blueTeam
			end
			print(("[GameManager] %s → %s"):format(p.Name, pData.team))
		end
	end
end

local function randomHeroForPlayer(p)
	local pData = gameData.players[p]
	if pData and not pData.locked then
		local randomHero = DEFAULT_HEROES[math.random(1, #DEFAULT_HEROES)]
		pData.heroId = randomHero
		pData.locked = true
		print(("[GameManager] %s auto-assigned hero: %s"):format(p.Name, randomHero))
		-- 通知所有客户端该玩家已锁定
		HeroSelectEvent:FireAllClients({
			action = "player_locked",
			playerId = p.UserId,
			playerName = p.Name,
		})
	end
end

function enterHeroSelect()
	if gameData.state ~= GameState.WAITING then return end
	if getPlayerCount() < REQUIRED_PLAYERS then return end

	-- 分配阵营
	assignTeams()

	-- 重置选择状态
	for p, pData in pairs(gameData.players) do
		if p and p.Parent then
			pData.heroId = nil
			pData.locked = false
		end
	end

	setState(GameState.HERO_SELECT, {
		heroSelectTime = HERO_SELECT_TIME,
		players = (function()
			local info = {}
			for p, pData in pairs(gameData.players) do
				if p and p.Parent then
					table.insert(info, {
						playerId = p.UserId,
						playerName = p.Name,
						team = pData.team,
					})
				end
			end
			return info
		end)(),
	})

	-- 倒计时
	gameData.heroSelectTimer = task.delay(HERO_SELECT_TIME, function()
		if gameData.state ~= GameState.HERO_SELECT then return end

		-- 超时：为未锁定的玩家随机分配
		for p, _ in pairs(gameData.players) do
			if p and p.Parent then
				randomHeroForPlayer(p)
			end
		end

		-- 进入 LOADING
		enterLoading()
	end)
end

-- ========== LOADING 阶段 ==========
local function spawnCharacter(p, spawnPos)
	-- 加载角色
	p:LoadCharacter()

	-- 等待角色完全加载
	local character = p.Character or p.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if rootPart then
		-- 等一帧确保物理引擎就绪后再传送
		task.wait()
		rootPart.CFrame = CFrame.new(spawnPos)
	end

	return character
end

local function equipHeroSkills(p, heroId)
	-- 服务端技能装备由客户端通过 EquipSkillEvent:FireServer 完成
	-- 这里只验证 HeroConfig 数据的完整性并记录日志
	local HeroConfig = require(ReplicatedStorage:WaitForChild("HeroConfig"))
	local heroData = HeroConfig[heroId]
	if not heroData or not heroData.Skills then
		warn(("[GameManager] HeroConfig missing for %s"):format(heroId))
		return
	end

	local skillKeys = {}
	for k, _ in pairs(heroData.Skills) do table.insert(skillKeys, k) end
	print(("[GameManager] %s hero ready: %s (skills: %s)"):format(
		p.Name, heroId, table.concat(skillKeys, "/")
	))
end

function enterLoading()
	if gameData.state ~= GameState.HERO_SELECT then return end

	-- 取消选英雄倒计时（pcall 防止已结束线程报错）
	if gameData.heroSelectTimer then
		pcall(task.cancel, gameData.heroSelectTimer)
		gameData.heroSelectTimer = nil
	end

	-- 构建加载数据
	local loadingData = {}
	for p, pData in pairs(gameData.players) do
		if p and p.Parent then
			table.insert(loadingData, {
				playerId = p.UserId,
				playerName = p.Name,
				team = pData.team,
				heroId = pData.heroId,
			})
		end
	end

	setState(GameState.LOADING, {
		players = loadingData,
	})

	-- 为每个玩家生成角色、装备技能
	local spawnTasks = {}
	for p, pData in pairs(gameData.players) do
		if p and p.Parent then
			local spawnPos = SPAWN_POINTS[pData.team] or Vector3.new(0, 5, 0)
			table.insert(spawnTasks, task.spawn(function()
				local ok, err = pcall(function()
					spawnCharacter(p, spawnPos)
					if pData.heroId then
						equipHeroSkills(p, pData.heroId)
					end
				end)
				if not ok then
					warn(("[GameManager] Failed to spawn %s: %s"):format(p.Name, tostring(err)))
				end
			end))
		end
	end

	-- 等待所有角色就绪（最多10秒）
	local waitStart = tick()
	while tick() - waitStart < 10 do
		local allReady = true
		for p, _ in pairs(gameData.players) do
			if p and p.Parent then
				local char = p.Character
				if not char or not char:FindFirstChild("HumanoidRootPart") then
					allReady = false
					break
				end
			end
		end
		if allReady then break end
		task.wait(0.5)
	end

	-- 进入 BATTLE
	enterBattle()
end

-- ========== BATTLE 阶段 ==========
function enterBattle()
	if gameData.state ~= GameState.LOADING then return end

	setState(GameState.BATTLE, {
		countdown = BATTLE_COUNTDOWN,
	})

	-- 广播倒计时开始
	BattleStartEvent:FireAllClients({ countdown = BATTLE_COUNTDOWN })

	-- 倒计时后正式开战
	task.delay(BATTLE_COUNTDOWN, function()
		if gameData.state ~= GameState.BATTLE then return end

		-- 通知客户端倒计时结束，解锁操作
		BattleStartEvent:FireAllClients({ countdown = 0 })
		print("[GameManager] Battle started!")

		-- 通知 MatchSystem 开始战斗追踪
		if shared.MatchSystem then
			shared.MatchSystem.StartBattle()
		end
	end)
end

-- ========== RESULT 阶段 ==========
function enterResult(winnerTeam)
	if gameData.state ~= GameState.BATTLE then return end

	-- 停止 MatchSystem 战斗追踪
	if shared.MatchSystem then
		shared.MatchSystem.EndBattle()
	end

	-- 收集结算数据
	local playerStats = {}
	for p, pData in pairs(gameData.players) do
		if p and p.Parent then
			table.insert(playerStats, {
				playerId = p.UserId,
				playerName = p.Name,
				team = pData.team,
				heroId = pData.heroId or "Unknown",
				kills = pData.kills or 0,
				deaths = pData.deaths or 0,
				damageDealt = pData.damageDealt or 0,
			})
		end
	end

	setState(GameState.RESULT, {
		winner = winnerTeam,
		players = playerStats,
	})

	-- 发送结算数据
	MatchResultEvent:FireAllClients({
		winner = winnerTeam,
		players = playerStats,
	})

	-- 结算倒计时后检查重开
	gameData.resultTimer = task.delay(RESULT_DURATION, function()
		if gameData.state ~= GameState.RESULT then return end
		-- 超时自动回到 WAITING
		resetToWaiting()
	end)
end

local function resetToWaiting()
	-- 取消定时器
	if gameData.resultTimer then
		task.cancel(gameData.resultTimer)
		gameData.resultTimer = nil
	end

	-- 重置 MatchSystem
	if shared.MatchSystem then
		shared.MatchSystem.ResetMatch()
	end

	-- 清理角色
	for p, _ in pairs(gameData.players) do
		if p and p.Parent and p.Character then
			p.Character:Destroy()
		end
	end

	setState(GameState.WAITING, {
		playerCount = getPlayerCount(),
		requiredPlayers = REQUIRED_PLAYERS,
	})

	enterWaiting()
end

-- ========== 击杀/死亡/伤害追踪（供 MatchSystem 回调） ==========
local function onPlayerKill(killer, victim)
	if gameData.state ~= GameState.BATTLE then return end
	if not killer or not victim then return end

	local killerData = gameData.players[killer]
	local victimData = gameData.players[victim]

	if killerData then
		killerData.kills = (killerData.kills or 0) + 1
	end
	if victimData then
		victimData.deaths = (victimData.deaths or 0) + 1
	end

	-- 检查胜利条件
	if killerData and killerData.kills >= KILLS_TO_WIN then
		local winnerTeam = killerData.team or "Unknown"
		print(("[GameManager] %s wins! Team: %s"):format(killer.Name, winnerTeam))
		enterResult(winnerTeam)
	end
end

local function onPlayerDamage(attacker, victim, damage)
	if gameData.state ~= GameState.BATTLE then return end
	if not attacker then return end

	local attackerData = gameData.players[attacker]
	if attackerData then
		attackerData.damageDealt = (attackerData.damageDealt or 0) + damage
	end
end

-- ========== RemoteEvent 处理 ==========

-- 英雄选择事件
HeroSelectEvent.OnServerEvent:Connect(function(player, data)
	if gameData.state ~= GameState.HERO_SELECT then return end
	if not data or type(data) ~= "table" then return end

	local pData = gameData.players[player]
	if not pData then return end

	-- 防止重复锁定
	if pData.locked then return end

	local heroId = data.heroId
	if type(heroId) ~= "string" or heroId == "" then return end

	-- 验证英雄ID是否有效
	local isValid = false
	for _, h in ipairs(DEFAULT_HEROES) do
		if h == heroId then
			isValid = true
			break
		end
	end
	-- 也允许 "Test" 英雄
	if heroId == "Test" then isValid = true end

	if not isValid then
		warn(("[GameManager] Invalid heroId from %s: %s"):format(player.Name, heroId))
		return
	end

	pData.heroId = heroId
	pData.locked = true
	print(("[GameManager] %s locked hero: %s"):format(player.Name, heroId))

	-- 广播锁定状态给所有客户端（不透露具体英雄）
	HeroSelectEvent:FireAllClients({
		action = "player_locked",
		playerId = player.UserId,
		playerName = player.Name,
	})

	-- 检查是否所有人都已锁定
	if allPlayersLocked() then
		enterLoading()
	end
end)

-- 重开事件
RematchEvent.OnServerEvent:Connect(function(player, data)
	if gameData.state ~= GameState.RESULT then return end
	if not data or type(data) ~= "table" then return end

	local action = data.action
	if action == "rematch" then
		gameData.rematchReady[player] = true
		-- 广播重开就绪状态
		RematchEvent:FireAllClients({
			playerId = player.UserId,
			ready = true,
		})

		-- 检查是否所有人都准备好重开
		local allReady = true
		for p, _ in pairs(gameData.players) do
			if p and p.Parent and not gameData.rematchReady[p] then
				allReady = false
				break
			end
		end
		if allReady then
			resetToWaiting()
		end

	elseif action == "leave" then
		-- 玩家选择离开
		player:Kick("感谢游玩！")
	end
end)

-- ========== 玩家加入/离开 ==========
local function onPlayerAdded(player)
	-- 注册玩家数据
	gameData.players[player] = {
		team = nil,
		heroId = nil,
		locked = false,
		kills = 0,
		deaths = 0,
		damageDealt = 0,
	}

	print(("[GameManager] Player joined: %s (total: %d/%d)"):format(
		player.Name, getPlayerCount(), REQUIRED_PLAYERS
	))

	-- 根据当前状态处理
	if gameData.state == GameState.WAITING then
		-- 广播更新人数
		GameStateEvent:FireAllClients({
			state = GameState.WAITING,
			data = {
				playerCount = getPlayerCount(),
				requiredPlayers = REQUIRED_PLAYERS,
			},
		})

		-- 人数到齐，进入选人
		if getPlayerCount() >= REQUIRED_PLAYERS then
			task.defer(function()
				enterHeroSelect()
			end)
		end
	else
		-- 非 WAITING 阶段加入的玩家，补发当前状态
		GameStateEvent:FireClient(player, {
			state = gameData.state,
			data = { message = "match_in_progress" },
		})
	end
end

local function onPlayerRemoving(player)
	local currentState = gameData.state
	gameData.players[player] = nil
	gameData.rematchReady[player] = nil

	print(("[GameManager] Player left: %s (total: %d/%d)"):format(
		player.Name, getPlayerCount(), REQUIRED_PLAYERS
	))

	if currentState == GameState.HERO_SELECT then
		-- 选人阶段有人离开 → 回到 WAITING
		if gameData.heroSelectTimer then
			task.cancel(gameData.heroSelectTimer)
			gameData.heroSelectTimer = nil
		end
		setState(GameState.WAITING, {
			playerCount = getPlayerCount(),
			requiredPlayers = REQUIRED_PLAYERS,
			message = "opponent_left",
		})
		enterWaiting()

	elseif currentState == GameState.BATTLE then
		-- 对战中有人离开 → 剩余玩家获胜
		local remainingPlayers = getActivePlayers()
		if #remainingPlayers > 0 then
			local winner = remainingPlayers[1]
			local winnerData = gameData.players[winner]
			local winnerTeam = winnerData and winnerData.team or "Unknown"
			enterResult(winnerTeam)
		else
			-- 所有人离开
			gameData.state = GameState.WAITING
			enterWaiting()
		end

	elseif currentState == GameState.RESULT then
		-- 结算阶段离开不影响，但检查是否触发重开
		local activePlayers = getActivePlayers()
		if #activePlayers == 0 then
			if gameData.resultTimer then
				task.cancel(gameData.resultTimer)
				gameData.resultTimer = nil
			end
			gameData.state = GameState.WAITING
			enterWaiting()
		end

	elseif currentState == GameState.LOADING then
		-- 加载阶段有人离开 → 回到 WAITING
		setState(GameState.WAITING, {
			playerCount = getPlayerCount(),
			requiredPlayers = REQUIRED_PLAYERS,
			message = "opponent_left",
		})
		enterWaiting()
	end
end

-- ========== 对外 API（供 MatchSystem 调用） ==========
local GameManager = {}

-- MatchSystem 通知击杀
function GameManager.NotifyKill(killer, victim)
	onPlayerKill(killer, victim)
end

-- MatchSystem 通知伤害
function GameManager.NotifyDamage(attacker, victim, damage)
	onPlayerDamage(attacker, victim, damage)
end

-- 获取当前游戏状态
function GameManager.GetState()
	return gameData.state
end

-- 获取配置
function GameManager.GetConfig()
	return {
		requiredPlayers = REQUIRED_PLAYERS,
		killsToWin = KILLS_TO_WIN,
		respawnTime = RESPAWN_TIME,
	}
end

-- 通过 shared 表暴露 API（Roblox 中 ServerScript 间通信的常见做法）
-- 注意：shared 是全局表，仅限服务端脚本间使用
shared.GameManager = GameManager

-- ========== 初始化 ==========
waitForTeams()

-- 禁用自动重生（由 GameManager 控制角色生成时机）
Players.CharacterAutoLoads = false

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 处理脚本启动时已在服务器的玩家
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

print(("[GameManager] Game Manager initialized! Required players: %d (Studio: %s)"):format(
	REQUIRED_PLAYERS, tostring(IS_STUDIO)
))
