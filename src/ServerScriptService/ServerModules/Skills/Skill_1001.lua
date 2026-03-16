-- ==========================================
-- Skill_1001: Fireball (火球术)
-- Archetype: ProjectileSkill
-- 效果: 3900 (Damage 2500)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ProjectileSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("ProjectileSkill"))

local FireballSkill = setmetatable({}, ProjectileSkill)
FireballSkill.__index = FireballSkill

function FireballSkill.new(skillID)
	return setmetatable(ProjectileSkill.new(skillID), FireballSkill)
end

-- VFX: 爆炸特效
local function playExplosionVFX(hitPosition, scale)
	local explosion = Instance.new("Part")
	explosion.Shape = Enum.PartType.Ball
	explosion.Material = Enum.Material.Neon
	explosion.Color = Color3.fromRGB(255, 60, 0)
	explosion.Size = Vector3.new(2, 2, 2) * scale
	explosion.Position = hitPosition
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Parent = workspace

	local tween = TweenService:Create(explosion, TweenInfo.new(0.3), {
		Size = Vector3.new(12, 12, 12) * scale,
		Transparency = 1
	})
	tween:Play()
	tween.Completed:Connect(function() explosion:Destroy() end)
end

function FireballSkill:OnProjectileHit(player, target, hitPos)
	local damageBoost = self:GetRuneStat("DamageBoost")
	local scale = (damageBoost > 0) and damageBoost or 1
	playExplosionVFX(hitPos, scale)
end

function FireballSkill:OnProjectileExpire(player, lastPos)
	local damageBoost = self:GetRuneStat("DamageBoost")
	local scale = (damageBoost > 0) and damageBoost or 1
	playExplosionVFX(lastPos, scale * 0.5)
end

return FireballSkill
