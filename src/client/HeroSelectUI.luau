--[[
    HeroSelectUI

    A lightweight hero switch panel with mobile-friendly interaction:
    - `Activated` for touch and mouse
    - safe inset awareness
    - responsive panel sizing
    - horizontal scrolling when hero count grows
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local HeroTable = require(shared:WaitForChild("HeroTable"))
local SkillTable = require(shared:WaitForChild("SkillTable"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))

local HeroSelectUI = {}

local remotes = nil
local localPlayer = Players.LocalPlayer

local screenGui = nil
local toggleFrame = nil
local toggleButton = nil
local panelFrame = nil
local heroNameLabel = nil
local cardContainer = nil

local currentHeroId = nil
local heroCards = {}
local isPanelOpen = false
local canSelectHero = false

local ROLE_COLORS = {
    Marksman = Color3.fromRGB(255, 180, 50),
    Tank = Color3.fromRGB(100, 180, 255),
    Mage = Color3.fromRGB(180, 100, 255),
    Assassin = Color3.fromRGB(255, 80, 80),
    Support = Color3.fromRGB(80, 220, 120),
}

local ROLE_NAMES = {
    Marksman = "射手",
    Tank = "坦克",
    Mage = "法师",
    Assassin = "刺客",
    Support = "辅助",
}

local function getSafeInsets()
    local ok, topLeftInset, bottomRightInset = pcall(GuiService.GetGuiInset, GuiService)
    if ok then
        return topLeftInset, bottomRightInset
    end

    return Vector2.zero, Vector2.zero
end

local function getViewportSize()
    local camera = Workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end

    return Vector2.new(1280, 720)
end

function HeroSelectUI.init(remotesRef)
    remotes = remotesRef

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HeroSelectUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 50
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

    HeroSelectUI._createToggleButton()
    HeroSelectUI._createPanel()
    HeroSelectUI._applyResponsiveLayout()

    if remotes.SkillBarUpdate then
        remotes.SkillBarUpdate.OnClientEvent:Connect(function(data)
            if data and data.action == "init" and data.heroId then
                currentHeroId = data.heroId
                HeroSelectUI._updateCurrentHeroDisplay()
            end
        end)
    end

    local camera = Workspace.CurrentCamera
    if camera then
        camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            HeroSelectUI._applyResponsiveLayout()
        end)
    end

    print("[HeroSelectUI] initialized")
end

function HeroSelectUI._createToggleButton()
    toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "ToggleFrame"
    toggleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    toggleFrame.BackgroundTransparency = 0.15
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = screenGui

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 10)
    toggleCorner.Parent = toggleFrame

    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(80, 80, 120)
    toggleStroke.Thickness = 1.5
    toggleStroke.Parent = toggleFrame

    heroNameLabel = Instance.new("TextLabel")
    heroNameLabel.Name = "HeroName"
    heroNameLabel.Size = UDim2.new(1, -58, 1, 0)
    heroNameLabel.Position = UDim2.new(0, 12, 0, 0)
    heroNameLabel.BackgroundTransparency = 1
    heroNameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    heroNameLabel.TextSize = 15
    heroNameLabel.Font = Enum.Font.GothamBold
    heroNameLabel.Text = "选择英雄"
    heroNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    heroNameLabel.Parent = toggleFrame

    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleBtn"
    toggleButton.Size = UDim2.fromOffset(42, 34)
    toggleButton.AnchorPoint = Vector2.new(1, 0.5)
    toggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.TextSize = 16
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Text = "▼"
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = toggleFrame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = toggleButton

    local toggleHitArea = Instance.new("TextButton")
    toggleHitArea.Name = "HitArea"
    toggleHitArea.Size = UDim2.fromScale(1, 1)
    toggleHitArea.BackgroundTransparency = 1
    toggleHitArea.Text = ""
    toggleHitArea.AutoButtonColor = false
    toggleHitArea.ZIndex = 5
    toggleHitArea.Parent = toggleFrame

    toggleHitArea.Activated:Connect(function()
        MovementController.suppressTouchTap()
        if isPanelOpen then
            HeroSelectUI._closePanel()
        else
            HeroSelectUI._openPanel()
        end
    end)

    if UserInputService.MouseEnabled then
        toggleFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                TweenService:Create(toggleStroke, TweenInfo.new(0.15), {
                    Color = Color3.fromRGB(120, 120, 180),
                }):Play()
            end
        end)

        toggleFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                TweenService:Create(toggleStroke, TweenInfo.new(0.15), {
                    Color = Color3.fromRGB(80, 80, 120),
                }):Play()
            end
        end)
    end
end

function HeroSelectUI._createPanel()
    panelFrame = Instance.new("Frame")
    panelFrame.Name = "HeroPanel"
    panelFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    panelFrame.BackgroundTransparency = 0.1
    panelFrame.BorderSizePixel = 0
    panelFrame.Visible = false
    panelFrame.Parent = screenGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panelFrame

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Color3.fromRGB(60, 60, 100)
    panelStroke.Thickness = 2
    panelStroke.Parent = panelFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -16, 0, 30)
    titleLabel.Position = UDim2.new(0, 8, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "切换英雄（点击立即切换）"
    titleLabel.Parent = panelFrame

    cardContainer = Instance.new("ScrollingFrame")
    cardContainer.Name = "CardContainer"
    cardContainer.Size = UDim2.new(1, -20, 1, -46)
    cardContainer.Position = UDim2.new(0, 10, 0, 38)
    cardContainer.BackgroundTransparency = 1
    cardContainer.BorderSizePixel = 0
    cardContainer.AutomaticCanvasSize = Enum.AutomaticSize.X
    cardContainer.CanvasSize = UDim2.new()
    cardContainer.ScrollingDirection = Enum.ScrollingDirection.X
    cardContainer.ScrollBarThickness = 4
    cardContainer.ScrollBarImageTransparency = 0.35
    cardContainer.Parent = panelFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    listLayout.Padding = UDim.new(0, 12)
    listLayout.Parent = cardContainer

    for _, heroId in ipairs(HeroTable.getAllHeroIds()) do
        local heroData = HeroTable.getHero(heroId)
        if heroData then
            HeroSelectUI._createHeroCard(cardContainer, heroData)
        end
    end
end

function HeroSelectUI._createHeroCard(parent, heroData)
    local heroId = heroData.id
    local roleColor = ROLE_COLORS[heroData.role] or Color3.fromRGB(200, 200, 200)
    local roleName = ROLE_NAMES[heroData.role] or heroData.role

    local card = Instance.new("TextButton")
    card.Name = "Card_" .. heroId
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    card.BorderSizePixel = 0
    card.Text = ""
    card.AutoButtonColor = false
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Name = "CardStroke"
    cardStroke.Color = Color3.fromRGB(60, 60, 80)
    cardStroke.Thickness = 2
    cardStroke.Parent = card

    local currentTag = Instance.new("TextLabel")
    currentTag.Name = "CurrentTag"
    currentTag.Size = UDim2.new(1, 0, 0, 18)
    currentTag.Position = UDim2.new(0, 0, 0, 2)
    currentTag.BackgroundTransparency = 1
    currentTag.TextColor3 = Color3.fromRGB(100, 255, 100)
    currentTag.TextSize = 10
    currentTag.Font = Enum.Font.GothamBold
    currentTag.Visible = false
    currentTag.Parent = card

    local roleBar = Instance.new("Frame")
    roleBar.Name = "RoleBar"
    roleBar.Size = UDim2.new(1, 0, 0, 3)
    roleBar.BackgroundColor3 = roleColor
    roleBar.BorderSizePixel = 0
    roleBar.Parent = card

    local roleBarCorner = Instance.new("UICorner")
    roleBarCorner.CornerRadius = UDim.new(0, 10)
    roleBarCorner.Parent = roleBar

    local avatarFrame = Instance.new("Frame")
    avatarFrame.Name = "Avatar"
    avatarFrame.Size = UDim2.fromOffset(50, 50)
    avatarFrame.Position = UDim2.new(0.5, 0, 0, 22)
    avatarFrame.AnchorPoint = Vector2.new(0.5, 0)
    avatarFrame.BackgroundColor3 = heroData.bodyColors and heroData.bodyColors.TorsoColor or Color3.fromRGB(100, 100, 100)
    avatarFrame.BorderSizePixel = 0
    avatarFrame.Parent = card

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 25)
    avatarCorner.Parent = avatarFrame

    local avatarStroke = Instance.new("UIStroke")
    avatarStroke.Color = roleColor
    avatarStroke.Thickness = 2
    avatarStroke.Parent = avatarFrame

    local avatarText = Instance.new("TextLabel")
    avatarText.Size = UDim2.fromScale(1, 1)
    avatarText.BackgroundTransparency = 1
    avatarText.TextColor3 = Color3.new(1, 1, 1)
    avatarText.TextSize = 20
    avatarText.Font = Enum.Font.GothamBlack
    local firstCharEnd = utf8.offset(heroData.name, 2)
    avatarText.Text = firstCharEnd and string.sub(heroData.name, 1, firstCharEnd - 1) or heroData.name
    avatarText.Parent = avatarFrame

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "HeroName"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.Position = UDim2.new(0, 0, 0, 76)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextSize = 15
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = heroData.name
    nameLabel.Parent = card

    local roleLabel = Instance.new("TextLabel")
    roleLabel.Name = "RoleLabel"
    roleLabel.Size = UDim2.new(1, 0, 0, 15)
    roleLabel.Position = UDim2.new(0, 0, 0, 96)
    roleLabel.BackgroundTransparency = 1
    roleLabel.TextColor3 = roleColor
    roleLabel.TextSize = 11
    roleLabel.Font = Enum.Font.GothamBold
    roleLabel.Text = roleName
    roleLabel.Parent = card

    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "Stats"
    statsLabel.Size = UDim2.new(1, -12, 0, 40)
    statsLabel.Position = UDim2.new(0, 6, 0, 114)
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    statsLabel.TextSize = 10
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.Text = string.format(
        "HP:%d  MP:%d\nATK:%d  AP:%d\nDEF:%d  MR:%d",
        heroData.maxHP,
        heroData.maxMP,
        heroData.attackDamage,
        heroData.magicPower,
        heroData.armor,
        heroData.magicResist
    )
    statsLabel.TextXAlignment = Enum.TextXAlignment.Left
    statsLabel.TextYAlignment = Enum.TextYAlignment.Top
    statsLabel.Parent = card

    local skillY = 158
    for _, key in ipairs({ "Q", "W", "E", "R" }) do
        local skillId = heroData.skills[key]
        if skillId then
            local skillData = SkillTable.getSkill(skillId)
            if skillData then
                local skillLabel = Instance.new("TextLabel")
                skillLabel.Name = "Skill_" .. key
                skillLabel.Size = UDim2.new(1, -12, 0, 13)
                skillLabel.Position = UDim2.new(0, 6, 0, skillY)
                skillLabel.BackgroundTransparency = 1
                skillLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
                skillLabel.TextSize = 9
                skillLabel.Font = Enum.Font.Gotham
                skillLabel.TextXAlignment = Enum.TextXAlignment.Left
                skillLabel.TextTruncate = Enum.TextTruncate.AtEnd
                skillLabel.Text = string.format("[%s] %s", key, skillData.name)
                skillLabel.Parent = card
                skillY += 14
            end
        end
    end

    card.Activated:Connect(function()
        MovementController.suppressTouchTap()
        HeroSelectUI._switchHero(heroId)
    end)

    if UserInputService.MouseEnabled then
        card.MouseEnter:Connect(function()
            if currentHeroId ~= heroId then
                TweenService:Create(cardStroke, TweenInfo.new(0.15), {
                    Color = Color3.fromRGB(120, 120, 160),
                }):Play()
                TweenService:Create(card, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(38, 38, 55),
                }):Play()
            end
        end)

        card.MouseLeave:Connect(function()
            if currentHeroId ~= heroId then
                TweenService:Create(cardStroke, TweenInfo.new(0.15), {
                    Color = Color3.fromRGB(60, 60, 80),
                }):Play()
                TweenService:Create(card, TweenInfo.new(0.15), {
                    BackgroundColor3 = Color3.fromRGB(30, 30, 45),
                }):Play()
            end
        end)
    end

    heroCards[heroId] = card
end

function HeroSelectUI._applyResponsiveLayout()
    if not toggleFrame or not panelFrame then
        return
    end

    local topLeftInset, bottomRightInset = getSafeInsets()
    local viewportSize = getViewportSize()
    local isTouch = UserInputService.TouchEnabled

    local toggleWidth = math.clamp(math.floor(viewportSize.X * (isTouch and 0.34 or 0.22)), 180, 260)
    local toggleHeight = isTouch and 48 or 40
    local leftPadding = 12 + topLeftInset.X
    local topPadding = 12 + topLeftInset.Y

    toggleFrame.Size = UDim2.fromOffset(toggleWidth, toggleHeight)
    toggleFrame.Position = UDim2.fromOffset(leftPadding, topPadding)
    toggleButton.Position = UDim2.new(1, -8, 0.5, 0)

    local availableWidth = math.max(320, viewportSize.X - leftPadding - bottomRightInset.X - 12)
    local availableHeight = math.max(220, viewportSize.Y - topPadding - bottomRightInset.Y - toggleHeight - 36)
    local panelWidth = math.min(availableWidth, isTouch and 560 or 700)
    local panelHeight = math.min(availableHeight, isTouch and 320 or 300)

    panelFrame.Size = UDim2.fromOffset(panelWidth, panelHeight)
    panelFrame.Position = UDim2.fromOffset(leftPadding, topPadding + toggleHeight + 10)

    local cardWidth = math.clamp(math.floor(panelWidth * (isTouch and 0.3 or 0.27)), 145, 180)
    for _, card in pairs(heroCards) do
        card.Size = UDim2.new(0, cardWidth, 1, 0)
    end

    if cardContainer then
        cardContainer.ScrollBarThickness = isTouch and 2 or 4
    end
end

function HeroSelectUI._switchHero(heroId: string)
    if not canSelectHero or heroId == currentHeroId then
        return
    end

    if remotes and remotes.HeroSelect then
        remotes.HeroSelect:FireServer({ heroId = heroId })
    end

    currentHeroId = heroId
    HeroSelectUI._updateCurrentHeroDisplay()
    HeroSelectUI._closePanel()

    print("[HeroSelectUI] switch hero:", heroId)
end

function HeroSelectUI._updateCurrentHeroDisplay()
    if heroNameLabel then
        local heroData = HeroTable.getHero(currentHeroId)
        if heroData then
            local roleColor = ROLE_COLORS[heroData.role] or Color3.fromRGB(255, 220, 100)
            heroNameLabel.Text = heroData.name .. " (" .. (ROLE_NAMES[heroData.role] or heroData.role) .. ")"
            heroNameLabel.TextColor3 = roleColor
        else
            heroNameLabel.Text = "选择英雄"
            heroNameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        end
    end

    for heroId, card in pairs(heroCards) do
        local cardStroke = card:FindFirstChild("CardStroke")
        local currentTag = card:FindFirstChild("CurrentTag")
        local heroData = HeroTable.getHero(heroId)
        local roleColor = ROLE_COLORS[heroData and heroData.role or ""] or Color3.fromRGB(200, 200, 200)

        if heroId == currentHeroId then
            if cardStroke then
                cardStroke.Color = roleColor
                cardStroke.Thickness = 3
            end
            card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            if currentTag then
                currentTag.Text = "● 当前英雄"
                currentTag.Visible = true
                currentTag.TextColor3 = roleColor
            end
        else
            if cardStroke then
                cardStroke.Color = Color3.fromRGB(60, 60, 80)
                cardStroke.Thickness = 2
            end
            card.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
            if currentTag then
                currentTag.Visible = false
            end
        end
    end
end

function HeroSelectUI._openPanel()
    if isPanelOpen then
        return
    end

    isPanelOpen = true
    HeroSelectUI._applyResponsiveLayout()

    panelFrame.Visible = true
    panelFrame.BackgroundTransparency = 1
    TweenService:Create(panelFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.1,
    }):Play()

    if toggleButton then
        toggleButton.Text = "▲"
    end
end

function HeroSelectUI._closePanel()
    if not isPanelOpen then
        return
    end

    isPanelOpen = false

    local tween = TweenService:Create(panelFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = 1,
    })
    tween:Play()
    tween.Completed:Wait()
    panelFrame.Visible = false

    if toggleButton then
        toggleButton.Text = "▼"
    end
end

function HeroSelectUI.show()
    canSelectHero = true
    HeroSelectUI._openPanel()
end

function HeroSelectUI.hide()
    canSelectHero = false
    HeroSelectUI._closePanel()
end

function HeroSelectUI.getSelectedHeroId(): string?
    return currentHeroId
end

return HeroSelectUI
