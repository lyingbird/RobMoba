-- ==========================================
-- EffectExecutor: 效果执行器
-- 6 种效果类型的执行和恢复逻辑
-- 由 BuffSystem 调用，不直接对外暴露
-- 运行位置: 服务端 (ServerScriptService)
-- ==========================================
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnergyConfig = require(ReplicatedStorage:WaitForChild("EnergyConfig"))

local EffectExecutor = {}

-- REQ-007: 延迟加载 PassiveSystem + EnergySystem (避免循环依赖)
local PassiveSystem = nil
local EnergySystem = nil
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

-- ========== 内部状态追踪 ==========
-- 存储 CC/StatMod 效果的原始值，用于到期恢复
-- _originalValues[characterModel][effectKey] = originalValue
local _originalValues = {}

local function getOriginals(target)
	if not _originalValues[target] then
		_originalValues[target] = {}
	end
	return _originalValues[target]
end

-- ========== 分发入口 ==========

--- 执行效果（由 BuffSystem:ApplyEffect 调用）
-- @param source Model 施加者角色
-- @param target Model 目标角色
-- @param effectConfig table EffectConfig 条目
-- @param buff table BuffInstance（可选，用于追踪）
function EffectExecutor:Execute(source, target, effectConfig, buff)
	if not effectConfig or not effectConfig.Type then
		warn("[EffectExecutor] 无效的效果配置")
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
		-- DoT 首次施加时执行第一次 Tick
		self:_executeDoT(source, target, effectConfig)
	elseif effectType == "HoT" then
		-- HoT 首次施加时执行第一次 Tick
		self:_executeHoT(source, target, effectConfig)
	end
end

-- ========== Shield 抵消公共方法 ==========

--- 扣除护盾后造成伤害（Damage/DoT 共用）
-- @param humanoid Humanoid 目标
-- @param amount number 原始伤害量
function EffectExecutor:_applyDamageAfterShield(humanoid, amount)
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then return end

	local shieldAmount = humanoid:GetAttribute("ShieldAmount") or 0
	if shieldAmount > 0 then
		if shieldAmount >= amount then
			humanoid:SetAttribute("ShieldAmount", shieldAmount - amount)
			return -- 伤害全部被护盾吸收
		else
			amount = amount - shieldAmount
			humanoid:SetAttribute("ShieldAmount", 0)
		end
	end

	humanoid:TakeDamage(amount)
end

-- ========== Damage 执行器 ==========

function EffectExecutor:_executeDamage(source, target, config)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	self:_applyDamageAfterShield(humanoid, config.Amount or 0)

	-- REQ-007: 被动事件派发 (受到伤害 → OnDamaged)
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	if targetPlayer then
		getPassiveSystem():OnEvent("OnDamaged", targetPlayer, {
			source = source,
			damage = config.Amount or 0,
			damageType = config.DamageType or "Magic",
		})
		-- Rage 能量获取 (受到伤害)
		local rageGain = EnergyConfig.Rage and EnergyConfig.Rage.GainOnDamaged or 0
		if rageGain > 0 then
			getEnergySystem():AddEnergy(targetPlayer, rageGain, "damaged")
		end
	end
end

-- ========== CC 执行器 ==========

function EffectExecutor:_executeCC(source, target, config, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local rootPart = target:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 then return end

	local ccType = config.CCType
	local originals = getOriginals(target)
	local buffKey = buff and buff.instanceId or ("cc_" .. tostring(config.CCType))

	if ccType == "Stun" or ccType == "Knockup" then
		-- 禁止移动、施法、普攻
		if rootPart and not originals[buffKey .. "_Anchored"] then
			originals[buffKey .. "_Anchored"] = rootPart.Anchored
			originals[buffKey .. "_OriginalCFrame"] = rootPart.CFrame
			rootPart.Anchored = true
		end
		if not originals[buffKey .. "_WalkSpeed"] then
			originals[buffKey .. "_WalkSpeed"] = humanoid.WalkSpeed
			humanoid.WalkSpeed = 0
		end
		humanoid:SetAttribute("CanCastSkill", false)
		humanoid:SetAttribute("CanAutoAttack", false)

		-- Knockup: Tween 上抛动画
		if ccType == "Knockup" and rootPart then
			local duration = config.Duration or 0.8
			local height = config.KnockupHeight or 8
			local upTime = duration * 0.4
			local downTime = duration * 0.6
			local startCFrame = rootPart.CFrame
			local upCFrame = startCFrame + Vector3.new(0, height, 0)

			local upTween = TweenService:Create(rootPart,
				TweenInfo.new(upTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = upCFrame }
			)
			upTween:Play()

			task.delay(upTime, function()
				if rootPart and rootPart.Parent then
					local downTween = TweenService:Create(rootPart,
						TweenInfo.new(downTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ CFrame = startCFrame }
					)
					downTween:Play()
				end
			end)
		end

	elseif ccType == "Slow" then
		-- 减速
		local percent = config.Percent or 0.25
		if not originals[buffKey .. "_WalkSpeed"] then
			originals[buffKey .. "_WalkSpeed"] = humanoid.WalkSpeed
		end
		humanoid.WalkSpeed = originals[buffKey .. "_WalkSpeed"] * (1 - percent)

	elseif ccType == "Root" then
		-- 定身（不能移动，可以施法）
		if rootPart and not originals[buffKey .. "_Anchored"] then
			originals[buffKey .. "_Anchored"] = rootPart.Anchored
			rootPart.Anchored = true
		end
		if not originals[buffKey .. "_WalkSpeed"] then
			originals[buffKey .. "_WalkSpeed"] = humanoid.WalkSpeed
			humanoid.WalkSpeed = 0
		end

	elseif ccType == "Silence" then
		-- 沉默（可移动，不能施法）
		humanoid:SetAttribute("CanCastSkill", false)

	elseif ccType == "Disarm" then
		-- 缴械（可移动、施法，不能普攻）
		humanoid:SetAttribute("CanAutoAttack", false)
	end
end

--- CC 效果恢复（到期时调用）
function EffectExecutor:_revertCC(target, ccType, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local rootPart = target:FindFirstChild("HumanoidRootPart")
	if not humanoid then return end

	local originals = getOriginals(target)
	local buffKey = buff and buff.instanceId or ("cc_" .. tostring(ccType))

	if ccType == "Stun" or ccType == "Knockup" then
		if rootPart and originals[buffKey .. "_Anchored"] ~= nil then
			rootPart.Anchored = originals[buffKey .. "_Anchored"]
			originals[buffKey .. "_Anchored"] = nil
		end
		-- Knockup: 恢复原始 CFrame（确保落回地面）
		if ccType == "Knockup" and rootPart and originals[buffKey .. "_OriginalCFrame"] then
			rootPart.CFrame = originals[buffKey .. "_OriginalCFrame"]
			originals[buffKey .. "_OriginalCFrame"] = nil
		end
		if originals[buffKey .. "_WalkSpeed"] then
			humanoid.WalkSpeed = originals[buffKey .. "_WalkSpeed"]
			originals[buffKey .. "_WalkSpeed"] = nil
		end
		humanoid:SetAttribute("CanCastSkill", true)
		humanoid:SetAttribute("CanAutoAttack", true)

	elseif ccType == "Slow" then
		if originals[buffKey .. "_WalkSpeed"] then
			humanoid.WalkSpeed = originals[buffKey .. "_WalkSpeed"]
			originals[buffKey .. "_WalkSpeed"] = nil
		end

	elseif ccType == "Root" then
		if rootPart and originals[buffKey .. "_Anchored"] ~= nil then
			rootPart.Anchored = originals[buffKey .. "_Anchored"]
			originals[buffKey .. "_Anchored"] = nil
		end
		if originals[buffKey .. "_WalkSpeed"] then
			humanoid.WalkSpeed = originals[buffKey .. "_WalkSpeed"]
			originals[buffKey .. "_WalkSpeed"] = nil
		end

	elseif ccType == "Silence" then
		humanoid:SetAttribute("CanCastSkill", true)

	elseif ccType == "Disarm" then
		humanoid:SetAttribute("CanAutoAttack", true)
	end

	-- 清理空条目
	if not next(originals) then
		_originalValues[target] = nil
	end
end

-- ========== Shield 执行器 ==========

function EffectExecutor:_executeShield(source, target, config, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local amount = config.Amount or 0
	local current = humanoid:GetAttribute("ShieldAmount") or 0
	humanoid:SetAttribute("ShieldAmount", current + amount)
end

-- ========== DoT 执行器（单次 Tick） ==========

function EffectExecutor:_executeDoT(source, target, config)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	self:_applyDamageAfterShield(humanoid, config.TickDamage or 0)
end

-- ========== HoT 执行器（单次 Tick） ==========

function EffectExecutor:_executeHoT(source, target, config)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local tickHeal = config.TickHeal or 0
	humanoid.Health = math.min(humanoid.Health + tickHeal, humanoid.MaxHealth)
end

-- ========== StatMod 执行器 ==========

function EffectExecutor:_executeStatMod(source, target, config, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local stat = config.Stat
	local modType = config.ModType or "Flat"
	local value = config.Value or 0

	local originals = getOriginals(target)
	local buffKey = buff and buff.instanceId or ("statmod_" .. tostring(stat))

	-- 支持 Humanoid 内建属性和自定义 Attribute
	if stat == "WalkSpeed" then
		if not originals[buffKey .. "_WalkSpeed"] then
			originals[buffKey .. "_WalkSpeed"] = humanoid.WalkSpeed
		end
		if modType == "Flat" then
			humanoid.WalkSpeed = humanoid.WalkSpeed + value
		elseif modType == "Percent" then
			humanoid.WalkSpeed = humanoid.WalkSpeed * (1 + value)
		end
	elseif stat == "JumpPower" then
		if not originals[buffKey .. "_JumpPower"] then
			originals[buffKey .. "_JumpPower"] = humanoid.JumpPower
		end
		if modType == "Flat" then
			humanoid.JumpPower = humanoid.JumpPower + value
		elseif modType == "Percent" then
			humanoid.JumpPower = humanoid.JumpPower * (1 + value)
		end
	else
		-- 自定义属性 — 通过 Attribute 系统
		local currentVal = humanoid:GetAttribute(stat) or 0
		if not originals[buffKey .. "_" .. stat] then
			originals[buffKey .. "_" .. stat] = currentVal
		end
		if modType == "Flat" then
			humanoid:SetAttribute(stat, currentVal + value)
		elseif modType == "Percent" then
			humanoid:SetAttribute(stat, currentVal * (1 + value))
		end
	end
end

--- StatMod 效果恢复（到期时调用）
function EffectExecutor:_revertStatMod(target, stat, buff)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local originals = getOriginals(target)
	local buffKey = buff and buff.instanceId or ("statmod_" .. tostring(stat))

	if stat == "WalkSpeed" then
		if originals[buffKey .. "_WalkSpeed"] then
			humanoid.WalkSpeed = originals[buffKey .. "_WalkSpeed"]
			originals[buffKey .. "_WalkSpeed"] = nil
		end
	elseif stat == "JumpPower" then
		if originals[buffKey .. "_JumpPower"] then
			humanoid.JumpPower = originals[buffKey .. "_JumpPower"]
			originals[buffKey .. "_JumpPower"] = nil
		end
	else
		if originals[buffKey .. "_" .. stat] then
			humanoid:SetAttribute(stat, originals[buffKey .. "_" .. stat])
			originals[buffKey .. "_" .. stat] = nil
		end
	end

	-- 清理空条目
	if not next(originals) then
		_originalValues[target] = nil
	end
end

return EffectExecutor
