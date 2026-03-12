-- 安琪拉 W: 混沌火种
-- 发射火种，到达最远处或命中目标时裂变为火焰漩涡，直接命中眩晕1秒

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local RunService = game:GetService("RunService")

local AngelaW = setmetatable({}, BaseSkill)
AngelaW.__index = AngelaW

function AngelaW.new(skillID)
	return setmetatable(BaseSkill.new(skillID), AngelaW)
end

local function applyStun(humanoid, stunDuration)
	local originalSpeed = humanoid.WalkSpeed
	local originalJump = humanoid.JumpPower
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	task.delay(stunDuration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
			humanoid.JumpPower = originalJump
		end
	end)
end

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

function AngelaW:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 400) * powerScale
	local maxRange = self.Config.BaseRange or 40
	local speed = self.Config.Speed or 50
	local stunDuration = self.Config.StunDuration or 1
	local vortexRadius = self.Config.VortexRadius or 8
	local vortexDuration = self.Config.VortexDuration or 3
	local vortexDamage = (self.Config.VortexDamage or 80) * powerScale

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit

	-- 发射火种弹体
	local seed = Instance.new("Part")
	seed.Shape = Enum.PartType.Ball
	seed.Size = Vector3.new(2, 2, 2)
	seed.Material = Enum.Material.Neon
	seed.Color = Color3.fromRGB(255, 100, 0)
	seed.CFrame = CFrame.new(startPos + direction * 3, startPos + direction * 4)
	seed.CanCollide = false
	seed.Anchored = false
	seed.Parent = workspace

	local att = Instance.new("Attachment")
	att.Parent = seed
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VectorVelocity = direction * speed
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = seed

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 0)
	light.Brightness = 3
	light.Range = 10
	light.Parent = seed

	local directHit = false
	local detonated = false

	local function detonate(pos, wasDirectHit, hitHumanoid)
		if detonated then return end
		detonated = true
		seed:Destroy()

		-- 直接命中眩晕
		if wasDirectHit and hitHumanoid then
			hitHumanoid:TakeDamage(finalDamage)
			applyStun(hitHumanoid, stunDuration)
		end

		-- 创建火焰漩涡
		createVortexVFX(pos, vortexRadius, vortexDuration)

		-- 漩涡持续伤害
		local tickInterval = vortexDuration / 6
		for tick = 1, 6 do
			task.delay(tickInterval * tick, function()
				local function checkModels(parent)
					for _, model in ipairs(parent:GetChildren()) do
						local humanoid = model:FindFirstChild("Humanoid")
						local targetRoot = model:FindFirstChild("HumanoidRootPart")
						if humanoid and targetRoot and model ~= character then
							if (targetRoot.Position - pos).Magnitude <= vortexRadius then
								humanoid:TakeDamage(vortexDamage)
							end
						end
					end
				end
				checkModels(workspace)
				local enemyFolder = workspace:FindFirstChild("敌人")
				if enemyFolder then checkModels(enemyFolder) end
			end)
		end
	end

	seed.Touched:Connect(function(hit)
		if detonated or hit:IsDescendantOf(character) then return end
		local targetModel = hit.Parent
		local humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
		if not humanoid then
			targetModel = hit.Parent and hit.Parent.Parent
			humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
		end

		if humanoid then
			detonate(seed.Position, true, humanoid)
		end
	end)

	-- 超距离引爆
	task.spawn(function()
		while not detonated and seed and seed.Parent do
			if (seed.Position - startPos).Magnitude >= maxRange then
				detonate(seed.Position, false, nil)
				break
			end
			task.wait(0.05)
		end
	end)

	Debris:AddItem(seed, 3)
end

return AngelaW
