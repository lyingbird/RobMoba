local InputManager = {}

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local MovementManager = require(script.Parent:WaitForChild("MovementManager"))
local CooldownManager = require(script.Parent:WaitForChild("CooldownManager"))
local UIManager = require(script.Parent.Parent:WaitForChild("UIManager"))
local SkillConfig = require(ReplicatedStorage:WaitForChild("SkillConfig"))
local CinematicManager = require(script.Parent:WaitForChild("CinematicManager"))
local HeroAnimator = require(script.Parent:WaitForChild("HeroAnimator"))
local HeroConfig = require(ReplicatedStorage:WaitForChild("HeroConfig"))

-- 全局启用/禁用开关（由 GameManager 状态控制）
local inputEnabled = true

-- RemoteEvents（懒加载，避免在 require 时阻塞）
local SkillDirectionEvent = nil
local AttackTargetEvent = nil

local function getSkillDirectionEvent()
	if not SkillDirectionEvent then
		SkillDirectionEvent = ReplicatedStorage:FindFirstChild("SkillDirectionEvent")
	end
	return SkillDirectionEvent
end

local function getAttackTargetEvent()
	if not AttackTargetEvent then
		AttackTargetEvent = ReplicatedStorage:FindFirstChild("AttackTargetEvent")
	end
	return AttackTargetEvent
end

local Players = game:GetService("Players")
local isChanneling = false

-- 普攻系统
local attackTarget = nil
local lastAttackTime = 0
local ATTACK_RANGE = 10
local ATTACK_INTERVAL = 0.8
local hoveredEnemy = nil
local enemyHighlight = nil
local enemiesFolder = workspace:WaitForChild("敌人")

--- 从 Part 向上查找目标 Model（NPC 或敌方玩家角色）
--- @param part Instance 鼠标悬停的零件
--- @return Model? 敌方目标模型
local function findTargetModel(part)
	local current = part
	while current and current ~= workspace do
		-- 检查是否为 NPC 敌人
		if current.Parent == enemiesFolder then
			return current
		end
		-- 检查是否为其他玩家的角色（排除自己）
		if current:IsA("Model") then
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer ~= player and otherPlayer.Character == current then
					-- 检查是否为不同 Team（敌方）
					local myTeam = player.Team
					local theirTeam = otherPlayer.Team
					if myTeam and theirTeam and myTeam ~= theirTeam then
						return current
					end
				end
			end
		end
		current = current.Parent
	end
	return nil
end

local isRightMouseDown = false
local rightClickStartTime = 0
local lastMoveCommandTime = 0
local HOLD_DELAY = 0.3
local COMMAND_TICK_RATE = 0.15

local isBackpackOpen = false
local currentState = "IDLE"
local activeSkillKey = nil
local castTween = nil

local VALID_SKILL_KEYS = {
	[Enum.KeyCode.Q] = "Q", [Enum.KeyCode.W] = "W", [Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R", [Enum.KeyCode.D] = "D", [Enum.KeyCode.F] = "F"
}

-- Cast bar UI elements
local playerGui = player:WaitForChild("PlayerGui")
local castScreen = Instance.new("ScreenGui")
castScreen.Name = "CastScreen"
castScreen.ResetOnSpawn = false
castScreen.Parent = playerGui

local castBarBg = Instance.new("Frame")
castBarBg.Size = UDim2.new(0, 200, 0, 20)
castBarBg.Position = UDim2.new(0.5, -100, 0.7, 0)
castBarBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
castBarBg.BorderSizePixel = 2
castBarBg.Visible = false
castBarBg.Parent = castScreen

local castBarFill = Instance.new("Frame")
castBarFill.Size = UDim2.new(0, 0, 1, 0)
castBarFill.BackgroundColor3 = Color3.fromRGB(255, 122, 6)
castBarFill.Parent = castBarBg

local castText = Instance.new("TextLabel")
castText.Size = UDim2.new(1, 0, 1, 0)
castText.BackgroundTransparency = 1
castText.TextColor3 = Color3.fromRGB(255, 255, 255)
castText.Font = Enum.Font.SourceSansBold
castText.TextSize = 14
castText.Parent = castBarBg

-- ========== LoL-style Indicator System (ViewportFrame — always on top, 3D look) ==========
local indicatorScreen = Instance.new("ScreenGui")
indicatorScreen.Name = "IndicatorScreen"
indicatorScreen.DisplayOrder = 5
indicatorScreen.IgnoreGuiInset = true
indicatorScreen.ResetOnSpawn = false
indicatorScreen.Parent = playerGui

local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Size = UDim2.new(1, 0, 1, 0)
viewportFrame.Position = UDim2.new(0, 0, 0, 0)
viewportFrame.BackgroundTransparency = 1
viewportFrame.ImageTransparency = 0
viewportFrame.LightDirection = Vector3.new(-1, -1, -1)
viewportFrame.Ambient = Color3.fromRGB(200, 200, 200)
viewportFrame.Parent = indicatorScreen

local vpCamera = Instance.new("Camera")
vpCamera.Parent = viewportFrame
viewportFrame.CurrentCamera = vpCamera

-- Hidden storage (outside ViewportFrame so parts don't render)
local hiddenFolder = Instance.new("Folder")
hiddenFolder.Name = "HiddenIndicators"
hiddenFolder.Parent = ReplicatedStorage

local function makeIndicatorPart(shape, color, transparency, parent)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Parent = parent or hiddenFolder
	return p
end

-- Line indicator parts
local lineFill = makeIndicatorPart(Enum.PartType.Block, Color3.fromRGB(0, 180, 240), 0.7)
local lineEdgeL = makeIndicatorPart(Enum.PartType.Block, Color3.fromRGB(60, 220, 255), 0.25)
local lineEdgeR = makeIndicatorPart(Enum.PartType.Block, Color3.fromRGB(60, 220, 255), 0.25)
local lineArrow = makeIndicatorPart(Enum.PartType.Block, Color3.fromRGB(100, 230, 255), 0.2)
local lineOrigin = makeIndicatorPart(Enum.PartType.Cylinder, Color3.fromRGB(60, 220, 255), 0.4)

local lineParts = {lineFill, lineEdgeL, lineEdgeR, lineArrow, lineOrigin}

-- Circle indicator parts
local circleFill = makeIndicatorPart(Enum.PartType.Cylinder, Color3.fromRGB(255, 220, 80), 0.75)
local circleEdge = makeIndicatorPart(Enum.PartType.Cylinder, Color3.fromRGB(255, 240, 120), 0.2)

local circleParts = {circleFill, circleEdge}

-- Converge indicator parts (安琪拉Q: 5条汇聚线)
local convergeParts = {}
for i = 1, 5 do
	local line = makeIndicatorPart(Enum.PartType.Block, Color3.fromRGB(255, 120, 0), 0.4)
	line.Name = "ConvergeLine" .. i
	table.insert(convergeParts, line)
end
local convergeTarget = makeIndicatorPart(Enum.PartType.Cylinder, Color3.fromRGB(255, 80, 0), 0.5)
convergeTarget.Name = "ConvergeTarget"

-- Range ring
local rangeRing = makeIndicatorPart(Enum.PartType.Cylinder, Color3.fromRGB(100, 180, 255), 0.6)
rangeRing.Name = "RangeRing"

-- 攻击范围指示器
local attackRangeRing = makeIndicatorPart(Enum.PartType.Cylinder, Color3.fromRGB(255, 80, 80), 0.5)
attackRangeRing.Name = "AttackRangeRing"

local currentIndicatorType = "line" -- "line" or "circle"

local function getSkillIndicatorInfo(key)
	local skillID = UIManager.GetSkillIDInSlot(key)
	if not skillID or not SkillConfig[skillID] then
		return "line", 40, 3, 40
	end
	local config = SkillConfig[skillID]
	local range = config.BaseRange or 40
	local width = 3

	if config.ConvergeIndicator then
		return "converge", range, config.SpreadWidth or 8, range
	elseif config.AreaRadius then
		return "circle", range, config.AreaRadius, range
	else
		if config.IsUltimate then width = 6 end
		return "line", range, width, range
	end
end

local function showParts(parts)
	for _, p in ipairs(parts) do
		p.Parent = viewportFrame
	end
end

local function hideParts(parts)
	for _, p in ipairs(parts) do
		p.Parent = hiddenFolder
	end
end

local function hideAllIndicators()
	hideParts(lineParts)
	hideParts(circleParts)
	hideParts(convergeParts)
	convergeTarget.Parent = hiddenFolder
	rangeRing.Parent = hiddenFolder
end

local function hideAttackRange()
	attackRangeRing.Parent = hiddenFolder
end

local function interruptCasting()
	if castTween then castTween:Cancel() end
	castBarBg.Visible = false
	currentState = "IDLE"
	activeSkillKey = nil
	hideAllIndicators()
	hideAttackRange()
end

local function checkSkillCD(key)
	local skillID = UIManager.GetSkillIDInSlot(key)
	if not skillID then return false end
	return CooldownManager.IsOnCooldown(skillID)
end

function InputManager.Init()
	CinematicManager.Init()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- 全局禁用时屏蔽所有输入
		if not inputEnabled then return end
		-- 电影特写期间屏蔽所有输入
		if CinematicManager.IsPlaying() then return end
		local isSkillKey = VALID_SKILL_KEYS[input.KeyCode] ~= nil
		local isAimingClick = (currentState == "AIMING" and input.UserInputType == Enum.UserInputType.MouseButton1)
		local isAttackKey = input.KeyCode == Enum.KeyCode.A
		local isStopKey = input.KeyCode == Enum.KeyCode.S
		if gameProcessed and input.KeyCode ~= Enum.KeyCode.B and not isSkillKey and not isAimingClick and not isAttackKey and not isStopKey then return end

		-- S key: 停止移动，取消普攻
		if isStopKey then
			attackTarget = nil
			MovementManager.StopMovement()
			isRightMouseDown = false
			if currentState == "AIMING" or currentState == "CASTING" then
				interruptCasting()
			end
			return
		end

		-- A key: 进入攻击瞄准模式，显示攻击范围
		if isAttackKey then
			if currentState == "CASTING" then return end
			if currentState == "AIMING" then
				interruptCasting()
			end
			currentState = "ATTACK_AIMING"
			attackRangeRing.Parent = viewportFrame
			return
		end

		-- B key: toggle backpack (只有 AllowBackpack 的英雄才能打开)
		if input.KeyCode == Enum.KeyCode.B then
			local heroID = HeroAnimator.GetHeroID()
			local heroData = heroID and HeroConfig[heroID]
			if heroData and not heroData.AllowBackpack then
				return
			end
			isBackpackOpen = UIManager.ToggleBackpack()
			if isBackpackOpen then
				interruptCasting()
				MovementManager.StopMovement()
				isRightMouseDown = false
			end
			return
		end

		if isBackpackOpen then return end

		-- QWERDF skill keys
		local pressedSkillKey = VALID_SKILL_KEYS[input.KeyCode]
		if pressedSkillKey then
			if currentState == "CASTING" then return end
			attackTarget = nil -- 使用技能时取消普攻
			if not UIManager.HasSkillInSlot(pressedSkillKey) then return end

			-- Recast: if skill is in recast state, immediately fire without aiming
			if CooldownManager.IsInRecast(UIManager.GetSkillIDInSlot(pressedSkillKey)) then
				local targetPos = mouse.Hit.Position
				ReplicatedStorage:WaitForChild("CastSkillEvent"):FireServer(pressedSkillKey, targetPos)
				return
			end

			if checkSkillCD(pressedSkillKey) then
				UIManager.ShowWarning("Skill on cooldown")
				return
			end

			-- 即时释放技能：按下直接释放，不进入瞄准
			local instantSkillID = UIManager.GetSkillIDInSlot(pressedSkillKey)
			if instantSkillID and SkillConfig[instantSkillID] and SkillConfig[instantSkillID].InstantCast then
				if currentState == "AIMING" then
					interruptCasting()
				end
				local targetPos = mouse.Hit.Position
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					local rootPart = character.HumanoidRootPart
					rootPart.CFrame = CFrame.lookAt(rootPart.Position, Vector3.new(targetPos.X, rootPart.Position.Y, targetPos.Z))
				end
				ReplicatedStorage:WaitForChild("CastSkillEvent"):FireServer(pressedSkillKey, targetPos)
				return
			end

			if currentState == "IDLE" then
				activeSkillKey = pressedSkillKey
				currentState = "AIMING"
				local indicType = getSkillIndicatorInfo(pressedSkillKey)
				currentIndicatorType = indicType
				hideAllIndicators()
				if indicType == "converge" then
					showParts(convergeParts)
					convergeTarget.Parent = viewportFrame
				elseif indicType == "circle" then
					showParts(circleParts)
				else
					showParts(lineParts)
				end
				rangeRing.Parent = viewportFrame
			elseif currentState == "AIMING" then
				if activeSkillKey == pressedSkillKey then
					interruptCasting()
				else
					if checkSkillCD(pressedSkillKey) then
						UIManager.ShowWarning("Skill on cooldown")
						return
					end
					activeSkillKey = pressedSkillKey
					local indicType = getSkillIndicatorInfo(pressedSkillKey)
					currentIndicatorType = indicType
					hideAllIndicators()
					if indicType == "converge" then
						showParts(convergeParts)
						convergeTarget.Parent = viewportFrame
					elseif indicType == "circle" then
						showParts(circleParts)
					else
						showParts(lineParts)
					end
					rangeRing.Parent = viewportFrame
				end
			end
		end

		-- Left click: cast aimed skill or confirm attack target
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- A键攻击瞄准模式：左键确认目标
			if currentState == "ATTACK_AIMING" then
				hideAttackRange()
				if hoveredEnemy then
					attackTarget = hoveredEnemy
				end
				currentState = "IDLE"
				return
			end

			if currentState == "AIMING" and activeSkillKey then
				if checkSkillCD(activeSkillKey) then
					UIManager.ShowWarning("Skill on cooldown")
					interruptCasting()
					return
				end

				local keyToCast = activeSkillKey
				hideAllIndicators()

				local targetPos = mouse.Hit.Position
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					local rootPart = character.HumanoidRootPart
					rootPart.CFrame = CFrame.lookAt(rootPart.Position, Vector3.new(targetPos.X, rootPart.Position.Y, targetPos.Z))
				end

				-- 检查是否是即时释放技能
				local skillID = UIManager.GetSkillIDInSlot(keyToCast)
				local isInstant = skillID and SkillConfig[skillID] and SkillConfig[skillID].InstantCast

				if isInstant then
					-- 即时释放，无读条
					currentState = "IDLE"
					activeSkillKey = nil
					ReplicatedStorage:WaitForChild("CastSkillEvent"):FireServer(keyToCast, targetPos)
				else
					currentState = "CASTING"

					castText.Text = "Casting " .. keyToCast
					castBarBg.Visible = true
					castBarFill.Size = UDim2.new(0, 0, 1, 0)

					castTween = TweenService:Create(castBarFill, TweenInfo.new(0.5), {Size = UDim2.new(1, 0, 1, 0)})
					castTween:Play()

					castTween.Completed:Connect(function(playbackState)
						if playbackState ~= Enum.PlaybackState.Completed then return end
						if currentState ~= "CASTING" then return end

						castBarBg.Visible = false
						currentState = "IDLE"
						ReplicatedStorage:WaitForChild("CastSkillEvent"):FireServer(keyToCast, targetPos)

						-- 如果是引导类技能（安琪拉R），开始发送鼠标方向
						local chanSkillID = UIManager.GetSkillIDInSlot(keyToCast)
						if chanSkillID and SkillConfig[chanSkillID] and SkillConfig[chanSkillID].TurnSpeed then
							isChanneling = true
							local channelDuration = SkillConfig[chanSkillID].Duration or 3
							task.delay(channelDuration, function()
								isChanneling = false
							end)
						end
					end)
				end
			end
		end

		-- Right click: attack enemy or move
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if isBackpackOpen then return end
			if currentState == "ATTACK_AIMING" then
				hideAttackRange()
				currentState = "IDLE"
			end
			if currentState == "AIMING" or currentState == "CASTING" then
				interruptCasting()
			end
			if currentState == "IDLE" then
				if hoveredEnemy then
					-- 右键敌人：进入自动攻击
					attackTarget = hoveredEnemy
					isRightMouseDown = false
				else
					-- 右键地面：取消攻击，正常移动
					attackTarget = nil
					isRightMouseDown = true
					rightClickStartTime = os.clock()
					lastMoveCommandTime = rightClickStartTime
					MovementManager.MoveToPosition(mouse.Hit.Position)
					MovementManager.ShowClickEffect(mouse.Hit.Position)
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then isRightMouseDown = false end
	end)

	RunService.RenderStepped:Connect(function()
		-- Sync ViewportFrame camera with main camera
		local mainCam = workspace.CurrentCamera
		if mainCam then
			vpCamera.CFrame = mainCam.CFrame
			vpCamera.FieldOfView = mainCam.FieldOfView
		end

		-- 引导技能鼠标方向发送
		if isChanneling then
			local dirEvent = getSkillDirectionEvent()
			if dirEvent then
				dirEvent:FireServer(mouse.Hit.Position)
			end
		end

		-- 鼠标悬停敌人高亮
		local mouseTarget = mouse.Target
		local enemyModel = mouseTarget and findTargetModel(mouseTarget) or nil
		if enemyModel ~= hoveredEnemy then
			if enemyHighlight then
				enemyHighlight:Destroy()
				enemyHighlight = nil
			end
			hoveredEnemy = enemyModel
			if hoveredEnemy then
				local h = Instance.new("Highlight")
				h.OutlineColor = Color3.fromRGB(255, 30, 30)
				h.OutlineTransparency = 0
				h.FillColor = Color3.fromRGB(255, 0, 0)
				h.FillTransparency = 0.7
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = hoveredEnemy
				enemyHighlight = h
			end
		end

		-- A键攻击瞄准：显示攻击范围圈
		if currentState == "ATTACK_AIMING" then
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local rootPos = character.HumanoidRootPart.Position
				local groundY = rootPos.Y - 2.5
				local outerD = ATTACK_RANGE * 2
				local ringCF = CFrame.new(rootPos.X, groundY, rootPos.Z) * CFrame.Angles(0, 0, math.rad(90))
				attackRangeRing.Size = Vector3.new(0.15, outerD, outerD)
				attackRangeRing.CFrame = ringCF
			end
		end

		-- 自动攻击循环
		if attackTarget then
			local targetRoot = attackTarget:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = attackTarget:FindFirstChild("Humanoid")
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")

			if not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 or not rootPart then
				attackTarget = nil
			else
				local dist = (rootPart.Position - targetRoot.Position).Magnitude
				if dist <= ATTACK_RANGE then
					MovementManager.StopMovement()
					rootPart.CFrame = CFrame.lookAt(rootPart.Position, Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z))
					if os.clock() - lastAttackTime >= ATTACK_INTERVAL then
						lastAttackTime = os.clock()
						local atkEvent = getAttackTargetEvent()
						if atkEvent then
							atkEvent:FireServer(attackTarget)
						end
					end
				else
					character.Humanoid:MoveTo(targetRoot.Position)
				end
			end
		end

		-- Hold right-click continuous movement
		if isRightMouseDown and currentState == "IDLE" and not isBackpackOpen then
			local currentTime = os.clock()
			if currentTime - rightClickStartTime >= HOLD_DELAY then
				if currentTime - lastMoveCommandTime >= COMMAND_TICK_RATE then
					MovementManager.MoveToPosition(mouse.Hit.Position)
					lastMoveCommandTime = currentTime
				end
			end
		end

		-- Aim indicator follow mouse
		if currentState == "AIMING" and activeSkillKey then
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local rootPos = character.HumanoidRootPart.Position
				local targetPos = mouse.Hit.Position
				local flatTarget = Vector3.new(targetPos.X, rootPos.Y, targetPos.Z)
				local dist = (flatTarget - rootPos).Magnitude
				if dist < 0.1 then dist = 0.1 end
				local direction = (flatTarget - rootPos).Unit

				local indicType, skillRange, indicSize, maxRange = getSkillIndicatorInfo(activeSkillKey)
				local onCD = checkSkillCD(activeSkillKey)
				local groundY = rootPos.Y - 2.5

				-- === Range ring (thin donut around player) ===
				local outerD = maxRange * 2
				local ringCF = CFrame.new(rootPos.X, groundY, rootPos.Z) * CFrame.Angles(0, 0, math.rad(90))

				rangeRing.Size = Vector3.new(0.1, outerD, outerD)
				rangeRing.CFrame = ringCF
				rangeRing.Color = onCD and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(100, 180, 255)
				rangeRing.Transparency = 0.6

				if indicType == "converge" then
					-- === 汇聚线指示器（安琪拉Q） ===
					local spreadWidth = indicSize
					local spawnForward = 3
					local rightDir = direction:Cross(Vector3.new(0, 1, 0))
					if rightDir.Magnitude > 0.01 then rightDir = rightDir.Unit else rightDir = Vector3.new(1, 0, 0) end
					local clampedDist = math.min(dist, maxRange)
					local clampedTarget = Vector3.new(rootPos.X, groundY, rootPos.Z) + direction * clampedDist

					for idx, line in ipairs(convergeParts) do
						local lateralOffset = (idx - 3) * (spreadWidth / 4)
						local spawnPos = Vector3.new(rootPos.X, groundY, rootPos.Z) + direction * spawnForward + rightDir * lateralOffset
						local toTarget = clampedTarget - spawnPos
						local lineLen = toTarget.Magnitude
						if lineLen < 0.5 then lineLen = 0.5 end
						local lineMid = spawnPos + toTarget / 2

						line.Size = Vector3.new(0.35, 0.12, lineLen)
						line.CFrame = CFrame.lookAt(lineMid, clampedTarget)
						line.Color = onCD and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 120, 0)
						line.Transparency = 0.35
					end

					-- 目标点指示圆
					local targetCF = CFrame.new(clampedTarget) * CFrame.Angles(0, 0, math.rad(90))
					convergeTarget.Size = Vector3.new(0.15, 3, 3)
					convergeTarget.CFrame = targetCF
					convergeTarget.Color = onCD and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 80, 0)
					convergeTarget.Transparency = 0.4

				elseif indicType == "circle" then
					-- === Circle area indicator ===
					local clampedPos = dist <= maxRange and flatTarget or (rootPos + direction * maxRange)
					local areaD = indicSize * 2
					local edgeThick = 0.5
					local circleCF = CFrame.new(clampedPos.X, groundY, clampedPos.Z) * CFrame.Angles(0, 0, math.rad(90))

					circleFill.Size = Vector3.new(0.12, areaD, areaD)
					circleFill.CFrame = circleCF
					circleFill.Color = onCD and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 220, 80)
					circleFill.Transparency = 0.78

					circleEdge.Size = Vector3.new(0.13, areaD + edgeThick, areaD + edgeThick)
					circleEdge.CFrame = circleCF
					circleEdge.Color = onCD and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 240, 120)
					circleEdge.Transparency = 0.3
				else
					-- === Line skillshot indicator ===
					local accentColor = onCD and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(60, 210, 255)
					local fillColor = onCD and Color3.fromRGB(200, 40, 40) or Color3.fromRGB(0, 150, 220)
					local edgeW = 0.15
					local halfW = indicSize / 2

					local lookCF = CFrame.lookAt(
						Vector3.new(rootPos.X, groundY, rootPos.Z) + direction * (skillRange / 2),
						Vector3.new(rootPos.X, groundY, rootPos.Z) + direction * skillRange
					)

					lineFill.Size = Vector3.new(indicSize, 0.1, skillRange)
					lineFill.CFrame = lookCF
					lineFill.Color = fillColor
					lineFill.Transparency = 0.75

					lineEdgeL.Size = Vector3.new(edgeW, 0.12, skillRange)
					lineEdgeL.CFrame = lookCF * CFrame.new(-halfW, 0.01, 0)
					lineEdgeL.Color = accentColor
					lineEdgeL.Transparency = 0.3

					lineEdgeR.Size = Vector3.new(edgeW, 0.12, skillRange)
					lineEdgeR.CFrame = lookCF * CFrame.new(halfW, 0.01, 0)
					lineEdgeR.Color = accentColor
					lineEdgeR.Transparency = 0.3

					lineArrow.Size = Vector3.new(indicSize + 1.5, 0.12, 1.5)
					lineArrow.CFrame = lookCF * CFrame.new(0, 0.01, -skillRange / 2 + 0.5)
					lineArrow.Color = accentColor
					lineArrow.Transparency = 0.2

					local originSize = indicSize + 1
					lineOrigin.Size = Vector3.new(0.12, originSize, originSize)
					lineOrigin.CFrame = CFrame.new(rootPos.X, groundY, rootPos.Z) * CFrame.Angles(0, 0, math.rad(90))
					lineOrigin.Color = accentColor
					lineOrigin.Transparency = 0.5
				end
			end
		end
	end)
end

--- 设置输入系统启用/禁用
--- @param enabled boolean
function InputManager.SetEnabled(enabled)
	inputEnabled = enabled
	if not enabled then
		-- 禁用时停止移动和攻击
		MovementManager.StopMovement()
		attackTarget = nil
		isRightMouseDown = false
		if currentState == "AIMING" or currentState == "CASTING" then
			currentState = "IDLE"
		end
	end
	print(("[InputManager] Input %s"):format(enabled and "enabled" or "disabled"))
end

--- 获取当前启用状态
function InputManager.IsEnabled()
	return inputEnabled
end

return InputManager
