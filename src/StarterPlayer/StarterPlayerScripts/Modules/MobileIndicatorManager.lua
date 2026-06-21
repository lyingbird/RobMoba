--[[
	MobileIndicatorManager.lua
	移动端技能指示器渲染管理器 (REQ-026)

	功能:
	- ViewportFrame + 3D Part 渲染6种指示器(line/rect/circle_drop/sector/self_circle/target_lock)
	- ScreenGui DisplayOrder = 5 (低于MobileUI 10, 低于CancelZone 15)
	- Camera 每帧同步 workspace.CurrentCamera
	- Show/Hide/UpdateDirection/UpdatePosition/SetCancelMode

	架构:
	- ScreenGui → ViewportFrame(全屏, 透明背景) → Camera + 各指示器Part
	- 指示器Part: 用于显示的放入 ViewportFrame, 隐藏的放入 hiddenFolder
	- RenderStepped 同步摄像机
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local MobileConfig = require(script.Parent.MobileConfig)

local MobileIndicatorManager = {}

-- ═══════════════════════════════════════
-- 内部状态
-- ═══════════════════════════════════════
local screenGui: ScreenGui? = nil
local viewportFrame: ViewportFrame? = nil
local vpCamera: Camera? = nil
local hiddenFolder: Folder? = nil      -- 隐藏的Part存放处
local character: Model? = nil
local rootPart: BasePart? = nil

local renderConnection: RBXScriptConnection? = nil

-- 当前指示器状态
local currentAimType: string? = nil
local currentConfig: table? = nil
local isCancelMode = false

-- 指示器Part缓存 { [aimType] = { parts... } }
local indicatorParts = {}

-- ═══════════════════════════════════════
-- Part创建辅助
-- ═══════════════════════════════════════

local function makePart(name: string, size: Vector3, color: Color3, transparency: number, shape: string?): BasePart
	local part
	if shape == "Cylinder" then
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Ball" then
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Ball
	else
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Block
	end
	part.Name = name
	part.Size = size
	part.Color = color
	part.Transparency = transparency
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = hiddenFolder  -- 默认隐藏
	return part
end

--- 创建射程环(圆形边框)
local function makeRangeRing(range: number): BasePart
	-- 用扁平圆柱模拟环
	local ring = makePart("RangeRing",
		Vector3.new(0.15, range * 2, range * 2),  -- Cylinder: X=height, Y=diameter, Z=diameter
		MobileConfig.INDICATOR_RANGE_RING_COLOR,
		MobileConfig.INDICATOR_RANGE_RING_ALPHA,
		"Cylinder"
	)
	return ring
end

--- 创建原点圆(角色脚下小圆)
local function makeOriginCircle(): BasePart
	local circle = makePart("OriginCircle",
		Vector3.new(0.1, 2, 2),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_FILL_ALPHA,
		"Cylinder"
	)
	return circle
end

-- ═══════════════════════════════════════
-- 各类型指示器创建
-- ═══════════════════════════════════════

--- line 指示器: FillPart(长条) + OriginCircle + RangeRing + ArrowHead
local function createLineIndicator()
	local parts = {}
	-- 主体(长条)
	parts.fill = makePart("LineFill",
		Vector3.new(3, 0.15, 40),  -- width, height, length(占位, 运行时更新)
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_FILL_ALPHA
	)
	-- 箭头(小三角用Part代替)
	parts.arrowHead = makePart("ArrowHead",
		Vector3.new(4, 0.15, 2),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_BORDER_ALPHA
	)
	-- 左边框
	parts.leftBorder = makePart("LeftBorder",
		Vector3.new(0.3, 0.2, 40),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_BORDER_ALPHA
	)
	-- 右边框
	parts.rightBorder = makePart("RightBorder",
		Vector3.new(0.3, 0.2, 40),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_BORDER_ALPHA
	)
	-- 原点圆
	parts.originCircle = makeOriginCircle()
	-- 射程环
	parts.rangeRing = makeRangeRing(40)
	return parts
end

--- rect 指示器: 类似line但更宽, 有独立宽度
local function createRectIndicator()
	local parts = {}
	parts.fill = makePart("RectFill",
		Vector3.new(6, 0.15, 40),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_FILL_ALPHA
	)
	parts.leftBorder = makePart("LeftBorder",
		Vector3.new(0.3, 0.2, 40),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_BORDER_ALPHA
	)
	parts.rightBorder = makePart("RightBorder",
		Vector3.new(0.3, 0.2, 40),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_BORDER_ALPHA
	)
	parts.originCircle = makeOriginCircle()
	parts.rangeRing = makeRangeRing(40)
	return parts
end

--- circle_drop 指示器: FillCircle(落点圆) + EdgeRing + RangeRing
local function createCircleDropIndicator()
	local parts = {}
	-- 落点圆(扁平圆柱)
	parts.fillCircle = makePart("FillCircle",
		Vector3.new(0.15, 20, 20),  -- 占位, 运行时用AreaRadius更新
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_FILL_ALPHA,
		"Cylinder"
	)
	-- 边缘环
	parts.edgeRing = makePart("EdgeRing",
		Vector3.new(0.2, 22, 22),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_BORDER_ALPHA,
		"Cylinder"
	)
	-- 射程环(以角色为中心)
	parts.rangeRing = makeRangeRing(40)
	return parts
end

--- sector 指示器: 用多个WedgePart拼成扇形(每15°一个) + OriginCircle + RangeRing
local function createSectorIndicator()
	local parts = {}
	-- 预创建最多24个WedgePart(360°/15°=24, 实际使用按sectorAngle裁剪)
	parts.wedges = {}
	for i = 1, 24 do
		local wedge = Instance.new("Part")
		wedge.Name = "Wedge_" .. i
		wedge.Shape = Enum.PartType.Block  -- 用窄Part模拟
		wedge.Size = Vector3.new(0.5, 0.15, 10)
		wedge.Color = MobileConfig.INDICATOR_NORMAL_COLOR
		wedge.Transparency = MobileConfig.INDICATOR_FILL_ALPHA
		wedge.Material = Enum.Material.Neon
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CastShadow = false
		wedge.Parent = hiddenFolder
		parts.wedges[i] = wedge
	end
	parts.originCircle = makeOriginCircle()
	parts.rangeRing = makeRangeRing(40)
	return parts
end

--- self_circle 指示器: FillCircle(自身脚下) + EdgeRing
local function createSelfCircleIndicator()
	local parts = {}
	parts.fillCircle = makePart("SelfFill",
		Vector3.new(0.15, 10, 10),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_FILL_ALPHA,
		"Cylinder"
	)
	parts.edgeRing = makePart("SelfEdge",
		Vector3.new(0.2, 12, 12),
		MobileConfig.INDICATOR_NORMAL_COLOR,
		MobileConfig.INDICATOR_BORDER_ALPHA,
		"Cylinder"
	)
	return parts
end

-- ═══════════════════════════════════════
-- 显示/隐藏 Part (Parent切换)
-- ═══════════════════════════════════════

local function showParts(parts: table)
	if not viewportFrame then return end
	for key, val in pairs(parts) do
		if key == "wedges" then
			-- wedges 是数组
			for _, wedge in ipairs(val) do
				wedge.Parent = viewportFrame
			end
		elseif typeof(val) == "Instance" then
			val.Parent = viewportFrame
		end
	end
end

local function hideParts(parts: table)
	if not hiddenFolder then return end
	for key, val in pairs(parts) do
		if key == "wedges" then
			for _, wedge in ipairs(val) do
				wedge.Parent = hiddenFolder
			end
		elseif typeof(val) == "Instance" then
			val.Parent = hiddenFolder
		end
	end
end

--- 设置Parts颜色
local function setPartsColor(parts: table, color: Color3)
	for key, val in pairs(parts) do
		if key == "wedges" then
			for _, wedge in ipairs(val) do
				wedge.Color = color
			end
		elseif key == "rangeRing" then
			-- 射程环保持白色不变
		elseif typeof(val) == "Instance" and val:IsA("BasePart") then
			val.Color = color
		end
	end
end

-- ═══════════════════════════════════════
-- 指示器位置/方向更新
-- ═══════════════════════════════════════

--- 更新line/rect指示器
local function updateDirectionalIndicator(parts: table, worldDir: Vector3, range: number, width: number)
	if not rootPart then return end

	local origin = rootPart.Position + Vector3.new(0, 0.2, 0)  -- 略高于地面
	local dir = Vector3.new(worldDir.X, 0, worldDir.Z)
	if dir.Magnitude < 0.001 then return end
	dir = dir.Unit

	local halfLen = range / 2
	local center = origin + dir * halfLen

	-- 主体填充
	if parts.fill then
		parts.fill.Size = Vector3.new(width, 0.15, range)
		parts.fill.CFrame = CFrame.lookAt(center, center + dir) * CFrame.new(0, 0, 0)
	end

	-- 箭头
	if parts.arrowHead then
		local arrowPos = origin + dir * range
		parts.arrowHead.Size = Vector3.new(width + 1, 0.15, 2)
		parts.arrowHead.CFrame = CFrame.lookAt(arrowPos, arrowPos + dir)
	end

	-- 左右边框
	local halfWidth = width / 2
	local rightVec = dir:Cross(Vector3.new(0, 1, 0)).Unit
	if parts.leftBorder then
		local leftCenter = center - rightVec * halfWidth
		parts.leftBorder.Size = Vector3.new(0.3, 0.2, range)
		parts.leftBorder.CFrame = CFrame.lookAt(leftCenter, leftCenter + dir)
	end
	if parts.rightBorder then
		local rightCenter = center + rightVec * halfWidth
		parts.rightBorder.Size = Vector3.new(0.3, 0.2, range)
		parts.rightBorder.CFrame = CFrame.lookAt(rightCenter, rightCenter + dir)
	end

	-- 原点圆
	if parts.originCircle then
		parts.originCircle.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- 射程环
	if parts.rangeRing then
		local ringDiameter = range * 2
		parts.rangeRing.Size = Vector3.new(0.15, ringDiameter, ringDiameter)
		parts.rangeRing.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	end
end

--- 更新circle_drop指示器
local function updateCircleDropIndicator(parts: table, worldPos: Vector3, areaRadius: number, range: number)
	if not rootPart then return end

	local origin = rootPart.Position + Vector3.new(0, 0.2, 0)
	local dropPos = Vector3.new(worldPos.X, origin.Y, worldPos.Z)

	-- 限制在射程内
	local offset = dropPos - origin
	if offset.Magnitude > range then
		dropPos = origin + offset.Unit * range
	end

	-- 落点圆
	local diameter = areaRadius * 2
	if parts.fillCircle then
		parts.fillCircle.Size = Vector3.new(0.15, diameter, diameter)
		parts.fillCircle.CFrame = CFrame.new(dropPos) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- 边缘环(略大)
	if parts.edgeRing then
		parts.edgeRing.Size = Vector3.new(0.2, diameter + 1, diameter + 1)
		parts.edgeRing.CFrame = CFrame.new(dropPos) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- 射程环(以角色为中心)
	if parts.rangeRing then
		local ringDiameter = range * 2
		parts.rangeRing.Size = Vector3.new(0.15, ringDiameter, ringDiameter)
		parts.rangeRing.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	end
end

--- 更新sector指示器
local function updateSectorIndicator(parts: table, worldDir: Vector3, range: number, sectorAngle: number)
	if not rootPart then return end

	local origin = rootPart.Position + Vector3.new(0, 0.2, 0)
	local dir = Vector3.new(worldDir.X, 0, worldDir.Z)
	if dir.Magnitude < 0.001 then return end
	dir = dir.Unit

	local baseAngle = math.atan2(dir.X, -dir.Z)  -- 世界Y轴旋转角
	local stepAngle = 15  -- 每个Part 15度
	local halfAngle = sectorAngle / 2
	local wedgeCount = math.ceil(sectorAngle / stepAngle)

	for i, wedge in ipairs(parts.wedges) do
		if i <= wedgeCount then
			local angleOffset = -halfAngle + (i - 0.5) * stepAngle
			local rad = baseAngle + math.rad(angleOffset)
			local wedgeDir = Vector3.new(math.sin(rad), 0, -math.cos(rad))
			local wedgeCenter = origin + wedgeDir * (range / 2)
			wedge.Size = Vector3.new(range * math.sin(math.rad(stepAngle / 2)) * 2, 0.15, range / 2)
			wedge.CFrame = CFrame.lookAt(wedgeCenter, wedgeCenter + wedgeDir)
			wedge.Parent = viewportFrame
		else
			wedge.Parent = hiddenFolder
		end
	end

	-- 原点圆
	if parts.originCircle then
		parts.originCircle.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	end

	-- 射程环
	if parts.rangeRing then
		local ringDiameter = range * 2
		parts.rangeRing.Size = Vector3.new(0.15, ringDiameter, ringDiameter)
		parts.rangeRing.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	end
end

--- 更新self_circle指示器
local function updateSelfCircleIndicator(parts: table, areaRadius: number)
	if not rootPart then return end

	local origin = rootPart.Position + Vector3.new(0, 0.2, 0)
	local diameter = areaRadius * 2

	if parts.fillCircle then
		parts.fillCircle.Size = Vector3.new(0.15, diameter, diameter)
		parts.fillCircle.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	end

	if parts.edgeRing then
		parts.edgeRing.Size = Vector3.new(0.2, diameter + 1, diameter + 1)
		parts.edgeRing.CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
	end
end

-- ═══════════════════════════════════════
-- 摄像机同步
-- ═══════════════════════════════════════

local function startCameraSync()
	if renderConnection then return end

	renderConnection = RunService.RenderStepped:Connect(function()
		if not vpCamera or not viewportFrame then return end
		local cam = workspace.CurrentCamera
		if cam then
			vpCamera.CFrame = cam.CFrame
			vpCamera.FieldOfView = cam.FieldOfView
		end

		-- self_circle 持续跟随角色
		if currentAimType == "self_circle" and rootPart and indicatorParts["self_circle"] then
			updateSelfCircleIndicator(indicatorParts["self_circle"], currentConfig and currentConfig.AreaRadius or 5)
		end
	end)
end

local function stopCameraSync()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

-- ═══════════════════════════════════════
-- 公共接口
-- ═══════════════════════════════════════

--- 初始化
--- @param char Model - 玩家角色
function MobileIndicatorManager.Init(char: Model)
	character = char
	rootPart = char:FindFirstChild("HumanoidRootPart")

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- 创建 ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "IndicatorGui"
	screenGui.DisplayOrder = MobileConfig.INDICATOR_GUI_DISPLAY_ORDER
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- 创建 ViewportFrame (全屏, 透明背景)
	viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "IndicatorViewport"
	viewportFrame.Size = UDim2.new(1, 0, 1, 0)
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.ImageTransparency = 0
	viewportFrame.LightColor = Color3.new(1, 1, 1)
	viewportFrame.LightDirection = Vector3.new(0, -1, 0)
	viewportFrame.Ambient = Color3.new(1, 1, 1)
	viewportFrame.Parent = screenGui

	-- 创建 Camera
	vpCamera = Instance.new("Camera")
	vpCamera.Name = "IndicatorCamera"
	vpCamera.Parent = viewportFrame
	viewportFrame.CurrentCamera = vpCamera

	-- 隐藏文件夹(不在ViewportFrame内的Part不会渲染)
	hiddenFolder = Instance.new("Folder")
	hiddenFolder.Name = "HiddenParts"
	hiddenFolder.Parent = screenGui  -- 放ScreenGui下但不在ViewportFrame内

	-- 预创建所有类型指示器Part
	indicatorParts["line"] = createLineIndicator()
	indicatorParts["rect"] = createRectIndicator()
	indicatorParts["circle_drop"] = createCircleDropIndicator()
	indicatorParts["sector"] = createSectorIndicator()
	indicatorParts["self_circle"] = createSelfCircleIndicator()

	-- 启动摄像机同步
	startCameraSync()
end

--- 显示指定类型的指示器
--- @param aimType string - "line"|"rect"|"circle_drop"|"sector"|"self_circle"
--- @param config table - {Range, AreaRadius?, indicatorWidth?, sectorAngle?}
function MobileIndicatorManager.ShowIndicator(aimType: string, config: table)
	-- 先隐藏当前
	MobileIndicatorManager.HideIndicator()

	currentAimType = aimType
	currentConfig = config
	isCancelMode = false

	local parts = indicatorParts[aimType]
	if not parts then return end

	-- 设置初始颜色
	setPartsColor(parts, MobileConfig.INDICATOR_NORMAL_COLOR)

	-- 显示Part
	showParts(parts)

	-- 初始位置更新
	if aimType == "line" then
		local width = config.indicatorWidth or MobileConfig.INDICATOR_LINE_DEFAULT_WIDTH
		-- 默认朝前
		local dir = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, -1)
		updateDirectionalIndicator(parts, dir, config.Range or 40, width)
	elseif aimType == "rect" then
		local width = config.indicatorWidth or 6
		local dir = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, -1)
		updateDirectionalIndicator(parts, dir, config.Range or 40, width)
	elseif aimType == "circle_drop" then
		local pos = rootPart and rootPart.Position or Vector3.zero
		updateCircleDropIndicator(parts, pos, config.AreaRadius or config.Radius or 10, config.Range or 40)
	elseif aimType == "sector" then
		local dir = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, -1)
		updateSectorIndicator(parts, dir, config.Range or 40, config.sectorAngle or 60)
	elseif aimType == "self_circle" then
		updateSelfCircleIndicator(parts, config.AreaRadius or config.Radius or config.Range or 5)
	end
end

--- 隐藏当前指示器
function MobileIndicatorManager.HideIndicator()
	if currentAimType and indicatorParts[currentAimType] then
		hideParts(indicatorParts[currentAimType])
	end
	currentAimType = nil
	currentConfig = nil
	isCancelMode = false
end

--- 更新方向型指示器的朝向 (line/rect/sector)
--- @param worldDir Vector3 - 世界方向
function MobileIndicatorManager.UpdateDirection(worldDir: Vector3)
	if not currentAimType or not currentConfig then return end
	local parts = indicatorParts[currentAimType]
	if not parts then return end

	if currentAimType == "line" then
		local width = currentConfig.indicatorWidth or MobileConfig.INDICATOR_LINE_DEFAULT_WIDTH
		updateDirectionalIndicator(parts, worldDir, currentConfig.Range or 40, width)
	elseif currentAimType == "rect" then
		local width = currentConfig.indicatorWidth or 6
		updateDirectionalIndicator(parts, worldDir, currentConfig.Range or 40, width)
	elseif currentAimType == "sector" then
		updateSectorIndicator(parts, worldDir, currentConfig.Range or 40, currentConfig.sectorAngle or 60)
	end
end

--- 更新位置型指示器的落点 (circle_drop)
--- @param worldPos Vector3 - 世界坐标
function MobileIndicatorManager.UpdatePosition(worldPos: Vector3)
	if currentAimType ~= "circle_drop" or not currentConfig then return end
	local parts = indicatorParts["circle_drop"]
	if not parts then return end

	updateCircleDropIndicator(parts, worldPos, currentConfig.AreaRadius or currentConfig.Radius or 10, currentConfig.Range or 40)
end

--- 设置取消模式(变红/恢复)
--- @param isCancel boolean
function MobileIndicatorManager.SetCancelMode(isCancel: boolean)
	if isCancelMode == isCancel then return end
	isCancelMode = isCancel

	if not currentAimType then return end
	local parts = indicatorParts[currentAimType]
	if not parts then return end

	local color = isCancel
		and MobileConfig.INDICATOR_CANCEL_COLOR
		or MobileConfig.INDICATOR_NORMAL_COLOR
	setPartsColor(parts, color)
end

--- 销毁
function MobileIndicatorManager.Destroy()
	stopCameraSync()

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	viewportFrame = nil
	vpCamera = nil
	hiddenFolder = nil
	character = nil
	rootPart = nil
	indicatorParts = {}
	currentAimType = nil
	currentConfig = nil
	isCancelMode = false
end

return MobileIndicatorManager
