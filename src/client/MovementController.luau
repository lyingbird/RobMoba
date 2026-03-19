--[[
    MovementController.luau
    LOL 风格鼠标右键点击移动控制器
    
    功能：
    - 禁用 Roblox 默认 WASD 移动
    - 右键点击地面 → 角色自动寻路到目标位置
    - 显示移动目标指示器（地面绿色光圈）
    - 支持按住右键持续更新目标位置（拖拽移动）
    - 施法期间（ForbidMove 状态）自动暂停移动
    - 角色面朝移动方向
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local MovementController = {}

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

-- 移动状态
local moveTarget = nil         -- 当前移动目标位置 (Vector3)
local isMoving = false         -- 是否正在移动
local isRightHeld = false      -- 右键是否按住
local moveConnection = nil     -- Heartbeat 连接
local moveSpeed = nil          -- 缓存 WalkSpeed（从 Humanoid 读取）

-- 移动指示器
local moveIndicator = nil
local indicatorFadeThread = nil

-- 配置
local INDICATOR_DURATION = 0.6  -- 指示器显示时长
local STOP_THRESHOLD = 1.5      -- 到达目标的距离阈值
local GROUND_RAYCAST_DIST = 1000

--============================================================
-- 初始化
--============================================================

function MovementController.init()
    -- 禁用 Roblox 默认 WASD 移动
    MovementController._disableDefaultMovement()
    
    -- 创建移动指示器
    MovementController._createIndicator()
    
    -- 监听右键按下
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            isRightHeld = true
            MovementController._onRightClick()
        end
    end)
    
    -- 监听右键松开
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            isRightHeld = false
        end
    end)
    
    -- 持续移动更新
    moveConnection = RunService.Heartbeat:Connect(function(dt)
        MovementController._updateMovement(dt)
    end)
    
    -- 角色重生时重置
    localPlayer.CharacterAdded:Connect(function(character)
        moveTarget = nil
        isMoving = false
        -- 重新禁用默认移动（新角色需要重新处理）
        task.wait(0.5)
        MovementController._disableDefaultMovement()
    end)
    
    -- 处理当前角色
    if localPlayer.Character then
        task.spawn(function()
            task.wait(0.1)
            MovementController._disableDefaultMovement()
        end)
    end
    
    print("[MovementController] LOL风格移动系统初始化完成")
end

--============================================================
-- 禁用默认移动
--============================================================

function MovementController._disableDefaultMovement()
    -- 方案1：设置移动模式为 Scriptable（禁用 PlayerModule 的 WASD 处理）
    pcall(function()
        localPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
        localPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
    end)
    
    -- 方案2：用 ContextActionService 拦截方向键和 A/S/D
    -- 注意：不拦截 W 键，因为 InputHandler 需要监听 W 作为技能键
    -- Q/E/R 也不在默认移动键中，不需要拦截
    local function sinkAction(_actionName, _inputState, _inputObj)
        return Enum.ContextActionResult.Sink
    end
    
    ContextActionService:BindAction(
        "DisableMovementKeys",
        sinkAction,
        false,
        Enum.KeyCode.A,
        Enum.KeyCode.S,
        Enum.KeyCode.D,
        Enum.KeyCode.Up,
        Enum.KeyCode.Down,
        Enum.KeyCode.Left,
        Enum.KeyCode.Right
    )
    
    -- 方案3：获取 PlayerModule 并禁用其 controls
    task.spawn(function()
        local playerScripts = localPlayer:WaitForChild("PlayerScripts", 5)
        if not playerScripts then return end
        
        local playerModule = playerScripts:WaitForChild("PlayerModule", 5)
        if not playerModule then return end
        
        local success, result = pcall(function()
            local pm = require(playerModule)
            local controls = pm:GetControls()
            if controls and controls.Disable then
                controls:Disable()
            end
        end)
        
        if success then
            print("[MovementController] PlayerModule controls 已禁用")
        else
            print("[MovementController] PlayerModule 禁用失败(非致命): " .. tostring(result))
        end
    end)
    
    -- 确保角色不自动旋转（我们手动控制朝向）
    local character = localPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = false
        end
    end
end

--============================================================
-- 右键点击处理
--============================================================

function MovementController._onRightClick()
    local character = localPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    -- 获取鼠标射线位置（地面）
    local groundPos = MovementController._getGroundPosition()
    if not groundPos then return end
    
    -- 设置移动目标
    moveTarget = groundPos
    isMoving = true
    moveSpeed = humanoid.WalkSpeed
    
    -- 显示指示器
    MovementController._showIndicator(groundPos)
end

--============================================================
-- 移动更新（每帧）
--============================================================

function MovementController._updateMovement(dt)
    -- 右键按住时持续更新目标
    if isRightHeld then
        local groundPos = MovementController._getGroundPosition()
        if groundPos then
            moveTarget = groundPos
            isMoving = true
            -- 更新指示器位置
            if moveIndicator and moveIndicator.Parent then
                moveIndicator.Position = Vector3.new(groundPos.X, groundPos.Y + 0.15, groundPos.Z)
            end
        end
    end
    
    if not isMoving or not moveTarget then return end
    
    local character = localPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        isMoving = false
        return
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    -- 检查是否被禁止移动（WalkSpeed == 0 通常意味着施法/控制中）
    if humanoid.WalkSpeed <= 0 then
        -- 不清除 moveTarget，等 WalkSpeed 恢复后继续移动
        humanoid:Move(Vector3.zero)
        return
    end
    
    -- 计算到目标的方向（平面）
    local currentPos = rootPart.Position
    local targetFlat = Vector3.new(moveTarget.X, currentPos.Y, moveTarget.Z)
    local delta = targetFlat - currentPos
    local dist = delta.Magnitude
    
    if dist < STOP_THRESHOLD then
        -- 到达目标
        isMoving = false
        moveTarget = nil
        humanoid:Move(Vector3.zero)
        return
    end
    
    -- 移动方向（归一化，平面）
    local moveDir = Vector3.new(delta.X, 0, delta.Z).Unit
    
    -- 使用 Humanoid:Move 驱动移动（服务端兼容）
    humanoid:Move(moveDir)
    
    -- 手动旋转角色朝向移动方向（使用 CFrame 旋转分量，保持位置由物理驱动）
    local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + moveDir * 10)
    rootPart.CFrame = CFrame.new(rootPart.Position) * targetCFrame.Rotation
end

--============================================================
-- 获取地面位置
--============================================================

function MovementController._getGroundPosition(): Vector3?
    local character = localPlayer.Character
    if not character then return nil end
    
    local mouseRay = mouse.UnitRay
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { character }
    
    local rayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * GROUND_RAYCAST_DIST, raycastParams)
    if rayResult then
        return rayResult.Position
    end
    
    -- 如果没射到任何东西，用地面平面计算交点
    local origin = mouseRay.Origin
    local dir = mouseRay.Direction
    if dir.Y ~= 0 then
        local t = -origin.Y / dir.Y
        if t > 0 then
            return origin + dir * t
        end
    end
    
    return nil
end

--============================================================
-- 移动目标指示器
--============================================================

function MovementController._createIndicator()
    local part = Instance.new("Part")
    part.Name = "MoveIndicator"
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.1, 1.6, 1.6)
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(80, 255, 120)
    part.Transparency = 1  -- 初始不可见
    part.CastShadow = false
    part.Parent = workspace
    
    -- 旋转为水平（圆柱体默认是竖直的，绕Z轴转90度使其水平）
    part.CFrame = CFrame.new(0, -100, 0) * CFrame.Angles(0, 0, math.rad(90))
    
    moveIndicator = part
end

function MovementController._showIndicator(position: Vector3)
    if not moveIndicator then return end
    
    -- 取消之前的淡出
    if indicatorFadeThread then
        pcall(task.cancel, indicatorFadeThread)
    end
    
    moveIndicator.Position = Vector3.new(position.X, position.Y + 0.15, position.Z)
    moveIndicator.CFrame = CFrame.new(position.X, position.Y + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
    moveIndicator.Transparency = 0.3
    moveIndicator.Size = Vector3.new(0.1, 1.6, 1.6)
    
    -- 淡出动画
    indicatorFadeThread = task.delay(INDICATOR_DURATION * 0.3, function()
        local fadeSteps = 10
        local fadeInterval = (INDICATOR_DURATION * 0.7) / fadeSteps
        for i = 1, fadeSteps do
            if not moveIndicator or not moveIndicator.Parent then break end
            moveIndicator.Transparency = 0.3 + (0.7 * (i / fadeSteps))
            -- 缩小效果
            local scale = 1 - (i / fadeSteps) * 0.3
            moveIndicator.Size = Vector3.new(0.1, 1.6 * scale, 1.6 * scale)
            task.wait(fadeInterval)
        end
        if moveIndicator and moveIndicator.Parent then
            moveIndicator.Transparency = 1
        end
    end)
end

--============================================================
-- 外部接口
--============================================================

-- 立即停止移动（用于施法开始时）
function MovementController.stopMovement()
    isMoving = false
    moveTarget = nil
    local character = localPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:Move(Vector3.zero)
        end
    end
end

-- 获取当前移动目标
function MovementController.getMoveTarget(): Vector3?
    return moveTarget
end

-- 是否正在移动
function MovementController.isMoving(): boolean
    return isMoving
end

return MovementController
