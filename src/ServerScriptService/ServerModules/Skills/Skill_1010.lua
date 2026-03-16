-- ==========================================
-- Skill_1010: HouYiW (日之塔)
-- Archetype: AreaSkill (标准区域 DoT)
-- 效果: 3041(DoT 30/tick, 2s)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AreaSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("AreaSkill"))

local HouYiW = setmetatable({}, AreaSkill)
HouYiW.__index = HouYiW

function HouYiW.new(skillID)
	return setmetatable(AreaSkill.new(skillID), HouYiW)
end

-- ===== VFX =====

local function createTowerVFX(position, radius)
	-- 地面光圈
	local zone = Instance.new("Part")
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(255, 180, 50)
	zone.Size = Vector3.new(0.5, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 0.4
	zone.Parent = workspace

	-- 光柱
	local pillar = Instance.new("Part")
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 220, 100)
	pillar.Size = Vector3.new(30, radius * 0.8, radius * 0.8)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, 15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Transparency = 0.5
	pillar.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 5
	light.Range = radius * 2
	light.Parent = zone

	-- 粒子
	local particlePart = Instance.new("Part")
	particlePart.Size = Vector3.new(1, 1, 1)
	particlePart.Position = position + Vector3.new(0, 2, 0)
	particlePart.Anchored = true
	particlePart.CanCollide = false
	particlePart.Transparency = 1
	particlePart.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Parent = particlePart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 100, 0))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.3, 0.6)
	particles.Rate = 50
	particles.Speed = NumberRange.new(2, 8)
	particles.SpreadAngle = Vector2.new(360, 30)
	particles.LightEmission = 1
	particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	particles.Parent = attach

	return zone, pillar, light, particlePart, particles
end

-- ===== Archetype 回调 =====

-- 区域创建: 添加 Tower VFX
function HouYiW:OnAreaCreate(player, areaData)
	local zone, pillar, light, particlePart, particles = createTowerVFX(areaData.position, areaData.radius)
	areaData._vfxZone = zone
	areaData._vfxPillar = pillar
	areaData._vfxLight = light
	areaData._vfxParticlePart = particlePart
	areaData._vfxParticles = particles
end

-- 区域到期: 清理 VFX
function HouYiW:OnAreaExpire(player, areaData)
	local duration = areaData.config.Duration or 2

	-- 消散动画
	if areaData._vfxParticles then areaData._vfxParticles.Enabled = false end
	if areaData._vfxZone then
		TweenService:Create(areaData._vfxZone, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(areaData._vfxZone, 0.5)
	end
	if areaData._vfxPillar then
		TweenService:Create(areaData._vfxPillar, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(areaData._vfxPillar, 0.5)
	end
	if areaData._vfxLight then
		TweenService:Create(areaData._vfxLight, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	end
	if areaData._vfxParticlePart then
		Debris:AddItem(areaData._vfxParticlePart, 0.5)
	end
end

-- 重写 OnCast: 投放位置范围限制
function HouYiW:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local maxRange = self.Config.Range or 45
	local startPos = rootPart.Position
	local dist = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Magnitude
	local castPos
	if dist <= maxRange then
		castPos = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
	else
		castPos = startPos + (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit * maxRange
	end

	-- 调用父类, 使用限制后的位置
	AreaSkill.OnCast(self, player, castPos)
end

return HouYiW
