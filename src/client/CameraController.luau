--[[
    CameraController.luau
    LOL 风格固定俯视角摄像机

    功能：
    - 固定角度俯视（45° 俯角，不可旋转）
    - 摄像机平滑跟随角色平移
    - 鼠标光标始终可见且自由移动（用于瞄准/点击）
    - 鼠标不旋转视角
    - 支持滚轮缩放（可选范围限制）
    - 提供 CameraShake 接口（保持固定角度的同时抖动）
    - 屏幕边缘滚屏（鼠标靠近屏幕边缘时平移摄像机，可选）
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ============================================================
-- 配置
-- ============================================================

local DEFAULT_HEIGHT = 40        -- 摄像机距地面高度
local DEFAULT_DISTANCE = 30      -- 摄像机后方偏移距离
local PITCH_ANGLE = -55          -- 俯仰角（度），-90 是正上方，-45 是 45° 俯视
local FOLLOW_SPEED = 10          -- 摄像机跟随平滑速度

-- 缩放
local MIN_ZOOM = 20              -- 最近缩放
local MAX_ZOOM = 70              -- 最远缩放
local ZOOM_SPEED = 5             -- 每次滚轮缩放量
local currentZoom = DEFAULT_HEIGHT

-- 屏幕边缘滚屏
local EDGE_SCROLL_ENABLED = true
local EDGE_SCROLL_BORDER = 20     -- 边缘像素宽度
local EDGE_SCROLL_SPEED = 40      -- 滚屏速度（studs/秒）
local cameraOffset = Vector3.zero  -- 摄像机相对角色的额外偏移

-- 抖动
local shakeOffset = Vector3.zero
local isShaking = false

-- 内部状态
local isInitialized = false
local updateConnection = nil

-- ============================================================
-- 初始化
-- ============================================================

function CameraController.init()
    if isInitialized then return end
    isInitialized = true

    -- 设置摄像机为 Scriptable（完全手动控制）
    camera.CameraType = Enum.CameraType.Scriptable

    -- 鼠标光标始终可见
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true

    -- 监听滚轮缩放
    UserInputService.InputChanged:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            currentZoom = math.clamp(currentZoom - input.Position.Z * ZOOM_SPEED, MIN_ZOOM, MAX_ZOOM)
        end
    end)

    -- 每帧更新摄像机
    updateConnection = RunService.RenderStepped:Connect(function(dt)
        CameraController._update(dt)
    end)

    -- 角色重生时重置偏移
    localPlayer.CharacterAdded:Connect(function()
        cameraOffset = Vector3.zero
    end)

    -- 如果当前角色已存在，立即定位
    if localPlayer.Character then
        cameraOffset = Vector3.zero
        CameraController._snapToCharacter()
    end

    print("[CameraController] LOL 固定俯视角摄像机初始化完成")
end

-- ============================================================
-- 每帧更新
-- ============================================================

function CameraController._update(dt)
    -- 确保摄像机模式正确
    if camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end

    -- 确保鼠标行为正确（防止被其他系统覆盖）
    if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end

    -- 获取角色位置
    local character = localPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- 屏幕边缘滚屏
    if EDGE_SCROLL_ENABLED then
        CameraController._handleEdgeScroll(dt)
    end

    -- 计算目标摄像机位置
    local characterPos = rootPart.Position
    local targetFocusPoint = characterPos + cameraOffset

    -- 计算摄像机偏移（固定角度）
    local pitchRad = math.rad(PITCH_ANGLE)
    -- 摄像机在目标点的后上方
    local cameraOffsetVec = Vector3.new(0, math.sin(-pitchRad) * currentZoom, math.cos(-pitchRad) * currentZoom)
    local targetCameraPos = targetFocusPoint + cameraOffsetVec

    -- 平滑插值
    local alpha = math.clamp(FOLLOW_SPEED * dt, 0, 1)
    local currentPos = camera.CFrame.Position
    local smoothedPos = currentPos:Lerp(targetCameraPos, alpha)

    -- 加上抖动偏移
    local finalPos = smoothedPos + shakeOffset

    -- 摄像机始终看向焦点（角色位置 + 偏移）
    local smoothedFocus = currentPos:Lerp(targetFocusPoint, alpha)
    -- 使用插值后的焦点，保持朝向一致
    local lookTarget = smoothedFocus + (targetFocusPoint - targetCameraPos).Unit * 10
    -- 更简洁：直接 lookAt 焦点
    camera.CFrame = CFrame.lookAt(finalPos, targetFocusPoint + shakeOffset * 0.5)
end

-- ============================================================
-- 直接对齐（无插值）
-- ============================================================

function CameraController._snapToCharacter()
    local character = localPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    local characterPos = rootPart.Position
    local targetFocusPoint = characterPos + cameraOffset

    local pitchRad = math.rad(PITCH_ANGLE)
    local cameraOffsetVec = Vector3.new(0, math.sin(-pitchRad) * currentZoom, math.cos(-pitchRad) * currentZoom)
    local targetCameraPos = targetFocusPoint + cameraOffsetVec

    camera.CFrame = CFrame.lookAt(targetCameraPos, targetFocusPoint)
end

-- ============================================================
-- 屏幕边缘滚屏
-- ============================================================

function CameraController._handleEdgeScroll(dt)
    local mousePos = UserInputService:GetMouseLocation()
    local viewportSize = camera.ViewportSize

    local scrollDir = Vector3.zero

    if mousePos.X <= EDGE_SCROLL_BORDER then
        scrollDir = scrollDir + Vector3.new(-1, 0, 0)
    elseif mousePos.X >= viewportSize.X - EDGE_SCROLL_BORDER then
        scrollDir = scrollDir + Vector3.new(1, 0, 0)
    end

    if mousePos.Y <= EDGE_SCROLL_BORDER then
        scrollDir = scrollDir + Vector3.new(0, 0, -1)
    elseif mousePos.Y >= viewportSize.Y - EDGE_SCROLL_BORDER then
        scrollDir = scrollDir + Vector3.new(0, 0, 1)
    end

    if scrollDir.Magnitude > 0 then
        cameraOffset = cameraOffset + scrollDir.Unit * EDGE_SCROLL_SPEED * dt
        -- 限制偏移范围（不要偏太远）
        local maxOffset = 60
        if cameraOffset.Magnitude > maxOffset then
            cameraOffset = cameraOffset.Unit * maxOffset
        end
    end

    -- 空格键回中（LOL 的空格键锁定镜头功能简化版）
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        cameraOffset = cameraOffset:Lerp(Vector3.zero, math.clamp(10 * dt, 0, 1))
    end
end

-- ============================================================
-- 摄像机抖动（供外部调用）
-- ============================================================

function CameraController.shake(intensity: number, duration: number)
    if isShaking then return end  -- 不叠加抖动
    isShaking = true

    task.spawn(function()
        local elapsed = 0
        while elapsed < duration do
            local dt = task.wait()
            elapsed += dt
            local progress = 1 - (elapsed / duration)
            local shakeX = (math.random() - 0.5) * 2 * intensity * progress
            local shakeY = (math.random() - 0.5) * 2 * intensity * progress
            local shakeZ = (math.random() - 0.5) * intensity * progress * 0.5
            shakeOffset = Vector3.new(shakeX, shakeY, shakeZ)
        end

        shakeOffset = Vector3.zero
        isShaking = false
    end)
end

-- ============================================================
-- 查询接口
-- ============================================================

-- 获取当前摄像机焦点（角色位置 + 偏移）
function CameraController.getFocusPosition(): Vector3
    local character = localPlayer.Character
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            return rootPart.Position + cameraOffset
        end
    end
    return camera.CFrame.Position
end

-- 获取当前缩放级别
function CameraController.getZoom(): number
    return currentZoom
end

-- 设置缩放
function CameraController.setZoom(zoom: number)
    currentZoom = math.clamp(zoom, MIN_ZOOM, MAX_ZOOM)
end

-- 重置摄像机偏移（回中）
function CameraController.resetOffset()
    cameraOffset = Vector3.zero
end

return CameraController
