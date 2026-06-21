-- ==========================================
-- Skill_10510: LianPoQ (爆裂冲撞)
-- 来源: 王者荣耀 21号表 10510 + 22号表 105100/105190/105101
-- Archetype: DashSkill
--
-- 机制:
--   方向冲刺(距离5studs) → 路径上敌人:
--     物理伤害(150+30/lv, +3%额外HP)
--     击飞 0.5s
--   自身: +16怒气
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DashSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("DashSkill"))
local BuffSystem = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BuffSystem"))

local LianPoQ = setmetatable({}, DashSkill)
LianPoQ.__index = LianPoQ

function LianPoQ.new(skillID)
	return setmetatable(DashSkill.new(skillID), LianPoQ)
end

-- VFX: 冲刺痕迹
local function createDashVFX(startPos, endPos, width)
	local mid = (startPos + endPos) / 2
	local length = (endPos - startPos).Magnitude

	local trail = Instance.new("Part")
	trail.Size = Vector3.new(width, 0.3, length)
	trail.Material = Enum.Material.Neon
	trail.Color = Color3.fromRGB(200, 160, 80)
	trail.CFrame = CFrame.lookAt(mid, endPos)
	trail.CFrame = CFrame.new(mid.X, startPos.Y - 2, mid.Z) * (trail.CFrame - trail.CFrame.Position)
	trail.Anchored = true
	trail.CanCollide = false
	trail.Transparency = 0.3
	trail.Parent = workspace

	TweenService:Create(trail, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	Debris:AddItem(trail, 0.6)

	-- 终点尘埃粒子
	local dustPart = Instance.new("Part")
	dustPart.Size = Vector3.new(1, 1, 1)
	dustPart.Position = endPos
	dustPart.Anchored = true
	dustPart.CanCollide = false
	dustPart.Transparency = 1
	dustPart.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Parent = dustPart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(180, 150, 100), Color3.fromRGB(120, 100, 60))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.3, 0.6)
	particles.Rate = 0
	particles.Speed = NumberRange.new(5, 15)
	particles.SpreadAngle = Vector2.new(360, 30)
	particles.LightEmission = 0.3
	particles.Parent = attach
	particles:Emit(20)

	Debris:AddItem(dustPart, 1)
end

function LianPoQ:OnDashStart(player, startPos, dashDirection)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local config = self:GetDashConfig()
	local direction = dashDirection or character.HumanoidRootPart.CFrame.LookVector
	local endPos = startPos + direction * config.MaxRange
	createDashVFX(startPos, endPos, config.Width)

	-- 自身回怒 +16 (来源: 105101)
	for _, selfEffectId in ipairs(self.Config.SelfEffects or {}) do
		BuffSystem:ApplyEffect(character, character, selfEffectId)
	end
end

return LianPoQ
