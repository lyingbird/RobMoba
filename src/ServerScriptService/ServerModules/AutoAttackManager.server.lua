-- ==========================================
-- 服务端：普攻管理器 (Auto Attack Manager)
-- 职责：处理普攻伤害、冷却、特效
-- ==========================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AttackTargetEvent = ReplicatedStorage:WaitForChild("AttackTargetEvent")
local enemiesFolder = workspace:WaitForChild("敌人")

local ATTACK_DAMAGE = 100
local ATTACK_RANGE = 12
local ATTACK_INTERVAL = 0.8

local playerLastAttack = {}
local playerAnimating = {}

-- 程序攻击动画：身体前倾 + 右臂挥砍
local function playAttackAnimation(character, targetRoot)
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	-- 检测骨骼类型
	local isR6 = character:FindFirstChild("Torso") ~= nil
	local torso = isR6 and character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	if not torso then return end

	-- 找到 RootJoint（身体前倾用）
	local rootJoint
	if isR6 then
		rootJoint = rootPart:FindFirstChild("RootJoint")
	else
		local lowerTorso = character:FindFirstChild("LowerTorso")
		if lowerTorso then
			rootJoint = lowerTorso:FindFirstChild("Root")
		end
	end

	-- 找到右臂 Motor6D
	local rightShoulder
	if isR6 then
		rightShoulder = torso:FindFirstChild("Right Shoulder")
	else
		local rightUpperArm = character:FindFirstChild("RightUpperArm")
		if rightUpperArm then
			rightShoulder = rightUpperArm:FindFirstChild("RightShoulder")
		end
	end

	-- 暂停默认动画
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local pausedTracks = {}
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:AdjustSpeed(0)
			table.insert(pausedTracks, track)
		end
	end

	-- 保存原始 C0
	local origRootC0 = rootJoint and rootJoint.C0 or nil
	local origShoulderC0 = rightShoulder and rightShoulder.C0 or nil

	-- 阶段1：快速前倾 + 手臂举起 (0.08s)
	local tweenInfoFast = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if rootJoint and origRootC0 then
		local leanC0 = origRootC0 * CFrame.Angles(math.rad(-15), 0, 0)
		TweenService:Create(rootJoint, tweenInfoFast, {C0 = leanC0}):Play()
	end

	if rightShoulder and origShoulderC0 then
		local raiseC0 = origShoulderC0 * CFrame.Angles(math.rad(-120), math.rad(-20), 0)
		TweenService:Create(rightShoulder, tweenInfoFast, {C0 = raiseC0}):Play()
	end

	task.delay(0.08, function()
		-- 阶段2：挥砍下劈 (0.1s)
		local tweenInfoSwing = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		if rightShoulder and origShoulderC0 then
			local swingC0 = origShoulderC0 * CFrame.Angles(math.rad(30), math.rad(20), 0)
			TweenService:Create(rightShoulder, tweenInfoSwing, {C0 = swingC0}):Play()
		end

		task.delay(0.15, function()
			-- 阶段3：恢复原位 (0.2s)
			local tweenInfoRecover = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			if rootJoint and origRootC0 then
				TweenService:Create(rootJoint, tweenInfoRecover, {C0 = origRootC0}):Play()
			end
			if rightShoulder and origShoulderC0 then
				TweenService:Create(rightShoulder, tweenInfoRecover, {C0 = origShoulderC0}):Play()
			end

			-- 恢复默认动画
			task.delay(0.2, function()
				for _, track in ipairs(pausedTracks) do
					if track.IsPlaying then
						track:AdjustSpeed(1)
					end
				end
			end)
		end)
	end)
end

local function createSlashVFX(originRoot, targetRoot)
	local direction = (targetRoot.Position - originRoot.Position).Unit
	local midPoint = originRoot.Position + direction * 3

	local slash = Instance.new("Part")
	slash.Size = Vector3.new(4, 4, 0.3)
	slash.CFrame = CFrame.lookAt(midPoint, targetRoot.Position) * CFrame.Angles(0, 0, math.rad(math.random(-30, 30)))
	slash.Anchored = true
	slash.CanCollide = false
	slash.Material = Enum.Material.Neon
	slash.Color = Color3.fromRGB(255, 255, 200)
	slash.Transparency = 0.3
	slash.Parent = workspace

	TweenService:Create(slash, TweenInfo.new(0.3), {
		Transparency = 1,
		Size = Vector3.new(6, 6, 0.3)
	}):Play()

	Debris:AddItem(slash, 0.4)
end

AttackTargetEvent.OnServerEvent:Connect(function(player, targetModel)
	if not targetModel or not targetModel:IsA("Model") then return end
	if not targetModel:IsDescendantOf(enemiesFolder) then return end

	local targetHumanoid = targetModel:FindFirstChild("Humanoid")
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
	if not targetHumanoid or not targetRoot or targetHumanoid.Health <= 0 then return end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local dist = (rootPart.Position - targetRoot.Position).Magnitude
	if dist > ATTACK_RANGE then return end

	local userId = player.UserId
	local now = os.clock()
	if playerLastAttack[userId] and (now - playerLastAttack[userId]) < ATTACK_INTERVAL then return end
	playerLastAttack[userId] = now

	targetHumanoid:TakeDamage(ATTACK_DAMAGE)
	playAttackAnimation(character, targetRoot)
	createSlashVFX(rootPart, targetRoot)
end)

Players.PlayerRemoving:Connect(function(player)
	playerLastAttack[player.UserId] = nil
end)