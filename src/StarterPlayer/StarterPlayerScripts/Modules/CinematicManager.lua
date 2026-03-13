-- ==========================================
-- 客户端：电影特写管理器 (Cinematic Manager)
-- 原神/绝区零风格的大招特写演出
-- ==========================================
local CinematicManager = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local CameraManager = require(script.Parent:WaitForChild("CameraManager"))

local isPlaying = false

-- ========== 屏幕UI元素 ==========
local playerGui = player:WaitForChild("PlayerGui")
local cinematicGui = Instance.new("ScreenGui")
cinematicGui.Name = "CinematicGui"
cinematicGui.DisplayOrder = 100
cinematicGui.IgnoreGuiInset = true
cinematicGui.ResetOnSpawn = false
cinematicGui.Parent = playerGui

-- 上下黑边
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0.12, 0)
topBar.Position = UDim2.new(0, 0, -0.12, 0)
topBar.BackgroundColor3 = Color3.new(0, 0, 0)
topBar.BorderSizePixel = 0
topBar.Parent = cinematicGui

local bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.new(1, 0, 0.12, 0)
bottomBar.Position = UDim2.new(0, 0, 1, 0)
bottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
bottomBar.BorderSizePixel = 0
bottomBar.Parent = cinematicGui

-- 闪白覆盖层
local flashFrame = Instance.new("Frame")
flashFrame.Size = UDim2.new(1, 0, 1, 0)
flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.ZIndex = 10
flashFrame.Parent = cinematicGui

-- 暗角覆盖层
local vignetteFrame = Instance.new("Frame")
vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
vignetteFrame.BackgroundColor3 = Color3.new(0, 0, 0)
vignetteFrame.BackgroundTransparency = 1
vignetteFrame.BorderSizePixel = 0
vignetteFrame.ZIndex = 5
vignetteFrame.Parent = cinematicGui

local savedCameraType = nil
local savedCameraCFrame = nil
local blur = nil
local colorCorrection = nil

-- ========== UI显隐控制 ==========
local hiddenGuis = {}

local function hideAllGameUI()
	hiddenGuis = {}
	-- 隐藏所有非电影的ScreenGui
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui ~= cinematicGui and gui.Enabled then
			gui.Enabled = false
			table.insert(hiddenGuis, gui)
		end
	end
	-- 隐藏玩家和敌人头顶BillboardGui
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			for _, v in ipairs(p.Character:GetDescendants()) do
				if v:IsA("BillboardGui") and v.Enabled then
					v.Enabled = false
					table.insert(hiddenGuis, v)
				end
			end
		end
	end
	local enemiesFolder = workspace:FindFirstChild("敌人")
	if enemiesFolder then
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			for _, v in ipairs(enemy:GetDescendants()) do
				if v:IsA("BillboardGui") and v.Enabled then
					v.Enabled = false
					table.insert(hiddenGuis, v)
				end
			end
		end
	end
end

local function restoreAllGameUI()
	for _, gui in ipairs(hiddenGuis) do
		if gui and gui.Parent then
			gui.Enabled = true
		end
	end
	hiddenGuis = {}
end

-- ========== 工具函数 ==========

function CinematicManager.IsPlaying()
	return isPlaying
end

local function showBars()
	TweenService:Create(topBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 0, 0, 0)}):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 0, 0.88, 0)}):Play()
end

local function hideBars()
	TweenService:Create(topBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 0, -0.12, 0)}):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 0, 1, 0)}):Play()
end

local function flash(duration, color)
	flashFrame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 0
	TweenService:Create(flashFrame, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	}):Play()
end

local function shakeCamera(intensity, duration)
	local startTime = os.clock()
	local baseCF = camera.CFrame
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			camera.CFrame = baseCF
			conn:Disconnect()
			return
		end
		local decay = 1 - (elapsed / duration)
		-- 使用正弦波形让震动更有节奏感
		local freq = 25
		local sx = math.sin(elapsed * freq) * intensity * decay * (math.random() * 0.4 + 0.8)
		local sy = math.cos(elapsed * freq * 1.3) * intensity * decay * (math.random() * 0.4 + 0.8)
		local sr = math.sin(elapsed * freq * 0.7) * intensity * 0.3 * decay
		camera.CFrame = baseCF * CFrame.new(sx, sy, 0) * CFrame.Angles(0, 0, math.rad(sr))
	end)
end

-- 丝滑镜头移动（贝塞尔曲线补间）
local function smoothCameraMove(targetCF, duration, easingStyle, easingDir)
	easingStyle = easingStyle or Enum.EasingStyle.Quint
	easingDir = easingDir or Enum.EasingDirection.InOut
	local tween = TweenService:Create(camera, TweenInfo.new(duration, easingStyle, easingDir), {
		CFrame = targetCF
	})
	tween:Play()
	return tween
end

-- 获取角色关节
local function getJoints(character)
	local joints = {}
	local isR6 = character:FindFirstChild("Torso") ~= nil

	if isR6 then
		local torso = character:FindFirstChild("Torso")
		joints.rootJoint = character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart:FindFirstChild("RootJoint")
		joints.rightShoulder = torso and torso:FindFirstChild("Right Shoulder")
		joints.leftShoulder = torso and torso:FindFirstChild("Left Shoulder")
		joints.neck = torso and torso:FindFirstChild("Neck")
	else
		local lowerTorso = character:FindFirstChild("LowerTorso")
		joints.rootJoint = lowerTorso and lowerTorso:FindFirstChild("Root")
		local rightUpperArm = character:FindFirstChild("RightUpperArm")
		joints.rightShoulder = rightUpperArm and rightUpperArm:FindFirstChild("RightShoulder")
		local leftUpperArm = character:FindFirstChild("LeftUpperArm")
		joints.leftShoulder = leftUpperArm and leftUpperArm:FindFirstChild("LeftShoulder")
		local head = character:FindFirstChild("Head")
		joints.neck = head and head:FindFirstChild("Neck")
	end

	return joints
end

local function saveJointC0(joints)
	local saved = {}
	for name, joint in pairs(joints) do
		if joint then saved[name] = joint.C0 end
	end
	return saved
end

local function restoreJointC0(joints, saved)
	for name, joint in pairs(joints) do
		if joint and saved[name] then
			TweenService:Create(joint, TweenInfo.new(0.3), {C0 = saved[name]}):Play()
		end
	end
end

local function poseArmsUp(joints, saved)
	if joints.rightShoulder and saved.rightShoulder then
		TweenService:Create(joints.rightShoulder, TweenInfo.new(0.4), {
			C0 = saved.rightShoulder * CFrame.Angles(math.rad(-150), 0, math.rad(20))
		}):Play()
	end
	if joints.leftShoulder and saved.leftShoulder then
		TweenService:Create(joints.leftShoulder, TweenInfo.new(0.4), {
			C0 = saved.leftShoulder * CFrame.Angles(math.rad(-150), 0, math.rad(-20))
		}):Play()
	end
	if joints.rootJoint and saved.rootJoint then
		TweenService:Create(joints.rootJoint, TweenInfo.new(0.4), {
			C0 = saved.rootJoint * CFrame.Angles(math.rad(10), 0, 0)
		}):Play()
	end
end

local function poseSlamDown(joints, saved, intensity)
	local armAngle = 30 + intensity * 10
	local bodyAngle = -20 - intensity * 5
	local tweenTime = 0.08
	if joints.rightShoulder and saved.rightShoulder then
		TweenService:Create(joints.rightShoulder, TweenInfo.new(tweenTime), {
			C0 = saved.rightShoulder * CFrame.Angles(math.rad(armAngle), 0, 0)
		}):Play()
	end
	if joints.leftShoulder and saved.leftShoulder then
		TweenService:Create(joints.leftShoulder, TweenInfo.new(tweenTime), {
			C0 = saved.leftShoulder * CFrame.Angles(math.rad(armAngle), 0, 0)
		}):Play()
	end
	if joints.rootJoint and saved.rootJoint then
		TweenService:Create(joints.rootJoint, TweenInfo.new(tweenTime), {
			C0 = saved.rootJoint * CFrame.Angles(math.rad(bodyAngle), 0, 0)
		}):Play()
	end
end

local function poseRaiseForSlam(joints, saved)
	if joints.rightShoulder and saved.rightShoulder then
		TweenService:Create(joints.rightShoulder, TweenInfo.new(0.2), {
			C0 = saved.rightShoulder * CFrame.Angles(math.rad(-140), 0, math.rad(15))
		}):Play()
	end
	if joints.leftShoulder and saved.leftShoulder then
		TweenService:Create(joints.leftShoulder, TweenInfo.new(0.2), {
			C0 = saved.leftShoulder * CFrame.Angles(math.rad(-140), 0, math.rad(-15))
		}):Play()
	end
	if joints.rootJoint and saved.rootJoint then
		TweenService:Create(joints.rootJoint, TweenInfo.new(0.2), {
			C0 = saved.rootJoint * CFrame.Angles(math.rad(15), 0, 0)
		}):Play()
	end
end

-- 客户端能量特效
local function createChargeVFX(rootPos)
	-- 能量环收缩
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 24, 24)
	ring.CFrame = CFrame.new(rootPos.X, rootPos.Y - 2, rootPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 100, 0)
	ring.Transparency = 0.4
	ring.Parent = workspace

	TweenService:Create(ring, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(0.3, 3, 3),
		Transparency = 0.1,
		Color = Color3.fromRGB(255, 200, 50)
	}):Play()
	Debris:AddItem(ring, 2.2)

	-- 能量粒子汇聚
	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2
		local dist = math.random(8, 14)
		local particle = Instance.new("Part")
		particle.Shape = Enum.PartType.Ball
		particle.Size = Vector3.new(0.6, 0.6, 0.6)
		particle.Position = rootPos + Vector3.new(math.cos(angle) * dist, math.random(-1, 3), math.sin(angle) * dist)
		particle.Anchored = true
		particle.CanCollide = false
		particle.Material = Enum.Material.Neon
		particle.Color = Color3.fromRGB(255, 150 + math.random(0, 80), 0)
		particle.Transparency = 0.3
		particle.Parent = workspace

		TweenService:Create(particle, TweenInfo.new(1.5 + math.random() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = rootPos + Vector3.new(0, 1, 0),
			Size = Vector3.new(0.2, 0.2, 0.2),
			Transparency = 1
		}):Play()
		Debris:AddItem(particle, 2.2)
	end

	return ring
end

-- ========== 廉颇终极特写 (5秒版) ==========
function CinematicManager.PlayLianPoUltimate(targetPos)
	if isPlaying then return end
	isPlaying = true

	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		isPlaying = false
		return
	end
	local rootPart = character.HumanoidRootPart
	local humanoid = character:FindFirstChild("Humanoid")

	-- 保存相机状态
	savedCameraType = camera.CameraType
	savedCameraCFrame = camera.CFrame

	-- 暂停MOBA摄像机
	CameraManager.SetPaused(true)
	camera.CameraType = Enum.CameraType.Scriptable

	-- 隐藏所有游戏UI
	hideAllGameUI()

	-- 暂停默认动画
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local pausedTracks = {}
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:AdjustSpeed(0)
			table.insert(pausedTracks, track)
		end
	end

	local joints = getJoints(character)
	local savedC0 = saveJointC0(joints)

	-- 光照效果
	blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = Lighting

	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Brightness = 0
	colorCorrection.Contrast = 0
	colorCorrection.Saturation = 0
	colorCorrection.TintColor = Color3.new(1, 1, 1)
	colorCorrection.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0
	dof.FocusDistance = 15
	dof.InFocusRadius = 20
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local rootPos = rootPart.Position
	local forwardDir = rootPart.CFrame.LookVector
	local rightDir = rootPart.CFrame.RightVector

	-- 快速甩镜辅助：瞬间Blur spike模拟运动模糊
	local function blurTransition()
		TweenService:Create(blur, TweenInfo.new(0.05), {Size = 20}):Play()
		task.delay(0.08, function()
			TweenService:Create(blur, TweenInfo.new(0.12), {Size = 3}):Play()
		end)
	end

	-- ================================================================
	--  PHASE 1：开场特写 (0-0.6s)
	-- ================================================================

	local blackScreen = Instance.new("Frame")
	blackScreen.Size = UDim2.new(1, 0, 1, 0)
	blackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
	blackScreen.BackgroundTransparency = 0
	blackScreen.BorderSizePixel = 0
	blackScreen.ZIndex = 20
	blackScreen.Parent = cinematicGui

	showBars()

	-- 脸部仰拍特写
	local facePos = rootPos + forwardDir * 2.5 + rightDir * 1.2 + Vector3.new(0, 1.8, 0)
	camera.CFrame = CFrame.lookAt(facePos, rootPos + Vector3.new(0, 2.8, 0))

	-- 景深+色调立即设置
	TweenService:Create(blur, TweenInfo.new(0.01), {Size = 5}):Play()
	TweenService:Create(dof, TweenInfo.new(0.01), {FarIntensity = 0.8, NearIntensity = 0.4}):Play()
	TweenService:Create(colorCorrection, TweenInfo.new(0.01), {
		Brightness = -0.15, Contrast = 0.3, Saturation = -0.3,
		TintColor = Color3.fromRGB(200, 180, 220)
	}):Play()

	-- 快速黑屏淡出(0.3s)
	TweenService:Create(blackScreen, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()

	-- 镜头快速推近
	local facePos2 = rootPos + forwardDir * 2 + rightDir * 1 + Vector3.new(0, 2.2, 0)
	smoothCameraMove(CFrame.lookAt(facePos2, rootPos + Vector3.new(0, 2.8, 0)), 0.6, Enum.EasingStyle.Sine)

	task.wait(0.6)
	blackScreen:Destroy()

	-- ================================================================
	--  PHASE 2：蓄力 + 快速环绕 + 跃起 (0.6-1.5s)
	-- ================================================================

	poseArmsUp(joints, savedC0)
	createChargeVFX(rootPos)

	-- 色调转暖
	TweenService:Create(colorCorrection, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
		Brightness = -0.1, Contrast = 0.35, Saturation = -0.1,
		TintColor = Color3.fromRGB(255, 180, 150)
	}):Play()
	TweenService:Create(dof, TweenInfo.new(0.8), {FarIntensity = 0.3, InFocusRadius = 40}):Play()

	-- 快速半环绕(0.5s)
	local orbitStart = os.clock()
	local orbitDuration = 0.5
	local orbitConn
	local startAngle = math.atan2(
		camera.CFrame.Position.Z - rootPos.Z,
		camera.CFrame.Position.X - rootPos.X
	)
	orbitConn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - orbitStart
		if elapsed >= orbitDuration then
			orbitConn:Disconnect()
			return
		end
		local rawT = elapsed / orbitDuration
		local t = rawT * rawT * (3 - 2 * rawT)
		local angle = startAngle + t * math.pi * 0.6
		local radius = 6 + math.sin(t * math.pi) * 2
		local camHeight = 2 + math.sin(t * math.pi) * 2.5
		camera.CFrame = CFrame.lookAt(
			rootPos + Vector3.new(math.cos(angle) * radius, camHeight, math.sin(angle) * radius),
			rootPos + Vector3.new(0, 1.5, 0)
		)
	end)

	task.wait(0.5)

	-- 跃起：快速拉远+闪光
	blurTransition()
	flash(0.1, Color3.fromRGB(255, 220, 150))

	if joints.rightShoulder and savedC0.rightShoulder then
		TweenService:Create(joints.rightShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
			C0 = savedC0.rightShoulder * CFrame.Angles(math.rad(-60), 0, 0)
		}):Play()
	end
	if joints.leftShoulder and savedC0.leftShoulder then
		TweenService:Create(joints.leftShoulder, TweenInfo.new(0.12, Enum.EasingStyle.Back), {
			C0 = savedC0.leftShoulder * CFrame.Angles(math.rad(-60), 0, 0)
		}):Play()
	end

	local pullBackPos = rootPos - forwardDir * 10 + Vector3.new(0, 12, 0)
	smoothCameraMove(
		CFrame.lookAt(pullBackPos, rootPos + Vector3.new(0, 5, 0)),
		0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out
	)

	task.wait(0.4)

	-- ================================================================
	--  PHASE 3：第1次砸地 (1.5-2.2s)
	-- ================================================================

	local slamPos = rootPart.Position

	-- 闪白遮盖镜头切换到侧面低角度
	flash(0.12)
	local slamCam1 = slamPos + rightDir * 5.5 + Vector3.new(0, 1, 0) + forwardDir * 2
	camera.CFrame = CFrame.lookAt(slamCam1, slamPos + Vector3.new(0, 0.5, 0))
	TweenService:Create(blur, TweenInfo.new(0.08), {Size = 3}):Play()

	poseSlamDown(joints, savedC0, 1)
	shakeCamera(1.8, 0.35)

	-- 微推进
	smoothCameraMove(
		CFrame.lookAt(slamCam1 - rightDir * 0.8, slamPos + Vector3.new(0, 0.3, 0)),
		0.5, Enum.EasingStyle.Sine
	)

	task.wait(0.55)

	-- ================================================================
	--  PHASE 4：第2次砸地 (2.2-3.0s)
	-- ================================================================

	poseRaiseForSlam(joints, savedC0)
	task.wait(0.15)

	-- 闪白+blur spike遮盖切换到背后仰视角
	flash(0.15)
	blurTransition()
	local slamCam2 = slamPos - forwardDir * 4 + Vector3.new(0, 1.5, 0) - rightDir * 2.5
	camera.CFrame = CFrame.lookAt(slamCam2, slamPos + Vector3.new(0, 1, 0))

	poseSlamDown(joints, savedC0, 2)
	shakeCamera(2.8, 0.4)

	TweenService:Create(colorCorrection, TweenInfo.new(0.1), {
		TintColor = Color3.fromRGB(255, 140, 100), Brightness = 0.05
	}):Play()

	smoothCameraMove(
		CFrame.lookAt(slamCam2 + forwardDir * 1.2, slamPos + Vector3.new(0, 0.8, 0)),
		0.5, Enum.EasingStyle.Sine
	)

	task.wait(0.6)

	-- ================================================================
	--  PHASE 5：终极一击 (3.0-4.0s)
	-- ================================================================

	poseRaiseForSlam(joints, savedC0)

	-- 拳头特写（极快平滑过渡）
	local fistPos = slamPos + Vector3.new(0, 3, 0)
	local fistCam = fistPos + forwardDir * 2 + rightDir * 1.2 + Vector3.new(0, 0.8, 0)
	blurTransition()
	smoothCameraMove(
		CFrame.lookAt(fistCam, fistPos),
		0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out
	)
	TweenService:Create(dof, TweenInfo.new(0.1), {FarIntensity = 0.9, InFocusRadius = 5, FocusDistance = 4}):Play()

	-- 短暂张力停顿
	task.wait(0.25)

	-- 终极砸下!
	poseSlamDown(joints, savedC0, 3)
	flash(0.4)
	shakeCamera(4.5, 0.8)

	TweenService:Create(colorCorrection, TweenInfo.new(0.06), {
		Brightness = 0.5, TintColor = Color3.fromRGB(255, 120, 60)
	}):Play()

	-- 镜头拉开看爆炸
	task.delay(0.08, function()
		local impactCam = slamPos - forwardDir * 6 + Vector3.new(0, 5, 0) + rightDir * 3
		smoothCameraMove(
			CFrame.lookAt(impactCam, slamPos),
			0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out
		)
	end)

	-- 橙红二次闪光
	task.delay(0.15, function()
		flash(0.35, Color3.fromRGB(255, 100, 30))
	end)

	-- 色调回归
	task.delay(0.3, function()
		TweenService:Create(colorCorrection, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
			Brightness = 0, TintColor = Color3.fromRGB(255, 200, 180)
		}):Play()
	end)

	task.wait(1.0)

	-- ================================================================
	--  PHASE 6：黑屏过渡恢复 (4.0-5.0s)
	-- ================================================================

	local fadeOut = Instance.new("Frame")
	fadeOut.Size = UDim2.new(1, 0, 1, 0)
	fadeOut.BackgroundColor3 = Color3.new(0, 0, 0)
	fadeOut.BackgroundTransparency = 1
	fadeOut.BorderSizePixel = 0
	fadeOut.ZIndex = 20
	fadeOut.Parent = cinematicGui

	-- 快速淡入黑屏(0.35s)
	TweenService:Create(fadeOut, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		BackgroundTransparency = 0
	}):Play()

	task.wait(0.4)

	-- 黑屏遮住时恢复一切
	if blur then blur:Destroy(); blur = nil end
	if colorCorrection then colorCorrection:Destroy(); colorCorrection = nil end
	if dof then dof:Destroy(); dof = nil end
	vignetteFrame.BackgroundTransparency = 1
	topBar.Position = UDim2.new(0, 0, -0.12, 0)
	bottomBar.Position = UDim2.new(0, 0, 1, 0)

	for name, joint in pairs(joints) do
		if joint and savedC0[name] then
			joint.C0 = savedC0[name]
		end
	end

	for _, track in ipairs(pausedTracks) do
		if track.IsPlaying then
			track:AdjustSpeed(1)
		end
	end

	camera.CameraType = savedCameraType
	CameraManager.SetPaused(false)
	restoreAllGameUI()

	task.wait(0.15)

	-- 快速淡出黑屏(0.4s)
	TweenService:Create(fadeOut, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	}):Play()

	task.wait(0.5)

	fadeOut:Destroy()
	isPlaying = false
end

-- ========== 初始化：监听服务端电影事件 ==========
function CinematicManager.Init()
	local CinematicEvent = ReplicatedStorage:WaitForChild("CinematicEvent", 10)
	if not CinematicEvent then
		warn("[CinematicManager] CinematicEvent not found!")
		return
	end
	CinematicEvent.OnClientEvent:Connect(function(cinematicName, targetPos)
		if cinematicName == "LianPoUltimate" then
			CinematicManager.PlayLianPoUltimate(targetPos)
		end
	end)
end

return CinematicManager