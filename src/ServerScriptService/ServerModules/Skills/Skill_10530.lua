local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AreaSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("Archetypes"):WaitForChild("AreaSkill"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))
local BuffSystem = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BuffSystem"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local MovementState = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("MovementState"))

local LianPoR = setmetatable({}, AreaSkill)
LianPoR.__index = LianPoR

local function isFiniteNumber(value)
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isFiniteVector3(value)
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function getSafeFlatDirection(fromPos, targetPos, fallbackCFrame)
	local safeTargetPos = isFiniteVector3(targetPos) and targetPos or (fromPos + (fallbackCFrame and fallbackCFrame.LookVector or Vector3.new(0, 0, -1)))
	local direction = Vector3.new(safeTargetPos.X - fromPos.X, 0, safeTargetPos.Z - fromPos.Z)
	if direction.Magnitude > 0.1 then
		return direction.Unit, direction.Magnitude
	end

	local fallback = fallbackCFrame and fallbackCFrame.LookVector or Vector3.new(0, 0, -1)
	fallback = Vector3.new(fallback.X, 0, fallback.Z)
	if fallback.Magnitude > 0.001 then
		return fallback.Unit, 0
	end

	return Vector3.new(0, 0, -1), 0
end

local function createSlamVFX(position, radius, intensity)
	local crack = Instance.new("Part")
	crack.Shape = Enum.PartType.Cylinder
	crack.Material = Enum.Material.Neon
	crack.Color = Color3.fromRGB(255, 140 - intensity * 30, 0)
	crack.Size = Vector3.new(0.3, 2, 2)
	crack.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	crack.Anchored = true
	crack.CanCollide = false
	crack.Transparency = 0.1
	crack.Parent = workspace

	TweenService:Create(crack, TweenInfo.new(0.3), {
		Size = Vector3.new(0.3, radius * 2 + intensity * 4, radius * 2 + intensity * 4),
		Transparency = 0.4,
	}):Play()

	task.delay(0.6, function()
		TweenService:Create(crack, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(crack, 1.2)

	local dustPart = Instance.new("Part")
	dustPart.Size = Vector3.new(1, 1, 1)
	dustPart.Position = position + Vector3.new(0, 1, 0)
	dustPart.Anchored = true
	dustPart.CanCollide = false
	dustPart.Transparency = 1
	dustPart.Parent = workspace

	local attach = Instance.new("Attachment")
	attach.Parent = dustPart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(Color3.fromRGB(180, 140, 80), Color3.fromRGB(120, 90, 50))
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1 + intensity),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(0.3, 0.7)
	particles.Rate = 0
	particles.Speed = NumberRange.new(8 + intensity * 5, 20 + intensity * 8)
	particles.SpreadAngle = Vector2.new(360, 40)
	particles.LightEmission = 0.2
	particles.Parent = attach
	particles:Emit(20 + intensity * 15)

	Debris:AddItem(dustPart, 1.2)

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(200, 150, 60)
	ring.Size = Vector3.new(0.2, 3, 3)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(0.35), {
		Size = Vector3.new(0.2, radius * 2.5 + intensity * 3, radius * 2.5 + intensity * 3),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.5)
end

function LianPoR.new(skillID)
	return setmetatable(AreaSkill.new(skillID), LianPoR)
end

function LianPoR:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChildOfClass("Humanoid")
	if not humanoidSelf or humanoidSelf.Health <= 0 then return end

	local maxRange = self.Config.Range or 5
	local radius = self.Config.Radius or 5
	local startPos = rootPart.Position
	local direction, requestedDistance = getSafeFlatDirection(startPos, targetPos, rootPart.CFrame)
	local landPos = startPos + direction * math.min(requestedDistance, maxRange)
	local moveLockToken = MovementState.NewLockToken("lianpo_r", player, self.ID)
	local jumpConn
	local released = false

	local function cleanup()
		if released then return end
		released = true

		if jumpConn then
			jumpConn:Disconnect()
			jumpConn = nil
		end
		if humanoidSelf and humanoidSelf.Parent then
			MovementState.PopLock(humanoidSelf, moveLockToken)
		end
	end

	MovementState.PushLock(humanoidSelf, moveLockToken)

	local ok, err = xpcall(function()
		for _, buffId in ipairs(self.Config.SelfBuffOnCast or {}) do
			BuffSystem:ApplyEffect(character, character, buffId)
		end

		local jumpTime = 0.5
		local jumpHeight = 10
		local jumpStart = os.clock()

		jumpConn = RunService.Heartbeat:Connect(function()
			local heartbeatOk, heartbeatErr = xpcall(function()
				if not character or not character.Parent or not rootPart or not rootPart.Parent then
					cleanup()
					return
				end

				local t = math.clamp((os.clock() - jumpStart) / jumpTime, 0, 1)
				local flatPos = startPos:Lerp(landPos, t)
				local yOffset = jumpHeight * 4 * t * (1 - t)
				rootPart.CFrame = CFrame.new(flatPos.X, flatPos.Y + yOffset, flatPos.Z)
					* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0)

				if t >= 1 and jumpConn then
					jumpConn:Disconnect()
					jumpConn = nil
				end
			end, tostring)

			if not heartbeatOk then
				warn("[LianPoR] Jump heartbeat failed: " .. tostring(heartbeatErr))
				cleanup()
			end
		end)

		task.wait(jumpTime)

		local stomps = {
			{
				effects = self.Config.Stomp1Effects or { 105300 },
				cc = self.Config.Stomp1CC or { 105390 },
				interval = 0,
			},
			{
				effects = self.Config.Stomp2Effects or { 105301 },
				cc = self.Config.Stomp2CC or { 105391 },
				interval = 0.7,
			},
			{
				effects = self.Config.Stomp3Effects or { 105302 },
				cc = self.Config.Stomp3CC or { 105392 },
				interval = 0.7,
			},
		}

		for stompIndex, stomp in ipairs(stomps) do
			if stompIndex > 1 then
				task.wait(stomp.interval)
			end

			if not character or not character.Parent or not rootPart or not rootPart.Parent or humanoidSelf.Health <= 0 then
				break
			end

			local slamPos = rootPart.Position
			local upHeight = 2 + stompIndex * 2
			local currentPos = rootPart.Position

			TweenService:Create(rootPart, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(currentPos + Vector3.new(0, upHeight, 0))
					* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0),
			}):Play()
			task.wait(0.15)

			TweenService:Create(rootPart, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = CFrame.new(currentPos)
					* CFrame.Angles(0, math.atan2(direction.X, direction.Z), 0),
			}):Play()
			task.wait(0.1)

			createSlamVFX(slamPos, radius, stompIndex)

			if #stomp.effects > 0 then
				SkillHelper.ApplyAreaEffects(self, character, player, slamPos, radius, stomp.effects)
			end

			if #stomp.cc > 0 then
				local enemies = CombatUtils.getEnemiesInRange(player, slamPos, radius, character)
				for _, enemy in ipairs(enemies) do
					for _, ccId in ipairs(stomp.cc) do
						BuffSystem:ApplyEffect(character, enemy, ccId)
					end
				end
			end
		end

		for _, removeId in ipairs(self.Config.RemoveBuffOnEnd or {}) do
			BuffSystem:RemoveEffect(character, removeId)
		end
	end, tostring)

	cleanup()
	if not ok then
		warn("[LianPoR] OnCast failed: " .. tostring(err))
	end
end

return LianPoR
