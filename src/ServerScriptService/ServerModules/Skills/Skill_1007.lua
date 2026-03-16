-- ==========================================
-- Skill_1007: AngelaW (混沌火种)
-- Archetype: ProjectileSkill (复合: 命中后创建漩涡区域)
-- 效果: 3021(Damage 400), 3022(Stun 1s), 3023(DoT 80/tick)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local ProjectileSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("ProjectileSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))
local BuffSystem = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BuffSystem"))

local AngelaW = setmetatable({}, ProjectileSkill)
AngelaW.__index = AngelaW

function AngelaW.new(skillID)
	return setmetatable(ProjectileSkill.new(skillID), AngelaW)
end

-- ===== VFX =====

local function createVortexVFX(position, radius, duration)
	-- 火焰漩涡地面圈
	local zone = Instance.new("Part")
	zone.Shape = Enum.PartType.Cylinder
	zone.Material = Enum.Material.Neon
	zone.Color = Color3.fromRGB(255, 80, 0)
	zone.Size = Vector3.new(0.5, radius * 2, radius * 2)
	zone.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 0.4
	zone.Parent = workspace

	-- 火焰粒子
	local particlePart = Instance.new("Part")
	particlePart.Size = Vector3.new(1, 1, 1)
	particlePart.Position = position + Vector3.new(0, 1, 0)
	particlePart.Anchored = true
	particlePart.CanCollide = false
	particlePart.Transparency = 1
	particlePart.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Parent = particlePart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 30, 0))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.4, 0.8)
	particles.Rate = 40
	particles.Speed = NumberRange.new(3, 8)
	particles.SpreadAngle = Vector2.new(360, 30)
	particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	particles.LightEmission = 1
	particles.Parent = attach

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 100, 0)
	light.Brightness = 4
	light.Range = radius + 5
	light.Parent = particlePart

	task.delay(duration - 0.3, function()
		particles.Enabled = false
		TweenService:Create(zone, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		TweenService:Create(light, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	end)

	Debris:AddItem(zone, duration + 0.5)
	Debris:AddItem(particlePart, duration + 0.5)
end

-- ===== 复合逻辑: 命中后创建漩涡区域 =====

local function createVortexArea(self, player, character, position)
	local vortexRadius = self.Config.VortexRadius or 8
	local vortexDuration = self.Config.VortexDuration or 3
	local vortexEffects = self.Config.VortexEffects or {}

	-- VFX
	createVortexVFX(position, vortexRadius, vortexDuration)

	-- 漩涡持续效果 (通过 SkillHelper → BuffSystem)
	if #vortexEffects > 0 then
		local tickInterval = vortexDuration / 6
		for tick = 1, 6 do
			task.delay(tickInterval * tick, function()
				if not character or not character.Parent then return end
				SkillHelper.ApplyAreaEffects(self, character, player, position, vortexRadius, vortexEffects)
			end)
		end
	end
end

-- ===== 弹体创建后添加光源 =====
function AngelaW:_createBullet(config, startPos, direction)
	local bullet = ProjectileSkill._createBullet(self, config, startPos, direction)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 0)
	light.Brightness = 3
	light.Range = 10
	light.Parent = bullet
	return bullet
end

-- ===== 命中回调: 创建漩涡区域 =====
function AngelaW:OnProjectileHit(player, target, hitPos)
	local character = player.Character
	if not character then return end
	createVortexArea(self, player, character, hitPos)
end

-- ===== 超距离时也在末端创建漩涡 =====
function AngelaW:OnProjectileExpire(player, lastPos)
	local character = player.Character
	if not character then return end
	createVortexArea(self, player, character, lastPos)
end

return AngelaW
