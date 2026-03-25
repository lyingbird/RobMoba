local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MovementController = require(script.Parent:WaitForChild("MovementController"))

local LobbyUI = {}

local localPlayer = Players.LocalPlayer
local remotes = nil

local screenGui = nil
local rootFrame = nil
local statusLabel = nil

local function createButton(parent, text, positionScale, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.5, -8, 0, 56)
    button.Position = positionScale
    button.BackgroundColor3 = Color3.fromRGB(32, 36, 52)
    button.TextColor3 = Color3.fromRGB(255, 244, 214)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 20
    button.Text = text
    button.BorderSizePixel = 0
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = button

    button.Activated:Connect(function()
        MovementController.suppressTouchTap()
        callback()
    end)

    return button
end

local function getViewportSize()
    local camera = Workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end

    return Vector2.new(1280, 720)
end

function LobbyUI.init(remotesRef)
    remotes = remotesRef

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LobbyUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Enabled = false
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

    rootFrame = Instance.new("Frame")
    rootFrame.Name = "Root"
    rootFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    rootFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
    rootFrame.BackgroundTransparency = 0.15
    rootFrame.BorderSizePixel = 0
    rootFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 22)
    corner.Parent = rootFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -24, 0, 40)
    titleLabel.Position = UDim2.fromOffset(12, 14)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "大厅"
    titleLabel.TextColor3 = Color3.fromRGB(255, 227, 143)
    titleLabel.TextSize = 28
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = rootFrame

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -24, 0, 36)
    descLabel.Position = UDim2.fromOffset(12, 54)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = "选择要进入的模式"
    descLabel.TextColor3 = Color3.fromRGB(219, 225, 240)
    descLabel.TextSize = 16
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextWrapped = true
    descLabel.Parent = rootFrame

    createButton(rootFrame, "PVP匹配", UDim2.new(0, 12, 0, 104), function()
        if remotes and remotes.ModeSelect then
            remotes.ModeSelect:FireServer({ mode = "PVP" })
        end
    end)

    createButton(rootFrame, "单人训练", UDim2.new(0.5, -4, 0, 104), function()
        if remotes and remotes.ModeSelect then
            remotes.ModeSelect:FireServer({ mode = "Training" })
        end
    end)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -24, 0, 48)
    statusLabel.Position = UDim2.new(0, 12, 1, -60)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(162, 173, 194)
    statusLabel.TextSize = 15
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextWrapped = true
    statusLabel.Parent = rootFrame

    LobbyUI._applyLayout()

    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            LobbyUI._applyLayout()
        end)
    end
end

function LobbyUI._applyLayout()
    if not rootFrame then
        return
    end

    local viewport = getViewportSize()
    local topLeftInset = Vector2.zero
    local bottomRightInset = Vector2.zero
    local ok, tl, br = pcall(GuiService.GetGuiInset, GuiService)
    if ok then
        topLeftInset = tl
        bottomRightInset = br
    end

    local isTouch = UserInputService.TouchEnabled
    local availableWidth = math.max(320, viewport.X - topLeftInset.X - bottomRightInset.X - 24)
    local availableHeight = math.max(180, viewport.Y - topLeftInset.Y - bottomRightInset.Y - 24)
    local width = math.min(isTouch and 520 or 460, availableWidth)
    local height = math.min(isTouch and 190 or 180, availableHeight)

    rootFrame.Size = UDim2.fromOffset(width, height)
    rootFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
end

function LobbyUI.show(data)
    if not screenGui then
        return
    end

    screenGui.Enabled = true
    if statusLabel then
        statusLabel.Text = data and data.message or ""
    end
end

function LobbyUI.hide()
    if screenGui then
        screenGui.Enabled = false
    end
end

return LobbyUI
