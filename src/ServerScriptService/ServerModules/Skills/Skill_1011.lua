-- ==========================================
-- Skill_1011: HouYiR (烈日裁决)
-- Archetype: ProjectileSkill (复合: 命中后落点爆炸)
-- 效果: 3042(Damage 500), 3043(Stun 1.5s), 3044(AOE Damage 250)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ProjectileSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("ProjectileSkill"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))

local HouYiR = setmetatable({}, ProjectileSkill)
HouYiR.__index = HouYiR

function HouYiR.new(skillID)
	return setmetatable(ProjectileSkill.new(skillID), HouYiR)
end

-- ===== VFX =====

local function createExplosionVFX(position, radius)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 150, 0)
	flash.Size = Vector3.new(3, 3, 3)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 0)
	light.Brightness = 8
	light.Range = radius * 2
	light.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.4), {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()

	-- 冲击波
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 180, 50)
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.4), {
		Size = Vector3.new(0.3, radius * 3, radius * 3),
		Transparency = 1
	}):Play()

	Debris:AddItem(flash, 0.5)
	Debris:AddItem(ring, 0.5)
end

local function createArrowTrail(arrow)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -2)
	a0.Parent = arrow
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, 2)
	a1.Parent = arrow

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 180, 50), Color3.fromRGB(255, 50, 0))
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	trail.Lifetime = 0.5
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 0)})
	trail.Parent = arrow

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 0)
	light.Brightness = 4
	light.Range = 15
	light.Parent = arrow
end

-- ===== 重写 _createBullet: 添加拖尾 =====
function HouYiR:_createBullet(config, startPos, direction)
	local bullet = ProjectileSkill._createBullet(self, config, startPos, direction)
	createArrowTrail(bullet)
	return bullet
end

-- ===== 爆炸逻辑 (命中/到期均触发) =====
local function triggerExplosion(self, player, position)
	local character = player.Character
	if not character then return end

	local explosionRadius = self.Config.ExplosionRadius or 12
	local explosionEffects = self.Config.ExplosionEffects or {}
	local explosionCC = self.Config.ExplosionCC or {}

	-- 爆炸 VFX
	createExplosionVFX(position, explosionRadius)

	-- 爆炸 AOE 效果 (通过 SkillHelper → BuffSystem)
	local allEffects = {}
	for _, id in ipairs(explosionEffects) do table.insert(allEffects, id) end
	for _, id in ipairs(explosionCC) do table.insert(allEffects, id) end
	if #allEffects > 0 then
		SkillHelper.ApplyAreaEffects(self, character, player, position, explosionRadius, allEffects)
	end
end

-- ===== 命中回调: 触发爆炸 =====
function HouYiR:OnProjectileHit(player, target, hitPos)
	triggerExplosion(self, player, hitPos)
end

-- ===== 超距离: 也触发爆炸 =====
function HouYiR:OnProjectileExpire(player, lastPos)
	triggerExplosion(self, player, lastPos)
end

return HouYiR
