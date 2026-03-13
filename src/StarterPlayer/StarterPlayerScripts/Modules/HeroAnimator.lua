--[[
	HeroAnimator v4 - Slow dramatic cast animations
	Phases: windup (crouch) -> launch (jump/float) -> hold (cast pose) -> recovery (descend)
	Features: BodyPosition float, book scaling for R, per-skill windup/cast poses
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local HeroConfig = require(ReplicatedStorage:WaitForChild("HeroConfig"))
local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))

local HeroAnimator = {}

local STATE = { IDLE = "Idle", CAST = "Cast", CHANNEL = "Channel" }

local character, humanoid, animator, config
local joints, defaultC0 = {}, {}
local currentState = STATE.IDLE
local castKey = nil
local castEndTime = 0
local bookModel, bookWeld, bookDefaultC0 = nil, nil, nil
local renderConn = nil
local stateTime = 0
local targetPose, windupPose = {}, {}
local castPhase = "none"
local phaseTimings = {}
local targetLift = 0
local bodyPosMover = nil
local moveLocked = false
local moveLockRule = "none" -- "none"/"until_fire"/"full"

local JOINT_MAP = {
	{ name = "Root", parent = "LowerTorso" },
	{ name = "Waist", parent = "UpperTorso" },
	{ name = "Neck", parent = "Head" },
	{ name = "RightShoulder", parent = "RightUpperArm" },
	{ name = "LeftShoulder", parent = "LeftUpperArm" },
	{ name = "RightElbow", parent = "RightLowerArm" },
	{ name = "LeftElbow", parent = "LeftLowerArm" },
	{ name = "RightHip", parent = "RightUpperLeg" },
	{ name = "LeftHip", parent = "LeftUpperLeg" },
}

local function degToCFrame(angles)
	if not angles then return CFrame.new() end
	return CFrame.Angles(math.rad(angles[1] or 0), math.rad(angles[2] or 0), math.rad(angles[3] or 0))
end

local function loadPose(poseName)
	local pose = {}
	local poseData = config.Poses and config.Poses[poseName]
	if poseData then
		for jointName, angles in pairs(poseData) do
			pose[jointName] = degToCFrame(angles)
		end
	end
	return pose
end

-- === Book ===
local function createBook()
	local acc = config.Accessory
	if not acc or acc.Type ~= "Book" then return end

	local cover = Instance.new("Part")
	cover.Name = "BookCover"
	cover.Size = acc.Size
	cover.Color = acc.CoverColor or Color3.fromRGB(180, 30, 30)
	cover.Material = Enum.Material.SmoothPlastic
	cover.CanCollide = false
	cover.Massless = true
	cover.Anchored = false
	cover.Parent = character

	local pages = Instance.new("Part")
	pages.Name = "BookPages"
	pages.Size = Vector3.new(acc.Size.X * 0.9, acc.Size.Y * 0.7, acc.Size.Z * 0.95)
	pages.Color = acc.PageColor or Color3.fromRGB(255, 240, 210)
	pages.Material = Enum.Material.SmoothPlastic
	pages.CanCollide = false
	pages.Massless = true
	pages.Anchored = false
	pages.Parent = character

	local pw = Instance.new("WeldConstraint")
	pw.Part0 = cover
	pw.Part1 = pages
	pw.Parent = pages
	pages.CFrame = cover.CFrame * CFrame.new(0, 0.03, 0)

	local glow = Instance.new("PointLight")
	glow.Name = "BookGlow"
	glow.Color = acc.GlowColor or Color3.fromRGB(255, 120, 0)
	glow.Brightness = acc.IdleGlow or 1.5
	glow.Range = 6
	glow.Parent = cover

	local att = Instance.new("Attachment")
	att.Name = "BookParticleAtt"
	att.Parent = cover

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "BookFireParticles"
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 50, 0))
	particles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
	particles.Lifetime = NumberRange.new(0.3, 0.6)
	particles.Rate = acc.ParticleRate or 8
	particles.Speed = NumberRange.new(0.5, 1.5)
	particles.SpreadAngle = Vector2.new(30, 30)
	particles.LightEmission = 1
	particles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	particles.Parent = att

	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("LeftLowerArm")
	if leftHand then
		local weld = Instance.new("Weld")
		weld.Name = "BookWeld"
		weld.Part0 = leftHand
		weld.Part1 = cover
		weld.C0 = CFrame.new(0, -0.5, -0.3) * CFrame.Angles(math.rad(-30), 0, 0)
		weld.Parent = cover
		bookWeld = weld
		bookDefaultC0 = weld.C0
	end

	bookModel = cover
end

local function cacheJoints()
	joints = {}
	defaultC0 = {}
	for _, info in ipairs(JOINT_MAP) do
		local parent = character:FindFirstChild(info.parent)
		if parent then
			local joint = parent:FindFirstChild(info.name)
			if joint and joint:IsA("Motor6D") then
				joints[info.name] = joint
				defaultC0[info.name] = joint.C0
			end
		end
	end
end

local function stopDefaultAnimations()
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0.1)
		end
	end
	local animate = character:FindFirstChild("Animate")
	if animate then animate.Disabled = true end
	for _, joint in pairs(joints) do
		joint.Transform = CFrame.new()
	end
end

local function resumeDefaultAnimations()
	for name, joint in pairs(joints) do
		if defaultC0[name] then joint.C0 = defaultC0[name] end
	end
	local animate = character:FindFirstChild("Animate")
	if animate then animate.Disabled = false end
	if bookWeld and bookDefaultC0 then bookWeld.C0 = bookDefaultC0 end
	if bookModel and bookModel.Parent and config and config.Accessory then
		bookModel.Size = config.Accessory.Size
	end
end

-- === Float ===
local function startFloat(height)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if bodyPosMover then bodyPosMover:Destroy() end
	local bp = Instance.new("BodyPosition")
	bp.Name = "CastFloat"
	bp.MaxForce = Vector3.new(0, 100000, 0)
	bp.D = 400
	bp.P = 6000
	bp.Position = rootPart.Position + Vector3.new(0, height, 0)
	bp.Parent = rootPart
	bodyPosMover = bp
end

local function stopFloat()
	targetLift = 0
	if bodyPosMover then bodyPosMover:Destroy(); bodyPosMover = nil end
end

-- === VFX ===
local function playCastFlash()
	if not config.Theme then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(rootPart.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = config.Theme
	ring.Anchored = true
	ring.CanCollide = false
	ring.Transparency = 0.3
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 16, 16), Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.7)

	local hl = Instance.new("Highlight")
	hl.FillColor = config.Theme
	hl.FillTransparency = 0.5
	hl.OutlineColor = config.Theme
	hl.OutlineTransparency = 0
	hl.Parent = character
	Debris:AddItem(hl, 0.5)

	if bookModel and bookModel.Parent then
		local att = bookModel:FindFirstChild("BookParticleAtt")
		if att then
			local burst = Instance.new("ParticleEmitter")
			burst.Color = ColorSequence.new(config.Theme)
			burst.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0)})
			burst.Lifetime = NumberRange.new(0.3, 0.7)
			burst.Speed = NumberRange.new(5, 15)
			burst.SpreadAngle = Vector2.new(180, 180)
			burst.LightEmission = 1
			burst.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
			burst.Parent = att
			task.delay(0.15, function() burst.Enabled = false; Debris:AddItem(burst, 0.8) end)
		end
	end
end

-- === State ===
local function setState(newState, key)
	currentState = newState
	castKey = key
	stateTime = 0

	if newState == STATE.IDLE then
		castPhase = "none"
		moveLocked = false
		moveLockRule = "none"
		stopFloat()
		resumeDefaultAnimations()
		return
	end

	stopDefaultAnimations()

	-- 设置移动锁定
	moveLockRule = config.MoveLock and config.MoveLock[key] or "none"
	moveLocked = (moveLockRule ~= "none")

	-- Load per-skill windup and cast poses
	windupPose = loadPose("Windup" .. (key or "Q"))
	if not next(windupPose) then
		windupPose = {
			["RightShoulder"] = CFrame.Angles(math.rad(30), 0, math.rad(20)),
			["LeftShoulder"] = CFrame.Angles(math.rad(30), 0, math.rad(-20)),
			["Waist"] = CFrame.Angles(math.rad(15), 0, 0),
		}
	end
	targetPose = loadPose("Cast" .. (key or "Q"))

	local dur = config.CastDurations and config.CastDurations[key] or 0.8
	local lift = config.CastLift and config.CastLift[key] or 0
	targetLift = lift

	local now = os.clock()
	if newState == STATE.CHANNEL then
		-- Channel: longer windup/launch, long hold
		phaseTimings = {
			windupEnd = now + 0.5,
			launchEnd = now + 1.0,
			holdEnd   = now + dur - 0.8,
			castEnd   = now + dur,
		}
	elseif key == "Q" then
		-- Q: 先跳起来(长) 再释放(短)
		phaseTimings = {
			windupEnd = now + dur * 0.3,     -- 30% 蓄力下蹲
			launchEnd = now + dur * 0.55,    -- 25% 跳起上升
			holdEnd   = now + dur * 0.8,     -- 25% 空中释放
			castEnd   = now + dur,           -- 20% 下降收招
		}
	else
		-- W etc: 快速 windup 然后释放
		phaseTimings = {
			windupEnd = now + dur * 0.35,
			launchEnd = now + dur * 0.45,
			holdEnd   = now + dur * 0.75,
			castEnd   = now + dur,
		}
	end
	castEndTime = now + dur
	castPhase = "windup"
	playCastFlash()
end

-- === Book VFX ===
local function updateBookVFX(dt)
	if not bookModel or not bookModel.Parent then return end
	local acc = config and config.Accessory
	if not acc then return end

	local glow = bookModel:FindFirstChild("BookGlow")
	local att = bookModel:FindFirstChild("BookParticleAtt")
	local particles = att and att:FindFirstChild("BookFireParticles")
	local isCasting = (currentState ~= STATE.IDLE)
	local isRHold = (castKey == "R" and (castPhase == "hold" or castPhase == "launch"))

	if glow then
		local tb = isCasting and (isRHold and 10 or (acc.CastGlow or 5)) or (acc.IdleGlow or 1.5)
		glow.Brightness = glow.Brightness + (tb - glow.Brightness) * math.min(1, 5 * dt)
		glow.Range = isCasting and (isRHold and 20 or 12) or 6
	end
	if particles then
		particles.Rate = isCasting and (isRHold and 60 or (acc.CastParticleRate or 35)) or (acc.ParticleRate or 8)
		particles.Speed = isCasting and NumberRange.new(3, 8) or NumberRange.new(0.5, 1.5)
	end

	-- R hold: book grows and moves to front
	if bookWeld and bookDefaultC0 then
		if isRHold then
			local tC0 = CFrame.new(0.5, -1.2, -1.5) * CFrame.Angles(math.rad(-80), 0, 0)
			bookWeld.C0 = bookWeld.C0:Lerp(tC0, 4 * dt)
			local tSize = Vector3.new(acc.Size.X * 2.5, acc.Size.Y * 1.5, acc.Size.Z * 2)
			bookModel.Size = bookModel.Size:Lerp(tSize, 4 * dt)
		else
			bookWeld.C0 = bookWeld.C0:Lerp(bookDefaultC0, 6 * dt)
			bookModel.Size = bookModel.Size:Lerp(acc.Size, 6 * dt)
		end
	end
end

-- === Render ===
local function onRenderStep(dt)
	if not character or not character.Parent then return end
	if not humanoid or humanoid.Health <= 0 then return end
	stateTime = stateTime + dt

	if currentState == STATE.CAST or currentState == STATE.CHANNEL then
		local now = os.clock()

		-- Phase transitions
		if castPhase == "windup" and now >= phaseTimings.windupEnd then
			castPhase = "launch"
			if targetLift > 0 then startFloat(targetLift) end
		elseif castPhase == "launch" and now >= phaseTimings.launchEnd then
			castPhase = "hold"
			-- until_fire: 火球发出后解锁移动
			if moveLockRule == "until_fire" then
				moveLocked = false
			end
		elseif castPhase == "hold" and now >= phaseTimings.holdEnd then
			castPhase = "recovery"
			stopFloat()
			-- recovery阶段: 重新启用Animate脚本实现融合
			local animate = character:FindFirstChild("Animate")
			if animate then animate.Disabled = false end
			moveLocked = false
		end

		if now >= castEndTime then
			setState(STATE.IDLE)
			updateBookVFX(dt)
			return
		end

		-- Clear Transform (不在recovery阶段清除，让Animate融合)
		if castPhase ~= "recovery" then
			for _, joint in pairs(joints) do
				joint.Transform = CFrame.new()
			end
		end

		-- Apply joint animation per phase
		for jointName, joint in pairs(joints) do
			local base = defaultC0[jointName]
			local target

			if castPhase == "windup" then
				local offset = windupPose[jointName] or CFrame.new()
				target = base * offset
				joint.C0 = joint.C0:Lerp(target, 6 * dt)  -- SLOW crouch
			elseif castPhase == "launch" then
				local offset = targetPose[jointName] or CFrame.new()
				target = base * offset
				joint.C0 = joint.C0:Lerp(target, 10 * dt) -- medium rise
			elseif castPhase == "hold" then
				local offset = targetPose[jointName] or CFrame.new()
				target = base * offset
				joint.C0 = joint.C0:Lerp(target, 5 * dt)  -- slow maintain
			elseif castPhase == "recovery" then
				target = base
				joint.C0 = joint.C0:Lerp(target, 4 * dt)  -- slowest recovery
			end
		end
	end

	updateBookVFX(dt)
end

-- === API ===
function HeroAnimator.PlayCast(key)
	if not config then return end
	local skillID = config.Skills and config.Skills[key]
	if skillID then
		local sd = SkillConfig[skillID]
		if sd and sd.Duration and sd.Duration > 1 then
			setState(STATE.CHANNEL, key)
			return
		end
	end
	setState(STATE.CAST, key)
end

function HeroAnimator.Init(char, heroID)
	HeroAnimator.Cleanup()
	character = char
	humanoid = char:WaitForChild("Humanoid")
	animator = humanoid:FindFirstChildOfClass("Animator")
	config = HeroConfig[heroID]
	if not config then warn("[HeroAnimator] Unknown hero: " .. tostring(heroID)); return end
	cacheJoints()
	if config.Accessory then createBook() end
	currentState = STATE.IDLE
	castPhase = "none"
	renderConn = RunService.RenderStepped:Connect(onRenderStep)
	print("[HeroAnimator] Init: " .. config.DisplayName)
end

function HeroAnimator.GetState() return currentState end
function HeroAnimator.GetConfig() return config end
function HeroAnimator.GetHeroID() return config and config.HeroID end
function HeroAnimator.IsMoveLocked() return moveLocked end

-- W技能等可以被移动打断的动画
function HeroAnimator.TryInterrupt()
	if currentState == STATE.IDLE then return end
	if moveLocked then return false end
	-- 可以打断: 立即回到idle
	setState(STATE.IDLE)
	return true
end

function HeroAnimator.Cleanup()
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	stopFloat()
	if bookModel and bookModel.Parent then
		local pg = character and character:FindFirstChild("BookPages")
		if pg then pg:Destroy() end
		bookModel:Destroy(); bookModel = nil
	end
	bookWeld = nil; bookDefaultC0 = nil
	for name, joint in pairs(joints) do
		if defaultC0[name] then joint.C0 = defaultC0[name] end
	end
	if character then
		local animate = character:FindFirstChild("Animate")
		if animate then animate.Disabled = false end
	end
	currentState = STATE.IDLE; castPhase = "none"; config = nil
end

return HeroAnimator
