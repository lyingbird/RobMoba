-- ==========================================
-- Skill_10520: LianPoW (熔岩重击)
-- 来源: 王者荣耀 21号表 10520 + 22号表 105200~105290
-- Archetype: InstantSkill
--
-- 机制:
--   瞬发 → 自身护盾(400+80/lv, 5s) + 回怒(+16)
--   延迟1s → AOE 3环递增伤害:
--     外圈: 330+66/lv 110%AD
--     中圈: 额外 +330 110%AD (外圈+中圈)
--     内圈: 额外 +330 110%AD (外圈+中圈+内圈)
--   减速 15%+3%/lv 1s
--   命中敌方英雄 → 刷新Q冷却
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local InstantSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("InstantSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))
local BuffSystem = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BuffSystem"))

local LianPoW = setmetatable({}, InstantSkill)
LianPoW.__index = LianPoW

function LianPoW.new(skillID)
	return setmetatable(InstantSkill.new(skillID), LianPoW)
end

-- VFX: 护盾
local function createShieldVFX(character, duration)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local shield = Instance.new("Part")
	shield.Shape = Enum.PartType.Ball
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(200, 160, 80)
	shield.Size = Vector3.new(8, 8, 8)
	shield.CFrame = CFrame.new(rootPart.Position)
	shield.Anchored = true
	shield.CanCollide = false
	shield.Transparency = 0.5
	shield.Parent = workspace

	local RunService = game:GetService("RunService")
	local followConn
	followConn = RunService.Heartbeat:Connect(function()
		if rootPart and rootPart.Parent then
			shield.CFrame = CFrame.new(rootPart.Position)
		else
			followConn:Disconnect()
			shield:Destroy()
		end
	end)

	task.delay(duration, function()
		followConn:Disconnect()
		TweenService:Create(shield, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(shield, 0.4)
	end)
end

-- VFX: 3环地面崩裂 (外→中→内圈扩散)
local function createGroundSlamVFX(position, outerRadius)
	-- 外圈
	local crack = Instance.new("Part")
	crack.Shape = Enum.PartType.Cylinder
	crack.Material = Enum.Material.Neon
	crack.Color = Color3.fromRGB(255, 120, 0)
	crack.Size = Vector3.new(0.3, 2, 2)
	crack.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	crack.Anchored = true
	crack.CanCollide = false
	crack.Transparency = 0.2
	crack.Parent = workspace

	TweenService:Create(crack, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, outerRadius * 2.5, outerRadius * 2.5),
		Transparency = 0.5
	}):Play()

	-- 中圈
	local mid = Instance.new("Part")
	mid.Shape = Enum.PartType.Cylinder
	mid.Material = Enum.Material.Neon
	mid.Color = Color3.fromRGB(255, 80, 0)
	mid.Size = Vector3.new(0.3, 2, 2)
	mid.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	mid.Anchored = true
	mid.CanCollide = false
	mid.Transparency = 0.3
	mid.Parent = workspace

	TweenService:Create(mid, TweenInfo.new(0.35), {
		Size = Vector3.new(0.3, outerRadius * 1.5, outerRadius * 1.5),
		Transparency = 0.6
	}):Play()

	-- 内圈
	local inner = Instance.new("Part")
	inner.Shape = Enum.PartType.Cylinder
	inner.Material = Enum.Material.Neon
	inner.Color = Color3.fromRGB(255, 40, 0)
	inner.Size = Vector3.new(0.3, 2, 2)
	inner.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	inner.Anchored = true
	inner.CanCollide = false
	inner.Transparency = 0.4
	inner.Parent = workspace

	TweenService:Create(inner, TweenInfo.new(0.3), {
		Size = Vector3.new(0.3, outerRadius * 0.8, outerRadius * 0.8),
		Transparency = 0.7
	}):Play()

	task.delay(0.8, function()
		TweenService:Create(crack, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		TweenService:Create(mid, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		TweenService:Create(inner, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(crack, 1.5)
	Debris:AddItem(mid, 1.5)
	Debris:AddItem(inner, 1.5)
end

-- 重写 OnInstantCast: 护盾 + 回怒 + 延迟3环AOE + 刷新Q
function LianPoW:OnInstantCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	-- ① 护盾 (来源: 105250, base=400+80/lv, 5s)
	createShieldVFX(character, 5) -- VFX持续5s与效果一致

	-- ② 回怒 +16 (来源: 105101)
	for _, selfEffectId in ipairs(self.Config.SelfEffectsOnCast or {}) do
		BuffSystem:ApplyEffect(character, character, selfEffectId)
	end

	local chargeDelay = self.Config.ChargeDelay or 1
	local outerRadius = self.Config.AreaRadius or 5
	local midRadius = outerRadius * 0.66   -- 中圈=外圈×2/3
	local innerRadius = outerRadius * 0.33 -- 内圈=外圈×1/3

	-- ③ 延迟后 3环AOE (来源: 105200/201/202)
	task.delay(chargeDelay, function()
		if not character or not character.Parent then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end
		local slamPos = rootPart.Position

		-- VFX
		createGroundSlamVFX(slamPos, outerRadius)

		-- 外圈伤害: 所有范围内敌人 (来源: 105200)
		local outerEffects = self.Config.AreaEffects or {}
		local outerCC = self.Config.AreaCC or {}
		local allOuterEffects = {}
		for _, id in ipairs(outerEffects) do table.insert(allOuterEffects, id) end
		for _, id in ipairs(outerCC) do table.insert(allOuterEffects, id) end

		local outerEnemies = SkillHelper.ApplyAreaEffects(self, character, player, slamPos, outerRadius, allOuterEffects)

		-- 中圈+内圈额外伤害: 距离更近的敌人额外受伤 (来源: 105201+105202)
		local innerRingEffects = self.Config.InnerRingEffects or {}
		if #innerRingEffects > 0 then
			local midEnemies = CombatUtils.getEnemiesInRange(player, slamPos, midRadius, character)
			for _, enemy in ipairs(midEnemies) do
				SkillHelper.ApplyEffects(self, character, enemy, innerRingEffects)
			end
		end

		-- ④ 命中敌方英雄 → 刷新Q冷却 (来源: 105260)
		if #outerEnemies > 0 and self.Config.RefreshQOnHit then
			if shared.PlayerSkillManager then
				shared.PlayerSkillManager.ResetCooldown(player, "Q", 10510)
			end

			local SyncCooldownEvent = ReplicatedStorage:FindFirstChild("SyncCooldownEvent")
			if SyncCooldownEvent then
				SyncCooldownEvent:FireClient(player, "Q", 0, 10510)
			end
		end
	end)
end

return LianPoW
