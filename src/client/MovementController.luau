--[[
    MovementController

    Desktop:
    - right click to move
    - hold right click to update the destination

    Mobile:
    - tap ground to move

    The controller also tries to disable Roblox default controls so the
    project can own camera and movement behavior.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local workspace = game:GetService("Workspace")

local SkillIndicator = require(script.Parent:WaitForChild("SkillIndicator"))
local TouchInputGuard = require(script.Parent:WaitForChild("TouchInputGuard"))

local MovementController = {}

local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

local moveTarget = nil
local isMoving = false
local isRightHeld = false
local moveConnection = nil

local moveIndicator = nil
local indicatorFadeThread = nil

local INDICATOR_DURATION = 0.6
local STOP_THRESHOLD = 1.5
local GROUND_RAYCAST_DIST = 1000
local MOBILE_HUD_DEADZONE = 160

function MovementController.init()
    MovementController._disableDefaultMovement()
    MovementController._createIndicator()

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            isRightHeld = true
            MovementController._moveToScreenPosition()
            return
        end

        if input.UserInputType == Enum.UserInputType.Touch then
            local touchPosition = Vector2.new(input.Position.X, input.Position.Y)
            if MovementController._canMoveFromTouch(touchPosition) then
                MovementController._moveToScreenPosition(touchPosition)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            isRightHeld = false
        end
    end)

    moveConnection = RunService.Heartbeat:Connect(function(dt)
        MovementController._updateMovement(dt)
    end)

    localPlayer.CharacterAdded:Connect(function()
        moveTarget = nil
        isMoving = false
        task.delay(0.5, MovementController._disableDefaultMovement)
    end)

    if localPlayer.Character then
        task.delay(0.1, MovementController._disableDefaultMovement)
    end

    print("[MovementController] initialized")
end

function MovementController._canMoveFromTouch(screenPosition: Vector2): boolean
    if TouchInputGuard.isConsumed() or SkillIndicator.isActive() then
        return false
    end

    if MovementController._isTouchInHudDeadzone(screenPosition) then
        return false
    end

    return true
end

function MovementController._isTouchInHudDeadzone(screenPosition: Vector2): boolean
    if not UserInputService.TouchEnabled then
        return false
    end

    local camera = workspace.CurrentCamera
    if not camera then
        return false
    end

    local viewportSize = camera.ViewportSize
    local bottomInset = 0
    local ok, _topLeftInset, bottomRightInset = pcall(GuiService.GetGuiInset, GuiService)
    if ok then
        bottomInset = bottomRightInset.Y
    end

    return screenPosition.Y >= (viewportSize.Y - bottomInset - MOBILE_HUD_DEADZONE)
end

function MovementController._disableDefaultMovement()
    pcall(function()
        localPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
        localPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
    end)

    local function sinkAction()
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

    task.spawn(function()
        local playerScripts = localPlayer:FindFirstChild("PlayerScripts") or localPlayer:WaitForChild("PlayerScripts", 5)
        if not playerScripts then
            return
        end

        for _ = 1, 4 do
            local playerModule = playerScripts:FindFirstChild("PlayerModule") or playerScripts:WaitForChild("PlayerModule", 2)
            if playerModule then
                local success, result = pcall(function()
                    local playerModuleApi = require(playerModule)
                    local controls = playerModuleApi:GetControls()
                    if controls and controls.Disable then
                        controls:Disable()
                    end
                end)

                if success then
                    print("[MovementController] PlayerModule controls disabled")
                    break
                else
                    warn("[MovementController] failed to disable PlayerModule controls:", tostring(result))
                end
            end

            task.wait(0.5)
        end
    end)

    local character = localPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = false
        end
    end
end

function MovementController._moveToScreenPosition(screenPosition: Vector2?)
    local character = localPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end

    local groundPosition = MovementController._getGroundPosition(screenPosition)
    if not groundPosition then
        return
    end

    moveTarget = groundPosition
    isMoving = true
    MovementController._showIndicator(groundPosition)
end

function MovementController._updateMovement(_dt)
    if isRightHeld then
        local groundPosition = MovementController._getGroundPosition()
        if groundPosition then
            moveTarget = groundPosition
            isMoving = true
            if moveIndicator and moveIndicator.Parent then
                moveIndicator.Position = Vector3.new(groundPosition.X, groundPosition.Y + 0.15, groundPosition.Z)
            end
        end
    end

    if not isMoving or not moveTarget then
        return
    end

    local character = localPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        isMoving = false
        return
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return
    end

    if humanoid.WalkSpeed <= 0 then
        humanoid:Move(Vector3.zero)
        return
    end

    local currentPosition = rootPart.Position
    local targetFlat = Vector3.new(moveTarget.X, currentPosition.Y, moveTarget.Z)
    local delta = targetFlat - currentPosition
    local distance = delta.Magnitude

    if distance < STOP_THRESHOLD then
        isMoving = false
        moveTarget = nil
        humanoid:Move(Vector3.zero)
        return
    end

    local moveDirection = Vector3.new(delta.X, 0, delta.Z).Unit
    humanoid:Move(moveDirection)

    local targetCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + moveDirection * 10)
    rootPart.CFrame = CFrame.new(rootPart.Position) * targetCFrame.Rotation
end

function MovementController._getGroundPosition(screenPosition: Vector2?): Vector3?
    local character = localPlayer.Character
    if not character then
        return nil
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { character }

    local ray
    if screenPosition then
        local camera = workspace.CurrentCamera
        if not camera then
            return nil
        end
        ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
    else
        ray = mouse.UnitRay
    end

    local rayResult = workspace:Raycast(ray.Origin, ray.Direction * GROUND_RAYCAST_DIST, raycastParams)
    if rayResult then
        return rayResult.Position
    end

    if ray.Direction.Y ~= 0 then
        local t = -ray.Origin.Y / ray.Direction.Y
        if t > 0 then
            return ray.Origin + ray.Direction * t
        end
    end

    return nil
end

function MovementController._createIndicator()
    local part = Instance.new("Part")
    part.Name = "MoveIndicator"
    part.Shape = Enum.PartType.Cylinder
    part.Size = Vector3.new(0.1, 1.6, 1.6)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(80, 255, 120)
    part.Transparency = 1
    part.CastShadow = false
    part.Parent = workspace
    part.CFrame = CFrame.new(0, -100, 0) * CFrame.Angles(0, 0, math.rad(90))

    moveIndicator = part
end

function MovementController._showIndicator(position: Vector3)
    if not moveIndicator then
        return
    end

    if indicatorFadeThread then
        pcall(task.cancel, indicatorFadeThread)
    end

    moveIndicator.Position = Vector3.new(position.X, position.Y + 0.15, position.Z)
    moveIndicator.CFrame = CFrame.new(position.X, position.Y + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
    moveIndicator.Transparency = 0.3
    moveIndicator.Size = Vector3.new(0.1, 1.6, 1.6)

    indicatorFadeThread = task.delay(INDICATOR_DURATION * 0.3, function()
        local fadeSteps = 10
        local fadeInterval = (INDICATOR_DURATION * 0.7) / fadeSteps
        for i = 1, fadeSteps do
            if not moveIndicator or not moveIndicator.Parent then
                break
            end

            moveIndicator.Transparency = 0.3 + (0.7 * (i / fadeSteps))
            local scale = 1 - (i / fadeSteps) * 0.3
            moveIndicator.Size = Vector3.new(0.1, 1.6 * scale, 1.6 * scale)
            task.wait(fadeInterval)
        end

        if moveIndicator and moveIndicator.Parent then
            moveIndicator.Transparency = 1
        end
    end)
end

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

function MovementController.suppressTouchTap(duration: number?)
    TouchInputGuard.consume(duration)
end

function MovementController.getMoveTarget(): Vector3?
    return moveTarget
end

function MovementController.isMoving(): boolean
    return isMoving
end

return MovementController
