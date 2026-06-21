local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local BaseSkill = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("BaseSkill"))
local CombatUtils = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("CombatUtils"))
local SkillHelper = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("SkillHelper"))
local MovementState = require(ServerScriptService:WaitForChild("ServerModules"):WaitForChild("MovementState"))

local DashSkill = setmetatable({}, BaseSkill)
DashSkill.__index = DashSkill

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

function DashSkill.new(skillID)
	return setmetatable(BaseSkill.new(skillID), DashSkill)
end

function DashSkill:GetDashConfig()
	return {
		Speed = self.Config.Speed or 40,
		Width = self.Config.Width or 6,
		MaxRange = self.Config.MaxRange or self.Config.Range or 30,
		OnDashHitEffects = self.Config.OnDashHitEffects or {},
		OnDashHitCC = self.Config.OnDashHitCC or {},
		LockMovement = (self.Config.LockMovement ~= false),
	}
end

function DashSkill:OnDashStart(player, startPos, direction, endPos) end
function DashSkill:OnDashHit(player, target) end
function DashSkill:OnDashEnd(player, endPos) end

function DashSkill:OnCast(player, targetPos)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then return end

	local rootPart = character.HumanoidRootPart
	local humanoidSelf = character:FindFirstChildOfClass("Humanoid")
	if not humanoidSelf or humanoidSelf.Health <= 0 then return end

	local config = self:GetDashConfig()
	local startPos = rootPart.Position
	local direction = getSafeFlatDirection(startPos, targetPos, rootPart.CFrame)
	local endPos = startPos + direction * config.MaxRange
	local dashTime = config.MaxRange / math.max(config.Speed, 0.001)
	local moveLockToken = MovementState.NewLockToken("dash", player, self.ID)
	local checkConn
	local released = false

	local function cleanup(runEndCallback)
		if released then return end
		released = true

		if checkConn then
			checkConn:Disconnect()
			checkConn = nil
		end
		if config.LockMovement and humanoidSelf and humanoidSelf.Parent then
			MovementState.PopLock(humanoidSelf, moveLockToken)
		end
		if runEndCallback then
			local ok, err = pcall(function()
				self:OnDashEnd(player, rootPart and rootPart.Parent and rootPart.Position or endPos)
			end)
			if not ok then
				warn("[DashSkill] OnDashEnd failed: " .. tostring(err))
			end
		end
	end

	if config.LockMovement then
		MovementState.PushLock(humanoidSelf, moveLockToken)
	end

	local startOk, startErr = xpcall(function()
		self:OnDashStart(player, startPos, direction, endPos)
	end, tostring)
	if not startOk then
		warn("[DashSkill] OnDashStart failed: " .. tostring(startErr))
		cleanup(false)
		return
	end

	if not rootPart or not rootPart.Parent then
		cleanup(false)
		return
	end

	rootPart.CFrame = CFrame.lookAt(startPos, startPos + direction)

	local tweenOk, tweenErr = pcall(function()
		local dashTween = TweenService:Create(
			rootPart,
			TweenInfo.new(dashTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.lookAt(endPos, endPos + direction) }
		)
		dashTween:Play()
	end)
	if not tweenOk then
		warn("[DashSkill] Tween failed: " .. tostring(tweenErr))
		cleanup(false)
		return
	end

	local hitTargets = {}
	local halfWidth = config.Width / 2

	checkConn = RunService.Heartbeat:Connect(function()
		local ok, err = xpcall(function()
			if not rootPart or not rootPart.Parent or not character or not character.Parent or humanoidSelf.Health <= 0 then
				cleanup(true)
				return
			end

			local currentPos = rootPart.Position
			local enemies = CombatUtils.getEnemiesInRange(player, currentPos, halfWidth + 3, character)
			for _, model in ipairs(enemies) do
				if not hitTargets[model] then
					hitTargets[model] = true

					local allEffects = {}
					for _, id in ipairs(config.OnDashHitEffects) do
						table.insert(allEffects, id)
					end
					for _, id in ipairs(config.OnDashHitCC) do
						table.insert(allEffects, id)
					end

					SkillHelper.ApplyEffects(self, character, model, allEffects)
					model:SetAttribute("LastDamagePlayer", player.Name)
					self:OnDashHit(player, model)
				end
			end
		end, tostring)

		if not ok then
			warn("[DashSkill] Heartbeat failed: " .. tostring(err))
			cleanup(true)
		end
	end)

	task.delay(dashTime, function()
		cleanup(true)
	end)
end

return DashSkill
