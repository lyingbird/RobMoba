--[[
    MobileCombatUI

    Mobile-only combat cluster:
    - main attack button
    - skill buttons without keyboard labels
    - one summoner slot
    - one recall slot
    - cancel zone for drag-to-cancel
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobileCombatUI = {}

local localPlayer = Players.LocalPlayer
local remotes = nil

local shared = ReplicatedStorage:WaitForChild("Shared")
local SkillTable = require(shared:WaitForChild("SkillTable"))
local HeroTable = require(shared:WaitForChild("HeroTable"))

local InputHandler = require(script.Parent:WaitForChild("InputHandler"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))
local TouchInputGuard = require(script.Parent:WaitForChild("TouchInputGuard"))

local screenGui = nil
local rootFrame = nil
local combatAnchor = nil
local cancelZone = nil
local attackButton = nil
local summonerButton = nil
local recallButton = nil

local skillButtons = {}
local mobileTouchState = nil
local skillData = {}
local currentHeroId = nil
local cooldowns = {}

local KEYS = { "Q", "W", "E", "R" }
local TYPE_COLORS = {
    Instant = Color3.fromRGB(76, 196, 110),
    Direction = Color3.fromRGB(74, 122, 255),
    Position = Color3.fromRGB(255, 161, 61),
    Channel = Color3.fromRGB(181, 87, 255),
    Passive = Color3.fromRGB(110, 110, 120),
}
local FACE_LABELS = {
    Q = "1",
    W = "2",
    E = "3",
    R = "ULT",
}
local LAYOUT = {
    AnchorSize = Vector2.new(340, 300),
    AttackCenter = Vector2.new(262, 216),
    AttackSize = 108,
    CancelZoneSize = 108,
    SkillButtons = {
        Q = { center = Vector2.new(148, 192), size = 84 },
        W = { center = Vector2.new(140, 96), size = 84 },
        E = { center = Vector2.new(220, 86), size = 84 },
        R = { center = Vector2.new(76, 84), size = 94 },
    },
    Summoner = { center = Vector2.new(78, 178), size = 62 },
    Recall = { center = Vector2.new(36, 238), size = 54 },
}

local function isTouchDevice(): boolean
    return UserInputService.TouchEnabled
end

local function getGuiInsets()
    local ok, topLeftInset, bottomRightInset = pcall(GuiService.GetGuiInset, GuiService)
    if ok then
        return topLeftInset, bottomRightInset
    end

    return Vector2.zero, Vector2.zero
end

local function getSkillColor(skill)
    return TYPE_COLORS[skill and skill.castType] or Color3.fromRGB(110, 110, 120)
end

local function createRoundButton(parent: Instance, name: string, diameter: number, zIndex: number)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.fromOffset(diameter, diameter)
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.AutoButtonColor = false
    button.Text = ""
    button.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
    button.BorderSizePixel = 0
    button.ZIndex = zIndex
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = button

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(115, 130, 160)
    stroke.Thickness = 3
    stroke.Parent = button

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, -10, 1, -10)
    fill.Position = UDim2.fromOffset(5, 5)
    fill.BackgroundColor3 = Color3.fromRGB(45, 55, 78)
    fill.BorderSizePixel = 0
    fill.ZIndex = zIndex
    fill.Parent = button

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "IconLabel"
    iconLabel.Size = UDim2.new(1, -10, 1, -26)
    iconLabel.Position = UDim2.fromOffset(5, 4)
    iconLabel.BackgroundTransparency = 1
    iconLabel.TextColor3 = Color3.new(1, 1, 1)
    iconLabel.TextSize = 22
    iconLabel.Font = Enum.Font.GothamBlack
    iconLabel.Text = ""
    iconLabel.ZIndex = zIndex + 1
    iconLabel.Parent = button

    local subLabel = Instance.new("TextLabel")
    subLabel.Name = "SubLabel"
    subLabel.Size = UDim2.new(1, -10, 0, 16)
    subLabel.Position = UDim2.new(0, 5, 1, -22)
    subLabel.BackgroundTransparency = 1
    subLabel.TextColor3 = Color3.fromRGB(205, 214, 232)
    subLabel.TextSize = 12
    subLabel.Font = Enum.Font.GothamBold
    subLabel.Text = ""
    subLabel.ZIndex = zIndex + 1
    subLabel.Parent = button

    local cooldownOverlay = Instance.new("Frame")
    cooldownOverlay.Name = "CooldownOverlay"
    cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
    cooldownOverlay.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
    cooldownOverlay.BackgroundTransparency = 0.35
    cooldownOverlay.BorderSizePixel = 0
    cooldownOverlay.Visible = false
    cooldownOverlay.ZIndex = zIndex + 2
    cooldownOverlay.Parent = button

    local overlayCorner = Instance.new("UICorner")
    overlayCorner.CornerRadius = UDim.new(1, 0)
    overlayCorner.Parent = cooldownOverlay

    local cooldownLabel = Instance.new("TextLabel")
    cooldownLabel.Name = "CooldownLabel"
    cooldownLabel.Size = UDim2.new(1, 0, 1, 0)
    cooldownLabel.BackgroundTransparency = 1
    cooldownLabel.TextColor3 = Color3.new(1, 1, 1)
    cooldownLabel.TextSize = 18
    cooldownLabel.Font = Enum.Font.GothamBlack
    cooldownLabel.Text = ""
    cooldownLabel.Visible = false
    cooldownLabel.ZIndex = zIndex + 3
    cooldownLabel.Parent = button

    local pressedGlow = Instance.new("UIStroke")
    pressedGlow.Color = Color3.fromRGB(255, 230, 120)
    pressedGlow.Thickness = 4
    pressedGlow.Enabled = false
    pressedGlow.Parent = fill

    return {
        button = button,
        fill = fill,
        stroke = stroke,
        iconLabel = iconLabel,
        subLabel = subLabel,
        cooldownOverlay = cooldownOverlay,
        cooldownLabel = cooldownLabel,
        pressedGlow = pressedGlow,
    }
end

function MobileCombatUI.init(remotesRef)
    remotes = remotesRef
    if not isTouchDevice() then
        return
    end

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MobileCombatUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

    rootFrame = Instance.new("Frame")
    rootFrame.Size = UDim2.fromScale(1, 1)
    rootFrame.BackgroundTransparency = 1
    rootFrame.Parent = screenGui

    combatAnchor = Instance.new("Frame")
    combatAnchor.Size = UDim2.fromOffset(LAYOUT.AnchorSize.X, LAYOUT.AnchorSize.Y)
    combatAnchor.AnchorPoint = Vector2.new(1, 1)
    combatAnchor.BackgroundTransparency = 1
    combatAnchor.Parent = rootFrame

    for _, keyName in ipairs(KEYS) do
        local config = LAYOUT.SkillButtons[keyName]
        local widget = createRoundButton(combatAnchor, "Skill_" .. keyName, config.size, 30)
        widget.button.Position = UDim2.fromOffset(config.center.X, config.center.Y)
        widget.iconLabel.Text = FACE_LABELS[keyName] or keyName
        widget.button.Visible = false
        widget.button.InputBegan:Connect(function(input)
            MobileCombatUI._handleSkillInputBegan(keyName, input)
        end)
        skillButtons[keyName] = widget
    end

    attackButton = createRoundButton(combatAnchor, "AttackButton", LAYOUT.AttackSize, 40)
    attackButton.button.Position = UDim2.fromOffset(LAYOUT.AttackCenter.X, LAYOUT.AttackCenter.Y)
    attackButton.fill.BackgroundColor3 = Color3.fromRGB(66, 88, 132)
    attackButton.stroke.Color = Color3.fromRGB(160, 186, 255)
    attackButton.iconLabel.Text = "ATK"
    attackButton.iconLabel.TextSize = 24
    attackButton.subLabel.Text = "Basic"
    attackButton.button.Activated:Connect(function()
        MovementController.suppressTouchTap()
        TouchInputGuard.consume(0.18)
        InputHandler.triggerBasicAttack()
    end)

    summonerButton = createRoundButton(combatAnchor, "SummonerButton", LAYOUT.Summoner.size, 26)
    summonerButton.button.Position = UDim2.fromOffset(LAYOUT.Summoner.center.X, LAYOUT.Summoner.center.Y)
    summonerButton.fill.BackgroundColor3 = Color3.fromRGB(82, 122, 80)
    summonerButton.stroke.Color = Color3.fromRGB(162, 230, 144)
    summonerButton.iconLabel.Text = "SUM"

    recallButton = createRoundButton(combatAnchor, "RecallButton", LAYOUT.Recall.size, 24)
    recallButton.button.Position = UDim2.fromOffset(LAYOUT.Recall.center.X, LAYOUT.Recall.center.Y)
    recallButton.fill.BackgroundColor3 = Color3.fromRGB(72, 86, 105)
    recallButton.stroke.Color = Color3.fromRGB(152, 174, 196)
    recallButton.iconLabel.Text = "BACK"
    recallButton.iconLabel.TextSize = 13

    cancelZone = Instance.new("Frame")
    cancelZone.Size = UDim2.fromOffset(LAYOUT.CancelZoneSize, LAYOUT.CancelZoneSize)
    cancelZone.AnchorPoint = Vector2.new(0.5, 0.5)
    cancelZone.BackgroundColor3 = Color3.fromRGB(120, 24, 24)
    cancelZone.BackgroundTransparency = 0.28
    cancelZone.BorderSizePixel = 0
    cancelZone.Visible = false
    cancelZone.ZIndex = 35
    cancelZone.Parent = rootFrame

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(1, 0)
    cancelCorner.Parent = cancelZone

    local cancelLabel = Instance.new("TextLabel")
    cancelLabel.Size = UDim2.new(1, 0, 1, 0)
    cancelLabel.BackgroundTransparency = 1
    cancelLabel.TextColor3 = Color3.new(1, 1, 1)
    cancelLabel.TextSize = 26
    cancelLabel.Font = Enum.Font.GothamBlack
    cancelLabel.Text = "X"
    cancelLabel.ZIndex = 36
    cancelLabel.Parent = cancelZone

    MobileCombatUI._applyResponsiveLayout()

    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            MobileCombatUI._applyResponsiveLayout()
        end)
    end

    UserInputService.InputChanged:Connect(function(input)
        MobileCombatUI._handleGlobalInputChanged(input)
    end)
    UserInputService.InputEnded:Connect(function(input)
        MobileCombatUI._handleGlobalInputEnded(input)
    end)

    if remotes.SkillBarUpdate then
        remotes.SkillBarUpdate.OnClientEvent:Connect(function(data)
            MobileCombatUI._onSkillBarUpdate(data)
        end)
    end
    if remotes.CooldownUpdate then
        remotes.CooldownUpdate.OnClientEvent:Connect(function(data)
            MobileCombatUI._onCooldownUpdate(data)
        end)
    end

    task.spawn(function()
        while true do
            MobileCombatUI._updateCooldowns()
            task.wait(0.05)
        end
    end)
end

function MobileCombatUI._applyResponsiveLayout()
    if not combatAnchor then
        return
    end
    local _topLeftInset, bottomRightInset = getGuiInsets()
    combatAnchor.Position = UDim2.new(1, -(bottomRightInset.X + 14), 1, -(bottomRightInset.Y + 12))
    cancelZone.Position = UDim2.new(0.5, 120, 0.56, 0)
end

function MobileCombatUI._handleSkillInputBegan(keyName: string, input)
    if mobileTouchState then
        return
    end
    local inputType = input.UserInputType
    if inputType ~= Enum.UserInputType.Touch and inputType ~= Enum.UserInputType.MouseButton1 then
        return
    end
    local screenPosition = Vector2.new(input.Position.X, input.Position.Y)
    MovementController.suppressTouchTap()
    TouchInputGuard.consume(0.22)
    if InputHandler.beginMobileSkillTouch(keyName, screenPosition) then
        mobileTouchState = { keyName = keyName, inputObject = input }
        MobileCombatUI._setCancelZoneVisible(true)
        MobileCombatUI._setPressed(keyName, true)
    end
end

function MobileCombatUI._handleGlobalInputChanged(input)
    if not mobileTouchState or input ~= mobileTouchState.inputObject then
        return
    end
    local screenPosition = Vector2.new(input.Position.X, input.Position.Y)
    local cancelPending = MobileCombatUI._isInCancelZone(screenPosition)
    TouchInputGuard.consume(0.18)
    InputHandler.updateMobileSkillTouch(screenPosition, cancelPending)
end

function MobileCombatUI._handleGlobalInputEnded(input)
    if not mobileTouchState or input ~= mobileTouchState.inputObject then
        return
    end
    local trackedState = mobileTouchState
    mobileTouchState = nil
    local screenPosition = Vector2.new(input.Position.X, input.Position.Y)
    local cancelPending = MobileCombatUI._isInCancelZone(screenPosition)
    MobileCombatUI._setCancelZoneVisible(false)
    MobileCombatUI._setPressed(trackedState.keyName, false)
    TouchInputGuard.consume(0.18)
    MovementController.suppressTouchTap()
    InputHandler.endMobileSkillTouch(trackedState.keyName, screenPosition, cancelPending)
end

function MobileCombatUI._isInCancelZone(screenPosition: Vector2): boolean
    if not cancelZone or not cancelZone.Visible then
        return false
    end
    local center = cancelZone.AbsolutePosition + (cancelZone.AbsoluteSize / 2)
    local radius = math.min(cancelZone.AbsoluteSize.X, cancelZone.AbsoluteSize.Y) * 0.5
    return (screenPosition - center).Magnitude <= radius
end

function MobileCombatUI._setCancelZoneVisible(isVisible: boolean)
    if cancelZone then
        cancelZone.Visible = isVisible
    end
end

function MobileCombatUI._setPressed(keyName: string, isPressed: boolean)
    local widget = skillButtons[keyName]
    if widget and widget.pressedGlow then
        widget.pressedGlow.Enabled = isPressed
    end
end

function MobileCombatUI._onSkillBarUpdate(data)
    if not data then
        return
    end
    if data.action == "init" and data.skills then
        currentHeroId = data.heroId
        skillData = {}
        for _, keyName in ipairs(KEYS) do
            skillData[keyName] = data.skills[keyName]
        end
        MobileCombatUI._refreshButtons()
        return
    end
    if data.action == "replace" and data.key and data.newSkillId then
        local skill = SkillTable.getSkill(data.newSkillId)
        if skill then
            skillData[data.key] = skill
            MobileCombatUI._refreshButton(data.key)
        end
        return
    end
    if data.action == "revert" and data.key and currentHeroId then
        local hero = HeroTable.getHero(currentHeroId)
        if hero and hero.skills[data.key] then
            skillData[data.key] = SkillTable.getSkill(hero.skills[data.key])
        else
            skillData[data.key] = nil
        end
        MobileCombatUI._refreshButton(data.key)
    end
end

function MobileCombatUI._refreshButtons()
    for _, keyName in ipairs(KEYS) do
        MobileCombatUI._refreshButton(keyName)
    end
end

function MobileCombatUI._refreshButton(keyName: string)
    local widget = skillButtons[keyName]
    local skill = skillData[keyName]
    if not widget then
        return
    end
    if skill and skill.castType ~= "Passive" then
        local skillColor = getSkillColor(skill)
        widget.button.Visible = true
        widget.fill.BackgroundColor3 = skillColor:Lerp(Color3.fromRGB(32, 38, 52), 0.38)
        widget.stroke.Color = skillColor
        widget.iconLabel.Text = FACE_LABELS[keyName] or keyName
        widget.subLabel.Text = (skill.manaCost and skill.manaCost > 0) and tostring(skill.manaCost) or ""
    else
        widget.button.Visible = false
        widget.cooldownOverlay.Visible = false
        widget.cooldownLabel.Visible = false
        widget.cooldownLabel.Text = ""
    end
end

function MobileCombatUI._onCooldownUpdate(data)
    if not data or not data.skillId then
        return
    end
    local cooldownTime = math.max(0, data.cooldownTime or 0)
    if cooldownTime <= 0 then
        cooldowns[data.skillId] = nil
    else
        cooldowns[data.skillId] = {
            endTime = tick() + cooldownTime,
            totalTime = cooldownTime,
        }
    end
end

function MobileCombatUI._updateCooldowns()
    local now = tick()
    for keyName, skill in pairs(skillData) do
        local widget = skillButtons[keyName]
        if widget and skill and widget.button.Visible then
            local cooldownState = cooldowns[skill.id]
            local remaining = 0
            if cooldownState and cooldownState.endTime > now then
                remaining = cooldownState.endTime - now
            else
                cooldowns[skill.id] = nil
            end
            local onCooldown = remaining > 0
            widget.cooldownOverlay.Visible = onCooldown
            widget.cooldownLabel.Visible = onCooldown
            widget.cooldownLabel.Text = onCooldown and string.format("%.1f", remaining) or ""
        end
    end
end

function MobileCombatUI._setTouchJumpVisible(isVisible: boolean)
    task.spawn(function()
        local playerGui = localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 3)
        if not playerGui then
            return
        end
        for _ = 1, 8 do
            local touchGui = playerGui:FindFirstChild("TouchGui")
            local controlFrame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
            local jumpButton = controlFrame and controlFrame:FindFirstChild("JumpButton")
            if jumpButton and jumpButton:IsA("GuiObject") then
                jumpButton.Visible = isVisible
                break
            end
            task.wait(0.25)
        end
    end)
end

function MobileCombatUI.show()
    if not screenGui then
        return
    end
    screenGui.Enabled = true
    MobileCombatUI._setTouchJumpVisible(false)
end

function MobileCombatUI.hide()
    if not screenGui then
        return
    end
    screenGui.Enabled = false
    MobileCombatUI._setCancelZoneVisible(false)
    MobileCombatUI._setTouchJumpVisible(true)
    if mobileTouchState then
        MobileCombatUI._setPressed(mobileTouchState.keyName, false)
        mobileTouchState = nil
    end
end

return MobileCombatUI
