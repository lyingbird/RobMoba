--[[
	UI_VirtualJoystick.lua
	虚拟摇杆系统 (MOD-01)
	REQ-016: 严格参照王者荣耀布局重设计
	REQ-018 v3: 采用 Roblox 官方 PlayerModule/TouchThumbstick 的事件模式

	左下角固定位置始终可见摇杆 → 触摸左半屏响应方向(摇杆位置不移动) → 松手内球复位
	支持: 死区、钳位、速度分级、多点触控独立追踪
	大厅模式: 摇杆可见但不响应输入
	战斗模式: 摇杆可见+响应输入

	事件架构 (REQ-018 v3):
	- InputBegan: GuiObject.InputBegan (接受 Touch + MouseButton1)
	- InputChanged/Moved: UserInputService 全局事件 (不依赖 GuiObject.InputChanged)
	  - Touch: UIS.TouchMoved (与官方 TouchThumbstick 一致)
	  - Mouse: UIS.InputChanged → MouseMovement (Studio/Device Emulator)
	- InputEnded: UserInputService 全局事件
	  - Touch: UIS.TouchEnded
	  - Mouse: UIS.InputEnded → MouseButton1
	- 追踪方式: Touch 用 InputObject 引用比较; Mouse 用 mouseActive 布尔标志
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local MobileConfig = require(script.Parent.Parent.Modules.MobileConfig)

local UI_VirtualJoystick = {}

-- 内部状态
local touchFrame: Frame? = nil          -- 左半屏触摸捕获层
local outerRing: ImageLabel? = nil       -- 外圈
local innerBall: ImageLabel? = nil       -- 摇杆球
local moveTouchObject = nil              -- 当前激活的 Touch InputObject (对象引用追踪)
local mouseActive = false                -- 鼠标拖拽是否激活 (Studio/Device Emulator)
local centerPosition = Vector2.zero      -- 摇杆中心位置(绝对像素)
local currentDirection = Vector2.zero    -- 当前方向(归一化)
local currentMagnitude = 0               -- 当前力度(0~1)
local enabled = true                     -- 是否启用
local lobbyMode = false                  -- REQ-015: 大厅模式(静态指示,不响应输入)
local directionCallback = nil            -- 方向变更回调
local fadeTween = nil                    -- 淡出Tween引用

-- Studio 诊断日志 (持久化到 StringValue, 非 warn, 可通过 execute_luau 读取)
local diagLogLines = {}
local diagLogValue = nil -- StringValue, 在 Init 中创建
local DIAG_ENABLED = MobileConfig.IS_STUDIO -- 仅 Studio 中启用诊断

local function diagLog(msg: string)
	if not DIAG_ENABLED then return end
	table.insert(diagLogLines, string.format("%.2f|%s", os.clock(), msg))
	if #diagLogLines > 50 then table.remove(diagLogLines, 1) end
	if diagLogValue then
		diagLogValue.Value = table.concat(diagLogLines, "\n")
	end
end

-- 判断摇杆是否处于活跃拖拽中
local function isJoystickActive(): boolean
	return moveTouchObject ~= nil or mouseActive
end

-- 创建圆形ImageLabel (REQ-016: 默认可见 + UIStroke边框)
local function createCircle(name: string, parent: GuiObject, sizeScale: number, alpha: number): ImageLabel
	local circle = Instance.new("ImageLabel")
	circle.Name = name
	circle.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
	circle.BackgroundTransparency = 1 - alpha
	circle.BorderSizePixel = 0
	circle.Image = "rbxassetid://7072706620" -- 圆形白色图片 (Roblox 内置)
	circle.ImageTransparency = 1 - alpha
	circle.ImageColor3 = Color3.fromRGB(40, 45, 60)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Visible = true   -- REQ-016: 始终可见
	circle.ZIndex = 10

	-- 使用 UICorner 确保圆形
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle

	-- REQ-016: 添加 UIStroke 边框(王者荣耀风格白色边框)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = Color3.fromRGB(200, 200, 220)
	stroke.Thickness = name == "JoystickOuter" and 2.5 or 1.5
	stroke.Transparency = 0.3
	stroke.Parent = circle

	circle.Parent = parent
	return circle
end

-- 设置摇杆UI可见性(带动画)
local function setJoystickVisible(visible: boolean, instant: boolean?)
	if not outerRing or not innerBall then return end

	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end

	if visible then
		outerRing.Visible = true
		innerBall.Visible = true
		if instant then
			outerRing.ImageTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA
			innerBall.ImageTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA
		else
			outerRing.ImageTransparency = 1
			innerBall.ImageTransparency = 1
			local tweenInfo = TweenInfo.new(MobileConfig.JOYSTICK_APPEAR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(outerRing, tweenInfo, { ImageTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA }):Play()
			TweenService:Create(innerBall, tweenInfo, { ImageTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA }):Play()
		end
	else
		local tweenInfo = TweenInfo.new(MobileConfig.JOYSTICK_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tween = TweenService:Create(outerRing, tweenInfo, { ImageTransparency = 1 })
		TweenService:Create(innerBall, tweenInfo, { ImageTransparency = 1 }):Play()
		tween:Play()
		fadeTween = tween
		tween.Completed:Connect(function()
			if fadeTween == tween then
				outerRing.Visible = false
				innerBall.Visible = false
				fadeTween = nil
			end
		end)
	end
end

-- 通知方向变更
local function notifyDirectionChanged()
	if directionCallback then
		directionCallback(currentDirection, currentMagnitude)
	end
end

-- ═══════════════════════════════════════
-- 核心: 方向计算与摇杆球位置更新
-- ═══════════════════════════════════════

-- 根据触摸/鼠标位置更新摇杆方向和内球位置
local function updateJoystickFromPosition(pos: Vector3)
	local touchPos = Vector2.new(pos.X, pos.Y)
	local offset = touchPos - centerPosition
	local distance = offset.Magnitude
	local maxRadius = MobileConfig.JOYSTICK_MAX_RADIUS
	local deadzoneRadius = maxRadius * MobileConfig.JOYSTICK_DEADZONE

	-- 钳位: 摇杆球不超出外圈
	if distance > maxRadius then
		offset = offset.Unit * maxRadius
		distance = maxRadius
	end

	-- 更新摇杆球位置 (AnchorPoint=0.5,0.5, 转为相对于touchFrame的偏移)
	if innerBall and outerRing then
		local tfAbsPos = touchFrame and touchFrame.AbsolutePosition or Vector2.zero
		local outerAbsPos = outerRing.AbsolutePosition
		local outerAbsSize = outerRing.AbsoluteSize
		local outerCenterX = outerAbsPos.X + outerAbsSize.X / 2
		local outerCenterY = outerAbsPos.Y + outerAbsSize.Y / 2
		innerBall.Position = UDim2.fromOffset(
			outerCenterX + offset.X - tfAbsPos.X,
			outerCenterY + offset.Y - tfAbsPos.Y
		)
	end

	-- 死区判断
	if distance < deadzoneRadius then
		currentDirection = Vector2.zero
		currentMagnitude = 0
	else
		currentDirection = offset.Unit
		currentMagnitude = math.clamp((distance - deadzoneRadius) / (maxRadius - deadzoneRadius), 0, 1)
	end

	notifyDirectionChanged()
end

-- 重置摇杆状态
local function resetJoystick()
	moveTouchObject = nil
	mouseActive = false
	currentDirection = Vector2.zero
	currentMagnitude = 0
	notifyDirectionChanged()

	-- 松手后内球复位到中心(不隐藏摇杆)
	if innerBall and outerRing then
		local tfAbsPos = touchFrame and touchFrame.AbsolutePosition or Vector2.zero
		local outerAbsPos = outerRing.AbsolutePosition
		local outerAbsSize = outerRing.AbsoluteSize
		local centerOffsetX = outerAbsPos.X + outerAbsSize.X / 2 - tfAbsPos.X
		local centerOffsetY = outerAbsPos.Y + outerAbsSize.Y / 2 - tfAbsPos.Y
		local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(innerBall, tweenInfo, {
			Position = UDim2.fromOffset(centerOffsetX, centerOffsetY)
		}):Play()
	end
end

-- ═══════════════════════════════════════
-- 触摸事件处理 (REQ-018 v3: 完全重写)
-- ═══════════════════════════════════════

-- GuiObject.InputBegan: 检测初始触摸/点击
local function onInputBegan(input: InputObject)
	if not enabled then return end
	if isJoystickActive() then return end -- 已有激活的操作

	local inputType = input.UserInputType
	local isTouch = (inputType == Enum.UserInputType.Touch)
	local isMouse = (inputType == Enum.UserInputType.MouseButton1)

	-- 只接受 Touch 或 MouseButton1 (Studio/Device Emulator 中鼠标)
	if not isTouch and not isMouse then return end
	if isMouse and not (MobileConfig.DEBUG_FORCE_MOBILE or MobileConfig.IS_STUDIO) then return end

	-- 额外检查: Touch 必须是 Begin 状态 (防止跨区域滑入误触)
	if isTouch and input.UserInputState ~= Enum.UserInputState.Begin then return end

	-- 激活摇杆
	if isTouch then
		moveTouchObject = input
		diagLog("BEGAN:Touch obj=" .. tostring(input))
	else
		mouseActive = true
		diagLog("BEGAN:Mouse pos=(" .. math.floor(input.Position.X) .. "," .. math.floor(input.Position.Y) .. ")")
	end

	-- 记录摇杆中心
	if outerRing then
		local absPos = outerRing.AbsolutePosition
		local absSize = outerRing.AbsoluteSize
		centerPosition = Vector2.new(absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2)
	end

	-- 立即处理初始方向
	updateJoystickFromPosition(input.Position)
end

-- ═══════════════════════════════════════
-- 公共接口
-- ═══════════════════════════════════════

--- 初始化摇杆系统 (REQ-016: 始终可见+固定位置)
--- REQ-018 v3: 事件架构完全重写
--- @param parentFrame Frame - 挂载父容器(ScreenGui)
function UI_VirtualJoystick.Init(parentFrame: Frame)
	-- 创建 Studio 诊断日志存储
	if DIAG_ENABLED then
		local player = game:GetService("Players").LocalPlayer
		if player then
			local existingDiag = player:FindFirstChild("JOY_DIAG")
			if existingDiag then existingDiag:Destroy() end
			diagLogValue = Instance.new("StringValue")
			diagLogValue.Name = "JOY_DIAG"
			diagLogValue.Parent = player
			diagLog("Init started, IS_STUDIO=true")
		end
	end

	-- 创建左半屏触摸捕获层
	touchFrame = Instance.new("Frame")
	touchFrame.Name = "JoystickTouchArea"
	touchFrame.Size = UDim2.new(0.5, 0, 1, 0)         -- 左半屏
	touchFrame.Position = UDim2.new(0, 0, 0, 0)
	touchFrame.AnchorPoint = Vector2.new(0, 0)
	touchFrame.BackgroundTransparency = 1               -- 完全透明
	touchFrame.ZIndex = 10
	touchFrame.Parent = parentFrame

	-- 创建外圈 (REQ-016: 背景深色+UIStroke)
	outerRing = createCircle("JoystickOuter", touchFrame, MobileConfig.JOYSTICK_OUTER_SIZE, MobileConfig.JOYSTICK_OUTER_ALPHA)

	-- 创建摇杆球 (REQ-016: 亮色以区分)
	innerBall = createCircle("JoystickInner", touchFrame, MobileConfig.JOYSTICK_INNER_SIZE, MobileConfig.JOYSTICK_INNER_ALPHA)
	innerBall.BackgroundColor3 = Color3.fromRGB(180, 185, 200)
	innerBall.ImageColor3 = Color3.fromRGB(180, 185, 200)
	innerBall.ZIndex = 11

	-- REQ-016: 延迟一帧设置正确尺寸和位置(等待AbsoluteSize)
	task.defer(function()
		if not touchFrame or not outerRing or not innerBall then return end

		local viewportSize = touchFrame.AbsoluteSize
		if viewportSize.Y < 1 then
			local cam = workspace.CurrentCamera
			if cam then
				viewportSize = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y)
			end
		end

		local outerDiameterPx = viewportSize.Y * MobileConfig.JOYSTICK_OUTER_SIZE * 2
		local innerDiameterPx = viewportSize.Y * MobileConfig.JOYSTICK_INNER_SIZE * 2

		-- 固定位置 (touchFrame是左半屏, 需要相对换算为绝对像素)
		local defaultX = MobileConfig.JOYSTICK_DEFAULT_X / 0.5
		local defaultY = MobileConfig.JOYSTICK_DEFAULT_Y
		local centerPxX = viewportSize.X * defaultX
		local centerPxY = viewportSize.Y * defaultY

		outerRing.Size = UDim2.fromOffset(outerDiameterPx, outerDiameterPx)
		outerRing.Position = UDim2.fromOffset(centerPxX, centerPxY)
		innerBall.Size = UDim2.fromOffset(innerDiameterPx, innerDiameterPx)
		innerBall.Position = UDim2.fromOffset(centerPxX, centerPxY)

		-- 设置初始透明度
		outerRing.ImageTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA
		outerRing.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA
		innerBall.ImageTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA
		innerBall.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA

		diagLog("Layout done, outer=" .. tostring(outerRing.AbsoluteSize))
	end)

	-- ═══════════════════════════════════════
	-- 事件绑定 (REQ-018 v3: 官方模式)
	-- ═══════════════════════════════════════

	-- 1. GuiObject.InputBegan — 检测初始触摸/点击（仅此事件用 GuiObject 级别）
	touchFrame.InputBegan:Connect(onInputBegan)

	-- 2. Touch 全局事件 — 与 Roblox 官方 TouchThumbstick 一致
	--    使用 UIS.TouchMoved/TouchEnded 而非 GuiObject.InputChanged
	--    好处: 手指移出 GuiObject 区域后仍能追踪
	UserInputService.TouchMoved:Connect(function(input, gameProcessed)
		if not enabled then return end
		if not moveTouchObject then return end
		-- 只处理与激活摇杆相同的 Touch 对象
		if input ~= moveTouchObject then return end
		updateJoystickFromPosition(input.Position)
	end)

	UserInputService.TouchEnded:Connect(function(input, gameProcessed)
		if not moveTouchObject then return end
		if input ~= moveTouchObject then return end
		diagLog("ENDED:Touch")
		resetJoystick()
	end)

	-- 3. Mouse 全局事件 — Studio/Device Emulator 中鼠标拖拽
	--    Device Emulator 中鼠标不会被转换为 Touch，仍然是 MouseMovement/MouseButton1
	--    GuiObject.InputChanged 可能不会在鼠标持续拖拽时触发 MouseMovement
	--    所以必须使用全局 UIS.InputChanged 来捕获
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not enabled then return end
		if not mouseActive then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		updateJoystickFromPosition(input.Position)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if not mouseActive then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		diagLog("ENDED:Mouse")
		resetJoystick()
	end)

	-- 4. 菜单打开时强制结束摇杆（与官方一致）
	GuiService.MenuOpened:Connect(function()
		if isJoystickActive() then
			diagLog("ENDED:MenuOpened")
			resetJoystick()
		end
	end)

	diagLog("Init complete, all listeners attached")
end

--- 获取当前方向(归一化的2D向量)
function UI_VirtualJoystick.GetDirection(): Vector2
	return currentDirection
end

--- 获取当前力度(0~1)
function UI_VirtualJoystick.GetMagnitude(): number
	return currentMagnitude
end

--- 启用/禁用摇杆
function UI_VirtualJoystick.SetEnabled(isEnabled: boolean)
	enabled = isEnabled
	if not enabled then
		-- 禁用时停止当前输入
		if isJoystickActive() then
			resetJoystick()
		end
		-- REQ-021: DISABLED 态视觉反馈 — 透明度降至禁用态
		if outerRing and innerBall then
			local disabledAlpha = MobileConfig.JOYSTICK_DISABLED_ALPHA
			outerRing.ImageTransparency = 1 - disabledAlpha
			outerRing.BackgroundTransparency = 1 - disabledAlpha
			innerBall.ImageTransparency = 1 - disabledAlpha
			innerBall.BackgroundTransparency = 1 - disabledAlpha
		end
	else
		-- REQ-021: 启用时恢复当前模式对应的正常透明度
		if outerRing and innerBall then
			if lobbyMode then
				outerRing.ImageTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_OUTER_ALPHA
				outerRing.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_OUTER_ALPHA
				innerBall.ImageTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_INNER_ALPHA
				innerBall.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_INNER_ALPHA
			else
				outerRing.ImageTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA
				outerRing.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA
				innerBall.ImageTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA
				innerBall.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA
			end
		end
	end
end

--- REQ-016: 设置大厅/战斗模式 (两种模式下摇杆都始终可见)
--- lobby=true: 摇杆可见但不响应输入(略低透明度)
--- lobby=false: 摇杆可见+响应输入(正常透明度)
function UI_VirtualJoystick.SetLobbyMode(lobby: boolean)
	lobbyMode = lobby

	if not touchFrame or not outerRing or not innerBall then return end

	if lobby then
		-- REQ-016 fix: 大厅模式 — 可见+可操作(但透明度略低)
		-- 不再设置 enabled = false，让玩家在大厅也能用摇杆移动
		enabled = true

		-- 设置大厅透明度(略低于战斗)
		task.defer(function()
			if not outerRing or not innerBall then return end
			if not lobbyMode then return end

			outerRing.ImageTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_OUTER_ALPHA
			outerRing.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_OUTER_ALPHA
			innerBall.ImageTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_INNER_ALPHA
			innerBall.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_LOBBY_INNER_ALPHA
		end)
	else
		-- 战斗模式: 可见+响应输入
		enabled = true

		-- 设置战斗透明度(正常)
		outerRing.ImageTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA
		outerRing.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_OUTER_ALPHA
		innerBall.ImageTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA
		innerBall.BackgroundTransparency = 1 - MobileConfig.JOYSTICK_INNER_ALPHA

		-- 确保内球在中心
		if outerRing.Position then
			innerBall.Position = outerRing.Position
		end
	end
end

--- 注册方向变更回调
--- @param callback (direction: Vector2, magnitude: number) -> ()
function UI_VirtualJoystick.OnDirectionChanged(callback)
	directionCallback = callback
end

--- 销毁清理
function UI_VirtualJoystick.Destroy()
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
	if touchFrame then
		touchFrame:Destroy()
		touchFrame = nil
	end
	outerRing = nil
	innerBall = nil
	moveTouchObject = nil
	mouseActive = false
	directionCallback = nil
	enabled = false
	if diagLogValue then
		diagLogValue:Destroy()
		diagLogValue = nil
	end
end

return UI_VirtualJoystick
