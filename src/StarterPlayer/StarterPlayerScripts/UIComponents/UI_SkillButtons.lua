--[[
	UI_SkillButtons.lua
	技能按钮与方向轮盘 (MOD-02)
	REQ-011: 手机端MOBA UI与操控系统

	弧形布局6个按钮(Q/W/R/D/F/普攻) + 方向轮盘瞄准系统
	按住指向性技能 → 显示方向轮盘 → 拖拽选方向 → 松手释放或取消
	8种按钮状态: Idle/Pressed/Aiming/Cooldown/Ready/NoMana/Disabled/Dead
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MobileConfig = require(script.Parent.Parent.Modules.MobileConfig)

local UI_SkillButtons = {}

-- ═══════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════
local parentFrame: Frame? = nil
local buttons = {}                    -- { [slotKey] = buttonData }
local aimingSlot = nil                -- 当前AIMING状态的槽位
local aimLine: Frame? = nil           -- 方向指示线
local aimCancelMark: Frame? = nil     -- 取消区标记
local enabled = true
local skillCastCallback = nil         -- 技能释放回调
local attackCallback = nil            -- 普攻回调
local cdUpdateConnection = nil        -- CD更新 RenderStepped 连接

-- 按钮状态枚举
local ButtonState = {
	Idle = "Idle",
	Pressed = "Pressed",
	Aiming = "Aiming",
	Cooldown = "Cooldown",
	Ready = "Ready",
	NoMana = "NoMana",
	Disabled = "Disabled",
	Dead = "Dead",
}

-- ═══════════════════════════════════════
-- 辅助函数
-- ═══════════════════════════════════════

local function createRoundButton(slotKey: string, parentGui: Frame): table
	local cfg = MobileConfig.BTN_POSITIONS[slotKey]
	local size = MobileConfig.BTN_SIZES[slotKey] or MobileConfig.SKILL_BTN_NORMAL
	if not cfg then return nil end

	-- 主按钮容器
	local btn = Instance.new("ImageButton")
	btn.Name = "Btn_" .. slotKey
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.new(cfg.X, 0, cfg.Y, 0)
	btn.Size = UDim2.new(0, 0, size, 0)
	btn.SizeConstraint = Enum.SizeConstraint.RelativeYY
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.ImageTransparency = 1   -- 用背景色而非Image
	btn.AutoButtonColor = false
	btn.ZIndex = 10
	btn.Parent = parentGui

	-- 圆角
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btn

	-- 边框
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = slotKey == "R" and Color3.fromRGB(255, 200, 50) or Color3.new(1, 1, 1)
	stroke.Thickness = slotKey == "Attack" and 3 or 2
	stroke.Transparency = 0.2
	stroke.Parent = btn

	-- 技能标识文字(简化, 实际应用图标)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0.5, 0)
	label.Position = UDim2.new(0, 0, 0.25, 0)
	label.BackgroundTransparency = 1
	label.Text = slotKey == "Attack" and "⚔" or slotKey
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 11
	label.Parent = btn

	-- CD遮罩(半透明灰色, 初始隐藏)
	local cdMask = Instance.new("Frame")
	cdMask.Name = "CDMask"
	cdMask.Size = UDim2.new(1, 0, 1, 0)
	cdMask.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	cdMask.BackgroundTransparency = 1 - MobileConfig.BTN_CD_MASK_ALPHA
	cdMask.BorderSizePixel = 0
	cdMask.Visible = false
	cdMask.ZIndex = 12
	cdMask.Parent = btn
	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0.5, 0)
	cdCorner.Parent = cdMask

	-- CD秒数文字
	local cdText = Instance.new("TextLabel")
	cdText.Name = "CDText"
	cdText.Size = UDim2.new(0.8, 0, 0.4, 0)
	cdText.Position = UDim2.new(0.1, 0, 0.3, 0)
	cdText.BackgroundTransparency = 1
	cdText.Text = ""
	cdText.TextColor3 = Color3.new(1, 1, 1)
	cdText.TextScaled = true
	cdText.Font = Enum.Font.GothamBold
	cdText.Visible = false
	cdText.ZIndex = 13
	cdText.Parent = btn

	-- 状态覆盖层(锁链/闪烁等)
	local overlay = Instance.new("TextLabel")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.TextColor3 = Color3.new(1, 1, 1)
	overlay.TextScaled = true
	overlay.Font = Enum.Font.GothamBold
	overlay.Visible = false
	overlay.ZIndex = 14
	overlay.Parent = btn

	return {
		slotKey = slotKey,
		button = btn,
		stroke = stroke,
		label = label,
		cdMask = cdMask,
		cdText = cdText,
		overlay = overlay,
		state = ButtonState.Idle,
		skillId = nil,
		aimType = "directional",
		cdRemaining = 0,
		cdTotal = 0,
		touchId = nil,
	}
end

-- 应用按钮视觉状态
local function applyVisualState(data: table)
	local btn = data.button
	local stroke = data.stroke
	local cdMask = data.cdMask
	local cdText = data.cdText
	local overlay = data.overlay

	-- 重置
	btn.BackgroundTransparency = 0.2
	stroke.Transparency = 0.2
	cdMask.Visible = false
	cdText.Visible = false
	overlay.Visible = false
	overlay.Text = ""

	local state = data.state

	if state == ButtonState.Idle then
		-- 默认状态: 正常显示
	elseif state == ButtonState.Pressed then
		-- 按下: 缩小
		TweenService:Create(btn, TweenInfo.new(MobileConfig.BTN_PRESS_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 0, (MobileConfig.BTN_SIZES[data.slotKey] or MobileConfig.SKILL_BTN_NORMAL) * MobileConfig.BTN_PRESS_SCALE, 0)
		}):Play()
	elseif state == ButtonState.Aiming then
		-- 瞄准中: 缩小 + 边框发光
		stroke.Color = Color3.fromRGB(100, 200, 255)
		stroke.Transparency = 0
	elseif state == ButtonState.Cooldown then
		-- CD中: 灰色遮罩 + 秒数
		cdMask.Visible = true
		cdText.Visible = true
		btn.BackgroundTransparency = 0.5
	elseif state == ButtonState.Ready then
		-- CD好了: 闪光脉冲
		stroke.Color = Color3.fromRGB(255, 215, 0)
		stroke.Transparency = 0
		TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0.2,
			Color = data.slotKey == "R" and Color3.fromRGB(255, 200, 50) or Color3.new(1, 1, 1),
		}):Play()
		data.state = ButtonState.Idle -- 自动回Idle
	elseif state == ButtonState.NoMana then
		-- MP不足: 暗淡
		btn.BackgroundTransparency = 1 - MobileConfig.BTN_DISABLED_ALPHA
		stroke.Color = Color3.fromRGB(80, 130, 255)
	elseif state == ButtonState.Disabled then
		-- 被控制: 暗淡 + 锁链图标
		btn.BackgroundTransparency = 1 - MobileConfig.BTN_DISABLED_ALPHA
		overlay.Text = "🔒"
		overlay.Visible = true
	elseif state == ButtonState.Dead then
		-- 死亡: 全暗
		btn.BackgroundTransparency = 0.8
		stroke.Transparency = 0.8
	end
end

-- 恢复按钮原始尺寸
local function restoreButtonSize(data: table)
	local size = MobileConfig.BTN_SIZES[data.slotKey] or MobileConfig.SKILL_BTN_NORMAL
	TweenService:Create(data.button, TweenInfo.new(MobileConfig.BTN_RELEASE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 0, size, 0)
	}):Play()
end

-- CD中按下的闪红反馈
local function flashButton(data: table, color: Color3)
	local btn = data.button
	local origColor = btn.BackgroundColor3
	btn.BackgroundColor3 = color
	task.delay(MobileConfig.BTN_FLASH_DURATION, function()
		if btn and btn.Parent then
			btn.BackgroundColor3 = origColor
		end
	end)
end

-- ═══════════════════════════════════════
-- 方向轮盘
-- ═══════════════════════════════════════

local function createAimElements()
	if not parentFrame then return end

	-- 方向指示线
	aimLine = Instance.new("Frame")
	aimLine.Name = "AimLine"
	aimLine.AnchorPoint = Vector2.new(0, 0.5)
	aimLine.Size = UDim2.fromOffset(100, MobileConfig.AIM_LINE_WIDTH)
	aimLine.BackgroundColor3 = MobileConfig.AIM_LINE_COLOR
	aimLine.BackgroundTransparency = 0.2
	aimLine.BorderSizePixel = 0
	aimLine.Visible = false
	aimLine.ZIndex = 15
	aimLine.Parent = parentFrame

	-- 取消区标记
	aimCancelMark = Instance.new("TextLabel")
	aimCancelMark.Name = "CancelMark"
	aimCancelMark.AnchorPoint = Vector2.new(0.5, 0.5)
	aimCancelMark.Size = UDim2.fromOffset(30, 30)
	aimCancelMark.BackgroundColor3 = MobileConfig.AIM_CANCEL_COLOR
	aimCancelMark.BackgroundTransparency = 0.5
	aimCancelMark.Text = "✕"
	aimCancelMark.TextColor3 = Color3.new(1, 1, 1)
	aimCancelMark.TextScaled = true
	aimCancelMark.Font = Enum.Font.GothamBold
	aimCancelMark.Visible = false
	aimCancelMark.ZIndex = 16
	aimCancelMark.Parent = parentFrame

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0.5, 0)
	cancelCorner.Parent = aimCancelMark
end

local function showAimWheel(data: table)
	if not aimLine or not aimCancelMark then return end

	-- 方向指示线起点 = 按钮中心(屏幕绝对坐标)
	local btnAbsPos = data.button.AbsolutePosition
	local btnAbsSize = data.button.AbsoluteSize
	local centerX = btnAbsPos.X + btnAbsSize.X / 2 - parentFrame.AbsolutePosition.X
	local centerY = btnAbsPos.Y + btnAbsSize.Y / 2 - parentFrame.AbsolutePosition.Y

	aimLine.Position = UDim2.fromOffset(centerX, centerY)
	aimLine.Visible = false  -- 初始隐藏, 拖出后才显示

	aimCancelMark.Position = UDim2.fromOffset(centerX, centerY)
	aimCancelMark.Visible = false
end

local function updateAimWheel(data: table, touchPos: Vector2)
	if not aimLine or not aimCancelMark then return end

	local btnAbsPos = data.button.AbsolutePosition
	local btnAbsSize = data.button.AbsoluteSize
	local centerX = btnAbsPos.X + btnAbsSize.X / 2
	local centerY = btnAbsPos.Y + btnAbsSize.Y / 2

	local dx = touchPos.X - centerX
	local dy = touchPos.Y - centerY
	local distance = math.sqrt(dx * dx + dy * dy)
	local cancelRadius = btnAbsSize.X / 2 * MobileConfig.AIM_CANCEL_THRESHOLD

	local frameCenterX = centerX - parentFrame.AbsolutePosition.X
	local frameCenterY = centerY - parentFrame.AbsolutePosition.Y

	if distance < cancelRadius then
		-- 在取消区
		aimLine.Visible = false
		aimCancelMark.Visible = true
		aimCancelMark.Position = UDim2.fromOffset(frameCenterX, frameCenterY)
	else
		-- 显示方向指示线
		aimCancelMark.Visible = false
		aimLine.Visible = true

		-- 计算角度
		local angle = math.atan2(dy, dx)
		aimLine.Rotation = math.deg(angle)
		aimLine.Position = UDim2.fromOffset(frameCenterX, frameCenterY)
		aimLine.Size = UDim2.fromOffset(math.min(distance, 120), MobileConfig.AIM_LINE_WIDTH)
	end
end

local function hideAimWheel()
	if aimLine then aimLine.Visible = false end
	if aimCancelMark then aimCancelMark.Visible = false end
end

-- 获取瞄准方向(屏幕2D → 世界3D)
local function getAimDirection(data: table, touchPos: Vector2): Vector3?
	local btnAbsPos = data.button.AbsolutePosition
	local btnAbsSize = data.button.AbsoluteSize
	local centerX = btnAbsPos.X + btnAbsSize.X / 2
	local centerY = btnAbsPos.Y + btnAbsSize.Y / 2

	local dx = touchPos.X - centerX
	local dy = touchPos.Y - centerY
	local distance = math.sqrt(dx * dx + dy * dy)
	local cancelRadius = btnAbsSize.X / 2 * MobileConfig.AIM_CANCEL_THRESHOLD

	if distance < cancelRadius then
		return nil  -- 在取消区
	end

	-- 2D屏幕方向 → 3D世界方向
	-- 固定摄像机朝-Z: 屏幕X→世界X, 屏幕Y→世界-Z
	local dir2d = Vector2.new(dx, dy).Unit
	return Vector3.new(dir2d.X, 0, dir2d.Y).Unit
end

-- ═══════════════════════════════════════
-- 按钮触摸事件
-- ═══════════════════════════════════════

-- REQ-012: 判断输入是否为有效的触摸/鼠标输入
local function isValidPointerInput(input: InputObject): boolean
	if input.UserInputType == Enum.UserInputType.Touch then return true end
	if MobileConfig.DEBUG_FORCE_MOBILE and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
	return false
end

local function onButtonTouchBegan(data: table, input: InputObject)
	if not enabled then return end
	if data.state == ButtonState.Cooldown or data.state == ButtonState.Dead then
		-- CD中或死亡: 无响应, 闪红
		if data.state == ButtonState.Cooldown then
			flashButton(data, MobileConfig.BTN_FLASH_COLOR_CD)
		end
		return
	end
	if data.state == ButtonState.NoMana then
		-- MP不足: 无响应
		return
	end
	if data.state == ButtonState.Disabled then
		-- 被控制: 无响应
		return
	end
	if aimingSlot and aimingSlot ~= data.slotKey then
		-- 已有其他技能在瞄准, 忽略
		return
	end

	if not isValidPointerInput(input) then return end

	data.touchId = input

	if data.slotKey == "Attack" then
		-- 普攻: 点按即触发
		data.state = ButtonState.Pressed
		applyVisualState(data)
		if attackCallback then
			attackCallback()
		end
		task.delay(0.1, function()
			if data.state == ButtonState.Pressed then
				data.state = ButtonState.Idle
				restoreButtonSize(data)
				applyVisualState(data)
			end
		end)
		return
	end

	-- 技能按钮: 判断aimType
	local aimType = data.aimType or "directional"
	if aimType == "self" or aimType == "channel" or aimType == "none" then
		-- 非指向性: 点按即释放
		data.state = ButtonState.Pressed
		applyVisualState(data)
		if skillCastCallback then
			skillCastCallback(data.skillId, nil)
		end
		task.delay(0.1, function()
			if data.state == ButtonState.Pressed then
				data.state = ButtonState.Idle
				restoreButtonSize(data)
				applyVisualState(data)
			end
		end)
	else
		-- 指向性/范围: 进入AIMING
		data.state = ButtonState.Aiming
		aimingSlot = data.slotKey
		applyVisualState(data)
		showAimWheel(data)
	end
end

local function onButtonTouchMoved(data: table, input: InputObject)
	-- REQ-012: 鼠标模式下 InputChanged 的 MouseMovement 与原 touchId 不同
	if input ~= data.touchId then
		if not (MobileConfig.DEBUG_FORCE_MOBILE and data.touchId and input.UserInputType == Enum.UserInputType.MouseMovement) then
			return
		end
	end
	if data.state ~= ButtonState.Aiming then return end

	local touchPos = Vector2.new(input.Position.X, input.Position.Y)
	updateAimWheel(data, touchPos)
end

local function onButtonTouchEnded(data: table, input: InputObject)
	-- REQ-012: 鼠标模式下 InputEnded 的 MouseButton1 与原 touchId 可能不同
	if input ~= data.touchId then
		if not (MobileConfig.DEBUG_FORCE_MOBILE and data.touchId and input.UserInputType == Enum.UserInputType.MouseButton1) then
			return
		end
	end
	data.touchId = nil

	if data.state == ButtonState.Aiming then
		-- 瞄准结束: 判断释放或取消
		local touchPos = Vector2.new(input.Position.X, input.Position.Y)
		local direction = getAimDirection(data, touchPos)

		hideAimWheel()
		aimingSlot = nil

		if direction then
			-- 释放技能
			if skillCastCallback then
				skillCastCallback(data.skillId, direction)
			end
		end
		-- 无论释放还是取消, 回到Idle
		data.state = ButtonState.Idle
		restoreButtonSize(data)
		applyVisualState(data)
	elseif data.state == ButtonState.Pressed then
		data.state = ButtonState.Idle
		restoreButtonSize(data)
		applyVisualState(data)
	end
end

-- ═══════════════════════════════════════
-- CD 更新循环
-- ═══════════════════════════════════════

local function startCDUpdateLoop()
	cdUpdateConnection = RunService.RenderStepped:Connect(function(deltaTime)
		for _, data in pairs(buttons) do
			if data.state == ButtonState.Cooldown and data.cdRemaining > 0 then
				-- 每帧递减CD, 平滑更新显示
				data.cdRemaining = math.max(0, data.cdRemaining - deltaTime)
				local fmt = string.format("%." .. MobileConfig.CD_DISPLAY_DECIMAL .. "f", data.cdRemaining)
				data.cdText.Text = fmt

				-- CD结束检测
				if data.cdRemaining <= 0 then
					data.state = ButtonState.Ready
					applyVisualState(data)
					data.cdText.Visible = false
					data.cdMask.Visible = false
				end
			end
		end
	end)
end

-- ═══════════════════════════════════════
-- 公共接口
-- ═══════════════════════════════════════

--- 初始化技能按钮面板
--- @param parent Frame - 挂载父容器(ScreenGui)
--- @param skillSlots table - { Q={skillId=1001, aimType="directional"}, W={...}, ... }
function UI_SkillButtons.Init(parent: Frame, skillSlots: table)
	parentFrame = parent

	-- 创建6个按钮
	local slotKeys = { "Q", "W", "R", "D", "F", "Attack" }
	for _, slotKey in ipairs(slotKeys) do
		local data = createRoundButton(slotKey, parentFrame)
		if data then
			-- 绑定技能信息
			local slotInfo = skillSlots[slotKey]
			if slotInfo then
				data.skillId = slotInfo.skillId
				data.aimType = slotInfo.aimType or "directional"
			end

			-- 绑定触摸事件
			data.button.InputBegan:Connect(function(input)
				onButtonTouchBegan(data, input)
			end)
			data.button.InputChanged:Connect(function(input)
				onButtonTouchMoved(data, input)
			end)
			data.button.InputEnded:Connect(function(input)
				onButtonTouchEnded(data, input)
			end)

			buttons[slotKey] = data
		end
	end

	-- 创建方向轮盘元素
	createAimElements()

	-- 启动CD更新循环
	startCDUpdateLoop()
end

--- 设置单个技能按钮状态
function UI_SkillButtons.SetSkillState(slotKey: string, state: string)
	local data = buttons[slotKey]
	if not data then return end
	data.state = state
	applyVisualState(data)
end

--- 更新冷却显示
function UI_SkillButtons.UpdateCooldown(slotKey: string, remaining: number, total: number)
	local data = buttons[slotKey]
	if not data then return end

	data.cdRemaining = remaining
	data.cdTotal = total

	if remaining > 0 then
		data.state = ButtonState.Cooldown
		applyVisualState(data)

		-- 更新CD文字
		local fmt = string.format("%." .. MobileConfig.CD_DISPLAY_DECIMAL .. "f", remaining)
		data.cdText.Text = fmt
		data.cdText.Visible = true
		data.cdMask.Visible = true

		-- 更新CD遮罩旋转(模拟扇形消退)
		-- 使用 Rotation 表示CD进度: 360(满CD) → 0(CD结束)
		local progress = remaining / math.max(total, 0.01)
		data.cdMask.Rotation = 360 * (1 - progress)
	else
		-- CD结束
		if data.state == ButtonState.Cooldown then
			data.state = ButtonState.Ready
			applyVisualState(data)
		end
		data.cdText.Visible = false
		data.cdMask.Visible = false
	end
end

--- 全局启用/禁用
function UI_SkillButtons.SetEnabled(isEnabled: boolean)
	enabled = isEnabled
	if not enabled then
		-- 取消当前瞄准
		if aimingSlot then
			local data = buttons[aimingSlot]
			if data then
				data.state = ButtonState.Idle
				data.touchId = nil
				restoreButtonSize(data)
				applyVisualState(data)
			end
			hideAimWheel()
			aimingSlot = nil
		end
	end
end

--- 注册技能释放回调
--- @param callback (skillId: number, direction: Vector3?) -> ()
function UI_SkillButtons.OnSkillCast(callback)
	skillCastCallback = callback
end

--- 注册普攻回调
--- @param callback () -> ()
function UI_SkillButtons.OnAttackPressed(callback)
	attackCallback = callback
end

--- 销毁清理
function UI_SkillButtons.Destroy()
	if cdUpdateConnection then
		cdUpdateConnection:Disconnect()
		cdUpdateConnection = nil
	end
	for _, data in pairs(buttons) do
		if data.button then
			data.button:Destroy()
		end
	end
	buttons = {}
	if aimLine then aimLine:Destroy(); aimLine = nil end
	if aimCancelMark then aimCancelMark:Destroy(); aimCancelMark = nil end
	aimingSlot = nil
	skillCastCallback = nil
	attackCallback = nil
	enabled = false
end

return UI_SkillButtons
