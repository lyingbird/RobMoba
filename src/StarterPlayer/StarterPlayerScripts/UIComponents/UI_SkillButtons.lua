--[[
	UI_SkillButtons.lua
	技能按钮与方向轮盘 (MOD-02)
	REQ-016: 严格参照王者荣耀弧形布局重设计

	弧形布局: 攻击按钮固定右下角, Q/W/R围绕攻击按钮弧形排列, D/F在更内侧
	方向轮盘: 按住指向性技能 → 显示方向轮盘 → 拖拽选方向 → 松手释放或取消
	8种按钮状态: Idle/Pressed/Aiming/Cooldown/Ready/NoMana/Disabled/Dead/Locked
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local MobileConfig = require(script.Parent.Parent.Modules.MobileConfig)

-- REQ-026: 指示器和取消框模块引用(外部注入)
local indicatorManager = nil  -- MobileIndicatorManager
local cancelZone = nil         -- MobileCancelZone

local UI_SkillButtons = {}

-- ═══════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════
local parentFrame: Frame? = nil
local buttons = {}                    -- { [slotKey] = buttonData }
local aimingSlot = nil                -- 当前AIMING状态的槽位
local isAiming = false                -- REQ-026: 全局瞄准锁(防多指)
local aimLine: Frame? = nil           -- 方向指示线
local aimCancelMark: Frame? = nil     -- 取消区标记
local enabled = true
local skillCastCallback = nil         -- 技能释放回调
local attackCallback = nil            -- 普攻回调
local cdUpdateConnection = nil        -- CD更新 RenderStepped 连接
local inputConnections = {}           -- 全局触摸/鼠标监听连接
local skillConfigs = nil              -- REQ-026: 技能配置引用(SkillRegistry)

-- REQ-026: 智能释放触控追踪
local touchStartTime = 0
local touchStartPos = Vector2.zero

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
	Locked = "Locked", -- REQ-015: 大厅锁定态(未选英雄)
}

local AIM_TYPE_ALIASES = {
	self = "self_circle",
	area = "circle_drop",
	channel = "rect",
	directional = "line",
	direction = "line",
}

local function normalizeAimType(aimType: string?): string
	if typeof(aimType) ~= "string" then
		return "line"
	end
	return AIM_TYPE_ALIASES[aimType] or aimType
end

-- ═══════════════════════════════════════
-- 辅助函数
-- ═══════════════════════════════════════

-- REQ-016: 计算按钮位置(弧形布局)
-- Attack: 固定位置; Q/W/R: 围绕Attack弧形; D/F: 内侧弧形
local function calcButtonPosition(slotKey: string): (number, number)
	if slotKey == "Attack" then
		return MobileConfig.BTN_ATTACK_POS.X, MobileConfig.BTN_ATTACK_POS.Y
	end

	-- 弧形计算: 以Attack按钮为圆心
	local atkX = MobileConfig.BTN_ATTACK_POS.X
	local atkY = MobileConfig.BTN_ATTACK_POS.Y
	local atkDiameter = MobileConfig.SKILL_BTN_ATTACK  -- 屏高比

	local angle, radius
	if MobileConfig.SKILL_ARC_ANGLES[slotKey] then
		-- Q/W/R 技能
		angle = MobileConfig.SKILL_ARC_ANGLES[slotKey]
		radius = atkDiameter * MobileConfig.SKILL_ARC_RADIUS_RATIO
	elseif MobileConfig.SUMM_ARC_ANGLES[slotKey] then
		-- D/F 召唤师技能
		angle = MobileConfig.SUMM_ARC_ANGLES[slotKey]
		radius = atkDiameter * MobileConfig.SKILL_ARC_SUMM_RADIUS_RATIO
	else
		return atkX, atkY -- fallback
	end

	-- 角度转弧度, 计算偏移(注意: Y轴Scale基于屏高, X轴基于屏宽)
	-- 但因为 SizeConstraint = RelativeYY, 我们需要把X偏移也换算成屏宽比
	-- radius 是屏高比, cos分量是X方向偏移(屏高比→需转屏宽比)
	local rad = math.rad(angle)
	-- 为了在Scale坐标中保持圆形弧度, 需要考虑屏幕宽高比
	-- 假设 16:9 屏幕, 宽/高 = 16/9 ≈ 1.778
	-- X_scale = radius * cos(angle) / aspectRatio
	-- Y_scale = radius * sin(angle)
	-- 但我们使用运行时宽高比更准确
	local cam = workspace.CurrentCamera
	local aspectRatio = cam and (cam.ViewportSize.X / cam.ViewportSize.Y) or (16 / 9)

	local dx = radius * math.cos(rad) / aspectRatio  -- 转换为屏宽比
	local dy = radius * math.sin(rad)                 -- 屏高比

	return atkX + dx, atkY + dy
end

local function createRoundButton(slotKey: string, parentGui: Frame): table
	local posX, posY = calcButtonPosition(slotKey)
	local size = MobileConfig.BTN_SIZES[slotKey] or MobileConfig.SKILL_BTN_NORMAL

	-- 主按钮容器
	local btn = Instance.new("ImageButton")
	btn.Name = "Btn_" .. slotKey
	btn.AnchorPoint = Vector2.new(0.5, 0.5)  -- REQ-016: 中心锚点
	btn.Position = UDim2.new(posX, 0, posY, 0)
	btn.Size = UDim2.new(size, 0, size, 0)
	btn.SizeConstraint = Enum.SizeConstraint.RelativeYY
	btn.BackgroundColor3 = Color3.fromRGB(30, 32, 48)   -- REQ-016: 更深的背景色
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.ImageTransparency = 1   -- 用背景色而非Image
	btn.AutoButtonColor = false
	btn.ZIndex = 10
	btn.Parent = parentGui

	-- 圆角
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = btn

	-- REQ-016: 边框 — 攻击按钮使用渐变金色, R使用金色, 其他使用银白色
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	if slotKey == "Attack" then
		stroke.Color = Color3.fromRGB(220, 180, 80)   -- 金色边框
		stroke.Thickness = 3
	elseif slotKey == "R" then
		stroke.Color = Color3.fromRGB(255, 200, 50)   -- 大招金色边框
		stroke.Thickness = 2.5
	elseif slotKey == "D" or slotKey == "F" then
		stroke.Color = Color3.fromRGB(140, 160, 180)   -- 召唤师技能银灰
		stroke.Thickness = 1.5
	else
		stroke.Color = Color3.fromRGB(200, 210, 230)   -- Q/W 银白
		stroke.Thickness = 2
	end
	stroke.Transparency = 0.15
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
		aimType = "line",
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

	-- 重置 (REQ-016: 使用新设计色)
	btn.BackgroundColor3 = Color3.fromRGB(30, 32, 48)
	btn.BackgroundTransparency = 0.15
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
		local pressedSize = (MobileConfig.BTN_SIZES[data.slotKey] or MobileConfig.SKILL_BTN_NORMAL) * MobileConfig.BTN_PRESS_SCALE
		TweenService:Create(btn, TweenInfo.new(MobileConfig.BTN_PRESS_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(pressedSize, 0, pressedSize, 0)
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
	elseif state == ButtonState.Locked then
		-- REQ-016: 大厅锁定态(未选英雄) — 暗色+灰色边框
		btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
		btn.BackgroundTransparency = 0.3
		stroke.Color = Color3.fromRGB(70, 70, 80)
		stroke.Transparency = 0.4
		data.label.Text = "?"
		data.label.TextColor3 = Color3.fromRGB(100, 100, 110)
	end
end

-- 恢复按钮原始尺寸
local function restoreButtonSize(data: table)
	local size = MobileConfig.BTN_SIZES[data.slotKey] or MobileConfig.SKILL_BTN_NORMAL
	TweenService:Create(data.button, TweenInfo.new(MobileConfig.BTN_RELEASE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(size, 0, size, 0)
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

	-- 2D屏幕方向 → 3D世界方向(基于摄像机朝向)
	local dir2d = Vector2.new(dx, dy).Unit
	local camera = workspace.CurrentCamera
	if camera then
		local camLook = camera.CFrame.LookVector
		local flatForward = Vector3.new(camLook.X, 0, camLook.Z)
		if flatForward.Magnitude < 0.001 then
			flatForward = Vector3.new(0, 0, -1)
		else
			flatForward = flatForward.Unit
		end
		local flatRight = Vector3.new(-flatForward.Z, 0, flatForward.X)
		local worldDir = flatRight * dir2d.X + flatForward * (-dir2d.Y)  -- 屏幕Y轴正方向朝下
		if worldDir.Magnitude < 0.001 then return Vector3.new(0, 0, -1) end
		return worldDir.Unit
	end
	return Vector3.new(dir2d.X, 0, dir2d.Y).Unit
end

-- REQ-026: 屏幕触摸位置 → 世界地面坐标(用于circle_drop)
local function screenToWorldPosition(touchPos: Vector2): Vector3
	local camera = workspace.CurrentCamera
	if not camera then return Vector3.zero end

	local ray = camera:ScreenPointToRay(touchPos.X, touchPos.Y)
	-- 与Y=0.2平面求交
	local planeY = 0.2
	if math.abs(ray.Direction.Y) < 0.001 then
		return ray.Origin
	end
	local t = (planeY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then t = 0 end
	return ray.Origin + ray.Direction * t
end

-- REQ-026: 智能释放 — 获取最近敌人方向/位置
local function getSmartCastParams(data: table): table?
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local char = player and player.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local myPos = hrp.Position
	local myTeam = player.Team
	local skillConfig = skillConfigs and data.skillId and skillConfigs[data.skillId]
	local range = skillConfig and skillConfig.Range or 40
	local searchRange = range * MobileConfig.SMART_CAST_RANGE_MULT

	local nearestTarget = nil
	local nearestDist = searchRange

	-- 搜索玩家
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local isEnemy = (myTeam == nil) or (otherPlayer.Team ~= myTeam)
			if isEnemy then
				local otherChar = otherPlayer.Character
				if otherChar then
					local otherRoot = otherChar:FindFirstChild("HumanoidRootPart")
					local otherHumanoid = otherChar:FindFirstChildOfClass("Humanoid")
					if otherRoot and otherHumanoid and otherHumanoid.Health > 0 then
						local dist = (otherRoot.Position - myPos).Magnitude
						if dist < nearestDist then
							nearestDist = dist
							nearestTarget = otherChar
						end
					end
				end
			end
		end
	end

	-- 搜索训练假人
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("IsTrainingDummy") then
			local dummyRoot = obj:FindFirstChild("HumanoidRootPart")
			local dummyHumanoid = obj:FindFirstChildOfClass("Humanoid")
			if dummyRoot and dummyHumanoid and dummyHumanoid.Health > 0 then
				local dist = (dummyRoot.Position - myPos).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestTarget = obj
				end
			end
		end
	end

	if nearestTarget then
		local targetRoot = nearestTarget:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local dir = (targetRoot.Position - myPos)
			dir = Vector3.new(dir.X, 0, dir.Z)
			if dir.Magnitude > 0.01 then
				local aimType = normalizeAimType(data.aimType)
				if aimType == "circle_drop" then
					return { position = targetRoot.Position }
				else
					return { direction = dir.Unit }
				end
			end
		end
	end

	-- 没找到敌人: 朝角色面朝方向
	local lookDir = hrp.CFrame.LookVector
	local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
	if flatLook.Magnitude < 0.01 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	local aimType = normalizeAimType(data.aimType)
	if aimType == "circle_drop" then
		return { position = myPos + flatLook * range }
	end
	return { direction = flatLook }
end

-- ═══════════════════════════════════════
-- 按钮触摸事件 (REQ-026: 重写支持6种aimType)
-- ═══════════════════════════════════════

-- REQ-012 + REQ-014: 判断输入是否为有效的触摸/鼠标输入
-- Device Emulator (IS_STUDIO) 和 DEBUG_FORCE_MOBILE 都需要接受鼠标
local function isValidPointerInput(input: InputObject): boolean
	if input.UserInputType == Enum.UserInputType.Touch then return true end
	if (MobileConfig.DEBUG_FORCE_MOBILE or MobileConfig.IS_STUDIO) and input.UserInputType == Enum.UserInputType.MouseButton1 then return true end
	return false
end

local function onButtonTouchBegan(data: table, input: InputObject)
	if not enabled then return end
	if data.state == ButtonState.Locked then return end
	if data.state == ButtonState.Cooldown or data.state == ButtonState.Dead then
		if data.state == ButtonState.Cooldown then
			flashButton(data, MobileConfig.BTN_FLASH_COLOR_CD)
		end
		return
	end
	if data.state == ButtonState.NoMana then return end
	if data.state == ButtonState.Disabled then return end

	-- REQ-026: 多指锁 — 已有技能在瞄准时拒绝其他技能
	if isAiming and aimingSlot ~= data.slotKey then return end

	if not isValidPointerInput(input) then return end

	data.touchId = input

	-- REQ-026: 记录触控开始时间和位置(用于智能释放判定)
	touchStartTime = tick()
	touchStartPos = Vector2.new(input.Position.X, input.Position.Y)

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

	-- REQ-026: 按aimType分支处理
	local aimType = normalizeAimType(data.aimType)

	if aimType == "self_circle" then
		-- self_circle: 点按即释放(不显示取消框)
		data.state = ButtonState.Pressed
		applyVisualState(data)

		-- 短暂显示自身指示器(视觉反馈)
		if indicatorManager then
			local skillConfig = skillConfigs and data.skillId and skillConfigs[data.skillId]
			if skillConfig then
				indicatorManager.ShowIndicator("self_circle", skillConfig)
				task.delay(0.3, function()
					indicatorManager.HideIndicator()
				end)
			end
		end

		if skillCastCallback then
			skillCastCallback(data.slotKey, { direction = Vector3.zero })
		end
		task.delay(0.1, function()
			if data.state == ButtonState.Pressed then
				data.state = ButtonState.Idle
				restoreButtonSize(data)
				applyVisualState(data)
			end
		end)
	elseif aimType == "line" or aimType == "rect" or aimType == "sector" then
		-- 方向拖拽型: 进入AIMING, 显示指示器+取消框
		data.state = ButtonState.Aiming
		aimingSlot = data.slotKey
		isAiming = true
		applyVisualState(data)
		showAimWheel(data)

		-- REQ-026: 显示3D指示器
		if indicatorManager then
			local skillConfig = skillConfigs and data.skillId and skillConfigs[data.skillId]
			if skillConfig then
				indicatorManager.ShowIndicator(aimType, skillConfig)
			end
		end
		-- REQ-026: 显示取消框
		if cancelZone then
			cancelZone.Show()
		end
	elseif aimType == "circle_drop" then
		-- 位置拖拽型: 进入AIMING(TARGETING), 显示指示器+取消框
		data.state = ButtonState.Aiming
		aimingSlot = data.slotKey
		isAiming = true
		applyVisualState(data)
		showAimWheel(data)

		-- REQ-026: 显示3D指示器(落点型)
		if indicatorManager then
			local skillConfig = skillConfigs and data.skillId and skillConfigs[data.skillId]
			if skillConfig then
				indicatorManager.ShowIndicator("circle_drop", skillConfig)
			end
		end
		-- REQ-026: 显示取消框
		if cancelZone then
			cancelZone.Show()
		end
	else
		-- 未知aimType: 按旧逻辑(方向)
		data.state = ButtonState.Aiming
		aimingSlot = data.slotKey
		isAiming = true
		applyVisualState(data)
		showAimWheel(data)
	end
end

local function onButtonTouchMoved(data: table, input: InputObject)
	-- REQ-012 + REQ-014: 鼠标模式下 InputChanged 的 MouseMovement 与原 touchId 不同
	if input ~= data.touchId then
		if not ((MobileConfig.DEBUG_FORCE_MOBILE or MobileConfig.IS_STUDIO) and data.touchId and input.UserInputType == Enum.UserInputType.MouseMovement) then
			return
		end
	end
	if data.state ~= ButtonState.Aiming then return end

	local touchPos = Vector2.new(input.Position.X, input.Position.Y)
	updateAimWheel(data, touchPos)

	-- REQ-026: 检测取消区域 + 更新指示器
	local inCancelZone = cancelZone and cancelZone.IsInCancelZone(touchPos) or false

	if inCancelZone then
		-- 手指在取消区域: 指示器变红 + 取消框变红
		if indicatorManager then
			indicatorManager.SetCancelMode(true)
		end
		if cancelZone then
			cancelZone.SetActive(true)
		end
	else
		-- 手指不在取消区域: 恢复正常
		if indicatorManager then
			indicatorManager.SetCancelMode(false)
		end
		if cancelZone then
			cancelZone.SetActive(false)
		end

		-- 更新指示器方向/位置
		local aimType = normalizeAimType(data.aimType)
		if aimType == "circle_drop" then
			-- 位置型: 触摸位置 → 世界坐标
			local worldPos = screenToWorldPosition(touchPos)
			if indicatorManager then
				indicatorManager.UpdatePosition(worldPos)
			end
		else
			-- 方向型: 触摸方向 → 世界方向
			local worldDir = getAimDirection(data, touchPos)
			if worldDir and indicatorManager then
				indicatorManager.UpdateDirection(worldDir)
			end
		end
	end
end

local function onButtonTouchEnded(data: table, input: InputObject)
	-- REQ-012 + REQ-014: 鼠标模式下 InputEnded 的 MouseButton1 与原 touchId 可能不同
	if input ~= data.touchId then
		if not ((MobileConfig.DEBUG_FORCE_MOBILE or MobileConfig.IS_STUDIO) and data.touchId and input.UserInputType == Enum.UserInputType.MouseButton1) then
			return
		end
	end
	data.touchId = nil

	if data.state == ButtonState.Aiming then
		local touchPos = Vector2.new(input.Position.X, input.Position.Y)

		-- REQ-026: 先检查是否为智能释放(快速点按)
		local elapsed = tick() - touchStartTime
		local moved = (touchPos - touchStartPos).Magnitude
		local isQuickTap = elapsed < MobileConfig.QUICK_TAP_MAX_DURATION and moved < MobileConfig.QUICK_TAP_MAX_DISTANCE

		-- 检查取消区域
		local inCancelZone = cancelZone and cancelZone.IsInCancelZone(touchPos) or false

		-- 清理UI
		hideAimWheel()
		aimingSlot = nil
		isAiming = false
		if indicatorManager then
			indicatorManager.HideIndicator()
		end
		if cancelZone then
			cancelZone.Hide()
		end

		if inCancelZone then
			-- 取消释放: 什么都不做
		elseif isQuickTap then
			-- REQ-026: 智能释放 — 自动朝最近敌人方向
			local smartParams = getSmartCastParams(data)
			if smartParams and skillCastCallback then
				skillCastCallback(data.slotKey, smartParams)
			end
		else
			-- 正常释放: 根据aimType获取参数
			local aimType = normalizeAimType(data.aimType)
			if aimType == "circle_drop" then
				-- 位置型: 触摸位置 → 世界坐标
				local worldPos = screenToWorldPosition(touchPos)
				if skillCastCallback then
					skillCastCallback(data.slotKey, { position = worldPos })
				end
			else
				-- 方向型: 获取方向
				local direction = getAimDirection(data, touchPos)
				if direction and skillCastCallback then
					skillCastCallback(data.slotKey, { direction = direction })
				elseif skillCastCallback then
					local smartParams = getSmartCastParams(data)
					if smartParams then
						skillCastCallback(data.slotKey, smartParams)
					end
				end
			end
		end

		-- 回到Idle
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
--- @param skillSlots table? - { Q={skillId=1001, aimType="directional"}, W={...}, ... } 或 nil(锁定态)
function UI_SkillButtons.Init(parent: Frame, skillSlots: table?)
	parentFrame = parent

	-- REQ-015: 判断是否锁定态(大厅模式,未选英雄)
	local isLocked = (skillSlots == nil)

	-- 创建6个按钮
	local slotKeys = { "Q", "W", "R", "D", "F", "Attack" }
	for _, slotKey in ipairs(slotKeys) do
		local data = createRoundButton(slotKey, parentFrame)
		if data then
			if isLocked then
				-- REQ-015: 锁定态 — 无技能信息, 显示"?"
				data.state = ButtonState.Locked
				applyVisualState(data)
			else
				-- 绑定技能信息
				local slotInfo = skillSlots[slotKey]
				if slotInfo then
					data.skillId = slotInfo.skillId
					data.aimType = normalizeAimType(slotInfo.aimType)
				end
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

	for _, conn in ipairs(inputConnections) do
		conn:Disconnect()
	end
	inputConnections = {}

	table.insert(inputConnections, UserInputService.TouchMoved:Connect(function(input)
		for _, data in pairs(buttons) do
			if data.touchId == input then
				onButtonTouchMoved(data, input)
				return
			end
		end
	end))

	table.insert(inputConnections, UserInputService.TouchEnded:Connect(function(input)
		for _, data in pairs(buttons) do
			if data.touchId == input then
				onButtonTouchEnded(data, input)
				return
			end
		end
	end))

	table.insert(inputConnections, UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		for _, data in pairs(buttons) do
			if data.touchId then
				onButtonTouchMoved(data, input)
				return
			end
		end
	end))

	table.insert(inputConnections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		for _, data in pairs(buttons) do
			if data.touchId then
				onButtonTouchEnded(data, input)
				return
			end
		end
	end))

	-- 创建方向轮盘元素
	createAimElements()

	-- 启动CD更新循环
	startCDUpdateLoop()
end

--- REQ-015: 更新技能槽(选完英雄后,从锁定态→正常态)
--- @param skillSlots table? - { Q={skillId, aimType}, W=..., R=... }
function UI_SkillButtons.UpdateSkills(skillSlots: table?)
	if not skillSlots then
		for slotKey, data in pairs(buttons) do
			data.skillId = nil
			data.aimType = "line"
			data.state = ButtonState.Locked
			data.label.Text = "?"
			data.label.TextColor3 = Color3.fromRGB(100, 100, 110)
			data.button.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			applyVisualState(data)
		end
		return
	end

	for slotKey, slotInfo in pairs(skillSlots) do
		local data = buttons[slotKey]
		if data then
			data.skillId = slotInfo.skillId
			data.aimType = normalizeAimType(slotInfo.aimType)
			data.state = ButtonState.Idle

			-- 恢复正常视觉 (REQ-016: 使用新设计色)
			data.label.Text = slotKey == "Attack" and "⚔" or slotKey
			data.label.TextColor3 = Color3.new(1, 1, 1)
			data.button.BackgroundColor3 = Color3.fromRGB(30, 32, 48)
			applyVisualState(data)
		end
	end

	-- Attack 按钮始终恢复为Idle(如果尚为Locked)
	local atkData = buttons["Attack"]
	if atkData and atkData.state == ButtonState.Locked then
		atkData.state = ButtonState.Idle
		atkData.label.Text = "⚔"
		atkData.label.TextColor3 = Color3.new(1, 1, 1)
		atkData.button.BackgroundColor3 = Color3.fromRGB(30, 32, 48)
		applyVisualState(atkData)
	end
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
			isAiming = false
		end
		-- REQ-026: 清理指示器和取消框(AC-030: 角色死亡清理)
		if indicatorManager then
			indicatorManager.HideIndicator()
		end
		if cancelZone then
			cancelZone.Hide()
		end
	end
end

--- 注册技能释放回调
--- REQ-026: 新签名 (slotKey: string, params: {direction: Vector3?, position: Vector3?}) -> ()
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
	for _, conn in ipairs(inputConnections) do
		conn:Disconnect()
	end
	inputConnections = {}
	for _, data in pairs(buttons) do
		if data.button then
			data.button:Destroy()
		end
	end
	buttons = {}
	if aimLine then aimLine:Destroy(); aimLine = nil end
	if aimCancelMark then aimCancelMark:Destroy(); aimCancelMark = nil end
	aimingSlot = nil
	isAiming = false
	skillCastCallback = nil
	attackCallback = nil
	enabled = false
	indicatorManager = nil
	cancelZone = nil
	skillConfigs = nil
end

--- REQ-026: 注入MobileIndicatorManager引用
function UI_SkillButtons.SetIndicatorManager(manager)
	indicatorManager = manager
end

--- REQ-026: 注入MobileCancelZone引用
function UI_SkillButtons.SetCancelZone(zone)
	cancelZone = zone
end

--- REQ-026: 注入技能配置表引用(SkillRegistry)
function UI_SkillButtons.SetSkillConfigs(configs)
	skillConfigs = configs
end

return UI_SkillButtons
