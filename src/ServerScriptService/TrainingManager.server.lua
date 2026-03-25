-- ==========================================
-- TrainingManager.server.lua
-- 职责: 训练场模式管理 — 无CD/回满/假人/等级/重置
-- REQ-009: 训练场模式（Training Ground）
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- 等待 RemoteEventInit 创建完成
task.wait(0.5)

local TrainingEvent = ReplicatedStorage:WaitForChild("TrainingEvent", 10)
local TrainingSyncEvent = ReplicatedStorage:WaitForChild("TrainingSyncEvent", 10)
local SyncCooldownEvent = ReplicatedStorage:FindFirstChild("SyncCooldownEvent")

-- 延迟加载服务端模块（避免初始化顺序问题）
local StatsManager, BuffSystem, EnergySystem
local function getStatsManager()
	if not StatsManager then
		StatsManager = require(ServerScriptService.ServerModules:WaitForChild("StatsManager"))
	end
	return StatsManager
end
local function getBuffSystem()
	if not BuffSystem then
		BuffSystem = require(ServerScriptService.ServerModules:WaitForChild("BuffSystem"))
	end
	return BuffSystem
end
local function getEnergySystem()
	if not EnergySystem then
		EnergySystem = require(ServerScriptService.ServerModules:WaitForChild("EnergySystem"))
	end
	return EnergySystem
end

-- ========== 常量 ==========
local MAX_DUMMIES_PER_PLAYER = 3
local RATE_LIMIT_INTERVAL = 0.2 -- 秒
local SPAWN_POINT = Vector3.new(-197, 62.5, 204)
local DUMMY_HP = 10000
local DUMMY_REGEN_INTERVAL = 5 -- 秒

-- ========== 数据结构 ==========
local trainingStates = {} -- [Player] = { noCooldown: bool, noCost: bool }
local dummies = {}        -- [Player] = { Model[] }
local lastActionTime = {} -- [Player] = number (rate limit)

-- ========== 工具函数 ==========
local function getPlayerState(player)
	if shared.LobbyManager then
		return shared.LobbyManager.GetPlayerState(player)
	end
	return "LOBBY"
end

local function isInLobby(player)
	return getPlayerState(player) == "LOBBY"
end

local function rateLimitCheck(player)
	local now = os.clock()
	local last = lastActionTime[player] or 0
	if now - last < RATE_LIMIT_INTERVAL then
		return false
	end
	lastActionTime[player] = now
	return true
end

local function syncState(player)
	if not TrainingSyncEvent then return end
	local state = trainingStates[player] or {}
	local playerDummies = dummies[player] or {}
	TrainingSyncEvent:FireClient(player, {
		noCooldown = state.noCooldown or false,
		dummyCount = #playerDummies,
		level = player.Character and player.Character:GetAttribute("Level") or 1,
		panelVisible = isInLobby(player),
	})
end

-- ========== F1: 开关技能冷却 ==========
local function toggleCD(player, enabled)
	if not isInLobby(player) then return end

	local state = trainingStates[player]
	if not state then return end

	state.noCooldown = enabled == true
	state.noCost = enabled == true

	-- 开启或关闭时: 都通知客户端重置所有技能CD状态
	-- 关闭时同样需要发送，让客户端清除可能卡住的 _casting 锁
	if SyncCooldownEvent then
		SyncCooldownEvent:FireClient(player, "ALL", 0, 0)
	end

	syncState(player)
end

-- ========== F2: 刷新HP/MP ==========
local function refreshHP(player)
	if not isInLobby(player) then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- HP 回满
	humanoid.Health = humanoid.MaxHealth
	character:SetAttribute("HP", math.floor(humanoid.MaxHealth))

	-- MP 回满
	local maxMP = character:GetAttribute("MaxMP") or 500
	character:SetAttribute("MP", maxMP)

	-- 能量回满
	local energy = getEnergySystem()
	local energyState = energy:GetEnergy(player)
	if energyState.energyType ~= "None" then
		energy:AddEnergy(player, energyState.max, "training_refill")
	end

	-- 清除所有负面 Buff
	getBuffSystem():RemoveAllEffects(character)
end

-- ========== F3: 训练假人 ==========
local function createDummyModel(position)
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	-- HumanoidRootPart
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.CFrame = CFrame.new(position)
	rootPart.Anchored = true
	rootPart.CanCollide = true
	rootPart.BrickColor = BrickColor.new("Medium stone grey")
	rootPart.Parent = model

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0))
	head.Anchored = true
	head.CanCollide = false
	head.BrickColor = BrickColor.new("Medium stone grey")
	head.Parent = model

	-- Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	torso.Anchored = true
	torso.CanCollide = false
	torso.BrickColor = BrickColor.new("Medium stone grey")
	torso.Parent = model

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = DUMMY_HP
	humanoid.Health = DUMMY_HP
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.PrimaryPart = rootPart

	-- REQ-010: 标记为训练假人（CombatUtils.isEnemy 用此属性识别）
	model:SetAttribute("IsTrainingDummy", true)

	-- BillboardGui 血条
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.new(0, 80, 0, 12)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = head

	local bgBar = Instance.new("Frame")
	bgBar.Name = "Background"
	bgBar.Size = UDim2.new(1, 0, 1, 0)
	bgBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bgBar.BorderSizePixel = 0
	bgBar.Parent = billboard

	local fillBar = Instance.new("Frame")
	fillBar.Name = "Fill"
	fillBar.Size = UDim2.new(1, 0, 1, 0)
	fillBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	fillBar.BorderSizePixel = 0
	fillBar.Parent = bgBar

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 16)
	nameLabel.Position = UDim2.new(0, 0, 0, -18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "🎯 训练假人"
	nameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard

	-- 不死机制 + 血条更新 + 伤害飘字（REQ-010）
	local previousHealth = DUMMY_HP
	humanoid.HealthChanged:Connect(function(health)
		if health <= 1 then
			humanoid.Health = 1
		end
		-- 更新血条
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		fillBar.Size = UDim2.new(ratio, 0, 1, 0)

		-- 伤害飘字
		local damage = previousHealth - health
		previousHealth = math.max(health, 1) -- 同步 previousHealth（不死机制钳位后）

		if damage > 0 and rootPart and rootPart.Parent then
			local randomX = (math.random() - 0.5) * 3
			local startY = math.random(3, 5)

			local dmgGui = Instance.new("BillboardGui")
			dmgGui.Name = "DamageNumber"
			dmgGui.Size = UDim2.new(3, 0, 1.5, 0)
			dmgGui.StudsOffset = Vector3.new(randomX, startY, 0)
			dmgGui.AlwaysOnTop = true
			dmgGui.Parent = rootPart

			local dmgLabel = Instance.new("TextLabel")
			dmgLabel.Size = UDim2.new(1, 0, 1, 0)
			dmgLabel.BackgroundTransparency = 1
			dmgLabel.Text = tostring(math.floor(damage))
			dmgLabel.Font = Enum.Font.GothamBold
			dmgLabel.TextScaled = false
			dmgLabel.TextSize = damage >= 200 and 28 or (damage >= 100 and 24 or 20)
			dmgLabel.TextColor3 = damage >= 200 and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 255, 255)
			dmgLabel.TextStrokeTransparency = 0.3
			dmgLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			dmgLabel.TextTransparency = 0
			dmgLabel.Parent = dmgGui

			-- Float upward and fade out
			local endY = startY + math.random(2, 3)
			TweenService:Create(dmgGui, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffset = Vector3.new(randomX, endY, 0)
			}):Play()
			TweenService:Create(dmgLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
				TextStrokeTransparency = 1
			}):Play()

			Debris:AddItem(dmgGui, 1)
		end
	end)

	-- HP 回满循环
	task.spawn(function()
		while model.Parent do
			task.wait(DUMMY_REGEN_INTERVAL)
			if model.Parent and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
		end
	end)

	return model
end

local function spawnDummy(player)
	if not isInLobby(player) then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- 初始化假人列表
	if not dummies[player] then
		dummies[player] = {}
	end

	-- 超过上限 → 移除最早的
	if #dummies[player] >= MAX_DUMMIES_PER_PLAYER then
		local oldest = table.remove(dummies[player], 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end

	-- 在玩家前方 10 studs 生成
	local spawnPos = rootPart.Position + rootPart.CFrame.LookVector * 10
	local dummy = createDummyModel(spawnPos)
	dummy.Parent = workspace

	table.insert(dummies[player], dummy)
	syncState(player)
end

local function clearDummies(player)
	local playerDummies = dummies[player]
	if not playerDummies then return end

	for _, dummy in ipairs(playerDummies) do
		if dummy and dummy.Parent then
			dummy:Destroy()
		end
	end
	dummies[player] = {}

	syncState(player)
end

-- ========== F4: 等级调整 ==========
local function setLevel(player, level)
	if not isInLobby(player) then return end
	if typeof(level) ~= "number" then return end

	local stats = getStatsManager()
	stats.SetLevel(player, level)

	-- 能量系统同步等级
	local energy = getEnergySystem()
	energy:OnLevelUp(player, level)

	syncState(player)
end

-- ========== F5: 重置位置 ==========
local function resetPosition(player)
	if not isInLobby(player) then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- 传送到出生点
	character:PivotTo(CFrame.new(SPAWN_POINT))

	-- 附带 F2: 回满
	refreshHP(player)
end

-- ========== 训练状态重置 (进入匹配/对决时) ==========
local function resetTrainingState(player)
	local state = trainingStates[player]
	if state then
		state.noCooldown = false
		state.noCost = false
	end
	clearDummies(player)

	-- 重置等级为 1
	local character = player.Character
	if character then
		local stats = getStatsManager()
		stats.SetLevel(player, 1)
	end

	syncState(player)
end

-- ========== RemoteEvent 处理 ==========
local function onTrainingAction(player, data)
	if not data or typeof(data) ~= "table" then return end
	if not data.action or typeof(data.action) ~= "string" then return end

	-- LOBBY 状态验证
	if not isInLobby(player) then return end

	-- Rate limit
	if not rateLimitCheck(player) then return end

	-- 必须已选英雄 (除了 clearDummies 和 resetPos)
	local heroRequired = data.action ~= "clearDummies"
	if heroRequired then
		local heroId = shared.LobbyManager and shared.LobbyManager.GetPlayerHero(player)
		if not heroId and data.action ~= "resetPos" then
			return
		end
	end

	if data.action == "toggleCD" then
		toggleCD(player, data.enabled)
	elseif data.action == "refreshHP" then
		refreshHP(player)
	elseif data.action == "spawnDummy" then
		spawnDummy(player)
	elseif data.action == "clearDummies" then
		clearDummies(player)
	elseif data.action == "setLevel" then
		setLevel(player, data.level)
	elseif data.action == "resetPos" then
		resetPosition(player)
	end
end

if TrainingEvent then
	TrainingEvent.OnServerEvent:Connect(onTrainingAction)
end

-- ========== 玩家生命周期 ==========
local function onPlayerAdded(player)
	trainingStates[player] = {
		noCooldown = false,
		noCost = false,
	}
	dummies[player] = {}

	-- 延迟同步（等 Character 加载）
	task.delay(1, function()
		if player.Parent then
			syncState(player)
		end
	end)
end

local function onPlayerRemoving(player)
	clearDummies(player)
	trainingStates[player] = nil
	dummies[player] = nil
	lastActionTime[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

-- ========== 状态监听 (检测 LOBBY → MATCHING/DUELING) ==========
task.spawn(function()
	while true do
		task.wait(0.5)
		-- 收集需要重置的玩家（避免遍历中修改表）
		local toReset = {}
		for player, state in pairs(trainingStates) do
			if player.Parent and not isInLobby(player) then
				-- 玩家离开 LOBBY，检查是否有训练状态或假人需要清理
				local hasDummies = dummies[player] and #dummies[player] > 0
				if state.noCooldown or state.noCost or hasDummies then
					table.insert(toReset, player)
				end
			end
		end
		for _, player in ipairs(toReset) do
			resetTrainingState(player)
		end
	end
end)

-- ========== shared API ==========
shared.TrainingManager = {
	IsNoCooldown = function(player)
		local state = trainingStates[player]
		return state and state.noCooldown == true
	end,
	IsNoCost = function(player)
		local state = trainingStates[player]
		return state and state.noCost == true
	end,
	ResetTrainingState = function(player)
		resetTrainingState(player)
	end,
}

print("[TrainingManager] Training ground system initialized!")
