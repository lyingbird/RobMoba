-- ==========================================
-- 对战系统 (Match System) — 战斗阶段辅助
-- 职责：击杀/死亡/伤害统计、死亡重生、达成击杀线时通知 DuelManager 判负
-- 生命周期由 DuelManager 驱动（StartBattle/EndBattle/ResetMatch）。
-- 注意：阵营分配与角色传送由 DuelManager 负责（GameManager 已弃用）。
-- ==========================================
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== 配置 ==========
local KILLS_TO_WIN = 3           -- 先达到此击杀数获胜
local RESPAWN_TIME = 5           -- 死亡后重生倒计时（秒）

-- ========== Teams 引用 ==========
local redTeam = Teams:WaitForChild("RedTeam", 10)
local blueTeam = Teams:WaitForChild("BlueTeam", 10)

-- ========== RemoteEvents ==========
local MatchStateEvent = ReplicatedStorage:WaitForChild("MatchStateEvent", 10)
local DeathTimerEvent = ReplicatedStorage:WaitForChild("DeathTimerEvent", 10)

-- ========== 竞技场出生点（与 DuelManager 保持一致） ==========
local ARENA_CENTER = Vector3.new(0, 62, 0)
local SPAWN_DISTANCE = 40
local ARENA_SPAWNS = {
	RedTeam  = ARENA_CENTER + Vector3.new(-SPAWN_DISTANCE, 0, 0),
	BlueTeam = ARENA_CENTER + Vector3.new(SPAWN_DISTANCE, 0, 0),
}

-- ========== 状态变量 ==========
local killCount = {}   -- { [Player] = number } 击杀数
local deathCount = {}  -- { [Player] = number } 死亡数
local damageDealt = {} -- { [Player] = number } 累计造成伤害
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

		-- 广播最终击杀状态
		broadcastMatchState()

		-- 事件驱动判负：通知 DuelManager 单点权威结算（取代旧的 0.5s 轮询）。
		-- endDuel 自带 duel.active 幂等保护，与掉线判负不会重复结算。
		if shared.DuelManager and shared.DuelManager.NotifyWin then
			shared.DuelManager.NotifyWin(killer)
		end
	end
end

-- ========== 死亡处理 ==========
local function onCharacterDied(player)
	if not matchActive then return end

	-- 记录死亡（结算面板用）
	deathCount[player] = (deathCount[player] or 0) + 1

	-- 获取击杀者（通过 LastDamagePlayer Attribute 追踪）
	local character = player.Character
	local killerName = character and character:GetAttribute("LastDamagePlayer") or nil
	local killer = killerName and Players:FindFirstChild(killerName) or nil

	if killer and killer ~= player then
		killCount[killer] = (killCount[killer] or 0) + 1
		print(("[MatchSystem] %s killed %s! (%d kills)"):format(
			killer.Name, player.Name, killCount[killer]
		))

		broadcastMatchState()
		checkWinCondition(killer)
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
	-- 初始化对局统计
	killCount[player] = 0
	deathCount[player] = 0
	damageDealt[player] = 0

	-- 角色加载时的设置
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)

	-- 注意：不再自动 LoadCharacter 和分配阵营
	-- 阵营分配与传送由 DuelManager 负责

	broadcastMatchState()
end

-- ========== 玩家离开 ==========
local function onPlayerRemoving(player)
	killCount[player] = nil
	deathCount[player] = nil
	damageDealt[player] = nil
	broadcastMatchState()
end

-- ========== 对外 API（供 DuelManager 调用） ==========
-- 通过 shared 表暴露

local MatchSystemAPI = {}

local function resetStats()
	table.clear(killCount)
	table.clear(deathCount)
	table.clear(damageDealt)
	for _, p in ipairs(Players:GetPlayers()) do
		killCount[p] = 0
		deathCount[p] = 0
		damageDealt[p] = 0
	end
end

-- 开始战斗追踪
function MatchSystemAPI.StartBattle()
	resetStats()
	matchActive = true
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
	resetStats()
	broadcastMatchState()
	print("[MatchSystem] Match reset!")
end

-- 记录玩家造成的伤害（由 EffectExecutor / AutoAttackManager 在实际造成伤害时调用）
function MatchSystemAPI.RecordDamage(attacker, amount)
	if not matchActive then return end
	if not attacker or not amount or amount <= 0 then return end
	damageDealt[attacker] = (damageDealt[attacker] or 0) + amount
end

-- 获取击杀数据（向后兼容）
function MatchSystemAPI.GetKillCount()
	return killCount
end

-- 获取完整对局统计 { [Player] = { kills, deaths, damage } }
function MatchSystemAPI.GetMatchStats()
	local stats = {}
	for _, p in ipairs(Players:GetPlayers()) do
		stats[p] = {
			kills = killCount[p] or 0,
			deaths = deathCount[p] or 0,
			damage = damageDealt[p] or 0,
		}
	end
	return stats
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

-- matchActive 仅由 DuelManager 在对决开始/结束时通过 StartBattle/EndBattle 控制。
-- 大厅/训练场期间保持 false，避免误把大厅死亡当作对局击杀统计。

print("[MatchSystem] Match system initialized! Kills to win:", KILLS_TO_WIN)
