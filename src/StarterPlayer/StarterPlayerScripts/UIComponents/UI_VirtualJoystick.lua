--[[
	UI_VirtualJoystick.lua
	虚拟摇杆系统 (MOD-01)
	REQ-011: 手机端MOBA UI与操控系统

	王者荣耀风格:
	- 大圆底盘固定在左下角，始终可见（半透明深色）
	- 小圆拖拽球居中，始终可见（亮色高光）
	- 触摸左半屏 → 摇杆球跟随手指偏移（被钳位在底盘内）
	- 松手 → 球弹回中心（Back缓动）
	- 底盘有微妙的边缘渐变，球有内发光效果
]]

local TweenService = game:GetService("TweenService")
local MobileConfig = require(script.Parent.Parent.Modules.MobileConfig)

local UI_VirtualJoystick = {}

-- 内部状态
local touchFrame: Frame? = nil          -- 左半屏触摸捕获层
local outerRing: Frame? = nil           -- 外圈底盘
local innerBall: Frame? = nil           -- 摇杆球
local activeTouchId = nil                -- 当前激活的触摸点ID
local fixedCenter = Vector2.zero         -- 底盘中心(绝对屏幕坐标, 运行时计算)
local maxRadiusPx = 0                    -- 底盘半径(像素, 运行时计算)
local currentDirection = Vector2.zero    -- 当前方向(归一化)
local currentMagnitude = 0               -- 当前力度(0~1)
local enabled = true
local directionCallback = nil

-- ═══════════════════════════════════════
-- 辅助函数
-- ═══════════════════════════════════════

local function isValidPointerInput(input: InputObject): boolean
	if input.UserInputType == Enum.UserInputType.Touch then return true end
	if MobileConfig.DEBUG_FORCE_MOBILE and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
	return false
end

local function notifyDirectionChanged()
	if directionCallback then
		directionCallback(currentDirection, currentMagnitude)
	end
end

-- 计算底盘中心的绝对屏幕坐标
local function recalcCenter()
	if not outerRing then return end
	local absPos = outerRing.AbsolutePosition
	local absSize = outerRing.AbsoluteSize
	fixedCenter = Vector2.new(absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2)
	maxRadiusPx = absSize.X / 2
end

-- 设置摇杆球在底盘内的位置(像素偏移)
local function setBallOffset(offsetX: number, offsetY: number)
	if not innerBall then return end
	-- innerBall 的 AnchorPoint=0.5, Position 相对于 outerRing
	-- outerRing 的中心 = (0.5, 0.5) in outerRing space
	innerBall.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
end

-- 摇杆球弹回中心
local function resetBallToCenter()
	if not innerBall then return end
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(innerBall, tweenInfo, {
		Position = UDim2.new(0.5, 0, 0.5, 0)
	}):Play()
end

-- ═══════════════════════════════════════
-- 触摸事件
-- ═══════════════════════════════════════

local function onTouchBegan(input: InputObject)
	if not enabled then return end
	if activeTouchId then return end
	if not isValidPointerInput(input) then return end

	activeTouchId = input
	recalcCenter() -- 确保中心坐标最新

	-- 初始方向为零
	currentDirection = Vector2.zero
	currentMagnitude = 0
	notifyDirectionChanged()
end

local function onTouchMoved(input: InputObject)
	if not enabled then return end
	if input ~= activeTouchId then
		if not (MobileConfig.DEBUG_FORCE_MOBILE and activeTouchId and input.UserInputType == Enum.UserInputType.MouseMovement) then
			return
		end
	end

	local touchPos = Vector2.new(input.Position.X, input.Position.Y)
	local offset = touchPos - fixedCenter
	local distance = offset.Magnitude
	local deadzoneRadius = maxRadiusPx * MobileConfig.JOYSTICK_DEADZONE

	-- 钳位: 摇杆球不超出底盘
	local clampedOffset = offset
	if distance > maxRadiusPx then
		clampedOffset = offset.Unit * maxRadiusPx
		distance = maxRadiusPx
	end

	-- 更新摇杆球位置
	setBallOffset(clampedOffset.X, clampedOffset.Y)

	-- 死区判断
	if distance < deadzoneRadius then
		currentDirection = Vector2.zero
		currentMagnitude = 0
	else
		currentDirection = offset.Unit
		currentMagnitude = math.clamp((distance - deadzoneRadius) / (maxRadiusPx - deadzoneRadius), 0, 1)
	end

	notifyDirectionChanged()
end

local function onTouchEnded(input: InputObject)
	if input ~= activeTouchId then
		if not (MobileConfig.DEBUG_FORCE_MOBILE and activeTouchId and input.UserInputType == Enum.UserInputType.MouseButton1) then
			return
		end
	end

	activeTouchId = nil
	currentDirection = Vector2.zero
	currentMagnitude = 0
	notifyDirectionChanged()

	resetBallToCenter()
end

-- ═══════════════════════════════════════
-- 公共接口
-- ═══════════════════════════════════════

function UI_VirtualJoystick.Init(parentFrame: Frame)
	-- 左半屏触摸捕获层(透明)
	touchFrame = Instance.new("Frame")
	touchFrame.Name = "JoystickTouchArea"
	touchFrame.Size = UDim2.new(0.5, 0, 1, 0)
	touchFrame.Position = UDim2.new(0, 0, 0, 0)
	touchFrame.BackgroundTransparency = 1
	touchFrame.ZIndex = 5
	touchFrame.Parent = parentFrame

	-- ═══════════════════════════════════
	-- 外圈底盘: 大圆, 固定左下角, 始终可见
	-- 使用 SizeConstraint.RelativeYY + 正确的 X/Y Scale
	-- ═══════════════════════════════════
	local outerDiameter = MobileConfig.JOYSTICK_OUTER_SIZE * 2  -- 如 0.25*2 = 0.5 屏高

	outerRing = Instance.new("Frame")
	outerRing.Name = "JoystickOuter"
	outerRing.AnchorPoint = Vector2.new(0.5, 0.5)
	-- 左下角位置: X=35% of touchFrame宽, Y=73% 屏高
	-- 确保底部不超出屏幕: 73% + 25%(半径) = 98%, 留2%安全边距
	outerRing.Position = UDim2.new(0.35, 0, 0.73, 0)
	-- 关键: X和Y的Scale都要设置! SizeConstraint.RelativeYY 下两者都参照父Y
	outerRing.Size = UDim2.new(outerDiameter, 0, outerDiameter, 0)
	outerRing.SizeConstraint = Enum.SizeConstraint.RelativeYY
	outerRing.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	outerRing.BackgroundTransparency = 0.35
	outerRing.BorderSizePixel = 0
	outerRing.Visible = true
	outerRing.ZIndex = 10
	outerRing.Parent = touchFrame

	-- 外圈圆角(变成圆形)
	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(0.5, 0)
	outerCorner.Parent = outerRing

	-- 外圈边框(微妙的灰色描边)
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = Color3.fromRGB(80, 90, 110)
	outerStroke.Thickness = 2
	outerStroke.Transparency = 0.4
	outerStroke.Parent = outerRing

	-- ═══════════════════════════════════
	-- 摇杆球: 小圆, 居中, 始终可见
	-- ═══════════════════════════════════
	local innerDiameter = MobileConfig.JOYSTICK_INNER_SIZE * 2  -- 如 0.10*2 = 0.2 屏高

	innerBall = Instance.new("Frame")
	innerBall.Name = "JoystickInner"
	innerBall.AnchorPoint = Vector2.new(0.5, 0.5)
	innerBall.Position = UDim2.new(0.5, 0, 0.5, 0)  -- 相对于 outerRing 的中心
	innerBall.Size = UDim2.new(innerDiameter / outerDiameter, 0, innerDiameter / outerDiameter, 0)
	-- innerBall 的 Size 是相对于 outerRing 的比例
	innerBall.BackgroundColor3 = Color3.fromRGB(160, 180, 210)
	innerBall.BackgroundTransparency = 0.05
	innerBall.BorderSizePixel = 0
	innerBall.Visible = true
	innerBall.ZIndex = 12
	innerBall.Parent = outerRing  -- 作为底盘的子元素

	-- 摇杆球圆角
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0.5, 0)
	innerCorner.Parent = innerBall

	-- 摇杆球边框(亮色高光)
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(200, 220, 255)
	innerStroke.Thickness = 2
	innerStroke.Transparency = 0.15
	innerStroke.Parent = innerBall

	-- 摇杆球内部高光点(模拟凸面镜效果)
	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.AnchorPoint = Vector2.new(0.5, 0.5)
	highlight.Position = UDim2.new(0.4, 0, 0.35, 0)  -- 左上偏移，模拟光照
	highlight.Size = UDim2.new(0.3, 0, 0.3, 0)
	highlight.BackgroundColor3 = Color3.fromRGB(230, 240, 255)
	highlight.BackgroundTransparency = 0.5
	highlight.BorderSizePixel = 0
	highlight.ZIndex = 13
	highlight.Parent = innerBall

	local hlCorner = Instance.new("UICorner")
	hlCorner.CornerRadius = UDim.new(0.5, 0)
	hlCorner.Parent = highlight

	-- 绑定触摸事件
	touchFrame.InputBegan:Connect(onTouchBegan)
	touchFrame.InputChanged:Connect(onTouchMoved)
	touchFrame.InputEnded:Connect(onTouchEnded)
end

function UI_VirtualJoystick.GetDirection(): Vector2
	return currentDirection
end

function UI_VirtualJoystick.GetMagnitude(): number
	return currentMagnitude
end

function UI_VirtualJoystick.SetEnabled(isEnabled: boolean)
	enabled = isEnabled
	if not enabled then
		if activeTouchId then
			activeTouchId = nil
			currentDirection = Vector2.zero
			currentMagnitude = 0
			notifyDirectionChanged()
			resetBallToCenter()
		end
	end
	if outerRing then outerRing.Visible = true end
	if innerBall then innerBall.Visible = true end
end

function UI_VirtualJoystick.OnDirectionChanged(callback)
	directionCallback = callback
end

function UI_VirtualJoystick.Destroy()
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
