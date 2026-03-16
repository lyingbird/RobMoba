-- ==========================================
-- Skill_1002: LuxQ (光之束缚)
-- Archetype: ProjectileSkill (MaxPierceCount=2)
-- 效果: 3001(Damage 250), 3002(Root 1s)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ProjectileSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("ProjectileSkill"))

local LuxQ = setmetatable({}, ProjectileSkill)
LuxQ.__index = LuxQ

function LuxQ.new(skillID)
	return setmetatable(ProjectileSkill.new(skillID), LuxQ)
end

-- ===== VFX =====

local function createBindVFX(targetModel, duration)
	local rootPart = targetModel:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- 光环束缚圈
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 240, 180)
	ring.Size = Vector3.new(0.3, 6, 6)
	ring.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace

	-- 光柱
	local pillar = Instance.new("Part")
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Material = Enum.Material.Neon
	pillar.Color = Color3.fromRGB(255, 255, 220)
	pillar.Size = Vector3.new(12, 2, 2)
	pillar.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.Transparency = 0.6
	pillar.Parent = workspace

	-- 光粒子
	local particleAttach = Instance.new("Attachment")
	particleAttach.Parent = ring

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 245, 200))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.4, 0.8)
	particles.Rate = 30
	particles.Speed = NumberRange.new(2, 5)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.LightEmission = 1
	particles.Parent = particleAttach

	-- 消散动画
	task.delay(duration - 0.3, function()
		TweenService:Create(ring, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(pillar, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		particles.Enabled = false
	end)

	Debris:AddItem(ring, duration + 0.5)
	Debris:AddItem(pillar, duration + 0.5)
end

local function createProjectileTrail(projectile)
	local attach = Instance.new("Attachment")
	attach.Parent = projectile

	local trail = Instance.new("Trail")
	local attach2 = Instance.new("Attachment")
	attach2.Position = Vector3.new(0, 0, 0.5)
	attach2.Parent = projectile
	attach.Position = Vector3.new(0, 0, -0.5)

	trail.Attachment0 = attach
	trail.Attachment1 = attach2
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(200, 180, 120))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.3
	trail.FaceCamera = true
	trail.LightEmission = 0.8
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	trail.Parent = projectile

	-- 点光源
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 240, 180)
	light.Brightness = 2
	light.Range = 12
	light.Parent = projectile
end

-- ===== Archetype 回调 =====

-- 重写 OnCast: 在创建弹体后添加拖尾VFX
function LuxQ:OnCast(player, targetPos)
	-- 调用父类标准弹道流程
	ProjectileSkill.OnCast(self, player, targetPos)
end

-- 弹体创建后添加拖尾 (重写 _createBullet)
function LuxQ:_createBullet(config, startPos, direction)
	local bullet = ProjectileSkill._createBullet(self, config, startPos, direction)
	createProjectileTrail(bullet)
	return bullet
end

-- 命中回调: 播放束缚 VFX
function LuxQ:OnProjectileHit(player, target, hitPos)
	createBindVFX(target, 1.0) -- 与 EffectConfig[3002].Duration 一致
end

-- 穿透回调: 第二个目标也播放束缚 VFX
function LuxQ:OnProjectilePierce(player, target, hitPos, count)
	createBindVFX(target, 1.0)
end

return LuxQ
