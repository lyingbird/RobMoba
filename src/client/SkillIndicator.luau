--[[
    SkillIndicator.luau
    技能指示器渲染模块
    
    功能：
    - 按下技能键后，在角色脚下显示技能释放范围指示器
    - 支持 Arrow（箭头/矩形方向）、Circle（圆形AOE）、Fan（扇形）、
      Rectangle（矩形区域）、SelfCircle（自身为中心圆形）五种类型
    - 跟随鼠标方向实时更新
    - 使用 SkillIndicatorTable 的配置数据
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local SkillIndicatorTable = require(shared:WaitForChild("SkillIndicatorTable"))
local SkillTable = require(shared:WaitForChild("SkillTable"))

local SkillIndicator = {}

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

-- 当前活跃的指示器
local activeIndicator = nil -- { parts = {}, connection = RBXScriptConnection, skillKey = string }

-- 指示器 Folder
local indicatorFolder = nil

-- 地面高度
local GROUND_Y = 0.15 -- 稍微高于地面避免z-fighting

--============================================================
-- 初始化
--============================================================

function SkillIndicator.init()
    -- 创建指示器容器
    indicatorFolder = Instance.new("Folder")
    indicatorFolder.Name = "SkillIndicators"
    indicatorFolder.Parent = workspace
    
    print("[SkillIndicator] 初始化完成")
end

--============================================================
-- 显示指示器
--============================================================

-- 显示指定技能的指示器
function SkillIndicator.show(skillId: string, skillKey: string)
    -- 先清理上一个指示器
    SkillIndicator.hide()
    
    local skillData = SkillTable.getSkill(skillId)
    if not skillData or not skillData.indicatorId then return end
    
    local indicatorConfig = SkillIndicatorTable.getIndicator(skillData.indicatorId)
    if not indicatorConfig then return end
    
    -- 合并技能自定义参数
    local params = {}
    if indicatorConfig.params then
        for k, v in pairs(indicatorConfig.params) do
            params[k] = v
        end
    end
    if skillData.indicatorParams then
        for k, v in pairs(skillData.indicatorParams) do
            params[k] = v
        end
    end
    
    local indicatorType = indicatorConfig.type
    local color = indicatorConfig.color or Color3.fromRGB(100, 200, 255)
    local alpha = indicatorConfig.alpha or 0.4
    
    local parts = {}
    
    if indicatorType == "Arrow" then
        parts = SkillIndicator._createArrowIndicator(params, color, alpha)
    elseif indicatorType == "Circle" then
        parts = SkillIndicator._createCircleIndicator(params, color, alpha)
    elseif indicatorType == "Fan" then
        parts = SkillIndicator._createFanIndicator(params, color, alpha)
    elseif indicatorType == "Rectangle" then
        parts = SkillIndicator._createRectangleIndicator(params, color, alpha)
    elseif indicatorType == "SelfCircle" then
        parts = SkillIndicator._createSelfCircleIndicator(params, color, alpha)
    end
    
    if #parts == 0 then return end
    
    -- 启动更新循环
    local connection = RunService.RenderStepped:Connect(function()
        SkillIndicator._updateIndicator(indicatorType, parts, params)
    end)
    
    activeIndicator = {
        parts = parts,
        connection = connection,
        skillKey = skillKey,
        indicatorType = indicatorType,
    }
end

--============================================================
-- 隐藏指示器
--============================================================

function SkillIndicator.hide()
    if not activeIndicator then return end
    
    if activeIndicator.connection then
        activeIndicator.connection:Disconnect()
    end
    
    for _, part in ipairs(activeIndicator.parts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    
    activeIndicator = nil
end

-- 获取当前活跃指示器的技能键
function SkillIndicator.getActiveKey(): string?
    if activeIndicator then
        return activeIndicator.skillKey
    end
    return nil
end

-- 是否有活跃的指示器
function SkillIndicator.isActive(): boolean
    return activeIndicator ~= nil
end

--============================================================
-- 创建各类型指示器
--============================================================

-- 箭头/矩形方向指示器
function SkillIndicator._createArrowIndicator(params, color: Color3, alpha: number): { Instance }
    local length = params.length or 20
    local width = params.width or 2
    local parts = {}
    
    -- 主体矩形
    local body = Instance.new("Part")
    body.Name = "Indicator_Arrow_Body"
    body.Size = Vector3.new(width, 0.1, length)
    body.Anchored = true
    body.CanCollide = false
    body.Material = Enum.Material.Neon
    body.Color = color
    body.Transparency = 1 - alpha
    body.CastShadow = false
    body.Parent = indicatorFolder
    table.insert(parts, body)
    
    -- 箭头头部（如果配置了）
    if params.showArrowHead then
        local head = Instance.new("Part")
        head.Name = "Indicator_Arrow_Head"
        head.Size = Vector3.new(width * 2, 0.1, width * 1.5)
        head.Anchored = true
        head.CanCollide = false
        head.Material = Enum.Material.Neon
        head.Color = color
        head.Transparency = 1 - alpha
        head.CastShadow = false
        head.Parent = indicatorFolder
        
        -- 使用 SpecialMesh 创建锥形
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Wedge
        mesh.Scale = Vector3.new(1, 1, 1)
        mesh.Parent = head
        
        table.insert(parts, head)
    end
    
    return parts
end

-- 圆形AOE指示器
function SkillIndicator._createCircleIndicator(params, color: Color3, alpha: number): { Instance }
    local radius = params.radius or 5
    local parts = {}
    
    -- 外圈
    local outerCircle = Instance.new("Part")
    outerCircle.Name = "Indicator_Circle_Outer"
    outerCircle.Shape = Enum.PartType.Cylinder
    outerCircle.Size = Vector3.new(0.1, radius * 2, radius * 2)
    outerCircle.Anchored = true
    outerCircle.CanCollide = false
    outerCircle.Material = Enum.Material.Neon
    outerCircle.Color = color
    outerCircle.Transparency = 1 - alpha
    outerCircle.CastShadow = false
    outerCircle.Parent = indicatorFolder
    table.insert(parts, outerCircle)
    
    -- 内圈（如果有）
    local innerRadius = params.innerRadius
    if innerRadius then
        local innerCircle = Instance.new("Part")
        innerCircle.Name = "Indicator_Circle_Inner"
        innerCircle.Shape = Enum.PartType.Cylinder
        innerCircle.Size = Vector3.new(0.12, innerRadius * 2, innerRadius * 2)
        innerCircle.Anchored = true
        innerCircle.CanCollide = false
        innerCircle.Material = Enum.Material.Neon
        innerCircle.Color = params.innerColor or Color3.fromRGB(255, 50, 50)
        innerCircle.Transparency = 1 - (alpha + 0.1)
        innerCircle.CastShadow = false
        innerCircle.Parent = indicatorFolder
        table.insert(parts, innerCircle)
    end
    
    return parts
end

-- 扇形指示器
function SkillIndicator._createFanIndicator(params, color: Color3, alpha: number): { Instance }
    local range = params.range or 15
    local angle = params.angle or 30
    local parts = {}
    
    -- 用多个窄矩形近似扇形
    local segmentCount = math.max(3, math.floor(angle / 3))
    local angleStep = math.rad(angle) / segmentCount
    local startAngle = -math.rad(angle) / 2
    
    for i = 0, segmentCount do
        local seg = Instance.new("Part")
        seg.Name = "Indicator_Fan_Seg_" .. i
        seg.Size = Vector3.new(0.15, 0.1, range)
        seg.Anchored = true
        seg.CanCollide = false
        seg.Material = Enum.Material.Neon
        seg.Color = color
        seg.Transparency = 1 - alpha
        seg.CastShadow = false
        seg.Parent = indicatorFolder
        table.insert(parts, seg)
    end
    
    -- 弧形边（左右两条边线）
    local leftEdge = Instance.new("Part")
    leftEdge.Name = "Indicator_Fan_Left"
    leftEdge.Size = Vector3.new(0.2, 0.1, range)
    leftEdge.Anchored = true
    leftEdge.CanCollide = false
    leftEdge.Material = Enum.Material.Neon
    leftEdge.Color = color
    leftEdge.Transparency = 1 - alpha - 0.15
    leftEdge.CastShadow = false
    leftEdge.Parent = indicatorFolder
    table.insert(parts, leftEdge)
    
    local rightEdge = Instance.new("Part")
    rightEdge.Name = "Indicator_Fan_Right"
    rightEdge.Size = Vector3.new(0.2, 0.1, range)
    rightEdge.Anchored = true
    rightEdge.CanCollide = false
    rightEdge.Material = Enum.Material.Neon
    rightEdge.Color = color
    rightEdge.Transparency = 1 - alpha - 0.15
    rightEdge.CastShadow = false
    rightEdge.Parent = indicatorFolder
    table.insert(parts, rightEdge)
    
    return parts
end

-- 矩形区域指示器
function SkillIndicator._createRectangleIndicator(params, color: Color3, alpha: number): { Instance }
    local length = params.length or 12
    local width = params.width or 2
    local parts = {}
    
    local rect = Instance.new("Part")
    rect.Name = "Indicator_Rectangle"
    rect.Size = Vector3.new(width, 0.1, length)
    rect.Anchored = true
    rect.CanCollide = false
    rect.Material = Enum.Material.Neon
    rect.Color = color
    rect.Transparency = 1 - alpha
    rect.CastShadow = false
    rect.Parent = indicatorFolder
    table.insert(parts, rect)
    
    -- 边框效果
    local border = Instance.new("Part")
    border.Name = "Indicator_Rectangle_Border"
    border.Size = Vector3.new(width + 0.3, 0.12, length + 0.3)
    border.Anchored = true
    border.CanCollide = false
    border.Material = Enum.Material.Neon
    border.Color = color
    border.Transparency = 1 - alpha + 0.2
    border.CastShadow = false
    border.Parent = indicatorFolder
    table.insert(parts, border)
    
    return parts
end

-- 自身为中心圆形指示器
function SkillIndicator._createSelfCircleIndicator(params, color: Color3, alpha: number): { Instance }
    local radius = params.radius or 5
    local parts = {}
    
    local circle = Instance.new("Part")
    circle.Name = "Indicator_SelfCircle"
    circle.Shape = Enum.PartType.Cylinder
    circle.Size = Vector3.new(0.1, radius * 2, radius * 2)
    circle.Anchored = true
    circle.CanCollide = false
    circle.Material = Enum.Material.Neon
    circle.Color = color
    circle.Transparency = 1 - alpha
    circle.CastShadow = false
    circle.Parent = indicatorFolder
    table.insert(parts, circle)
    
    return parts
end

--============================================================
-- 更新指示器位置/朝向
--============================================================

function SkillIndicator._updateIndicator(indicatorType: string, parts: { Instance }, params)
    local character = localPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local charPos = rootPart.Position
    local flatCharPos = Vector3.new(charPos.X, GROUND_Y, charPos.Z)
    
    -- 获取鼠标射线目标位置
    local mouseRay = mouse.UnitRay
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { character, indicatorFolder }
    
    local rayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
    local hitPosition
    if rayResult then
        hitPosition = rayResult.Position
    else
        hitPosition = mouseRay.Origin + mouseRay.Direction * 200
    end
    
    -- 计算方向（平面）
    local flatOffset = Vector3.new(
        hitPosition.X - charPos.X,
        0,
        hitPosition.Z - charPos.Z
    )
    local maxRange = params.range
    if maxRange and flatOffset.Magnitude > maxRange then
        flatOffset = flatOffset.Unit * maxRange
    end

    local flatDir
    if flatOffset.Magnitude > 0.01 then
        flatDir = flatOffset.Unit
    else
        flatDir = rootPart.CFrame.LookVector
        flatDir = Vector3.new(flatDir.X, 0, flatDir.Z).Unit
    end
    
    local targetFlat = Vector3.new(
        charPos.X + flatOffset.X,
        GROUND_Y,
        charPos.Z + flatOffset.Z
    )
    
    if indicatorType == "Arrow" then
        SkillIndicator._updateArrow(parts, flatCharPos, flatDir, params)
    elseif indicatorType == "Circle" then
        SkillIndicator._updateCircle(parts, targetFlat, params)
    elseif indicatorType == "Fan" then
        SkillIndicator._updateFan(parts, flatCharPos, flatDir, params)
    elseif indicatorType == "Rectangle" then
        SkillIndicator._updateRectangle(parts, flatCharPos, flatDir, params)
    elseif indicatorType == "SelfCircle" then
        SkillIndicator._updateSelfCircle(parts, flatCharPos, params)
    end
end

function SkillIndicator._updateArrow(parts, origin: Vector3, direction: Vector3, params)
    local length = params.length or 20
    
    -- 主体：从角色前方延伸
    local body = parts[1]
    if body then
        local center = origin + direction * (length / 2)
        body.CFrame = CFrame.lookAt(center, center + direction)
    end
    
    -- 箭头头部
    if parts[2] and params.showArrowHead then
        local tipPos = origin + direction * (length + 0.5)
        parts[2].CFrame = CFrame.lookAt(tipPos, tipPos + direction)
    end
end

function SkillIndicator._updateCircle(parts, targetPos: Vector3, params)
    -- 外圈位置
    local outerCircle = parts[1]
    if outerCircle then
        outerCircle.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, 0, math.rad(90))
    end
    
    -- 内圈位置
    if parts[2] then
        parts[2].CFrame = CFrame.new(targetPos + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90))
    end
end

function SkillIndicator._updateFan(parts, origin: Vector3, direction: Vector3, params)
    local range = params.range or 15
    local angle = params.angle or 30
    
    -- 计算扇形分段
    local segmentCount = math.max(3, math.floor(angle / 3))
    local angleStep = math.rad(angle) / segmentCount
    local startAngle = -math.rad(angle) / 2
    local baseAngle = math.atan2(direction.X, direction.Z)
    
    for i = 0, segmentCount do
        local seg = parts[i + 1]
        if not seg then break end
        
        local segAngle = baseAngle + startAngle + angleStep * i
        local segDir = Vector3.new(math.sin(segAngle), 0, math.cos(segAngle))
        local segCenter = origin + segDir * (range / 2)
        seg.CFrame = CFrame.lookAt(segCenter, segCenter + segDir)
    end
    
    -- 左右边线
    local leftEdge = parts[segmentCount + 2]
    local rightEdge = parts[segmentCount + 3]
    
    if leftEdge then
        local leftAngle = baseAngle + startAngle
        local leftDir = Vector3.new(math.sin(leftAngle), 0, math.cos(leftAngle))
        local leftCenter = origin + leftDir * (range / 2)
        leftEdge.CFrame = CFrame.lookAt(leftCenter, leftCenter + leftDir)
    end
    
    if rightEdge then
        local rightAngle = baseAngle - startAngle
        local rightDir = Vector3.new(math.sin(rightAngle), 0, math.cos(rightAngle))
        local rightCenter = origin + rightDir * (range / 2)
        rightEdge.CFrame = CFrame.lookAt(rightCenter, rightCenter + rightDir)
    end
end

function SkillIndicator._updateRectangle(parts, origin: Vector3, direction: Vector3, params)
    local length = params.length or 12
    
    local center = origin + direction * (length / 2)
    local cframe = CFrame.lookAt(center, center + direction)
    
    if parts[1] then
        parts[1].CFrame = cframe
    end
    if parts[2] then
        parts[2].CFrame = cframe + Vector3.new(0, -0.01, 0)
    end
end

function SkillIndicator._updateSelfCircle(parts, origin: Vector3, params)
    if parts[1] then
        parts[1].CFrame = CFrame.new(origin) * CFrame.Angles(0, 0, math.rad(90))
    end
end

return SkillIndicator
