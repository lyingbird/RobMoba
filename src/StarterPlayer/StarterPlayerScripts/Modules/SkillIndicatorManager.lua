--[[
	SkillIndicatorManager.lua
	REQ-014: 3D技能指示器管理模块(对象池)

	纯渲染模块 — 管理 Workspace 中的 3D 指示器 Part
	由 UI_SkillButtons 驱动，不包含任何业务逻辑(不判断CD/蓝量/状态)

	指示器类型:
	  LINE        — 方向线(Part+Neon, 长度=技能Range)
	  CIRCLE_SELF — 自身范围圈(Cylinder Part, 闪现后淡出)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = script.Parent
local MobileConfig = require(Modules:WaitForChild("MobileConfig"))

local SkillIndicatorManager = {}

-- ═══════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════
local indicatorFolder = nil  -- Workspace.SkillIndicators

-- LINE 对象池 {body: Part, arrow: Part, origin: Part}
local linePool = nil
-- CIRCLE_SELF 对象池 {part: Part}
local circlePool = nil

local activeType = nil       -- nil | "LINE" | "CIRCLE_SELF"
local currentColor = nil     -- 当前指示器颜色(Color3)
local cancelColor = MobileConfig.INDICATOR_CANCEL_COLOR
local cancelAlpha = MobileConfig.INDICATOR_CANCEL_ALPHA
local normalAlpha = MobileConfig.INDICATOR_LINE_ALPHA
local isInCancelState = false

local renderConn = nil       -- RenderStepped 连接(LINE跟随角色)
local currentOrigin = nil    -- Vector3: 英雄脚下位置
local currentDirection = nil -- Vector3: 当前指向方向
local currentRange = 0       -- number: 技能射程
local circleTweenId = 0      -- CIRCLE_SELF tween 竞态保护: 每次 ShowCircleSelf 递增

-- ═══════════════════════════════════════
-- 私有: 创建对象池
-- ═══════════════════════════════════════

local function createLineParts()
	local lineW = MobileConfig.INDICATOR_LINE_WIDTH

	-- 方向线主体 (薄片 Part)
	-- CFrame.lookAt 使 -Z 轴朝向目标, 所以长度放在 Z 轴, 宽度放在 X 轴
	local body = Instance.new("Part")
	body.Name = "IndicatorLine"
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = false
	body.Material = Enum.Material.Neon
	body.Size = Vector3.new(lineW, 0.1, 1)  -- X=宽度, Y=厚度, Z=长度(运行时设)
	body.Transparency = 1  -- 默认隐藏(Part无Visible属性，用Transparency=1代替)
	body.Parent = indicatorFolder

	-- 箭头装饰 (小方块, 在线末端)
	local arrow = Instance.new("Part")
	arrow.Name = "IndicatorArrow"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CastShadow = false
	arrow.Material = Enum.Material.Neon
	local arrowSize = MobileConfig.INDICATOR_LINE_ARROW_SIZE
	arrow.Size = Vector3.new(arrowSize, 0.1, arrowSize)
	arrow.Transparency = 1  -- 默认隐藏
	arrow.Parent = indicatorFolder

	-- 起始圆环 (扁平圆柱)
	local origin = Instance.new("Part")
	origin.Name = "IndicatorOrigin"
	origin.Shape = Enum.PartType.Cylinder
	origin.Anchored = true
	origin.CanCollide = false
	origin.CastShadow = false
	origin.Material = Enum.Material.Neon
	local originR = MobileConfig.INDICATOR_ORIGIN_RADIUS
	origin.Size = Vector3.new(0.1, originR * 2, originR * 2)  -- Cylinder: X=高, Y=直径, Z=直径
	origin.Transparency = 1  -- 默认隐藏
	origin.Parent = indicatorFolder

	return { body = body, arrow = arrow, origin = origin }
end

local function createCirclePart()
	local part = Instance.new("Part")
	part.Name = "IndicatorCircleSelf"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Size = Vector3.new(0.1, 1, 1)  -- 运行时设尺寸
	part.Transparency = 1  -- 默认隐藏
	part.Parent = indicatorFolder

	return { part = part }
end

-- ═══════════════════════════════════════
-- 私有: LINE 变换更新
-- ═══════════════════════════════════════

local function updateLineTransform()
	if not linePool or not currentOrigin or not currentDirection then return end
	if activeType ~= "LINE" then return end

	local yOff = MobileConfig.INDICATOR_Y_OFFSET
	local halfLen = currentRange / 2
	local dir = currentDirection

	-- 方向线主体: 从 origin 沿 direction 延伸 range
	-- CFrame.lookAt 使 -Z 轴朝向 dir, 所以 Z=长度(range), X=宽度(lineWidth)
	local midPoint = currentOrigin + dir * halfLen + Vector3.new(0, yOff, 0)
	linePool.body.Size = Vector3.new(MobileConfig.INDICATOR_LINE_WIDTH, 0.1, currentRange)
	linePool.body.CFrame = CFrame.lookAt(midPoint, midPoint + dir)

	-- 箭头: 在线末端
	local endPoint = currentOrigin + dir * currentRange + Vector3.new(0, yOff, 0)
	linePool.arrow.CFrame = CFrame.lookAt(endPoint, endPoint + dir)

	-- 起始圆: 在英雄脚下(圆柱需旋转90度让圆面朝上)
	local originPos = currentOrigin + Vector3.new(0, yOff, 0)
	linePool.origin.CFrame = CFrame.new(originPos) * CFrame.Angles(0, 0, math.rad(90))
end

-- ═══════════════════════════════════════
-- 公有方法
-- ═══════════════════════════════════════

--- 初始化指示器系统(创建对象池)
function SkillIndicatorManager.Init()
	-- 清除旧 Folder (防止上次运行残留的 Part 导致属性错误)
	local oldFolder = Workspace:FindFirstChild("SkillIndicators")
	if oldFolder then
		oldFolder:Destroy()
	end

	-- 创建全新 Folder
	indicatorFolder = Instance.new("Folder")
	indicatorFolder.Name = "SkillIndicators"
	indicatorFolder.Parent = Workspace

	-- 创建对象池
	linePool = createLineParts()
	circlePool = createCirclePart()
end

--- 显示 LINE 方向线指示器
function SkillIndicatorManager.ShowLine(origin, range, color)
	SkillIndicatorManager.Hide() -- 先隐藏旧的
	if not linePool then warn("[SkillIndicatorManager] ShowLine: linePool 未初始化, 请先调用 Init()"); return end

	activeType = "LINE"
	currentOrigin = origin
	currentRange = range
	currentColor = color
	currentDirection = Vector3.new(0, 0, -1) -- 默认朝前
	isInCancelState = false

	-- 设置颜色
	linePool.body.Color = color
	linePool.arrow.Color = color
	linePool.origin.Color = color
	linePool.body.Transparency = normalAlpha
	linePool.arrow.Transparency = normalAlpha
	linePool.origin.Transparency = normalAlpha

	-- 显示(恢复透明度)
	linePool.body.Transparency = normalAlpha
	linePool.arrow.Transparency = normalAlpha
	linePool.origin.Transparency = normalAlpha

	-- 初始位置
	updateLineTransform()

	-- 连接每帧更新(跟随角色移动)
	if renderConn then renderConn:Disconnect() end
	renderConn = RunService.RenderStepped:Connect(function()
		updateLineTransform()
	end)
end

--- 显示 CIRCLE_SELF 自身范围指示器(闪现式, 点按即放)
function SkillIndicatorManager.ShowCircleSelf(origin, range, color)
	SkillIndicatorManager.Hide() -- 先隐藏旧的
	if not circlePool then warn("[SkillIndicatorManager] ShowCircleSelf: circlePool 未初始化, 请先调用 Init()"); return end

	activeType = "CIRCLE_SELF"
	currentOrigin = origin
	isInCancelState = false

	-- 竞态保护: 记录当前 tween 序号, Completed 回调中检查是否过期
	circleTweenId = circleTweenId + 1
	local myTweenId = circleTweenId

	local yOff = MobileConfig.INDICATOR_Y_OFFSET
	range = math.max(range, 2) -- 最小半径保护: Range=0 时仍显示可见圆形(直径4)
	local diameter = range * 2
	local part = circlePool.part

	-- 设置属性
	part.Color = color
	part.Size = Vector3.new(0.1, diameter, diameter)
	part.CFrame = CFrame.new(origin + Vector3.new(0, yOff, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Transparency = MobileConfig.INDICATOR_CIRCLE_ALPHA
	-- part 已可见(Transparency < 1)

	-- 弹性脉冲: 0→1.05→1.0
	local flashDur = MobileConfig.INDICATOR_FLASH_DURATION
	part.Size = Vector3.new(0.1, 0, 0) -- 从零开始
	local expandTween = TweenService:Create(part, TweenInfo.new(flashDur * 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, diameter * 1.05, diameter * 1.05)
	})
	expandTween:Play()
	expandTween.Completed:Connect(function()
		if myTweenId ~= circleTweenId then return end -- 竞态保护: 已被新指示器覆盖
		-- 回弹到正常尺寸
		local settleTween = TweenService:Create(part, TweenInfo.new(flashDur * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, diameter, diameter)
		})
		settleTween:Play()
		settleTween.Completed:Connect(function()
			if myTweenId ~= circleTweenId then return end -- 竞态保护
			-- 淡出消失
			local fadeTween = TweenService:Create(part, TweenInfo.new(flashDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1
			})
			fadeTween:Play()
			fadeTween.Completed:Connect(function()
				if myTweenId ~= circleTweenId then return end -- 竞态保护
				-- Transparency 已经 tween 到 1，无需额外操作
				activeType = nil
			end)
		end)
	end)
end

--- 更新 LINE 指示器方向(每帧由 UI_SkillButtons 调用)
function SkillIndicatorManager.UpdateDirection(direction)
	if activeType ~= "LINE" then return end
	if direction and direction.Magnitude > 0 then
		currentDirection = direction.Unit
	end
end

--- 更新指示器起始点(跟随角色移动)
function SkillIndicatorManager.UpdateOrigin(origin)
	currentOrigin = origin
end

--- 切换取消态/正常态颜色
function SkillIndicatorManager.SetCancelState(isCancel)
	if activeType ~= "LINE" then return end
	if isInCancelState == isCancel then return end -- 无变化不更新
	isInCancelState = isCancel

	if isCancel then
		linePool.body.Color = cancelColor
		linePool.arrow.Color = cancelColor
		linePool.origin.Color = cancelColor
		linePool.body.Transparency = cancelAlpha
		linePool.arrow.Transparency = cancelAlpha
		linePool.origin.Transparency = cancelAlpha
	else
		linePool.body.Color = currentColor
		linePool.arrow.Color = currentColor
		linePool.origin.Color = currentColor
		linePool.body.Transparency = normalAlpha
		linePool.arrow.Transparency = normalAlpha
		linePool.origin.Transparency = normalAlpha
	end
end

--- 播放释放闪光动画 → 自动隐藏
function SkillIndicatorManager.FlashRelease()
	if not activeType then return end
	local flashDur = MobileConfig.INDICATOR_FLASH_DURATION

	if activeType == "LINE" then
		-- 白色闪光
		local whiteColor = Color3.new(1, 1, 1)
		linePool.body.Color = whiteColor
		linePool.arrow.Color = whiteColor
		linePool.origin.Color = whiteColor
		linePool.body.Transparency = 0
		linePool.arrow.Transparency = 0
		linePool.origin.Transparency = 0

		-- 淡出
		local tw1 = TweenService:Create(linePool.body, TweenInfo.new(flashDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 })
		local tw2 = TweenService:Create(linePool.arrow, TweenInfo.new(flashDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 })
		local tw3 = TweenService:Create(linePool.origin, TweenInfo.new(flashDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 })
		tw1:Play(); tw2:Play(); tw3:Play()
		tw1.Completed:Connect(function()
			SkillIndicatorManager.Hide()
		end)
	end

	-- CIRCLE_SELF 通常在 ShowCircleSelf 中自动消散，FlashRelease 不常被调用
end

--- 播放取消消散动画 → 自动隐藏
function SkillIndicatorManager.FadeCancel()
	if not activeType then return end
	local fadeDur = MobileConfig.INDICATOR_FADE_DURATION

	if activeType == "LINE" then
		local tw1 = TweenService:Create(linePool.body, TweenInfo.new(fadeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
		local tw2 = TweenService:Create(linePool.arrow, TweenInfo.new(fadeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
		local tw3 = TweenService:Create(linePool.origin, TweenInfo.new(fadeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
		tw1:Play(); tw2:Play(); tw3:Play()
		tw1.Completed:Connect(function()
			SkillIndicatorManager.Hide()
		end)
	end
end

--- 立即隐藏当前指示器(无动画)
function SkillIndicatorManager.Hide()
	-- 断开每帧更新
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end

	-- 隐藏 LINE
	if linePool then
		linePool.body.Transparency = 1
		linePool.arrow.Transparency = 1
		linePool.origin.Transparency = 1
	end

	-- 隐藏 CIRCLE_SELF
	if circlePool then
		circlePool.part.Transparency = 1
	end

	activeType = nil
	isInCancelState = false
	currentDirection = nil
	currentOrigin = nil
end

--- 销毁所有对象池和连接
function SkillIndicatorManager.Destroy()
	SkillIndicatorManager.Hide()

	if indicatorFolder then
		indicatorFolder:Destroy()
		indicatorFolder = nil
	end

	linePool = nil
	circlePool = nil
end

return SkillIndicatorManager
