-- ==========================================
-- Skill_1005: LuxR (终极闪光)
-- Archetype: BeamSkill (Mode=Instant)
-- 效果: 3006 (Damage 500)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BeamSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("BeamSkill"))

local LuxR = setmetatable({}, BeamSkill)
LuxR.__index = LuxR

function LuxR.new(skillID)
	return setmetatable(BeamSkill.new(skillID), LuxR)
end

local function getSafeFlatDirection(fromPos, targetPos, fallbackCFrame)
	local flatOffset = Vector3.new(targetPos.X - fromPos.X, 0, targetPos.Z - fromPos.Z)
	if flatOffset.Magnitude >= 0.001 then
		return flatOffset.Unit
	end

	local fallback = fallbackCFrame and fallbackCFrame.LookVector or Vector3.new(0, 0, -1)
	fallback = Vector3.new(fallback.X, 0, fallback.Z)
	if fallback.Magnitude >= 0.001 then
		return fallback.Unit
	end

	return Vector3.new(0, 0, -1)
end

-- VFX: 蓄力
local function createChargeVFX(rootPart, direction, duration)
	local chargeOrb = Instance.new("Part")
	chargeOrb.Shape = Enum.PartType.Ball
	chargeOrb.Material = Enum.Material.Neon
	chargeOrb.Color = Color3.fromRGB(255, 255, 220)
	chargeOrb.Size = Vector3.new(1, 1, 1)
	chargeOrb.Position = rootPart.Position + direction * 3
	chargeOrb.Anchored = true
	chargeOrb.CanCollide = false
	chargeOrb.Transparency = 0.2
	chargeOrb.Parent = workspace

	TweenService:Create(chargeOrb, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(4, 4, 4), Transparency = 0
	}):Play()

	return chargeOrb
end

-- VFX: 光束
local function createBeamVFX(startPos, direction, length, beamWidth)
	local beam = Instance.new("Part")
	beam.Size = Vector3.new(beamWidth, beamWidth, length)
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 255, 240)
	beam.CFrame = CFrame.new(startPos + direction * (length / 2), startPos + direction * length)
	beam.Anchored = true
	beam.CanCollide = false
	beam.Parent = workspace

	local glow = Instance.new("Part")
	glow.Size = Vector3.new(beamWidth * 2.5, beamWidth * 2.5, length)
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(255, 240, 180)
	glow.CFrame = beam.CFrame
	glow.Anchored = true
	glow.CanCollide = false
	glow.Transparency = 0.5
	glow.Parent = workspace

	local fadeTime = 0.6
	TweenService:Create(beam, TweenInfo.new(fadeTime), { Transparency = 1, Size = Vector3.new(beamWidth * 0.3, beamWidth * 0.3, length) }):Play()
	TweenService:Create(glow, TweenInfo.new(fadeTime), { Transparency = 1, Size = Vector3.new(beamWidth * 4, beamWidth * 4, length) }):Play()

	Debris:AddItem(beam, fadeTime + 0.1)
	Debris:AddItem(glow, fadeTime + 0.1)
end

-- 重写 OnCast: 先播蓄力VFX，然后调用父类
function LuxR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local config = self:GetBeamConfig()
	local startPos = rootPart.Position
	local direction = getSafeFlatDirection(startPos, targetPos, rootPart.CFrame)

	-- 蓄力 VFX
	local chargeOrb = createChargeVFX(rootPart, direction, config.CastTime)

	-- 父类处理蓄力 + 命中
	BeamSkill.OnCast(self, player, targetPos)

	-- 蓄力 VFX 清理
	if chargeOrb and chargeOrb.Parent then
		TweenService:Create(chargeOrb, TweenInfo.new(0.15), { Transparency = 1 }):Play()
		Debris:AddItem(chargeOrb, 0.2)
	end

	-- 光束 VFX
	if rootPart and rootPart.Parent then
		local beamWidth = config.Width
		local extraShots = self:GetRuneStat("MultiShot")
		beamWidth = beamWidth + extraShots * 2
		createBeamVFX(rootPart.Position + direction * 3, direction, config.Range, beamWidth)
	end
end

return LuxR
