-- ==========================================
-- Skill_1008: AngelaR (炽热光辉)
-- Archetype: BeamSkill (Mode=Channel, TrackMouse=true)
-- 效果: 3024(Damage 200/tick)
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeamSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("BeamSkill"))

local AngelaR = setmetatable({}, BeamSkill)
AngelaR.__index = AngelaR

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

function AngelaR.new(skillID)
	return setmetatable(BeamSkill.new(skillID), AngelaR)
end

-- ===== VFX 状态 =====
-- 存储在每次 OnCast 调用的 upvalue 中

-- ===== 重写 OnCast: 添加光束VFX, 然后让父类处理伤害逻辑 =====
function AngelaR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end
	local rootPart = character.HumanoidRootPart

	local config = self:GetBeamConfig()
	local beamWidth = config.Width
	local maxRange = config.Range
	local duration = config.Duration

	-- 初始方向
	local currentAngle = math.atan2(targetPos.X - rootPart.Position.X, targetPos.Z - rootPart.Position.Z)
	local direction = Vector3.new(math.sin(currentAngle), 0, math.cos(currentAngle))
	local beamStart = rootPart.Position + direction * 3

	-- === 创建持续光束 VFX ===
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

	-- VFX 跟随光束角度 (用 Heartbeat 更新)
	local vfxStartTime = os.clock()
	local vfxAngle = currentAngle

	-- 监听方向事件来同步VFX角度
	local dirEvent = ReplicatedStorage:FindFirstChild("SkillDirectionEvent")
	local vfxDirConn
	if dirEvent then
		vfxDirConn = dirEvent.OnServerEvent:Connect(function(sender, newTargetPos)
			if sender ~= player then return end
			if not isFiniteVector3(newTargetPos) then return end
			vfxAngle = math.atan2(newTargetPos.X - rootPart.Position.X, newTargetPos.Z - rootPart.Position.Z)
		end)
	end

	local vfxConn
	vfxConn = RunService.Heartbeat:Connect(function(dt)
		local elapsed = os.clock() - vfxStartTime
		if elapsed >= duration or not rootPart or not rootPart.Parent then
			-- 清理 VFX
			vfxConn:Disconnect()
			if vfxDirConn then vfxDirConn:Disconnect() end

			fireParticles.Enabled = false
			pulseTween:Cancel()
			glowPulse:Cancel()
			TweenService:Create(beam, TweenInfo.new(0.25), { Transparency = 1, Size = Vector3.new(beamWidth * 0.3, beamWidth * 0.3, maxRange) }):Play()
			TweenService:Create(glow, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			TweenService:Create(beamLight, TweenInfo.new(0.25), { Brightness = 0 }):Play()

			Debris:AddItem(beam, 0.3)
			Debris:AddItem(glow, 0.3)
			Debris:AddItem(originPart, 0.5)
			return
		end

		-- 缓慢转向 (与 BeamSkill 同步)
		local turnSpeed = config.TurnSpeed or 1.5
		local angleDiff = vfxAngle - currentAngle
		angleDiff = math.atan2(math.sin(angleDiff), math.cos(angleDiff))
		local maxTurn = turnSpeed * dt
		if math.abs(angleDiff) > maxTurn then
			currentAngle = currentAngle + maxTurn * (angleDiff > 0 and 1 or -1)
		else
			currentAngle = vfxAngle
		end

		direction = Vector3.new(math.sin(currentAngle), 0, math.cos(currentAngle))
		beamStart = rootPart.Position + direction * 3

		local beamCF = CFrame.new(beamStart + direction * (maxRange / 2), beamStart + direction * maxRange)
		beam.CFrame = beamCF
		glow.CFrame = beamCF
		originPart.CFrame = CFrame.new(beamStart, beamStart + direction)
	end)

	-- 调用父类处理伤害逻辑 (Channel模式)
	BeamSkill.OnCast(self, player, targetPos)
end

return AngelaR
