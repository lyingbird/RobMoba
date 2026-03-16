-- ==========================================
-- PassiveSystem: 被动技能运行时管理器
-- 职责: 被动注册/注销/事件触发/CD管理/叠层衰减
-- 驱动方式: 事件驱动 (由 AutoAttackManager/EffectExecutor 调用)
--           + Heartbeat (叠层衰减检测)
-- 运行位置: 服务端 (ServerScriptService)
-- ==========================================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PassiveConfig = require(ReplicatedStorage:WaitForChild("PassiveConfig"))
local HeroRegistry = require(ReplicatedStorage:WaitForChild("HeroRegistry"))

-- BuffSystem 延迟加载（避免循环依赖）
local BuffSystem = nil
local function getBuffSystem()
	if not BuffSystem then
		BuffSystem = require(ServerScriptService.ServerModules:WaitForChild("BuffSystem"))
	end
	return BuffSystem
end

local PassiveSystem = {}

-- ========== 数据结构 ==========
-- activePassives[player] = {
--   [passiveId] = {
--     config = PassiveConfig entry,
--     lastTriggerTime = number,
--     stacks = number (for StackBehavior),
--     lastHitTime = number (for decay tracking),
--     paused = boolean (death pause),
--   }
-- }
local activePassives = {}

-- ========== 条件检查 ==========

local function checkCondition(condition, player, passiveData, context)
	local condType = condition.Type

	if condType == "CooldownReady" then
		local cd = passiveData.config.Cooldown or 0
		if cd <= 0 then return true end
		local lastTrigger = passiveData.lastTriggerTime or 0
		return (os.clock() - lastTrigger) >= cd

	elseif condType == "HealthBelow" then
		local character = player.Character
		if not character then return false end
		local hp = character:GetAttribute("HP") or 0
		local maxHP = character:GetAttribute("MaxHP") or 1
		return (hp / maxHP) < (condition.threshold or 0.3)

	elseif condType == "HealthAbove" then
		local character = player.Character
		if not character then return false end
		local hp = character:GetAttribute("HP") or 0
		local maxHP = character:GetAttribute("MaxHP") or 1
		return (hp / maxHP) > (condition.threshold or 0.5)

	elseif condType == "TargetIsHero" then
		-- context.target must be a player's character
		if not context or not context.target then return false end
		local targetModel = context.target
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character == targetModel then
				return true
			end
		end
		return false

	elseif condType == "HasBuff" then
		local character = player.Character
		if not character then return false end
		return getBuffSystem():HasEffect(character, condition.buffId)

	elseif condType == "NotHasBuff" then
		local character = player.Character
		if not character then return false end
		return not getBuffSystem():HasEffect(character, condition.buffId)
	end

	return true -- unknown condition type passes
end

local function checkAllConditions(conditions, player, passiveData, context)
	if not conditions or #conditions == 0 then return true end

	local logic = conditions.Logic or "AND"
	for _, cond in ipairs(conditions) do
		if type(cond) == "table" and cond.Type then
			local result = checkCondition(cond, player, passiveData, context)
			if logic == "AND" and not result then
				return false
			elseif logic == "OR" and result then
				return true
			end
		end
	end

	if logic == "AND" then return true end
	if logic == "OR" then return false end
	return true
end

-- ========== 叠层处理 (后羿被动专用) ==========

local function applyStackEffect(player, passiveData)
	local character = player.Character
	if not character then return end

	local stackBehavior = passiveData.config.StackBehavior
	if not stackBehavior then return end

	local maxStacks = stackBehavior.MaxStacks or 1
	local currentStacks = passiveData.stacks or 0

	if currentStacks < maxStacks then
		passiveData.stacks = currentStacks + 1
		-- Apply one stack of the effect
		local effectId = stackBehavior.StackEffect
		if effectId then
			getBuffSystem():ApplyEffect(character, character, effectId)
		end
	end

	-- Update last hit time for decay tracking
	passiveData.lastHitTime = os.clock()
end

local function decayStacks(player, passiveData, dt)
	local stackBehavior = passiveData.config.StackBehavior
	if not stackBehavior then return end
	if not passiveData.stacks or passiveData.stacks <= 0 then return end

	local lastHit = passiveData.lastHitTime or 0
	local decayDelay = stackBehavior.DecayDelay or 3
	local now = os.clock()

	if (now - lastHit) < decayDelay then return end

	-- Accumulate decay time
	if not passiveData.decayAccumulator then
		passiveData.decayAccumulator = 0
	end
	passiveData.decayAccumulator = passiveData.decayAccumulator + dt

	local decayRate = stackBehavior.DecayRate or 1
	local decayInterval = 1 / decayRate -- 1 stack per second if DecayRate=1

	while passiveData.decayAccumulator >= decayInterval and passiveData.stacks > 0 do
		passiveData.decayAccumulator = passiveData.decayAccumulator - decayInterval
		passiveData.stacks = passiveData.stacks - 1

		-- Remove one stack of the buff effect
		local effectId = stackBehavior.StackEffect
		if effectId then
			local character = player.Character
			if character then
				getBuffSystem():RemoveEffect(character, effectId)
			end
		end
	end
end

-- ========== 公开 API ==========

--- 为玩家注册英雄被动
function PassiveSystem:RegisterPassives(player, heroId)
	if not player or not heroId then return end

	local heroData = HeroRegistry[heroId]
	if not heroData or not heroData.Passives then return end

	if not activePassives[player] then
		activePassives[player] = {}
	end

	for _, passiveId in ipairs(heroData.Passives) do
		local config = PassiveConfig[passiveId]
		if config then
			activePassives[player][passiveId] = {
				config = config,
				lastTriggerTime = 0,
				stacks = 0,
				lastHitTime = 0,
				paused = false,
				decayAccumulator = 0,
			}
		else
			warn("[PassiveSystem] PassiveConfig not found for ID:", passiveId)
		end
	end
end

--- 注销玩家所有被动 (英雄切换/离开时)
function PassiveSystem:UnregisterPassives(player)
	if not player then return end

	-- Clear any buff effects from passives
	local passives = activePassives[player]
	if passives then
		local character = player.Character
		if character then
			for _, passiveData in pairs(passives) do
				-- Remove stack effects
				if passiveData.config.StackBehavior and passiveData.stacks > 0 then
					local effectId = passiveData.config.StackBehavior.StackEffect
					if effectId then
						getBuffSystem():RemoveAllEffects(character)
					end
				end
				-- Remove regular effects
				for _, effectId in ipairs(passiveData.config.Effects or {}) do
					getBuffSystem():RemoveEffect(character, effectId)
				end
			end
		end
	end

	activePassives[player] = nil
end

--- 事件派发入口 — 由 AutoAttackManager/EffectExecutor/MatchSystem 调用
function PassiveSystem:OnEvent(eventType, player, context)
	if not player or not eventType then return end

	local passives = activePassives[player]
	if not passives then return end

	for passiveId, passiveData in pairs(passives) do
		-- Skip paused passives (dead)
		if passiveData.paused then continue end

		-- Match trigger event
		if passiveData.config.TriggerEvent ~= eventType then continue end

		-- Check conditions
		if not checkAllConditions(passiveData.config.Conditions, player, passiveData, context) then
			continue
		end

		-- Handle stack-based passives (e.g., HouYi)
		if passiveData.config.StackBehavior then
			applyStackEffect(player, passiveData)
		else
			-- Normal passive: apply all effects
			local character = player.Character
			if character then
				local source = character
				local target = character -- default self-targeting

				-- For OnHit, target is the hit target
				if eventType == "OnHit" and context and context.target then
					target = context.target
				end

				for _, effectId in ipairs(passiveData.config.Effects or {}) do
					getBuffSystem():ApplyEffect(source, target, effectId)
				end
			end
		end

		-- Update cooldown timer
		passiveData.lastTriggerTime = os.clock()
	end
end

--- 查询某被动是否在 CD
function PassiveSystem:IsPassiveOnCooldown(player, passiveId)
	local passives = activePassives[player]
	if not passives then return false end

	local passiveData = passives[passiveId]
	if not passiveData then return false end

	local cd = passiveData.config.Cooldown or 0
	if cd <= 0 then return false end

	return (os.clock() - (passiveData.lastTriggerTime or 0)) < cd
end

-- ========== Heartbeat: 叠层衰减 + 死亡检测 ==========

RunService.Heartbeat:Connect(function(dt)
	for player, passives in pairs(activePassives) do
		local character = player.Character
		if not character then continue end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local isDead = not humanoid or humanoid.Health <= 0

		for passiveId, passiveData in pairs(passives) do
			-- Death pause/resume
			if isDead and not passiveData.paused then
				passiveData.paused = true
			elseif not isDead and passiveData.paused then
				passiveData.paused = false
			end

			-- Stack decay (only when alive)
			if not passiveData.paused and passiveData.config.StackBehavior then
				decayStacks(player, passiveData, dt)
			end
		end
	end
end)

-- ========== 玩家离开清理 ==========

Players.PlayerRemoving:Connect(function(player)
	activePassives[player] = nil
end)

return PassiveSystem
