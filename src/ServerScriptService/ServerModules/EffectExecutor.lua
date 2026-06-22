local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnergyConfig = require(ReplicatedStorage:WaitForChild("EnergyConfig"))
local MovementState = require(script.Parent:WaitForChild("MovementState"))

local EffectExecutor = {}

local PassiveSystem = nil
local EnergySystem = nil

local actionBlocks = setmetatable({}, { __mode = "k" })
local anchorBlocks = setmetatable({}, { __mode = "k" })
local attributeMods = setmetatable({}, { __mode = "k" })
local propertyMods = setmetatable({}, { __mode = "k" })
local shieldMods = setmetatable({}, { __mode = "k" })

local function getPassiveSystem()
	if not PassiveSystem then
		local ServerScriptService = game:GetService("ServerScriptService")
		PassiveSystem = require(ServerScriptService.ServerModules:WaitForChild("PassiveSystem"))
	end
	return PassiveSystem
end

local function getEnergySystem()
	if not EnergySystem then
		local ServerScriptService = game:GetService("ServerScriptService")
		EnergySystem = require(ServerScriptService.ServerModules:WaitForChild("EnergySystem"))
	end
	return EnergySystem
end

local function countEntries(map)
	local count = 0
	for _ in pairs(map) do
		count = count + 1
	end
	return count
end

local function getBuffToken(buff, suffix)
	local base = buff and buff.instanceId or "effect"
	return tostring(base) .. "_" .. suffix
end

local function getActionState(humanoid)
	local state = actionBlocks[humanoid]
	if not state then
		state = {
			cast = {},
			autoAttack = {},
		}
		actionBlocks[humanoid] = state
	end
	return state
end

local function setActionBlock(humanoid, bucketName, countAttr, allowedAttr, token, enabled)
	if not humanoid or token == nil then return end

	local state = actionBlocks[humanoid]
	if not enabled and not state then return end
	if not state then
		state = getActionState(humanoid)
	end

	local bucket = state[bucketName]
	if enabled then
		bucket[token] = true
	else
		if not bucket[token] then return end
		bucket[token] = nil
	end

	local count = countEntries(bucket)
	humanoid:SetAttribute(countAttr, count)
	humanoid:SetAttribute(allowedAttr, count <= 0)
end

local function pushCastBlock(humanoid, token)
	setActionBlock(humanoid, "cast", "CanCastSkillBlockCount", "CanCastSkill", token, true)
end

local function popCastBlock(humanoid, token)
	setActionBlock(humanoid, "cast", "CanCastSkillBlockCount", "CanCastSkill", token, false)
end

local function pushAutoAttackBlock(humanoid, token)
	setActionBlock(humanoid, "autoAttack", "CanAutoAttackBlockCount", "CanAutoAttack", token, true)
end

local function popAutoAttackBlock(humanoid, token)
	setActionBlock(humanoid, "autoAttack", "CanAutoAttackBlockCount", "CanAutoAttack", token, false)
end

local function getAnchorState(rootPart)
	local state = anchorBlocks[rootPart]
	if not state then
		state = {
			originalAnchored = rootPart.Anchored,
			tokens = {},
			cframes = {},
			pendingRestoreCFrame = nil,
		}
		anchorBlocks[rootPart] = state
	end
	return state
end

local function pushAnchor(rootPart, token, captureCFrame)
	if not rootPart or token == nil then return end

	local state = getAnchorState(rootPart)
	if captureCFrame and not state.cframes[token] then
		state.cframes[token] = rootPart.CFrame
	end
	state.tokens[token] = true

	rootPart.Anchored = true
	rootPart:SetAttribute("AnchorBlockCount", countEntries(state.tokens))
end

local function popAnchor(rootPart, token, restoreCFrame)
	if not rootPart or token == nil then return end

	local state = anchorBlocks[rootPart]
	if not state then return end

	local savedCFrame = state.cframes[token]
	state.tokens[token] = nil
	state.cframes[token] = nil

	if restoreCFrame and savedCFrame then
		state.pendingRestoreCFrame = savedCFrame
	end

	local count = countEntries(state.tokens)
	rootPart:SetAttribute("AnchorBlockCount", count)
	if count > 0 then return end

	if state.pendingRestoreCFrame then
		rootPart.CFrame = state.pendingRestoreCFrame
	end
	rootPart.Anchored = state.originalAnchored
	anchorBlocks[rootPart] = nil
end

local function getAttributeModState(humanoid, stat)
	local byStat = attributeMods[humanoid]
	if not byStat then
		byStat = {}
		attributeMods[humanoid] = byStat
	end

	local state = byStat[stat]
	if not state then
		local originalValue = humanoid:GetAttribute(stat)
		state = {
			base = originalValue or 0,
			hadBase = originalValue ~= nil,
			modifiers = {},
		}
		byStat[stat] = state
	end

	return byStat, state
end

local function refreshAttributeModifier(humanoid, stat, state)
	local flatBonus = 0
	local multiplier = 1

	for _, modifier in pairs(state.modifiers) do
		flatBonus = flatBonus + (modifier.flat or 0)
		if modifier.percent then
			multiplier = multiplier * (1 + modifier.percent)
		end
	end

	humanoid:SetAttribute(stat, (state.base + flatBonus) * multiplier)
end

local function setAttributeModifier(humanoid, stat, token, modType, value)
	if not humanoid or not stat or token == nil then return end

	local _, state = getAttributeModState(humanoid, stat)
	if modType == "Percent" then
		state.modifiers[token] = { percent = value }
	else
		state.modifiers[token] = { flat = value }
	end
	refreshAttributeModifier(humanoid, stat, state)
end

local function clearAttributeModifier(humanoid, stat, token)
	if not humanoid or not stat or token == nil then return end

	local byStat = attributeMods[humanoid]
	if not byStat then return end

	local state = byStat[stat]
	if not state then return end

	state.modifiers[token] = nil
	if next(state.modifiers) then
		refreshAttributeModifier(humanoid, stat, state)
		return
	end

	if state.hadBase then
		humanoid:SetAttribute(stat, state.base)
	else
		humanoid:SetAttribute(stat, nil)
	end
	byStat[stat] = nil
	if not next(byStat) then
		attributeMods[humanoid] = nil
	end
end

local function getPropertyModState(humanoid, property)
	local byProperty = propertyMods[humanoid]
	if not byProperty then
		byProperty = {}
		propertyMods[humanoid] = byProperty
	end

	local state = byProperty[property]
	if not state then
		state = {
			base = humanoid[property],
			modifiers = {},
		}
		byProperty[property] = state
	end

	return byProperty, state
end

local function refreshPropertyModifier(humanoid, property, state)
	local flatBonus = 0
	local multiplier = 1

	for _, modifier in pairs(state.modifiers) do
		flatBonus = flatBonus + (modifier.flat or 0)
		if modifier.percent then
			multiplier = multiplier * (1 + modifier.percent)
		end
	end

	humanoid[property] = math.max(0, (state.base + flatBonus) * multiplier)
end

local function setPropertyModifier(humanoid, property, token, modType, value)
	if not humanoid or not property or token == nil then return end

	local _, state = getPropertyModState(humanoid, property)
	if modType == "Percent" then
		state.modifiers[token] = { percent = value }
	else
		state.modifiers[token] = { flat = value }
	end
	refreshPropertyModifier(humanoid, property, state)
end

local function clearPropertyModifier(humanoid, property, token)
	if not humanoid or not property or token == nil then return end

	local byProperty = propertyMods[humanoid]
	if not byProperty then return end

	local state = byProperty[property]
	if not state then return end

	state.modifiers[token] = nil
	if next(state.modifiers) then
		refreshPropertyModifier(humanoid, property, state)
		return
	end

	humanoid[property] = state.base
	byProperty[property] = nil
	if not next(byProperty) then
		propertyMods[humanoid] = nil
	end
end

local function refreshShieldAmount(humanoid, shields)
	local amount = 0
	for _, shield in pairs(shields) do
		amount = amount + math.max(0, shield.remaining or 0)
	end

	humanoid:SetAttribute("ShieldAmount", amount)
	if amount <= 0 then
		shieldMods[humanoid] = nil
	end
end

local function addShieldModifier(humanoid, token, amount)
	if not humanoid or token == nil or amount <= 0 then return end

	local shields = shieldMods[humanoid]
	if not shields then
		shields = {}
		shieldMods[humanoid] = shields
	end

	shields[token] = { remaining = amount }
	refreshShieldAmount(humanoid, shields)
end

local function clearShieldModifier(humanoid, token)
	if not humanoid or token == nil then return end

	local shields = shieldMods[humanoid]
	if not shields or not shields[token] then return end

	shields[token] = nil
	refreshShieldAmount(humanoid, shields)
end

local function absorbDamageWithShields(humanoid, amount)
	local shields = shieldMods[humanoid]
	if shields then
		local remainingDamage = amount
		for token, shield in pairs(shields) do
			if remainingDamage <= 0 then break end

			local shieldRemaining = math.max(0, shield.remaining or 0)
			local absorbed = math.min(shieldRemaining, remainingDamage)
			shield.remaining = shieldRemaining - absorbed
			remainingDamage = remainingDamage - absorbed
			if shield.remaining <= 0 then
				shields[token] = nil
			end
		end

		refreshShieldAmount(humanoid, shields)
		return remainingDamage
	end

	local shieldAmount = humanoid:GetAttribute("ShieldAmount") or 0
	if shieldAmount <= 0 then return amount end

	if shieldAmount >= amount then
		humanoid:SetAttribute("ShieldAmount", shieldAmount - amount)
		return 0
	end

	humanoid:SetAttribute("ShieldAmount", 0)
	return amount - shieldAmount
end

function EffectExecutor:Execute(source, target, effectConfig, buff)
	if not effectConfig or not effectConfig.Type then
		warn("[EffectExecutor] Invalid effect config")
		return
	end

	local effectType = effectConfig.Type
	if effectType == "Damage" then
		self:_executeDamage(source, target, effectConfig)
	elseif effectType == "CC" then
		self:_executeCC(source, target, effectConfig, buff)
	elseif effectType == "Shield" then
		self:_executeShield(source, target, effectConfig, buff)
	elseif effectType == "StatMod" then
		self:_executeStatMod(source, target, effectConfig, buff)
	elseif effectType == "DoT" then
		self:_executeDoT(source, target, effectConfig)
	elseif effectType == "HoT" then
		self:_executeHoT(source, target, effectConfig)
	end
end

function EffectExecutor:_applyDamageAfterShield(humanoid, amount, source, target)
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then return end

	local damageReduction = humanoid:GetAttribute("DamageReduction") or 0
	if damageReduction > 0 then
		amount = amount * (1 - math.clamp(damageReduction, 0, 0.9))
	end

	amount = absorbDamageWithShields(humanoid, amount)
	if amount <= 0 then return end

	humanoid:TakeDamage(amount)

	-- 统一击杀归因：仅在实际造成伤害时，且施法者为玩家、非自伤，
	-- 在目标上记录最后伤害来源，供 MatchSystem.onCharacterDied 按 LastDamagePlayer 计分。
	-- 这是所有"基于效果"的伤害（普通伤害/AOE/瞬发/DoT）的唯一落地出口，
	-- 集中在此处写入可覆盖各 Archetype 零散补写遗漏的 Area/Instant/DoT 路径。
	if target and source and source ~= target then
		local sourcePlayer = Players:GetPlayerFromCharacter(source)
		if sourcePlayer then
			target:SetAttribute("LastDamagePlayer", sourcePlayer.Name)
			-- 对局伤害统计（结算面板用）：仅战斗中累计，MatchSystem 自带 guard
			if shared.MatchSystem and shared.MatchSystem.RecordDamage then
				shared.MatchSystem.RecordDamage(sourcePlayer, amount)
			end
		end
	end
end

function EffectExecutor:_executeDamage(source, target, config)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	self:_applyDamageAfterShield(humanoid, config.Amount or 0, source, target)

	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if not targetPlayer then return end

	getPassiveSystem():OnEvent("OnDamaged", targetPlayer, {
		source = source,
		damage = config.Amount or 0,
		damageType = config.DamageType or "Magic",
	})

	local rageGain = EnergyConfig.Rage and EnergyConfig.Rage.GainOnDamaged or 0
	if rageGain > 0 then
		getEnergySystem():AddEnergy(targetPlayer, rageGain, "damaged")
	end
end

function EffectExecutor:_executeCC(source, target, config, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local rootPart = target:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 then return end
	if (humanoid:GetAttribute("CCImmune") or 0) > 0 then return end

	local ccType = config.CCType

	if ccType == "Stun" or ccType == "Knockup" then
		if rootPart then
			pushAnchor(rootPart, getBuffToken(buff, "hard_cc_anchor"), ccType == "Knockup")
		end
		MovementState.PushLock(humanoid, getBuffToken(buff, "hard_cc_move_lock"))
		pushCastBlock(humanoid, getBuffToken(buff, "hard_cc_cast_block"))
		pushAutoAttackBlock(humanoid, getBuffToken(buff, "hard_cc_auto_block"))

		if ccType == "Knockup" and rootPart then
			local duration = config.Duration or 0.8
			local height = config.KnockupHeight or 8
			local upTime = duration * 0.4
			local downTime = duration * 0.6
			local startCFrame = rootPart.CFrame
			local upCFrame = startCFrame + Vector3.new(0, height, 0)

			local upTween = TweenService:Create(
				rootPart,
				TweenInfo.new(upTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = upCFrame }
			)
			upTween:Play()

			task.delay(upTime, function()
				if rootPart and rootPart.Parent then
					local downTween = TweenService:Create(
						rootPart,
						TweenInfo.new(downTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ CFrame = startCFrame }
					)
					downTween:Play()
				end
			end)
		end
	elseif ccType == "Slow" then
		local percent = config.Percent or 0.25
		MovementState.SetModifier(humanoid, getBuffToken(buff, "slow"), 0, -percent)
	elseif ccType == "Root" then
		if rootPart then
			pushAnchor(rootPart, getBuffToken(buff, "root_anchor"), false)
		end
		MovementState.PushLock(humanoid, getBuffToken(buff, "root_move_lock"))
	elseif ccType == "Silence" then
		pushCastBlock(humanoid, getBuffToken(buff, "silence_cast_block"))
	elseif ccType == "Disarm" then
		pushAutoAttackBlock(humanoid, getBuffToken(buff, "disarm_auto_block"))
	end
end

function EffectExecutor:_revertCC(target, ccType, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local rootPart = target:FindFirstChild("HumanoidRootPart")
	if not humanoid then return end

	if ccType == "Stun" or ccType == "Knockup" then
		if rootPart then
			popAnchor(rootPart, getBuffToken(buff, "hard_cc_anchor"), ccType == "Knockup")
		end
		MovementState.PopLock(humanoid, getBuffToken(buff, "hard_cc_move_lock"))
		popCastBlock(humanoid, getBuffToken(buff, "hard_cc_cast_block"))
		popAutoAttackBlock(humanoid, getBuffToken(buff, "hard_cc_auto_block"))
	elseif ccType == "Slow" then
		MovementState.ClearModifier(humanoid, getBuffToken(buff, "slow"))
	elseif ccType == "Root" then
		if rootPart then
			popAnchor(rootPart, getBuffToken(buff, "root_anchor"), false)
		end
		MovementState.PopLock(humanoid, getBuffToken(buff, "root_move_lock"))
	elseif ccType == "Silence" then
		popCastBlock(humanoid, getBuffToken(buff, "silence_cast_block"))
	elseif ccType == "Disarm" then
		popAutoAttackBlock(humanoid, getBuffToken(buff, "disarm_auto_block"))
	end
end

function EffectExecutor:_executeShield(source, target, config, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	addShieldModifier(humanoid, getBuffToken(buff, "shield"), config.Amount or 0)
end

function EffectExecutor:_revertShield(target, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	clearShieldModifier(humanoid, getBuffToken(buff, "shield"))
end

function EffectExecutor:_executeDoT(source, target, config)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	self:_applyDamageAfterShield(humanoid, config.TickDamage or 0, source, target)
end

function EffectExecutor:_executeHoT(source, target, config)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local tickHeal = config.TickHeal or 0
	humanoid.Health = math.min(humanoid.Health + tickHeal, humanoid.MaxHealth)
end

function EffectExecutor:_executeStatMod(source, target, config, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stat = config.Stat
	local modType = config.ModType or "Flat"
	local value = config.Value or 0

	if stat == "Energy" then
		local targetPlayer = Players:GetPlayerFromCharacter(target)
		if targetPlayer and modType == "Flat" and value > 0 then
			getEnergySystem():AddEnergy(targetPlayer, value, "skill_hit")
		end
	elseif stat == "WalkSpeed" or stat == "MoveSpeed" then
		local token = getBuffToken(buff, "movespeed")
		if modType == "Percent" then
			MovementState.SetModifier(humanoid, token, 0, value)
		else
			MovementState.SetModifier(humanoid, token, value, 0)
		end
	elseif stat == "JumpPower" then
		setPropertyModifier(humanoid, "JumpPower", getBuffToken(buff, "stat_" .. tostring(stat)), modType, value)
	else
		setAttributeModifier(humanoid, stat, getBuffToken(buff, "stat_" .. tostring(stat)), modType, value)
	end
end

function EffectExecutor:_revertStatMod(target, stat, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if stat == "Energy" then
		return
	elseif stat == "WalkSpeed" or stat == "MoveSpeed" then
		MovementState.ClearModifier(humanoid, getBuffToken(buff, "movespeed"))
	elseif stat == "JumpPower" then
		clearPropertyModifier(humanoid, "JumpPower", getBuffToken(buff, "stat_" .. tostring(stat)))
	else
		clearAttributeModifier(humanoid, stat, getBuffToken(buff, "stat_" .. tostring(stat)))
	end
end

return EffectExecutor
