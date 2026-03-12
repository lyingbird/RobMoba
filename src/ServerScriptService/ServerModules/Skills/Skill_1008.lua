-- 安琪拉 R: 炽热光辉
-- 持续火焰激光，跟随鼠标缓慢转向（参考维克兹大招）

local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))

local AngelaR = setmetatable({}, BaseSkill)
AngelaR.__index = AngelaR

function AngelaR.new(skillID)
	return setmetatable(BaseSkill.new(skillID), AngelaR)
end

function AngelaR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local damageBoost = self:GetRuneStat("DamageBoost")
	local powerScale = (damageBoost > 0) and damageBoost or 1
	local totalDamage = (self.Config.BaseDamage or 200) * powerScale
	local maxRange = self.Config.BaseRange or 60
	local duration = self.Config.Duration or 3
	local tickCount = self.Config.TickCount or 10
	local beamWidth = self.Config.BeamWidth or 8
	local turnSpeed = self.Config.TurnSpeed or 1.5
	local damagePerTick = totalDamage / tickCount
	local halfWidth = beamWidth / 2

	local humanoidSelf = character:FindFirstChild("Humanoid")
	local originalSpeed = humanoidSelf and humanoidSelf.WalkSpeed or 16
	if humanoidSelf then humanoidSelf.WalkSpeed = 0 end

	local currentAngle = math.atan2(targetPos.X - rootPart.Position.X, targetPos.Z - rootPart.Position.Z)
	local targetAngle = currentAngle

	-- 监听客户端鼠标方向
	local dirEvent = ReplicatedStorage:FindFirstChild("SkillDirectionEvent")
	local dirConn
	if dirEvent then
		dirConn = dirEvent.OnServerEvent:Connect(function(sender, newTargetPos)
			if sender ~= player then return end
			if typeof(newTargetPos) ~= "Vector3" then return end
			targetAngle = math.atan2(newTargetPos.X - rootPart.Position.X, newTargetPos.Z - rootPart.Position.Z)
		end)
	end

	-- === 创建持续光束 ===
	local direction = Vector3.new(math.sin(currentAngle), 0, math.cos(currentAngle))
	local beamStart = rootPart.Position + direction * 3

	local beam = Instance.new("Part")
	beam.Size = Vector3.new(beamWidth, beamWidth, maxRange)
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 120, 0)
	beam.CFrame = CFrame.new(beamStart + direction * (maxRange / 2), beamStart + direction * maxRange)
	beam.Anchored = true
	beam.CanCollide = false
	beam.Transparency = 0.1
	beam.Parent = workspace

	local glow = Instance.new("Part")
	glow.Size = Vector3.new(beamWidth * 2.2, beamWidth * 2.2, maxRange)
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(255, 60, 0)
	glow.CFrame = beam.CFrame
	glow.Anchored = true
	glow.CanCollide = false
	glow.Transparency = 0.55
	glow.Parent = workspace

	local beamLight = Instance.new("PointLight")
	beamLight.Color = Color3.fromRGB(255, 100, 0)
	beamLight.Brightness = 6
	beamLight.Range = 30
	beamLight.Parent = beam

	-- 起点火焰粒子
	local originPart = Instance.new("Part")
	originPart.Size = Vector3.new(1, 1, 1)
	originPart.Position = beamStart
	originPart.Anchored = true
	originPart.CanCollide = false
	originPart.Transparency = 1
	originPart.Parent = workspace

	local originAttach = Instance.new("Attachment")
	originAttach.Parent = originPart

	local fireParticles = Instance.new("ParticleEmitter")
	fireParticles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 50), Color3.fromRGB(255, 50, 0))
	fireParticles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0)})
	fireParticles.Lifetime = NumberRange.new(0.2, 0.4)
	fireParticles.Rate = 80
	fireParticles.Speed = NumberRange.new(20, 40)
	fireParticles.SpreadAngle = Vector2.new(10, 10)
	fireParticles.LightEmission = 1
	fireParticles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	fireParticles.Parent = originAttach

	-- 光束呼吸脉动
	local pulseTween = TweenService:Create(beam, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = Vector3.new(beamWidth * 1.15, beamWidth * 1.15, maxRange)
	})
	pulseTween:Play()

	local glowPulse = TweenService:Create(glow, TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.45
	})
	glowPulse:Play()

	-- === Heartbeat 实时更新 ===
	local startTime = os.clock()
	local lastDamageTick = 0
	local damageInterval = duration / tickCount

	local heartbeatConn
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		local elapsed = os.clock() - startTime

		if elapsed >= duration or not character or not character.Parent or not rootPart or not rootPart.Parent then
			heartbeatConn:Disconnect()
			if dirConn then dirConn:Disconnect() end

			fireParticles.Enabled = false
			pulseTween:Cancel()
			glowPulse:Cancel()
			TweenService:Create(beam, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(beamWidth * 0.3, beamWidth * 0.3, maxRange) }):Play()
			TweenService:Create(glow, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			TweenService:Create(beamLight, TweenInfo.new(0.25), { Brightness = 0 }):Play()

			Debris:AddItem(beam, 0.3)
			Debris:AddItem(glow, 0.3)
			Debris:AddItem(originPart, 0.5)

			if humanoidSelf and humanoidSelf.Parent then
				humanoidSelf.WalkSpeed = originalSpeed
			end
			return
		end

		-- 缓慢转向
		local angleDiff = targetAngle - currentAngle
		angleDiff = math.atan2(math.sin(angleDiff), math.cos(angleDiff))
		local maxTurn = turnSpeed * dt
		if math.abs(angleDiff) > maxTurn then
			currentAngle = currentAngle + maxTurn * (angleDiff > 0 and 1 or -1)
		else
			currentAngle = targetAngle
		end

		direction = Vector3.new(math.sin(currentAngle), 0, math.cos(currentAngle))
		beamStart = rootPart.Position + direction * 3

		local beamCF = CFrame.new(beamStart + direction * (maxRange / 2), beamStart + direction * maxRange)
		beam.CFrame = beamCF
		glow.CFrame = beamCF
		originPart.CFrame = CFrame.new(beamStart, beamStart + direction)
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)

		-- 定时伤害
		if elapsed - lastDamageTick >= damageInterval then
			lastDamageTick = elapsed

			local function checkModels(parent)
				for _, model in ipairs(parent:GetChildren()) do
					local humanoid = model:FindFirstChild("Humanoid")
					local tRoot = model:FindFirstChild("HumanoidRootPart")
					if humanoid and tRoot and model ~= character then
						local toTarget = tRoot.Position - beamStart
						local projected = toTarget:Dot(direction)
						if projected >= 0 and projected <= maxRange then
							local closestPoint = beamStart + direction * projected
							local perpDist = (tRoot.Position - closestPoint).Magnitude
							if perpDist <= halfWidth + 3 then
								humanoid:TakeDamage(damagePerTick)
							end
						end
					end
				end
			end

			checkModels(workspace)
			local enemyFolder = workspace:FindFirstChild("敌人")
			if enemyFolder then checkModels(enemyFolder) end
		end
	end)
end

return AngelaR
