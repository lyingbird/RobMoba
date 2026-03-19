--[[
    HealthBarUI.luau
    血条/蓝条 UI
    
    两部分：
    1. 屏幕 HUD：显示自己的血条 + 蓝条 + 数值
    2. 头顶 BillboardGui：显示所有角色的血条和名字
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HealthBarUI = {}

local remotes = nil
local localPlayer = Players.LocalPlayer

-- 加载游戏配置获取友敌颜色
local shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(shared:WaitForChild("GameConfig"))

-- UI 引用
local screenGui = nil
local hudFrame = nil
local hpBar, hpLabel, mpBar, mpLabel = nil, nil, nil, nil

-- 头顶血条缓存: { [Model] = BillboardGui }
local overheadBars = {}

--============================================================
-- 初始化
--============================================================

function HealthBarUI.init(remotesRef)
    remotes = remotesRef
    
    -- 创建 ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HealthBarUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    
    -- 创建 HUD 血蓝条
    HealthBarUI._createHUD()
    
    -- 更新循环
    RunService.RenderStepped:Connect(function()
        HealthBarUI._updateHUD()
        HealthBarUI._updateOverheadBars()
    end)
    
    -- 监听角色
    localPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        HealthBarUI._setupOverheadBar(character)
    end)
    
    -- 监听其他玩家
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            HealthBarUI._setupOverheadBar(character)
        end)
    end)
    
    -- 初始化现有角色（仅处理已有角色，不重复绑定 CharacterAdded）
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            if player.Character then
                HealthBarUI._setupOverheadBar(player.Character)
            end
            -- 对 init 时已存在但之后可能重生的玩家绑定 CharacterAdded
            -- 注意：PlayerAdded 只对 init 之后加入的玩家生效，所以这里需要绑定
            player.CharacterAdded:Connect(function(character)
                task.wait(0.5)
                HealthBarUI._setupOverheadBar(character)
            end)
        end
    end
    
    print("[HealthBarUI] 初始化完成")
end

--============================================================
-- HUD 血蓝条
--============================================================

function HealthBarUI._createHUD()
    hudFrame = Instance.new("Frame")
    hudFrame.Name = "HealthHUD"
    hudFrame.Size = UDim2.new(0, 250, 0, 50)
    hudFrame.Position = UDim2.new(0.5, 0, 1, -130)
    hudFrame.AnchorPoint = Vector2.new(0.5, 1)
    hudFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    hudFrame.BackgroundTransparency = 0.3
    hudFrame.BorderSizePixel = 0
    hudFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = hudFrame
    
    -- 血条背景
    local hpBg = Instance.new("Frame")
    hpBg.Name = "HPBg"
    hpBg.Size = UDim2.new(1, -20, 0, 18)
    hpBg.Position = UDim2.new(0, 10, 0, 6)
    hpBg.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
    hpBg.BorderSizePixel = 0
    hpBg.Parent = hudFrame
    
    local hpBgCorner = Instance.new("UICorner")
    hpBgCorner.CornerRadius = UDim.new(0, 4)
    hpBgCorner.Parent = hpBg
    
    hpBar = Instance.new("Frame")
    hpBar.Name = "HPBar"
    hpBar.Size = UDim2.new(1, 0, 1, 0)
    hpBar.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    hpBar.BorderSizePixel = 0
    hpBar.Parent = hpBg
    
    local hpBarCorner = Instance.new("UICorner")
    hpBarCorner.CornerRadius = UDim.new(0, 4)
    hpBarCorner.Parent = hpBar
    
    hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "HPLabel"
    hpLabel.Size = UDim2.new(1, 0, 1, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = Color3.new(1, 1, 1)
    hpLabel.TextSize = 12
    hpLabel.Font = Enum.Font.GothamBold
    hpLabel.Text = "0 / 0"
    hpLabel.ZIndex = 2
    hpLabel.Parent = hpBg
    
    -- 蓝条背景
    local mpBg = Instance.new("Frame")
    mpBg.Name = "MPBg"
    mpBg.Size = UDim2.new(1, -20, 0, 12)
    mpBg.Position = UDim2.new(0, 10, 0, 28)
    mpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 60)
    mpBg.BorderSizePixel = 0
    mpBg.Parent = hudFrame
    
    local mpBgCorner = Instance.new("UICorner")
    mpBgCorner.CornerRadius = UDim.new(0, 3)
    mpBgCorner.Parent = mpBg
    
    mpBar = Instance.new("Frame")
    mpBar.Name = "MPBar"
    mpBar.Size = UDim2.new(1, 0, 1, 0)
    mpBar.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
    mpBar.BorderSizePixel = 0
    mpBar.Parent = mpBg
    
    local mpBarCorner = Instance.new("UICorner")
    mpBarCorner.CornerRadius = UDim.new(0, 3)
    mpBarCorner.Parent = mpBar
    
    mpLabel = Instance.new("TextLabel")
    mpLabel.Name = "MPLabel"
    mpLabel.Size = UDim2.new(1, 0, 1, 0)
    mpLabel.BackgroundTransparency = 1
    mpLabel.TextColor3 = Color3.new(1, 1, 1)
    mpLabel.TextSize = 10
    mpLabel.Font = Enum.Font.GothamBold
    mpLabel.Text = "0 / 0"
    mpLabel.ZIndex = 2
    mpLabel.Parent = mpBg
end

function HealthBarUI._updateHUD()
    local character = localPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- 血条
    local hp = humanoid.Health
    local maxHP = humanoid.MaxHealth
    local hpRatio = maxHP > 0 and math.clamp(hp / maxHP, 0, 1) or 0
    
    if hpBar then
        hpBar.Size = UDim2.new(hpRatio, 0, 1, 0)
        -- 颜色渐变
        if hpRatio > 0.5 then
            hpBar.BackgroundColor3 = Color3.fromRGB(50, 200, 80):Lerp(Color3.fromRGB(220, 220, 50), (1 - hpRatio) * 2)
        else
            hpBar.BackgroundColor3 = Color3.fromRGB(220, 220, 50):Lerp(Color3.fromRGB(220, 50, 50), (0.5 - hpRatio) * 2)
        end
    end
    if hpLabel then
        hpLabel.Text = string.format("%d / %d", math.floor(hp), math.floor(maxHP))
    end
    
    -- 蓝条
    local mpValue = character:FindFirstChild("MP")
    local maxMPValue = character:FindFirstChild("MaxMP")
    if mpValue and maxMPValue and mpBar and mpLabel then
        local mp = mpValue.Value
        local maxMP2 = maxMPValue.Value
        local mpRatio = maxMP2 > 0 and math.clamp(mp / maxMP2, 0, 1) or 0
        mpBar.Size = UDim2.new(mpRatio, 0, 1, 0)
        mpLabel.Text = string.format("%d / %d", math.floor(mp), math.floor(maxMP2))
    end
end

--============================================================
-- 头顶血条
--============================================================

function HealthBarUI._setupOverheadBar(character)
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head then return end
    
    -- 清理旧的
    if overheadBars[character] then
        overheadBars[character]:Destroy()
    end
    
    -- 不给自己添加头顶血条（用 HUD 代替）
    local player = Players:GetPlayerFromCharacter(character)
    if player == localPlayer then return end
    
    -- 判断友敌
    local isFriendly = false
    if player and localPlayer.Team and player.Team then
        isFriendly = (localPlayer.Team == player.Team)
    end
    
    local nameColor
    local barDefaultColor
    if isFriendly then
        nameColor = GameConfig.Team.FriendlyColor
        barDefaultColor = GameConfig.Team.FriendlyColor
    else
        nameColor = GameConfig.Team.EnemyColor
        barDefaultColor = GameConfig.Team.EnemyColor
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "OverheadHealth"
    billboard.Adornee = head
    billboard.Size = UDim2.new(4, 0, 0.5, 0)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head
    
    -- 名字
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = nameColor
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.TextScaled = true
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = character.Name
    nameLabel.Parent = billboard
    
    -- 血条背景
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(1, 0, 0.4, 0)
    barBg.Position = UDim2.new(0, 0, 0.55, 0)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    barBg.BorderSizePixel = 0
    barBg.Parent = billboard
    
    local barBgCorner = Instance.new("UICorner")
    barBgCorner.CornerRadius = UDim.new(0, 2)
    barBgCorner.Parent = barBg
    
    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = barDefaultColor
    bar.BorderSizePixel = 0
    bar.Parent = barBg
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 2)
    barCorner.Parent = bar
    
    -- 标记友敌（用于更新时着色）
    local friendlyTag = Instance.new("BoolValue")
    friendlyTag.Name = "IsFriendly"
    friendlyTag.Value = isFriendly
    friendlyTag.Parent = billboard
    
    overheadBars[character] = billboard
    
    -- 角色移除时清理
    character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            overheadBars[character] = nil
        end
    end)
end

function HealthBarUI._updateOverheadBars()
    for character, billboard in pairs(overheadBars) do
        if not character or not character.Parent then
            overheadBars[character] = nil
            continue
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then continue end
        
        local barBg = billboard:FindFirstChild("BarBg")
        if not barBg then continue end
        local bar = barBg:FindFirstChild("Bar")
        if not bar then continue end
        
        local ratio = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
        bar.Size = UDim2.new(ratio, 0, 1, 0)
        
        -- 根据友敌关系和血量设置颜色
        local friendlyTag = billboard:FindFirstChild("IsFriendly")
        local isFriendly = friendlyTag and friendlyTag.Value or false
        
        if isFriendly then
            -- 友军：绿→黄→红 渐变
            if ratio > 0.5 then
                bar.BackgroundColor3 = Color3.fromRGB(50, 200, 80):Lerp(Color3.fromRGB(220, 220, 50), (1 - ratio) * 2)
            else
                bar.BackgroundColor3 = Color3.fromRGB(220, 220, 50):Lerp(Color3.fromRGB(220, 50, 50), (0.5 - ratio) * 2)
            end
        else
            -- 敌方：固定红色系
            bar.BackgroundColor3 = Color3.fromRGB(220, 50, 50):Lerp(Color3.fromRGB(180, 30, 30), (1 - ratio))
        end
    end
end

return HealthBarUI
