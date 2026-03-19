--[[
    CombatUI.luau
    战斗提示 UI
    
    功能：
    - 浮动伤害数字（从受击位置飘起渐隐）
    - 击杀/被击杀全屏提示
    - 复活倒计时居中显示
    - 击杀信息流
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local CombatUI = {}

local remotes = nil
local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- UI 引用
local screenGui = nil
local killFeedContainer = nil
local respawnFrame = nil
local respawnLabel = nil

-- 持续施法进度条
local channelBarFrame = nil
local channelBarFill = nil
local channelBarLabel = nil

-- 伤害数字颜色
local DAMAGE_COLORS = {
    Physical = Color3.fromRGB(255, 200, 100),
    Magic    = Color3.fromRGB(180, 100, 255),
    True     = Color3.fromRGB(255, 255, 255),
}

--============================================================
-- 初始化
--============================================================

function CombatUI.init(remotesRef)
    remotes = remotesRef
    
    -- 创建 ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CombatUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    
    -- 击杀信息流容器
    killFeedContainer = Instance.new("Frame")
    killFeedContainer.Name = "KillFeed"
    killFeedContainer.Size = UDim2.new(0, 300, 0, 200)
    killFeedContainer.Position = UDim2.new(1, -10, 0, 80)
    killFeedContainer.AnchorPoint = Vector2.new(1, 0)
    killFeedContainer.BackgroundTransparency = 1
    killFeedContainer.Parent = screenGui
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    listLayout.Parent = killFeedContainer
    
    -- 复活倒计时
    respawnFrame = Instance.new("Frame")
    respawnFrame.Name = "RespawnOverlay"
    respawnFrame.Size = UDim2.new(1, 0, 1, 0)
    respawnFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    respawnFrame.BackgroundTransparency = 0.5
    respawnFrame.Visible = false
    respawnFrame.ZIndex = 10
    respawnFrame.Parent = screenGui
    
    respawnLabel = Instance.new("TextLabel")
    respawnLabel.Name = "RespawnLabel"
    respawnLabel.Size = UDim2.new(0.5, 0, 0, 80)
    respawnLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
    respawnLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    respawnLabel.BackgroundTransparency = 1
    respawnLabel.TextColor3 = Color3.new(1, 1, 1)
    respawnLabel.TextSize = 36
    respawnLabel.Font = Enum.Font.GothamBold
    respawnLabel.Text = ""
    respawnLabel.ZIndex = 11
    respawnLabel.Parent = respawnFrame
    
    -- 监听事件
    if remotes.DamageDealt then
        remotes.DamageDealt.OnClientEvent:Connect(function(data)
            CombatUI._showDamageNumber(data)
        end)
    end
    
    if remotes.TargetDied then
        remotes.TargetDied.OnClientEvent:Connect(function(data)
            CombatUI._onTargetDied(data)
        end)
    end
    
    if remotes.KillFeed then
        remotes.KillFeed.OnClientEvent:Connect(function(data)
            CombatUI._addKillFeedEntry(data)
        end)
    end
    
    if remotes.HeroRespawned then
        remotes.HeroRespawned.OnClientEvent:Connect(function(data)
            if data and data.playerName == localPlayer.Name then
                respawnFrame.Visible = false
            end
        end)
    end
    
    -- 创建持续施法进度条 UI
    CombatUI._createChannelBar()
    
    -- 监听持续施法进度条更新
    if remotes.ChannelBarUpdate then
        remotes.ChannelBarUpdate.OnClientEvent:Connect(function(data)
            CombatUI._onChannelBarUpdate(data)
        end)
    end
    
    print("[CombatUI] 初始化完成")
end

--============================================================
-- 浮动伤害数字
--============================================================

function CombatUI._showDamageNumber(data)
    if not data or not data.position or not data.amount then return end
    if data.amount <= 0 then return end
    
    local worldPos = data.position
    local damageType = data.damageType or "Physical"
    local amount = math.floor(data.amount)
    
    -- 创建 BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(3, 0, 1, 0)
    billboard.StudsOffset = Vector3.new(math.random(-10, 10) / 10, 0, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = nil
    billboard.Parent = screenGui
    
    -- 使用 Part 作为 Adornee（临时锚点）
    local anchor = Instance.new("Part")
    anchor.Size = Vector3.new(0.1, 0.1, 0.1)
    anchor.Position = worldPos
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Parent = workspace
    billboard.Adornee = anchor
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = DAMAGE_COLORS[damageType] or DAMAGE_COLORS.Physical
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.3
    label.TextScaled = true
    label.Font = Enum.Font.GothamBlack
    label.Text = tostring(amount)
    label.Parent = billboard
    
    -- 动画：上飘 + 渐隐
    local startPos = worldPos
    local elapsed = 0
    local duration = 1.0
    
    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        elapsed += dt
        if elapsed >= duration then
            if connection then connection:Disconnect() end
            billboard:Destroy()
            anchor:Destroy()
            return
        end
        
        local t = elapsed / duration
        anchor.Position = startPos + Vector3.new(0, t * 3, 0)
        label.TextTransparency = t
        label.TextStrokeTransparency = 0.3 + t * 0.7
    end)
end

--============================================================
-- 死亡 / 复活
--============================================================

function CombatUI._onTargetDied(data)
    if not data then return end
    
    -- 如果是本地玩家死亡，显示复活倒计时
    local targetModel = data.targetModel
    if targetModel then
        local player = Players:GetPlayerFromCharacter(targetModel)
        if player == localPlayer then
            local respawnTime = data.respawnTime or 5
            CombatUI._showRespawnCountdown(respawnTime)
        end
    end
end

function CombatUI._showRespawnCountdown(respawnTime)
    respawnFrame.Visible = true
    
    task.spawn(function()
        local remaining = respawnTime
        while remaining > 0 do
            respawnLabel.Text = string.format("复活倒计时: %.1f", remaining)
            task.wait(0.1)
            remaining -= 0.1
        end
        respawnLabel.Text = "复活中..."
        task.wait(0.5)
        respawnFrame.Visible = false
    end)
end

--============================================================
-- 击杀信息流
--============================================================

function CombatUI._addKillFeedEntry(data)
    if not data then return end
    
    local entry = Instance.new("Frame")
    entry.Size = UDim2.new(1, 0, 0, 24)
    entry.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    entry.BackgroundTransparency = 0.5
    entry.BorderSizePixel = 0
    entry.Parent = killFeedContainer
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = entry
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -8, 1, 0)
    text.Position = UDim2.new(0, 4, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.TextSize = 13
    text.Font = Enum.Font.Gotham
    text.TextXAlignment = Enum.TextXAlignment.Right
    text.Text = string.format("%s 击杀了 %s", data.killerName or "?", data.victimName or "?")
    text.TextTruncate = Enum.TextTruncate.AtEnd
    text.Parent = entry
    
    -- 5秒后淡出
    task.delay(5, function()
        local tween = TweenService:Create(entry, TweenInfo.new(0.5), {
            BackgroundTransparency = 1,
        })
        local textTween = TweenService:Create(text, TweenInfo.new(0.5), {
            TextTransparency = 1,
        })
        tween:Play()
        textTween:Play()
        textTween.Completed:Wait()
        entry:Destroy()
    end)
end

--============================================================
-- 持续施法进度条
--============================================================

function CombatUI._createChannelBar()
    -- 进度条容器（屏幕中央偏下，角色头顶区域）
    channelBarFrame = Instance.new("Frame")
    channelBarFrame.Name = "ChannelBarFrame"
    channelBarFrame.Size = UDim2.new(0, 200, 0, 16)
    channelBarFrame.Position = UDim2.new(0.5, 0, 0.65, 0)
    channelBarFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    channelBarFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    channelBarFrame.BorderSizePixel = 0
    channelBarFrame.Visible = false
    channelBarFrame.ZIndex = 5
    channelBarFrame.Parent = screenGui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 6)
    frameCorner.Parent = channelBarFrame
    
    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(160, 80, 255)
    frameStroke.Thickness = 2
    frameStroke.Parent = channelBarFrame
    
    -- 进度条填充
    channelBarFill = Instance.new("Frame")
    channelBarFill.Name = "Fill"
    channelBarFill.Size = UDim2.new(0, 0, 1, -4)
    channelBarFill.Position = UDim2.new(0, 2, 0, 2)
    channelBarFill.BackgroundColor3 = Color3.fromRGB(160, 80, 255)
    channelBarFill.BorderSizePixel = 0
    channelBarFill.ZIndex = 6
    channelBarFill.Parent = channelBarFrame
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = channelBarFill
    
    -- 进度文字
    channelBarLabel = Instance.new("TextLabel")
    channelBarLabel.Name = "ChannelLabel"
    channelBarLabel.Size = UDim2.new(1, 0, 1, 0)
    channelBarLabel.BackgroundTransparency = 1
    channelBarLabel.TextColor3 = Color3.new(1, 1, 1)
    channelBarLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    channelBarLabel.TextStrokeTransparency = 0.3
    channelBarLabel.TextSize = 11
    channelBarLabel.Font = Enum.Font.GothamBold
    channelBarLabel.Text = ""
    channelBarLabel.ZIndex = 7
    channelBarLabel.Parent = channelBarFrame
end

function CombatUI._onChannelBarUpdate(data)
    if not data then return end
    if not channelBarFrame then return end
    
    local progress = data.progress or 0
    local maxDuration = data.maxDuration or 0
    
    -- progress == 0 且 maxDuration == 0 表示施法结束
    if maxDuration <= 0 then
        channelBarFrame.Visible = false
        return
    end
    
    -- 显示进度条
    channelBarFrame.Visible = true
    
    -- 更新填充
    local ratio = math.clamp(progress, 0, 1)
    local fillWidth = 196 * ratio  -- 200 - 4(两侧padding)
    channelBarFill.Size = UDim2.new(0, fillWidth, 1, -4)
    
    -- 更新文字
    local remaining = maxDuration * (1 - progress)
    channelBarLabel.Text = string.format("施法中 %.1fs", remaining)
    
    -- 颜色渐变：紫色→金色
    local r = math.floor(160 + 95 * ratio)
    local g = math.floor(80 + 150 * ratio)
    local b = math.floor(255 - 200 * ratio)
    channelBarFill.BackgroundColor3 = Color3.fromRGB(r, g, b)
    
    -- 施法完成
    if progress >= 1 then
        channelBarLabel.Text = "完成!"
        task.delay(0.5, function()
            if channelBarFrame then
                channelBarFrame.Visible = false
            end
        end)
    end
end

return CombatUI
