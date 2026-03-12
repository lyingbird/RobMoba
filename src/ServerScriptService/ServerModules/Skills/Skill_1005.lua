-- 拉克丝 R: 终极闪光 (Final Spark)
-- 短暂蓄力后向目标方向发射超远距离光束，对路径上所有敌人造成伤害

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local LuxR = setmetatable({}, BaseSkill)
LuxR.__index = LuxR

function LuxR.new(skillID)
	return setmetatable(BaseSkill.new(skillID), LuxR)
end

local function createChargeVFX(rootPart, direction, duration)
	-- 蓄力光芒
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

	-- 蓄力粒子
	local attach = Instance.new("Attachment")
	attach.Parent = chargeOrb

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 250, 200))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.3, 0.5)
	particles.Rate = 60
	particles.Speed = NumberRange.new(5, 10)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.LightEmission = 1
	particles.Parent = attach

	-- 蓄力光源
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 250, 200)
	light.Brightness = 2
	light.Range = 15
	light.Parent = chargeOrb

	-- 蓄力膨胀
	TweenService:Create(chargeOrb, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(4, 4, 4),
		Transparency = 0
	}):Play()

	TweenService:Create(light, TweenInfo.new(duration), { Brightness = 8, Range = 30 }):Play()

	return chargeOrb, particles, light
end

local function createBeamVFX(startPos, direction, length, beamWidth)
	-- 主光束
	local beam = Instance.new("Part")
	beam.Size = Vector3.new(beamWidth, beamWidth, length)
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 255, 240)
	beam.CFrame = CFrame.new(startPos + direction * (length / 2), startPos + direction * length)
	beam.Anchored = true
	beam.CanCollide = false
	beam.Transparency = 0
	beam.Parent = workspace

	-- 外层光晕
	local glow = Instance.new("Part")
	glow.Size = Vector3.new(beamWidth * 2.5, beamWidth * 2.5, length)
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(255, 240, 180)
	glow.CFrame = beam.CFrame
	glow.Anchored = true
	glow.CanCollide = false
	glow.Transparency = 0.5
	glow.Parent = workspace

	-- 中心极亮光源
	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(255, 255, 220)
	beamLight.Brightness = 10
	beamLight.Range = 40
	beamLight.Parent = beam

	-- 起点闪光
	local startFlash = Instance.new("Part")
	startFlash.Shape = Enum.PartType.Ball
	startFlash.Material = Enum.Material.Neon
	startFlash.Color = Color3.fromRGB(255, 255, 255)
	startFlash.Size = Vector3.new(beamWidth * 3, beamWidth * 3, beamWidth * 3)
	startFlash.Position = startPos
	startFlash.Anchored = true
	startFlash.CanCollide = false
	startFlash.Transparency = 0.2
	startFlash.Parent = workspace

	-- 终点闪光
	local endFlash = startFlash:Clone()
	endFlash.Position = startPos + direction * length
	endFlash.Parent = workspace

	-- 消散动画
	local fadeTime = 0.6

	TweenService:Create(beam, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = Vector3.new(beamWidth * 0.3, beamWidth * 0.3, length)
	}):Play()

	TweenService:Create(glow, TweenInfo.new(fadeTime), {
		Transparency = 1,
		Size = Vector3.new(beamWidth * 4, beamWidth * 4, length)
	}):Play()

	TweenService:Create(startFlash, TweenInfo.new(fadeTime), { Transparency = 1, Size = Vector3.new(1, 1, 1) }):Play()
	TweenService:Create(endFlash, TweenInfo.new(fadeTime), { Transparency = 1, Size = Vector3.new(1, 1, 1) }):Play()
	TweenService:Create(beamLight, TweenInfo.new(fadeTime), { Brightness = 0 }):Play()

	Debris:AddItem(beam, fadeTime + 0.1)
	Debris:AddItem(glow, fadeTime + 0.1)
	Debris:AddItem(startFlash, fadeTime + 0.1)
	Debris:AddItem(endFlash, fadeTime + 0.1)

	return beam
end

function LuxR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 500) * powerScale
	local maxRange = self.Config.BaseRange or 200
	local castTime = self.Config.CastTime or 1
	-- MultiShot: 增加光束宽度
	local extraShots = self:GetRuneStat("MultiShot")
	local beamWidth = 6 + extraShots * 2

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit

	-- 蓄力阶段
	local chargeOrb, chargeParticles, chargeLight = createChargeVFX(rootPart, direction, castTime)

	task.wait(castTime)

	-- 清除蓄力特效
	if chargeParticles then chargeParticles.Enabled = false end
	TweenService:Create(chargeOrb, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	Debris:AddItem(chargeOrb, 0.2)

	-- 发射光束
	local beamStart = rootPart.Position + direction * 3
	createBeamVFX(beamStart, direction, maxRange, beamWidth)

	-- 对光束路径上所有敌人造成伤害
	local hitTargets = {}
	local halfWidth = beamWidth / 2

	local function checkModels(parent)
		for _, model in ipairs(parent:GetChildren()) do
			if hitTargets[model] then continue end
			local humanoid = model:FindFirstChild("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and targetRoot and model ~= character then
				-- 计算目标到光束中心线的距离
				local toTarget = targetRoot.Position - beamStart
				local projected = toTarget:Dot(direction)

				if projected >= 0 and projected <= maxRange then
					local closestPointOnBeam = beamStart + direction * projected
					local perpDist = (targetRoot.Position - closestPointOnBeam).Magnitude

					if perpDist <= halfWidth + 3 then
						hitTargets[model] = true
						humanoid:TakeDamage(finalDamage)
					end
				end
			end
		end
	end

	checkModels(workspace)
	local enemyFolder = workspace:FindFirstChild("敌人")
	if enemyFolder then
		checkModels(enemyFolder)
	end
end

return LuxR
