-- ==========================================
-- 对战系统 (Match System) — 战斗阶段辅助
-- 职责：击杀计数、死亡重生、胜负判定、伤害统计追踪
-- 注意：阵营分配和角色生成由 GameManager 控制
-- ==========================================
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== 配置（从 GameManager 获取） ==========
local KILLS_TO_WIN = 3           -- 先达到此击杀数获胜
local RESPAWN_TIME = 5           -- 死亡后重生倒计时（秒）

-- ========== Teams 引用 ==========
local redTeam = Teams:WaitForChild("RedTeam", 10)
local blueTeam = Teams:WaitForChild("BlueTeam", 10)

-- ========== 创建 RemoteEvents ==========
local MatchStateEvent = Instance.new("RemoteEvent")
MatchStateEvent.Name = "MatchStateEvent"
MatchStateEvent.Parent = ReplicatedStorage

local DeathTimerEvent = Instance.new("RemoteEvent")
DeathTimerEvent.Name = "DeathTimerEvent"
DeathTimerEvent.Parent = ReplicatedStorage

-- ========== 竞技场出生点（与 DuelManager 保持一致） ==========
local ARENA_CENTER = Vector3.new(0, 62, 0)
local SPAWN_DISTANCE = 40
local ARENA_SPAWNS = {
	RedTeam  = ARENA_CENTER + Vector3.new(-SPAWN_DISTANCE, 0, 0),
	BlueTeam = ARENA_CENTER + Vector3.new(SPAWN_DISTANCE, 0, 0),
}

-- ========== 状态变量 ==========
local killCount = {} -- { [Player] = number }
local matchActive = false

-- ========== 注意: CharacterAutoLoads 保持默认 true，大厅模式需要角色自动加载 ==========

-- ========== 通知所有客户端当前比赛状态 ==========
local function broadcastMatchState()
	-- Aggregate kills by team
	local teamKills = {}
	if redTeam then teamKills[redTeam.Name] = 0 end
	if blueTeam then teamKills[blueTeam.Name] = 0 end

	for p, kills in pairs(killCount) do
		if p and p.Parent and p.Team then
			teamKills[p.Team.Name] = (teamKills[p.Team.Name] or 0) + kills
		end
	end

	MatchStateEvent:FireAllClients("kill_update", {
		kills = teamKills,
	})
end

-- ========== 胜负判定 ==========
local function checkWinCondition(killer)
	if not matchActive then return end

	local kills = killCount[killer] or 0
	if kills >= KILLS_TO_WIN then
		matchActive = false
		local winnerTeam = killer.Team and killer.Team.Name or "Unknown"
		print(("[MatchSystem] %s wins! Team: %s"):format(killer.Name, winnerTeam))

		-- 胜负判定由 GameManager 处理（GameManager.onPlayerKill 中已有 enterResult 逻辑）
		-- 注意：不在这里再次调用 NotifyKill，避免重复计数
		-- onCharacterDied 中已经调用过 NotifyKill 了

		-- 发送兼容的 kill_update（最终状态），但不发 match_end
		-- match_end 由 GameManager 通过 MatchResultEvent 替代
		broadcastMatchState()
	end
end

-- ========== 死亡处理 ==========
local function onCharacterDied(player)
	if not matchActive then return end

	-- 获取击杀者（通过 LastDamagePlayer Attribute 追踪）
	local character = player.Character
	local killerName = character and character:GetAttribute("LastDamagePlayer") or nil
	local killer = killerName and Players:FindFirstChild(killerName) or nil

	if killer and killer ~= player then
		killCount[killer] = (killCount[killer] or 0) + 1
		print(("[MatchSystem] %s killed %s! (%d kills)"):format(
			killer.Name, player.Name, killCount[killer]
		))

		-- 通知 GameManager 记录击杀
		if shared.GameManager then
			shared.GameManager.NotifyKill(killer, player)
		end

		broadcastMatchState()
		checkWinCondition(killer)
	else
		-- 自杀或未知击杀者，仍然通知 GameManager 记录死亡
		if shared.GameManager then
			shared.GameManager.NotifyKill(nil, player)
		end
	end

	-- 发送死亡倒计时给客户端
	DeathTimerEvent:FireClient(player, "death_start", { respawnTime = RESPAWN_TIME })

	-- 倒计时后重生
	task.delay(RESPAWN_TIME, function()
		if player and player.Parent and matchActive then
			DeathTimerEvent:FireClient(player, "death_end", {})
			player:LoadCharacter()

			-- 等待角色加载完成，传送到竞技场对应出生点
			local character = player.Character or player.CharacterAdded:Wait()
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if rootPart and player.Team then
				local spawnPos = ARENA_SPAWNS[player.Team.Name]
				if spawnPos then
					task.wait() -- 等一帧确保物理引擎就绪
					rootPart.CFrame = CFrame.new(spawnPos)
				end
			end
		end
	end)
end

-- ========== 角色初始化 ==========
local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")

	-- 清除上一次的伤害来源记录
	character:SetAttribute("LastDamagePlayer", nil)

	-- 监听死亡
	humanoid.Died:Connect(function()
		onCharacterDied(player)
	end)
end

-- ========== 玩家角色加载监听 ==========
local function onPlayerAdded(player)
	-- 初始化击杀数
	killCount[player] = 0

	-- 角色加载时的设置
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)

	-- 注意：不再自动 LoadCharacter 和分配阵营
	-- 这些由 GameManager 控制

	broadcastMatchState()
end

-- ========== 玩家离开 ==========
local function onPlayerRemoving(player)
	killCount[player] = nil
	broadcastMatchState()
end

-- ========== 对外 API（供 GameManager 调用） ==========
-- 通过 shared 表暴露

local MatchSystemAPI = {}

-- 开始战斗追踪
function MatchSystemAPI.StartBattle()
	matchActive = true
	-- 重置击杀计数
	for p, _ in pairs(killCount) do
		killCount[p] = 0
	end
	for _, p in ipairs(Players:GetPlayers()) do
		killCount[p] = killCount[p] or 0
	end
	broadcastMatchState()
	print("[MatchSystem] Battle tracking started!")
end

-- 结束战斗追踪
function MatchSystemAPI.EndBattle()
	matchActive = false
	print("[MatchSystem] Battle tracking ended!")
end

-- 重置比赛
function MatchSystemAPI.ResetMatch()
	matchActive = false
	for p, _ in pairs(killCount) do
		killCount[p] = 0
	end
	broadcastMatchState()
	print("[MatchSystem] Match reset!")
end

-- 获取击杀数据
function MatchSystemAPI.GetKillCount()
	return killCount
end

shared.MatchSystem = MatchSystemAPI

-- ========== 初始化 ==========
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 处理脚本启动时已在服务器的玩家
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

-- 默认开启战斗追踪（当 GameManager 发出 BATTLE 状态时由 GameManager 调用 StartBattle）
-- 为了向后兼容，如果 GameManager 未加载，默认 matchActive = true
task.delay(5, function()
	if shared.GameManager then
		-- GameManager 存在，由它控制
		print("[MatchSystem] GameManager detected, waiting for battle start signal")
	else
		-- 兼容模式：无 GameManager 时自动激活
		matchActive = true
		print("[MatchSystem] No GameManager detected, auto-activating battle tracking")
	end
end)

print("[MatchSystem] Match system initialized! Kills to win:", KILLS_TO_WIN)
