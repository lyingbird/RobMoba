-- ==========================================
-- 对战系统 (Match System)
-- 职责：阵营分配、死亡重生、击杀计数、胜负判定
-- ==========================================
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========== 配置 ==========
local KILLS_TO_WIN = 3           -- 先达到此击杀数获胜
local RESPAWN_TIME = 5           -- 死亡后重生倒计时（秒）

-- ========== 创建 Teams ==========
local redTeam = Instance.new("Team")
redTeam.Name = "RedTeam"
redTeam.TeamColor = BrickColor.new("Bright red")
redTeam.AutoAssignable = false
redTeam.Parent = Teams

local blueTeam = Instance.new("Team")
blueTeam.Name = "BlueTeam"
blueTeam.TeamColor = BrickColor.new("Bright blue")
blueTeam.AutoAssignable = false
blueTeam.Parent = Teams

-- ========== 创建 RemoteEvents ==========
local MatchStateEvent = Instance.new("RemoteEvent")
MatchStateEvent.Name = "MatchStateEvent"
MatchStateEvent.Parent = ReplicatedStorage

local DeathTimerEvent = Instance.new("RemoteEvent")
DeathTimerEvent.Name = "DeathTimerEvent"
DeathTimerEvent.Parent = ReplicatedStorage

-- ========== 状态变量 ==========
local killCount = {} -- { [Player] = number }
local matchEnded = false

-- ========== 禁用自动重生（自定义重生流程） ==========
Players.CharacterAutoLoads = false

-- ========== 阵营分配 ==========
local function assignTeam(player)
	local redCount = #redTeam:GetPlayers()
	local blueCount = #blueTeam:GetPlayers()

	if redCount <= blueCount then
		player.Team = redTeam
	else
		player.Team = blueTeam
	end

	print(("[MatchSystem] %s assigned to %s"):format(player.Name, player.Team.Name))
end

-- ========== 通知所有客户端当前比赛状态 ==========
local function broadcastMatchState()
	-- Aggregate kills by team
	local teamKills = {}
	teamKills[redTeam.Name] = 0
	teamKills[blueTeam.Name] = 0

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
	if matchEnded then return end

	local kills = killCount[killer] or 0
	if kills >= KILLS_TO_WIN then
		matchEnded = true
		local winnerTeam = killer.Team and killer.Team.Name or "Unknown"
		print(("[MatchSystem] %s wins! Team: %s"):format(killer.Name, winnerTeam))

		-- Aggregate final kills by team
		local teamKills = {}
		teamKills[redTeam.Name] = 0
		teamKills[blueTeam.Name] = 0
		for p, k in pairs(killCount) do
			if p and p.Parent and p.Team then
				teamKills[p.Team.Name] = (teamKills[p.Team.Name] or 0) + k
			end
		end

		MatchStateEvent:FireAllClients("match_end", {
			winner = killer.Name,
			winnerTeam = winnerTeam,
			kills = teamKills,
		})
	end
end

-- ========== 死亡处理 ==========
local function onCharacterDied(player)
	if matchEnded then return end

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
		if player and player.Parent and not matchEnded then
			DeathTimerEvent:FireClient(player, "death_end", {})
			player:LoadCharacter()
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

-- ========== 玩家加入 ==========
local function onPlayerAdded(player)
	-- 分配阵营
	assignTeam(player)

	-- 初始化击杀数
	killCount[player] = 0

	-- 角色加载时的设置
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)

	-- 加载角色（因为禁用了 AutoLoads，需要手动触发）
	player:LoadCharacter()

	-- 通知所有客户端更新
	broadcastMatchState()
end

-- ========== 玩家离开 ==========
local function onPlayerRemoving(player)
	killCount[player] = nil
	broadcastMatchState()
end

-- ========== 初始化 ==========
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 处理脚本启动时已在服务器的玩家
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

print("[MatchSystem] Match system initialized! Kills to win:", KILLS_TO_WIN)
