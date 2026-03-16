-- ==========================================
-- EnergySystem: 能量系统运行时管理器
-- 职责: 能量初始化/恢复/衰减/消耗/同步
-- 驱动方式: RunService.Heartbeat (自然恢复/怒气衰减/同步节流)
-- 运行位置: 服务端 (ServerScriptService)
-- ==========================================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnergyConfig = require(ReplicatedStorage:WaitForChild("EnergyConfig"))
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))

local EnergySystem = {}

-- ========== 数据结构 ==========
-- energyStates[player] = {
--   current = number,
--   max = number,
--   energyType = string ("Mana"/"Rage"/"Energy"/"None"),
--   config = EnergyConfig entry,
--   lastCombatTime = number,
--   lastSynced = number (last synced current value),
--   lastSyncTime = number,
--   level = number,
-- }
local energyStates = {}

-- SyncEnergyEvent — 延迟获取 (RemoteEventInit 先创建)
local SyncEnergyEvent = nil
local function getSyncEvent()
	if not SyncEnergyEvent then
		SyncEnergyEvent = ReplicatedStorage:WaitForChild("SyncEnergyEvent", 10)
	end
	return SyncEnergyEvent
end

-- ========== 同步常量 ==========
local SYNC_INTERVAL = 0.5      -- 最短同步间隔 (秒)
local SYNC_THRESHOLD = 0.05    -- 变化阈值 (5% of max)

-- ========== 内部工具 ==========

local function syncToClient(player, state)
	local event = getSyncEvent()
	if not event then return end

	local now = os.clock()
	local lastSync = state.lastSyncTime or 0
	local lastSynced = state.lastSynced or 0
	local max = state.max or 1

	-- 双重节流: 时间间隔 + 变化阈值
	local changePct = math.abs(state.current - lastSynced) / math.max(max, 1)
	local timeSinceSync = now - lastSync

	if changePct >= SYNC_THRESHOLD or timeSinceSync >= SYNC_INTERVAL then
		event:FireClient(player, {
			current = math.floor(state.current),
			max = math.floor(state.max),
			energyType = state.energyType,
		})
		state.lastSynced = state.current
		state.lastSyncTime = now
	end
end

-- ========== 公开 API ==========

--- 初始化玩家能量 (英雄装备/切换时调用)
function EnergySystem:InitEnergy(player, heroId)
	if not player or not heroId then return end

	local heroData = HeroRegistry[heroId]
	if not heroData then return end

	local energyType = heroData.EnergyType or "None"
	local config = EnergyConfig[energyType]
	if not config then
		warn("[EnergySystem] Unknown energy type:", energyType)
		return
	end

	-- None 类型不需要初始化
	if energyType == "None" then
		energyStates[player] = nil
		-- Sync to client: hide bar
		local event = getSyncEvent()
		if event then
			event:FireClient(player, {
				current = 0,
				max = 0,
				energyType = "None",
			})
		end
		return
	end

	local level = 1
	local character = player.Character
	if character then
		level = character:GetAttribute("Level") or 1
	end

	local maxEnergy = config.BaseMax + (config.GrowthPerLevel or 0) * (level - 1)
	local initialValue = config.InitialValue
	if initialValue == nil then
		initialValue = maxEnergy -- Mana/Energy: 满值开局
	end

	energyStates[player] = {
		current = initialValue,
		max = maxEnergy,
		energyType = energyType,
		config = config,
		lastCombatTime = 0,
		lastSynced = -1, -- force first sync
		lastSyncTime = 0,
		level = level,
	}

	-- Immediate sync
	syncToClient(player, energyStates[player])
end

--- 检查能否施法 (能量 >= cost)
function EnergySystem:CanCast(player, cost)
	if not cost or cost <= 0 then return true end

	local state = energyStates[player]
	if not state then return true end -- None type or uninitialized = free cast

	return state.current >= cost
end

--- 消耗能量
function EnergySystem:ConsumeEnergy(player, amount)
	if not amount or amount <= 0 then return end

	local state = energyStates[player]
	if not state then return end

	state.current = math.max(0, state.current - amount)
	syncToClient(player, state)
end

--- 增加能量 (Rage 战斗获取用)
function EnergySystem:AddEnergy(player, amount, reason)
	if not amount or amount <= 0 then return end

	local state = energyStates[player]
	if not state then return end

	state.current = math.min(state.max, state.current + amount)

	-- Update combat time for Rage decay tracking
	if reason == "combat" or reason == "hit" or reason == "damaged" or reason == "skill_hit" then
		state.lastCombatTime = os.clock()
	end

	-- Sync handled by Heartbeat throttle
end

--- 查询当前能量状态
function EnergySystem:GetEnergy(player)
	local state = energyStates[player]
	if not state then
		return { current = 0, max = 0, energyType = "None" }
	end
	return {
		current = state.current,
		max = state.max,
		energyType = state.energyType,
	}
end

--- 清理玩家能量数据
function EnergySystem:RemovePlayer(player)
	energyStates[player] = nil
end

--- 等级提升时更新 Max (Mana 成长)
function EnergySystem:OnLevelUp(player, newLevel)
	local state = energyStates[player]
	if not state then return end

	local config = state.config
	if not config then return end

	local growth = config.GrowthPerLevel or 0
	if growth <= 0 then return end

	local oldMax = state.max
	state.max = config.BaseMax + growth * (newLevel - 1)
	state.level = newLevel

	-- Add the growth to current (like gaining max MP on level up)
	local gained = state.max - oldMax
	state.current = math.min(state.max, state.current + gained)
end

--- 死亡处理: Rage重置为0, Mana/Energy保持当前值
function EnergySystem:OnDeath(player)
	local state = energyStates[player]
	if not state then return end

	if state.energyType == "Rage" then
		state.current = 0
		syncToClient(player, state)
	end
end

-- ========== Heartbeat: 自然恢复 / 怒气衰减 / 同步 / 死亡检测 ==========

RunService.Heartbeat:Connect(function(dt)
	for player, state in pairs(energyStates) do
		local character = player.Character
		if not character then continue end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local isDead = not humanoid or humanoid.Health <= 0

		-- 死亡处理: Rage 重置 (只触发一次)
		if isDead then
			if not state.deathProcessed then
				state.deathProcessed = true
				if state.energyType == "Rage" then
					state.current = 0
					syncToClient(player, state)
				end
			end
			continue -- 死亡时不恢复/衰减
		else
			state.deathProcessed = nil -- 复活后重置标记
		end

		local config = state.config
		if not config then continue end

		local energyType = state.energyType

		-- Mana / Energy: 自然恢复
		if energyType == "Mana" or energyType == "Energy" then
			local regen = config.RegenPerSecond or 0
			if energyType == "Mana" then
				-- Mana regen grows with level
				local regenGrowth = config.RegenGrowth or 0
				regen = regen + regenGrowth * ((state.level or 1) - 1)
			end

			if regen > 0 and state.current < state.max then
				state.current = math.min(state.max, state.current + regen * dt)
			end
		end

		-- Rage: 脱战衰减
		if energyType == "Rage" then
			local decayConfig = config.DecayAfterCombat
			if decayConfig and state.current > 0 then
				local timeSinceCombat = os.clock() - (state.lastCombatTime or 0)
				if timeSinceCombat > (decayConfig.Delay or 5) then
					local decayRate = decayConfig.Rate or 10
					state.current = math.max(0, state.current - decayRate * dt)
				end
			end
		end

		-- Sync to client (throttled)
		syncToClient(player, state)
	end
end)

-- ========== 玩家离开清理 ==========

Players.PlayerRemoving:Connect(function(player)
	energyStates[player] = nil
end)

return EnergySystem
