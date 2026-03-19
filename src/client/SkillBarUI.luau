--[[
    SkillBarUI.luau
    技能栏 HUD
    
    底部居中显示 4 格技能栏：
    - 技能图标背景色区分类型
    - 按键提示 (Q/W/E/R)
    - 冷却遮罩动画
    - 法力消耗文字
    - 技能名称
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SkillBarUI = {}

local remotes = nil
local localPlayer = Players.LocalPlayer
local InputHandler = require(script.Parent:WaitForChild("InputHandler"))

-- UI 引用
local screenGui = nil
local skillSlots = {} -- { [key] = { frame, cooldownOverlay, cdLabel, ... } }

-- 技能数据
local skillData = {} -- { [key] = { id, name, cooldown, manaCost, castType } }

-- 冷却状态
local cooldowns = {} -- { [skillId] = { endTime, totalTime } }

-- 战意条引用
local zhanYiBar = nil
local zhanYiLabel = nil
local zhanYiFrame = nil

-- 配置
local SLOT_SIZE = 70
local SLOT_SPACING = 10
local KEYS = { "Q", "W", "E", "R" }
local HITBOX_PADDING_Y = 6
local HITBOX_EXTRA_HEIGHT = 14

-- 技能类型颜色
local TYPE_COLORS = {
    Instant   = Color3.fromRGB(80, 180, 80),
    Direction = Color3.fromRGB(80, 130, 255),
    Position  = Color3.fromRGB(255, 150, 50),
    Channel   = Color3.fromRGB(180, 80, 255),
    Passive   = Color3.fromRGB(120, 120, 120),
}

-- 技能类型图标符号
local TYPE_ICONS = {
    Instant   = "⚡",
    Direction = "➤",
    Position  = "◎",
    Channel   = "≋",
    Passive   = "★",
}

--============================================================
-- 初始化
--============================================================

function SkillBarUI.init(remotesRef)
    remotes = remotesRef
    
    -- 创建 ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SkillBarUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    
    -- 创建技能栏容器
    local container = Instance.new("Frame")
    container.Name = "SkillBar"
    container.Size = UDim2.new(0, (SLOT_SIZE + SLOT_SPACING) * 4 - SLOT_SPACING, 0, SLOT_SIZE + 30)
    container.Position = UDim2.new(0.5, 0, 1, -25)
    container.AnchorPoint = Vector2.new(0.5, 1)
    container.BackgroundTransparency = 1
    container.Parent = screenGui
    
    -- 创建 4 个技能槽
    for i, key in ipairs(KEYS) do
        SkillBarUI._createSlot(container, key, i)
    end
    
    -- 监听冷却更新
    if remotes.CooldownUpdate then
        remotes.CooldownUpdate.OnClientEvent:Connect(function(data)
            SkillBarUI._onCooldownUpdate(data)
        end)
    end
    
    -- 监听技能栏初始化
    if remotes.SkillBarUpdate then
        remotes.SkillBarUpdate.OnClientEvent:Connect(function(data)
            SkillBarUI._onSkillBarUpdate(data)
        end)
    end
    
    -- 监听战意值更新（廉颇专属）
    if remotes.ZhanYiUpdate then
        remotes.ZhanYiUpdate.OnClientEvent:Connect(function(data)
            SkillBarUI._onZhanYiUpdate(data)
        end)
    end
    
    -- 创建战意条 UI（初始隐藏，选廉颇后显示）
    SkillBarUI._createZhanYiBar(container)
    
    -- 启动冷却更新循环
    task.spawn(function()
        while true do
            SkillBarUI._updateCooldowns()
            task.wait(0.05)
        end
    end)
    
    print("[SkillBarUI] 初始化完成")
end

--============================================================
-- 创建技能槽
--============================================================

function SkillBarUI._createSlot(parent, key, index)
    local x = (index - 1) * (SLOT_SIZE + SLOT_SPACING)
    
    -- 主框架
    local frame = Instance.new("Frame")
    frame.Name = "Slot_" .. key
    frame.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
    frame.Position = UDim2.new(0, x, 0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    
    -- 圆角
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    
    -- 描边
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 80, 100)
    stroke.Thickness = 2
    stroke.Parent = frame
    
    -- 技能类型色块背景（填充整个槽位上半部分作为"图标"）
    local iconBg = Instance.new("Frame")
    iconBg.Name = "IconBg"
    iconBg.Size = UDim2.new(1, -6, 0, 36)
    iconBg.Position = UDim2.new(0, 3, 0, 3)
    iconBg.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    iconBg.BorderSizePixel = 0
    iconBg.Parent = frame
    
    local iconBgCorner = Instance.new("UICorner")
    iconBgCorner.CornerRadius = UDim.new(0, 6)
    iconBgCorner.Parent = iconBg
    
    -- 技能类型符号（大图标）
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name = "IconLabel"
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.TextColor3 = Color3.new(1, 1, 1)
    iconLabel.TextSize = 22
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.Text = ""
    iconLabel.Parent = iconBg
    
    -- 技能名称（底部小字）
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "SkillName"
    nameLabel.Size = UDim2.new(1, -4, 0, 14)
    nameLabel.Position = UDim2.new(0, 2, 0, 40)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    nameLabel.TextSize = 10
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = ""
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = frame
    
    -- 法力消耗（右下角小字）
    local manaLabel = Instance.new("TextLabel")
    manaLabel.Name = "ManaCost"
    manaLabel.Size = UDim2.new(1, -4, 0, 12)
    manaLabel.Position = UDim2.new(0, 2, 1, -14)
    manaLabel.BackgroundTransparency = 1
    manaLabel.TextColor3 = Color3.fromRGB(100, 160, 255)
    manaLabel.TextSize = 9
    manaLabel.Font = Enum.Font.Gotham
    manaLabel.Text = ""
    manaLabel.Parent = frame
    
    -- 冷却遮罩
    local cooldownOverlay = Instance.new("Frame")
    cooldownOverlay.Name = "CooldownOverlay"
    cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
    cooldownOverlay.Position = UDim2.new(0, 0, 1, 0)
    cooldownOverlay.AnchorPoint = Vector2.new(0, 1)
    cooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    cooldownOverlay.BackgroundTransparency = 0.4
    cooldownOverlay.BorderSizePixel = 0
    cooldownOverlay.ZIndex = 2
    cooldownOverlay.Visible = false
    cooldownOverlay.Parent = frame
    
    local cdCorner = Instance.new("UICorner")
    cdCorner.CornerRadius = UDim.new(0, 10)
    cdCorner.Parent = cooldownOverlay
    
    -- 冷却时间文字
    local cdLabel = Instance.new("TextLabel")
    cdLabel.Name = "CDLabel"
    cdLabel.Size = UDim2.new(1, 0, 1, 0)
    cdLabel.BackgroundTransparency = 1
    cdLabel.TextColor3 = Color3.new(1, 1, 1)
    cdLabel.TextSize = 22
    cdLabel.Font = Enum.Font.GothamBold
    cdLabel.Text = ""
    cdLabel.ZIndex = 3
    cdLabel.Visible = false
    cdLabel.Parent = frame
    
    -- 按键提示（底部标签）
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Name = "KeyLabel"
    keyLabel.Size = UDim2.new(0, SLOT_SIZE, 0, 20)
    keyLabel.Position = UDim2.new(0, x, 0, SLOT_SIZE + 4)
    keyLabel.BackgroundTransparency = 1
    keyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    keyLabel.TextSize = 14
    keyLabel.Font = Enum.Font.GothamBold
    keyLabel.Text = key
    keyLabel.Parent = parent

    -- Transparent forgiving hit area that also covers the nearby gap and key label.
    local hitArea = Instance.new("TextButton")
    hitArea.Name = "HitArea_" .. key
    hitArea.Size = UDim2.new(0, SLOT_SIZE + SLOT_SPACING, 0, SLOT_SIZE + 20 + HITBOX_EXTRA_HEIGHT)
    hitArea.Position = UDim2.new(0, x - (SLOT_SPACING / 2), 0, -HITBOX_PADDING_Y)
    hitArea.BackgroundTransparency = 1
    hitArea.BorderSizePixel = 0
    hitArea.AutoButtonColor = false
    hitArea.Text = ""
    hitArea.ZIndex = 4
    hitArea.Parent = parent

    hitArea.Activated:Connect(function()
        InputHandler.triggerSkillKey(key)
    end)
    
    skillSlots[key] = {
        frame = frame,
        iconBg = iconBg,
        iconLabel = iconLabel,
        nameLabel = nameLabel,
        manaLabel = manaLabel,
        cooldownOverlay = cooldownOverlay,
        cdLabel = cdLabel,
        keyLabel = keyLabel,
        hitArea = hitArea,
        stroke = stroke,
    }
end

--============================================================
-- 技能栏更新
--============================================================

function SkillBarUI._onSkillBarUpdate(data)
    if not data then return end
    
    if data.action == "init" and data.skills then
        skillData = {}
        for key, skill in pairs(data.skills) do
            skillData[key] = skill
            SkillBarUI._updateSlotDisplay(key, skill)
        end
    elseif data.action == "replace" and data.key then
        -- 技能替换
        if data.newSkillId then
            -- 简化：标记替换
            local slot = skillSlots[data.key]
            if slot then
                slot.nameLabel.Text = "取消"
                slot.frame.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            end
        end
    elseif data.action == "revert" and data.key then
        -- 恢复
        local skill = skillData[data.key]
        if skill then
            SkillBarUI._updateSlotDisplay(data.key, skill)
        end
    end
end

function SkillBarUI._updateSlotDisplay(key, skill)
    local slot = skillSlots[key]
    if not slot then return end
    
    slot.nameLabel.Text = skill.name or ""
    
    if skill.manaCost and skill.manaCost > 0 then
        slot.manaLabel.Text = tostring(skill.manaCost) .. " MP"
    else
        slot.manaLabel.Text = ""
    end
    
    -- 类型颜色和图标
    local typeColor = TYPE_COLORS[skill.castType] or Color3.fromRGB(80, 80, 80)
    -- 优先使用技能专属图标，否则回退到类型通用图标
    local displayIcon = skill.icon or TYPE_ICONS[skill.castType] or "?"
    
    slot.iconBg.BackgroundColor3 = Color3.new(
        typeColor.R * 0.4,
        typeColor.G * 0.4,
        typeColor.B * 0.4
    )
    slot.iconLabel.Text = displayIcon
    slot.iconLabel.TextColor3 = typeColor
    slot.stroke.Color = typeColor
    
    -- 被动技能灰色
    if skill.castType == "Passive" then
        slot.frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        slot.nameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        slot.iconLabel.TextTransparency = 0.3
    else
        slot.frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        slot.nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        slot.iconLabel.TextTransparency = 0
    end
end

--============================================================
-- 冷却更新
--============================================================

function SkillBarUI._onCooldownUpdate(data)
    if not data or not data.skillId then return end
    
    cooldowns[data.skillId] = {
        endTime = tick() + (data.cooldownTime or 0),
        totalTime = data.cooldownTime or 0,
    }
end

function SkillBarUI._updateCooldowns()
    local now = tick()
    
    for key, skill in pairs(skillData) do
        local slot = skillSlots[key]
        if not slot then continue end
        
        local cd = cooldowns[skill.id]
        if cd and cd.endTime > now then
            local remaining = cd.endTime - now
            local ratio = remaining / cd.totalTime
            
            slot.cooldownOverlay.Visible = true
            slot.cooldownOverlay.Size = UDim2.new(1, 0, ratio, 0)
            slot.cdLabel.Visible = true
            slot.cdLabel.Text = string.format("%.1f", remaining)
        else
            slot.cooldownOverlay.Visible = false
            slot.cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
            slot.cdLabel.Visible = false
            slot.cdLabel.Text = ""
        end
    end
end

--============================================================
-- 廉颇战意条
--============================================================

function SkillBarUI._createZhanYiBar(container)
    -- 战意条框架（位于 R 槽位上方）
    local totalWidth = (SLOT_SIZE + SLOT_SPACING) * 4 - SLOT_SPACING
    
    zhanYiFrame = Instance.new("Frame")
    zhanYiFrame.Name = "ZhanYiFrame"
    zhanYiFrame.Size = UDim2.new(0, totalWidth, 0, 12)
    zhanYiFrame.Position = UDim2.new(0, 0, 0, -18)
    zhanYiFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    zhanYiFrame.BorderSizePixel = 0
    zhanYiFrame.Visible = false
    zhanYiFrame.Parent = container
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 4)
    frameCorner.Parent = zhanYiFrame
    
    local frameStroke = Instance.new("UIStroke")
    frameStroke.Color = Color3.fromRGB(180, 100, 40)
    frameStroke.Thickness = 1
    frameStroke.Parent = zhanYiFrame
    
    -- 战意进度条（橙色→红色渐变）
    zhanYiBar = Instance.new("Frame")
    zhanYiBar.Name = "ZhanYiBar"
    zhanYiBar.Size = UDim2.new(0, 0, 1, -2)
    zhanYiBar.Position = UDim2.new(0, 1, 0, 1)
    zhanYiBar.BackgroundColor3 = Color3.fromRGB(220, 120, 30)
    zhanYiBar.BorderSizePixel = 0
    zhanYiBar.Parent = zhanYiFrame
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 3)
    barCorner.Parent = zhanYiBar
    
    -- 战意文字标签
    zhanYiLabel = Instance.new("TextLabel")
    zhanYiLabel.Name = "ZhanYiLabel"
    zhanYiLabel.Size = UDim2.new(1, 0, 1, 0)
    zhanYiLabel.BackgroundTransparency = 1
    zhanYiLabel.TextColor3 = Color3.new(1, 1, 1)
    zhanYiLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    zhanYiLabel.TextStrokeTransparency = 0.3
    zhanYiLabel.TextSize = 9
    zhanYiLabel.Font = Enum.Font.GothamBold
    zhanYiLabel.Text = "战意 0/100"
    zhanYiLabel.ZIndex = 2
    zhanYiLabel.Parent = zhanYiFrame
end

function SkillBarUI._onZhanYiUpdate(data)
    if not data then return end
    if not zhanYiFrame then return end
    
    -- 只对本地玩家的角色显示
    local targetModel = data.playerModel
    if not targetModel then return end
    local player = Players:GetPlayerFromCharacter(targetModel)
    if player ~= localPlayer then return end
    
    local value = data.value or 0
    local maxValue = data.maxValue or 100
    local hasFullBonus = data.hasFullBonus or false
    
    -- 显示战意条
    zhanYiFrame.Visible = true
    
    -- 更新进度条宽度
    local ratio = math.clamp(value / maxValue, 0, 1)
    local totalWidth = (SLOT_SIZE + SLOT_SPACING) * 4 - SLOT_SPACING - 2
    zhanYiBar.Size = UDim2.new(0, totalWidth * ratio, 1, -2)
    
    -- 颜色渐变：低战意橙色 → 高战意红色，满战意金色闪烁
    if hasFullBonus then
        zhanYiBar.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        zhanYiLabel.Text = string.format("⚔️ 战意 MAX — 攻速UP! ⚔️")
        zhanYiLabel.TextColor3 = Color3.fromRGB(255, 230, 100)
    else
        local r = 220 + math.floor(35 * ratio)
        local g = math.floor(120 - 80 * ratio)
        local b = math.floor(30 - 20 * ratio)
        zhanYiBar.BackgroundColor3 = Color3.fromRGB(r, g, b)
        zhanYiLabel.Text = string.format("战意 %d/%d (减伤%.0f%%)", math.floor(value), maxValue, ratio * 20)
        zhanYiLabel.TextColor3 = Color3.new(1, 1, 1)
    end
    
    -- 战意归零时隐藏
    if value <= 0 then
        zhanYiFrame.Visible = false
    end
end

return SkillBarUI
