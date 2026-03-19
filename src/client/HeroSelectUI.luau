--[[
    HeroSelectUI.luau
    英雄切换面板（常驻）
    
    功能：
    - 屏幕左上角常驻的英雄切换按钮
    - 点击展开英雄选择面板
    - 选择英雄后通过 HeroSwitch 立刻切换（重生新英雄）
    - 当前英雄高亮标记
    - 支持随时切换
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local HeroTable = require(shared:WaitForChild("HeroTable"))
local SkillTable = require(shared:WaitForChild("SkillTable"))

local HeroSelectUI = {}

local remotes = nil
local localPlayer = Players.LocalPlayer

-- UI 引用
local screenGui = nil
local toggleButton = nil
local panelFrame = nil
local heroNameLabel = nil

-- 状态
local currentHeroId = nil
local heroCards = {} -- { [heroId] = Frame }
local isPanelOpen = false
local canSelectHero = false

-- 英雄职业颜色
local ROLE_COLORS = {
    Marksman = Color3.fromRGB(255, 180, 50),
    Tank     = Color3.fromRGB(100, 180, 255),
    Mage     = Color3.fromRGB(180, 100, 255),
    Assassin = Color3.fromRGB(255, 80, 80),
    Support  = Color3.fromRGB(80, 220, 120),
}

-- 职业中文名
local ROLE_NAMES = {
    Marksman = "射手",
    Tank     = "坦克",
    Mage     = "法师",
    Assassin = "刺客",
    Support  = "辅助",
}

--============================================================
-- 初始化
--============================================================

function HeroSelectUI.init(remotesRef)
    remotes = remotesRef
    
    -- 创建 ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HeroSelectUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 50
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    
    -- 创建切换按钮（屏幕左上角）
    HeroSelectUI._createToggleButton()
    
    -- 创建英雄选择面板
    HeroSelectUI._createPanel()
    
    -- 监听技能栏更新来同步当前英雄ID
    if remotes.SkillBarUpdate then
        remotes.SkillBarUpdate.OnClientEvent:Connect(function(data)
            if data and data.action == "init" and data.heroId then
                currentHeroId = data.heroId
                HeroSelectUI._updateCurrentHeroDisplay()
            end
        end)
    end
    
    print("[HeroSelectUI] 初始化完成")
end

--============================================================
-- 切换按钮
--============================================================

function HeroSelectUI._createToggleButton()
    -- 容器
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "ToggleFrame"
    toggleFrame.Size = UDim2.new(0, 200, 0, 40)
    toggleFrame.Position = UDim2.new(0, 15, 0, 15)
    toggleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    toggleFrame.BackgroundTransparency = 0.15
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = screenGui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleFrame
    
    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(80, 80, 120)
    toggleStroke.Thickness = 1.5
    toggleStroke.Parent = toggleFrame
    
    -- 当前英雄名称标签
    heroNameLabel = Instance.new("TextLabel")
    heroNameLabel.Name = "HeroName"
    heroNameLabel.Size = UDim2.new(1, -50, 1, 0)
    heroNameLabel.Position = UDim2.new(0, 10, 0, 0)
    heroNameLabel.BackgroundTransparency = 1
    heroNameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    heroNameLabel.TextSize = 15
    heroNameLabel.Font = Enum.Font.GothamBold
    heroNameLabel.Text = "选择英雄"
    heroNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    heroNameLabel.Parent = toggleFrame
    
    -- 展开/收起按钮
    toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleBtn"
    toggleButton.Size = UDim2.new(0, 35, 0, 30)
    toggleButton.Position = UDim2.new(1, -40, 0.5, 0)
    toggleButton.AnchorPoint = Vector2.new(0, 0.5)
    toggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.TextSize = 16
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Text = "▼"
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = toggleFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleButton
    
    toggleButton.MouseButton1Click:Connect(function()
        if isPanelOpen then
            HeroSelectUI._closePanel()
        else
            HeroSelectUI._openPanel()
        end
    end)
    
    -- 悬停效果
    toggleFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(toggleStroke, TweenInfo.new(0.15), {
                Color = Color3.fromRGB(120, 120, 180)
            }):Play()
        end
    end)
    toggleFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(toggleStroke, TweenInfo.new(0.15), {
                Color = Color3.fromRGB(80, 80, 120)
            }):Play()
        end
    end)
end

--============================================================
-- 英雄选择面板
--============================================================

function HeroSelectUI._createPanel()
    panelFrame = Instance.new("Frame")
    panelFrame.Name = "HeroPanel"
    panelFrame.Size = UDim2.new(0, 600, 0, 260)
    panelFrame.Position = UDim2.new(0, 15, 0, 60)
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
    
    -- 标题
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "切换英雄（点击立刻切换）"
    titleLabel.Parent = panelFrame
    
    -- 英雄卡片容器
    local cardContainer = Instance.new("Frame")
    cardContainer.Name = "CardContainer"
    cardContainer.Size = UDim2.new(1, -20, 1, -45)
    cardContainer.Position = UDim2.new(0, 10, 0, 38)
    cardContainer.BackgroundTransparency = 1
    cardContainer.Parent = panelFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    listLayout.Padding = UDim.new(0, 12)
    listLayout.Parent = cardContainer
    
    -- 创建英雄卡片
    local heroIds = HeroTable.getAllHeroIds()
    for _, heroId in ipairs(heroIds) do
        local heroData = HeroTable.getHero(heroId)
        if heroData then
            HeroSelectUI._createHeroCard(cardContainer, heroData)
        end
    end
end

--============================================================
-- 英雄卡片
--============================================================

function HeroSelectUI._createHeroCard(parent, heroData)
    local heroId = heroData.id
    local roleColor = ROLE_COLORS[heroData.role] or Color3.fromRGB(200, 200, 200)
    local roleName = ROLE_NAMES[heroData.role] or heroData.role
    
    local card = Instance.new("TextButton")
    card.Name = "Card_" .. heroId
    card.Size = UDim2.new(0, 180, 1, 0)
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
    
    -- 当前英雄标记
    local currentTag = Instance.new("TextLabel")
    currentTag.Name = "CurrentTag"
    currentTag.Size = UDim2.new(1, 0, 0, 18)
    currentTag.Position = UDim2.new(0, 0, 0, 2)
    currentTag.BackgroundTransparency = 1
    currentTag.TextColor3 = Color3.fromRGB(100, 255, 100)
    currentTag.TextSize = 10
    currentTag.Font = Enum.Font.GothamBold
    currentTag.Text = ""
    currentTag.Visible = false
    currentTag.Parent = card
    
    -- 职业色条
    local roleBar = Instance.new("Frame")
    roleBar.Name = "RoleBar"
    roleBar.Size = UDim2.new(1, 0, 0, 3)
    roleBar.BackgroundColor3 = roleColor
    roleBar.BorderSizePixel = 0
    roleBar.Parent = card
    
    local roleBarCorner = Instance.new("UICorner")
    roleBarCorner.CornerRadius = UDim.new(0, 10)
    roleBarCorner.Parent = roleBar
    
    -- 英雄头像区域（用颜色块模拟）
    local avatarFrame = Instance.new("Frame")
    avatarFrame.Name = "Avatar"
    avatarFrame.Size = UDim2.new(0, 50, 0, 50)
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
    
    -- 英雄名字首字（正确处理 UTF-8 中文字符）
    local avatarText = Instance.new("TextLabel")
    avatarText.Size = UDim2.new(1, 0, 1, 0)
    avatarText.BackgroundTransparency = 1
    avatarText.TextColor3 = Color3.new(1, 1, 1)
    avatarText.TextSize = 20
    avatarText.Font = Enum.Font.GothamBlack
    -- UTF-8: 1个中文字符 = 3字节，用 utf8.offset 安全截取第1个字符
    local firstCharEnd = utf8.offset(heroData.name, 2) -- 第2个字符的起始位置
    if firstCharEnd then
        avatarText.Text = string.sub(heroData.name, 1, firstCharEnd - 1)
    else
        avatarText.Text = heroData.name -- fallback: 名字只有1个字符或为空
    end
    avatarText.Parent = avatarFrame
    
    -- 英雄名称
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
    
    -- 职业标签
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
    
    -- 属性概览
    local statsText = string.format(
        "HP:%d  MP:%d\nATK:%d  AP:%d\nDEF:%d  MR:%d",
        heroData.maxHP, heroData.maxMP,
        heroData.attackDamage, heroData.magicPower,
        heroData.armor, heroData.magicResist
    )
    
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Name = "Stats"
    statsLabel.Size = UDim2.new(1, -12, 0, 40)
    statsLabel.Position = UDim2.new(0, 6, 0, 114)
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    statsLabel.TextSize = 10
    statsLabel.Font = Enum.Font.Gotham
    statsLabel.Text = statsText
    statsLabel.TextXAlignment = Enum.TextXAlignment.Left
    statsLabel.TextYAlignment = Enum.TextYAlignment.Top
    statsLabel.Parent = card
    
    -- 技能列表
    local skillY = 158
    for _, key in ipairs({"Q", "W", "E", "R"}) do
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
    
    -- 点击事件 - 直接切换英雄
    card.MouseButton1Click:Connect(function()
        HeroSelectUI._switchHero(heroId)
    end)
    
    -- 悬停效果
    card.MouseEnter:Connect(function()
        if currentHeroId ~= heroId then
            TweenService:Create(cardStroke, TweenInfo.new(0.15), {
                Color = Color3.fromRGB(120, 120, 160)
            }):Play()
            TweenService:Create(card, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(38, 38, 55),
            }):Play()
        end
    end)
    
    card.MouseLeave:Connect(function()
        if currentHeroId ~= heroId then
            TweenService:Create(cardStroke, TweenInfo.new(0.15), {
                Color = Color3.fromRGB(60, 60, 80)
            }):Play()
            TweenService:Create(card, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.fromRGB(30, 30, 45),
            }):Play()
        end
    end)
    
    heroCards[heroId] = card
end

--============================================================
-- 英雄切换
--============================================================

function HeroSelectUI._switchHero(heroId: string)
    if not canSelectHero then return end
    if heroId == currentHeroId then return end -- 已经是当前英雄
    
    -- 发送切换请求到服务端
    if remotes and remotes.HeroSelect then
        remotes.HeroSelect:FireServer({ heroId = heroId })
    end
    
    -- 本地更新（不等服务端回应，先更新UI）
    currentHeroId = heroId
    HeroSelectUI._updateCurrentHeroDisplay()
    
    -- 关闭面板
    HeroSelectUI._closePanel()
    
    print("[HeroSelectUI] 切换英雄: " .. heroId)
end

--============================================================
-- 更新当前英雄显示
--============================================================

function HeroSelectUI._updateCurrentHeroDisplay()
    -- 更新顶部标签
    if heroNameLabel then
        local heroData = HeroTable.getHero(currentHeroId)
        if heroData then
            local roleColor = ROLE_COLORS[heroData.role] or Color3.fromRGB(255, 220, 100)
            heroNameLabel.Text = heroData.name .. " (" .. (ROLE_NAMES[heroData.role] or heroData.role) .. ")"
            heroNameLabel.TextColor3 = roleColor
        end
    end
    
    -- 更新卡片高亮
    for heroId, card in pairs(heroCards) do
        local cardStroke = card:FindFirstChild("CardStroke")
        local currentTag = card:FindFirstChild("CurrentTag")
        local heroData = HeroTable.getHero(heroId)
        local roleColor = ROLE_COLORS[heroData and heroData.role or ""] or Color3.fromRGB(200, 200, 200)
        
        if heroId == currentHeroId then
            -- 当前英雄高亮
            if cardStroke then
                cardStroke.Color = roleColor
                cardStroke.Thickness = 3
            end
            card.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
            if currentTag then
                currentTag.Text = "◆ 当前英雄"
                currentTag.Visible = true
                currentTag.TextColor3 = roleColor
            end
        else
            -- 非当前英雄
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

--============================================================
-- 面板展开/收起
--============================================================

function HeroSelectUI._openPanel()
    if isPanelOpen then return end
    isPanelOpen = true
    
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
    if not isPanelOpen then return end
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

--============================================================
-- 公开接口
--============================================================

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
