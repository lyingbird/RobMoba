--[[
	UI_VirtualJoystick.lua
	虚拟摇杆系统 (MOD-01)
	REQ-011: 手机端MOBA UI与操控系统

	左半屏触摸 → 在触摸点显示摇杆(外圈+摇杆球) → 拖拽输出方向向量 → 松手淡出
	支持: 死区、钳位、速度分级、多点触控独立追踪
]]

local TweenService = game:GetService("TweenService")
local MobileConfig = require(script.Parent.Parent.Modules.MobileConfig)

local UI_VirtualJoystick = {}

-- 内部状态
local touchFrame: Frame? = nil          -- 左半屏触摸捕获层
local outerRing: ImageLabel? = nil       -- 外圈
local innerBall: ImageLabel? = nil       -- 摇杆球
local activeTouchId = nil                -- 当前激活的触摸点ID
local centerPosition = Vector2.zero      -- 摇杆中心位置(绝对像素)
local currentDirection = Vector2.zero    -- 当前方向(归一化)
local currentMagnitude = 0               -- 当前力度(0~1)
local enabled = true                     -- 是否启用
local directionCallback = nil            -- 方向变更回调
local fadeTween = nil                    -- 淡出Tween引用

-- ═══════════════════════════════════════
-- 辅助函数
-- ═══════════════════════════════════════

-- REQ-012: 判断输入是否为有效的触摸/鼠标输入
local function isValidPointerInput(input: InputObject): boolean
	if input.UserInputType == Enum.UserInputType.Touch then return true end
	if MobileConfig.DEBUG_FORCE_MOBILE and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
	return false
end

-- 创建圆形ImageLabel
local function createCircle(name: string, parent: GuiObject, sizeScale: number, alpha: number): ImageLabel
	local circle = Instance.new("ImageLabel")
	circle.Name = name
	circle.BackgroundColor3 = Color3.new(1, 1, 1)
	circle.BackgroundTransparency = 1 - alpha
	circle.BorderSizePixel = 0
	circle.Image = "rbxassetid://7072706620" -- 圆形白色图片 (Roblox 内置)
	circle.ImageTransparency = 1 - alpha
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Visible = false
	circle.ZIndex = 10

	-- 使用 UICorner 确保圆形
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle

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
-- 触摸事件处理
-- ═══════════════════════════════════════

local function onTouchBegan(input: InputObject)
	if not enabled then return end
	if activeTouchId then return end -- 已有激活的触摸点, 忽略

	-- 只处理触摸输入(REQ-012: 调试模式下也接受鼠标)
	if not isValidPointerInput(input) then return end

	activeTouchId = input
	local pos = input.Position
	centerPosition = Vector2.new(pos.X, pos.Y)

	-- 计算摇杆UI的屏幕像素尺寸
	local viewportSize = touchFrame.AbsoluteSize
	local outerDiameterPx = viewportSize.Y * MobileConfig.JOYSTICK_OUTER_SIZE * 2 -- 左半屏的Y就是屏幕高度
	local innerDiameterPx = viewportSize.Y * MobileConfig.JOYSTICK_INNER_SIZE * 2

	-- 定位摇杆到触摸点(绝对像素)
	outerRing.Size = UDim2.fromOffset(outerDiameterPx, outerDiameterPx)
	outerRing.Position = UDim2.fromOffset(pos.X - touchFrame.AbsolutePosition.X, pos.Y - touchFrame.AbsolutePosition.Y)

	innerBall.Size = UDim2.fromOffset(innerDiameterPx, innerDiameterPx)
	innerBall.Position = outerRing.Position

	-- 显示摇杆
	setJoystickVisible(true, false)

	-- 初始方向为零
	currentDirection = Vector2.zero
	currentMagnitude = 0
	notifyDirectionChanged()
end

local function onTouchMoved(input: InputObject)
	if not enabled then return end
	-- REQ-012: 鼠标模式下 InputChanged 收到的是 MouseMovement 类型,
	-- 与 InputBegan 的 MouseButton1 input 对象不同, 需要特殊处理
	if input ~= activeTouchId then
		if not (MobileConfig.DEBUG_FORCE_MOBILE and activeTouchId and input.UserInputType == Enum.UserInputType.MouseMovement) then
			return
		end
	end

	local pos = input.Position
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

	-- 更新摇杆球位置
	if innerBall then
		local basePos = outerRing.Position
		innerBall.Position = UDim2.fromOffset(
			basePos.X.Offset + offset.X,
			basePos.Y.Offset + offset.Y
		)
	end

	-- 死区判断
	if distance < deadzoneRadius then
		currentDirection = Vector2.zero
		currentMagnitude = 0
	else
		currentDirection = offset.Unit
		-- 力度映射: 0(死区边缘) ~ 1(最大半径)
		currentMagnitude = math.clamp((distance - deadzoneRadius) / (maxRadius - deadzoneRadius), 0, 1)
	end

	notifyDirectionChanged()
end

local function onTouchEnded(input: InputObject)
	-- REQ-012: 鼠标模式下 InputEnded 的 MouseButton1 input 也要能释放
	if input ~= activeTouchId then
		if not (MobileConfig.DEBUG_FORCE_MOBILE and activeTouchId and input.UserInputType == Enum.UserInputType.MouseButton1) then
			return
		end
	end

	activeTouchId = nil
	currentDirection = Vector2.zero
	currentMagnitude = 0
	notifyDirectionChanged()

	-- 淡出摇杆
	setJoystickVisible(false, false)
end

-- ═══════════════════════════════════════
-- 公共接口
-- ═══════════════════════════════════════

--- 初始化摇杆系统
--- @param parentFrame Frame - 挂载父容器(ScreenGui)
function UI_VirtualJoystick.Init(parentFrame: Frame)
	-- 创建左半屏触摸捕获层
	touchFrame = Instance.new("Frame")
	touchFrame.Name = "JoystickTouchArea"
	touchFrame.Size = UDim2.new(0.5, 0, 1, 0)         -- 左半屏
	touchFrame.Position = UDim2.new(0, 0, 0, 0)
	touchFrame.AnchorPoint = Vector2.new(0, 0)
	touchFrame.BackgroundTransparency = 1               -- 完全透明
	touchFrame.ZIndex = 10
	touchFrame.Parent = parentFrame

	-- 创建外圈
	outerRing = createCircle("JoystickOuter", touchFrame, MobileConfig.JOYSTICK_OUTER_SIZE, MobileConfig.JOYSTICK_OUTER_ALPHA)

	-- 创建摇杆球
	innerBall = createCircle("JoystickInner", touchFrame, MobileConfig.JOYSTICK_INNER_SIZE, MobileConfig.JOYSTICK_INNER_ALPHA)
	innerBall.ZIndex = 11

	-- 绑定触摸事件(使用GuiObject事件, 独立于其他UI元素)
	touchFrame.InputBegan:Connect(onTouchBegan)
	touchFrame.InputChanged:Connect(onTouchMoved)
	touchFrame.InputEnded:Connect(onTouchEnded)
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
		if activeTouchId then
			activeTouchId = nil
			currentDirection = Vector2.zero
			currentMagnitude = 0
			notifyDirectionChanged()
			setJoystickVisible(false, true)
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
	activeTouchId = nil
	directionCallback = nil
	enabled = false
end

return UI_VirtualJoystick
