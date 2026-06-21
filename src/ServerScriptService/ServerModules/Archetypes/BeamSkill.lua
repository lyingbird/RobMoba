local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))
local MovementState = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("MovementState"))

local BeamSkill = setmetatable({}, BaseSkill)
BeamSkill.__index = BeamSkill

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
	local flatOffset = Vector3.new(safeTargetPos.X - fromPos.X, 0, safeTargetPos.Z - fromPos.Z)
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

function BeamSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), BeamSkill)
end

function BeamSkill:GetBeamConfig()
	return {
		Width = self.Config.Width or 6,
		Range = self.Config.Range or self.Config.BaseRange or 100,
		Duration = self.Config.Duration or 0,
		TickInterval = self.Config.TickInterval or 0.3,
		TickEffects = self.Config.TickEffects or {},
		OnHitEffects = self.Config.OnHitEffects or {},
		Mode = self.Config.Mode or "Instant",
		TrackMouse = self.Config.TrackMouse or false,
		TurnSpeed = self.Config.TurnSpeed or 1.5,
		CastTime = self.Config.CastTime or 0,
	}
end

function BeamSkill:OnBeamHit(player, target, hitPos) end
function BeamSkill:OnBeamTick(player, targets) end
function BeamSkill:OnBeamEnd(player) end

function BeamSkill:_detectBeamTargets(player, character, beamStart, direction, range, halfWidth)
	local hitTargets = {}
	local enemies = CombatUtils.getEnemiesInRange(player, beamStart, range, character)
	for _, model in ipairs(enemies) do
		local targetRoot = model:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local toTarget = targetRoot.Position - beamStart
			local projected = toTarget:Dot(direction)
			if projected >= 0 and projected <= range then
				local closestPoint = beamStart + direction * projected
				local perpDist = (targetRoot.Position - closestPoint).Magnitude
				if perpDist <= halfWidth + 3 then
					table.insert(hitTargets, model)
				end
			end
		end
	end
	return hitTargets
end

function BeamSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChildOfClass("Humanoid")
	local config = self:GetBeamConfig()
	local halfWidth = config.Width / 2

	if config.CastTime > 0 then
		task.wait(config.CastTime)
	end

	if not character or not character.Parent or not rootPart or not rootPart.Parent then return end
	if humanoidSelf and (humanoidSelf.Health <= 0 or humanoidSelf:GetAttribute("CanCastSkill") == false) then return end

	if config.Mode == "Instant" then
		local startPos = rootPart.Position
		local direction = getSafeFlatDirection(startPos, targetPos, rootPart.CFrame)
		local beamStart = startPos + direction * 3
		local targets = self:_detectBeamTargets(player, character, beamStart, direction, config.Range, halfWidth)

		for _, model in ipairs(targets) do
			SkillHelper.ApplyEffects(self, character, model, config.OnHitEffects)
			model:SetAttribute("LastDamagePlayer", player.Name)
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			self:OnBeamHit(player, model, targetRoot and targetRoot.Position or beamStart)
		end
		self:OnBeamEnd(player)
		return
	end

	if config.Mode ~= "Channel" then return end

	local moveLockToken = MovementState.NewLockToken("beam_channel", player, self.ID)
	if humanoidSelf then
		MovementState.PushLock(humanoidSelf, moveLockToken)
	end

	local initialDirection = getSafeFlatDirection(rootPart.Position, targetPos, rootPart.CFrame)
	local currentAngle = math.atan2(initialDirection.X, initialDirection.Z)
	local targetAngle = currentAngle
	local dirConn
	local heartbeatConn
	local released = false

	local function cleanup(runEndCallback)
		if released then return end
		released = true

		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		if dirConn then
			dirConn:Disconnect()
			dirConn = nil
		end
		if humanoidSelf and humanoidSelf.Parent then
			MovementState.PopLock(humanoidSelf, moveLockToken)
		end
		if runEndCallback then
			local ok, err = pcall(function()
				self:OnBeamEnd(player)
			end)
			if not ok then
				warn("[BeamSkill] OnBeamEnd failed: " .. tostring(err))
			end
		end
	end

	if config.TrackMouse then
		local dirEvent = ReplicatedStorage:FindFirstChild("SkillDirectionEvent")
		if dirEvent then
			dirConn = dirEvent.OnServerEvent:Connect(function(sender, newTargetPos)
				if sender ~= player then return end
				if not isFiniteVector3(newTargetPos) then return end
				if not rootPart or not rootPart.Parent then return end

				local newDirection = getSafeFlatDirection(rootPart.Position, newTargetPos, rootPart.CFrame)
				targetAngle = math.atan2(newDirection.X, newDirection.Z)
			end)
		end
	end

	local startTime = os.clock()
	local lastTickTime = 0

	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		local ok, err = xpcall(function()
			local elapsed = os.clock() - startTime
			if elapsed >= config.Duration
				or not character
				or not character.Parent
				or not rootPart
				or not rootPart.Parent
				or (humanoidSelf and (humanoidSelf.Health <= 0 or humanoidSelf:GetAttribute("CanCastSkill") == false))
			then
				cleanup(true)
				return
			end

			if config.TrackMouse then
				local angleDiff = targetAngle - currentAngle
				angleDiff = math.atan2(math.sin(angleDiff), math.cos(angleDiff))
				local maxTurn = config.TurnSpeed * dt
				if math.abs(angleDiff) > maxTurn then
					currentAngle = currentAngle + maxTurn * (angleDiff > 0 and 1 or -1)
				else
					currentAngle = targetAngle
				end
			end

			local direction = Vector3.new(math.sin(currentAngle), 0, math.cos(currentAngle))
			local beamStart = rootPart.Position + direction * 3
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction)

			if elapsed - lastTickTime >= config.TickInterval then
				lastTickTime = elapsed
				local targets = self:_detectBeamTargets(player, character, beamStart, direction, config.Range, halfWidth)
				for _, model in ipairs(targets) do
					SkillHelper.ApplyEffects(self, character, model, config.TickEffects)
					model:SetAttribute("LastDamagePlayer", player.Name)
				end
				self:OnBeamTick(player, targets)
			end
		end, tostring)

		if not ok then
			warn("[BeamSkill] Channel heartbeat failed: " .. tostring(err))
			cleanup(true)
		end
	end)
end

return BeamSkill
