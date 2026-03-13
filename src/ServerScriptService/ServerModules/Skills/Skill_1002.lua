-- 拉克丝 Q: 光之束缚 (Light Binding)
-- 发射一道光线，命中第一个敌人时束缚并造成伤害

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))

local LuxQ = setmetatable({}, BaseSkill)
LuxQ.__index = LuxQ

function LuxQ.new(skillID)
	return setmetatable(BaseSkill.new(skillID), LuxQ)
end

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

function LuxQ:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local finalDamage = (self.Config.BaseDamage or 250) * powerScale
	local maxRange = self.Config.BaseRange or 50
	local speed = self.Config.Speed or 55
	local bindDuration = 1.5

	-- MultiShot: 增加最大命中目标数
	local extraShots = self:GetRuneStat("MultiShot")
	local maxHitsBase = 2 + extraShots

	local startPos = rootPart.Position
	local direction = (Vector3.new(targetPos.X, startPos.Y, targetPos.Z) - startPos).Unit

	-- 弹道光球
	local projectile = Instance.new("Part")
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(2, 2, 2)
	projectile.Material = Enum.Material.Neon
	projectile.Color = Color3.fromRGB(255, 240, 180)
	projectile.CFrame = CFrame.new(startPos + direction * 3, startPos + direction * 4)
	projectile.CanCollide = false
	projectile.Anchored = false
	projectile.Parent = workspace

	createProjectileTrail(projectile)

	local attachment = Instance.new("Attachment")
	attachment.Parent = projectile

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment
	lv.VectorVelocity = direction * speed
	lv.MaxForce = math.huge
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = projectile

	local hitCount = 0
	local maxHits = maxHitsBase
	local hitTargets = {}

	projectile.Touched:Connect(function(hit)
		if hit:IsDescendantOf(character) then return end
		local targetModel = hit.Parent
		local humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
		if not humanoid then
			targetModel = hit.Parent and hit.Parent.Parent
			humanoid = targetModel and targetModel:FindFirstChild("Humanoid")
		end

		if humanoid and not hitTargets[targetModel] then
			-- PvP: 只对敌方目标生效
			if not CombatUtils.isEnemy(player, targetModel) then return end
			hitTargets[targetModel] = true
			hitCount = hitCount + 1
			targetModel:SetAttribute("LastDamagePlayer", player.Name)
			humanoid:TakeDamage(finalDamage)

			-- 束缚: 临时锚定根部件
			local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local originalAnchored = targetRoot.Anchored
				targetRoot.Anchored = true
				createBindVFX(targetModel, bindDuration)

				task.delay(bindDuration, function()
					if targetRoot and targetRoot.Parent then
						targetRoot.Anchored = originalAnchored
					end
				end)
			end

			if hitCount >= maxHits then
				projectile:Destroy()
			end
		elseif not humanoid and hit.CanCollide then
			projectile:Destroy()
		end
	end)

	-- 超距离销毁
	task.spawn(function()
		while projectile and projectile.Parent do
			if (projectile.Position - startPos).Magnitude >= maxRange then
				projectile:Destroy()
				break
			end
			task.wait(0.05)
		end
	end)

	Debris:AddItem(projectile, 3)
end

return LuxQ
