--[[
    MapGenerator.luau
    程序化地图生成器
    
    生成对称的 MOBA 地图：
    - 地面平台
    - 两侧基地区域（含泉水回血区）
    - 中间战斗区域
    - 墙壁/掩体障碍物
    - 假人靶标（供测试）
    - 两队出生点
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapGenerator = {}

local remotes = nil
local gameConfigRef = nil

-- 缓存
local dummies = {}
local fountains = {}  -- { Red = Part, Blue = Part }
local bases = {}      -- { Red = Model, Blue = Model }

-- 地图配置
local CONFIG = {
    -- 地面
    GroundSize = Vector3.new(200, 1, 300),
    GroundPos  = Vector3.new(0, -0.5, 0),
    
    -- 基地
    BaseSize     = Vector3.new(30, 1, 30),
    BaseHealth   = 5000,
    RedBasePos   = Vector3.new(0, 0.5, 130),
    BlueBasePos  = Vector3.new(0, 0.5, -130),
    
    -- 泉水
    FountainSize = Vector3.new(16, 0.3, 16),
    RedFountainPos  = Vector3.new(0, 0.2, 140),
    BlueFountainPos = Vector3.new(0, 0.2, -140),
    FountainHealRate = 100,
    FountainManaRate = 50,
    
    -- 出生点
    RedSpawnPos  = Vector3.new(0, 1, 135),
    BlueSpawnPos = Vector3.new(0, 1, -135),
    
    -- 中心战斗区
    CenterSize = Vector3.new(60, 0.1, 60),
    CenterPos  = Vector3.new(0, 0.05, 0),
    
    -- 掩体/墙壁（对称放置）
    Walls = {
        -- 上半场（蓝方侧）
        { pos = Vector3.new(25, 4, -40), size = Vector3.new(6, 8, 2) },
        { pos = Vector3.new(-25, 4, -40), size = Vector3.new(6, 8, 2) },
        { pos = Vector3.new(0, 4, -65), size = Vector3.new(2, 8, 8) },
        { pos = Vector3.new(40, 4, -20), size = Vector3.new(2, 8, 6) },
        { pos = Vector3.new(-40, 4, -20), size = Vector3.new(2, 8, 6) },
        -- 中心区域
        { pos = Vector3.new(15, 3, 0), size = Vector3.new(4, 6, 4) },
        { pos = Vector3.new(-15, 3, 0), size = Vector3.new(4, 6, 4) },
    },
    
    -- 假人（测试用，放在地图中心附近）
    DummyCount   = 3,
    DummyHP      = 5000,
    DummyRespawnTime = 5,
    DummyPositions = {
        Vector3.new(0, 3, -20),
        Vector3.new(10, 3, -15),
        Vector3.new(-10, 3, -15),
    },
    
    -- 装饰柱子
    Pillars = {
        Vector3.new(50, 5, -80),
        Vector3.new(-50, 5, -80),
        Vector3.new(30, 5, -100),
        Vector3.new(-30, 5, -100),
    },
}

--============================================================
-- 内部辅助
--============================================================

local function createPart(name, size, position, color, material, parent, props)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = position
    part.Anchored = true
    part.Color = color or Color3.fromRGB(128, 128, 128)
    part.Material = material or Enum.Material.SmoothPlastic
    part.Parent = parent or workspace
    if props then
        for k, v in pairs(props) do
            part[k] = v
        end
    end
    return part
end

--============================================================
-- 地面
--============================================================

local function createGround()
    -- 主地面
    createPart("Ground", CONFIG.GroundSize, CONFIG.GroundPos,
        Color3.fromRGB(85, 120, 70), Enum.Material.Grass, workspace,
        { Locked = true, CastShadow = false })
    
    -- 中心战斗区域标记
    createPart("CenterArena", CONFIG.CenterSize, CONFIG.CenterPos,
        Color3.fromRGB(140, 140, 120), Enum.Material.Concrete, workspace,
        { Locked = true, CastShadow = false })
    
    -- 中线标记
    createPart("CenterLine", Vector3.new(200, 0.05, 0.5), Vector3.new(0, 0.03, 0),
        Color3.fromRGB(200, 200, 200), Enum.Material.Neon, workspace,
        { Locked = true, CastShadow = false, Transparency = 0.5 })
end

--============================================================
-- 基地
--============================================================

local function createBase(teamName, position, color)
    local model = Instance.new("Model")
    model.Name = teamName .. "Base"
    
    -- 基地平台
    local platform = createPart("BasePlatform", CONFIG.BaseSize, position,
        color, Enum.Material.SmoothPlastic, model, { CanCollide = true })
    
    -- 基地核心（可被攻击的目标）
    local core = createPart("BaseCore", Vector3.new(6, 10, 6),
        position + Vector3.new(0, 5.5, 0),
        color, Enum.Material.Neon, model, { CanCollide = true })
    
    -- 给核心添加血量
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = CONFIG.BaseHealth
    humanoid.Health = CONFIG.BaseHealth
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.Parent = model
    
    -- 标记为基地
    local tag = Instance.new("StringValue")
    tag.Name = "TeamBase"
    tag.Value = teamName
    tag.Parent = model
    
    model.PrimaryPart = core
    model.Parent = workspace
    
    -- 基地血条
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BaseHealthDisplay"
    billboard.Adornee = core
    billboard.Size = UDim2.new(8, 0, 0.8, 0)
    billboard.StudsOffset = Vector3.new(0, 7, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = core
    
    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.new(1, 0, 0.5, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0.5
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = teamName .. " 基地"
    label.Parent = billboard
    
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBg"
    barBg.Size = UDim2.new(1, 0, 0.4, 0)
    barBg.Position = UDim2.new(0, 0, 0.6, 0)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    barBg.BorderSizePixel = 0
    barBg.Parent = billboard
    
    local bar = Instance.new("Frame")
    bar.Name = "Bar"
    bar.Size = UDim2.new(1, 0, 1, 0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.Parent = barBg
    
    -- 更新血条
    humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local ratio = math.max(0, humanoid.Health / humanoid.MaxHealth)
        bar.Size = UDim2.new(ratio, 0, 1, 0)
    end)
    
    return model
end

--============================================================
-- 泉水（回血区域）
--============================================================

local function createFountain(teamName, position, color)
    local fountain = createPart(teamName .. "Fountain", CONFIG.FountainSize, position,
        color, Enum.Material.Neon, workspace,
        { CanCollide = false, Transparency = 0.4, CastShadow = false })
    
    -- 泉水标签
    local tag = Instance.new("StringValue")
    tag.Name = "Fountain"
    tag.Value = teamName
    tag.Parent = fountain
    
    -- 粒子特效（发光感）
    local particle = Instance.new("ParticleEmitter")
    particle.Color = ColorSequence.new(color)
    particle.Size = NumberSequence.new(0.5, 0)
    particle.Lifetime = NumberRange.new(1, 2)
    particle.Rate = 15
    particle.Speed = NumberRange.new(2, 4)
    particle.SpreadAngle = Vector2.new(360, 360)
    particle.LightEmission = 1
    particle.Parent = fountain
    
    return fountain
end

--============================================================
-- 墙壁/掩体
--============================================================

local function createWalls()
    for i, wallDef in ipairs(CONFIG.Walls) do
        -- 上半场
        createPart("Wall_" .. i, wallDef.size, wallDef.pos,
            Color3.fromRGB(100, 100, 110), Enum.Material.Concrete, workspace,
            { CastShadow = true })
        
        -- 对称 - 下半场（Z 轴翻转）
        local mirrorPos = Vector3.new(wallDef.pos.X, wallDef.pos.Y, -wallDef.pos.Z)
        local mirrorSize = Vector3.new(wallDef.size.X, wallDef.size.Y, wallDef.size.Z)
        createPart("Wall_Mirror_" .. i, mirrorSize, mirrorPos,
            Color3.fromRGB(100, 100, 110), Enum.Material.Concrete, workspace,
            { CastShadow = true })
    end
end

--============================================================
-- 装饰
--============================================================

local function createDecorations()
    -- 柱子（两侧对称）
    for i, pos in ipairs(CONFIG.Pillars) do
        createPart("Pillar_" .. i, Vector3.new(3, 10, 3), pos,
            Color3.fromRGB(80, 80, 90), Enum.Material.Slate, workspace)
        local mirrorPos = Vector3.new(pos.X, pos.Y, -pos.Z)
        createPart("Pillar_Mirror_" .. i, Vector3.new(3, 10, 3), mirrorPos,
            Color3.fromRGB(80, 80, 90), Enum.Material.Slate, workspace)
    end
    
    -- 地图边界墙
    local borderHeight = 12
    local halfW = CONFIG.GroundSize.X / 2
    local halfL = CONFIG.GroundSize.Z / 2
    createPart("BorderN", Vector3.new(CONFIG.GroundSize.X + 4, borderHeight, 2),
        Vector3.new(0, borderHeight/2, -halfL - 1),
        Color3.fromRGB(60, 60, 60), Enum.Material.Concrete, workspace,
        { Transparency = 0.7 })
    createPart("BorderS", Vector3.new(CONFIG.GroundSize.X + 4, borderHeight, 2),
        Vector3.new(0, borderHeight/2, halfL + 1),
        Color3.fromRGB(60, 60, 60), Enum.Material.Concrete, workspace,
        { Transparency = 0.7 })
    createPart("BorderW", Vector3.new(2, borderHeight, CONFIG.GroundSize.Z + 4),
        Vector3.new(-halfW - 1, borderHeight/2, 0),
        Color3.fromRGB(60, 60, 60), Enum.Material.Concrete, workspace,
        { Transparency = 0.7 })
    createPart("BorderE", Vector3.new(2, borderHeight, CONFIG.GroundSize.Z + 4),
        Vector3.new(halfW + 1, borderHeight/2, 0),
        Color3.fromRGB(60, 60, 60), Enum.Material.Concrete, workspace,
        { Transparency = 0.7 })
end

--============================================================
-- 出生点
--============================================================

local function createSpawnPoints()
    -- 红队出生点
    local redSpawn = Instance.new("SpawnLocation")
    redSpawn.Name = "RedSpawn"
    redSpawn.Anchored = true
    redSpawn.Size = Vector3.new(8, 1, 8)
    redSpawn.Position = CONFIG.RedSpawnPos
    redSpawn.Material = Enum.Material.Neon
    redSpawn.Color = Color3.fromRGB(255, 100, 100)
    redSpawn.Transparency = 0.5
    redSpawn.CanCollide = true
    redSpawn.Neutral = false
    redSpawn.TeamColor = BrickColor.new("Bright red")
    redSpawn.Parent = workspace
    
    -- 蓝队出生点
    local blueSpawn = Instance.new("SpawnLocation")
    blueSpawn.Name = "BlueSpawn"
    blueSpawn.Anchored = true
    blueSpawn.Size = Vector3.new(8, 1, 8)
    blueSpawn.Position = CONFIG.BlueSpawnPos
    blueSpawn.Material = Enum.Material.Neon
    blueSpawn.Color = Color3.fromRGB(100, 130, 255)
    blueSpawn.Transparency = 0.5
    blueSpawn.CanCollide = true
    blueSpawn.Neutral = false
    blueSpawn.TeamColor = BrickColor.new("Bright blue")
    blueSpawn.Parent = workspace
end

--============================================================
-- 假人系统
--============================================================

-- DPS 统计数据: { [dummyIndex] = { totalDamage, startTime, lastHitTime, peakDPS, ... } }
local dummyStats = {}

-- 上一帧血量缓存（用于计算增量伤害）: { [dummyIndex] = number }
local dummyPrevHealth = {}

local function resetDummyStats(dummyIndex)
    dummyStats[dummyIndex] = {
        totalDamage = 0,
        startTime = 0,    -- 首次受伤时间
        lastHitTime = 0,  -- 上次受伤时间
        peakDPS = 0,
        isTracking = false,
    }
    dummyPrevHealth[dummyIndex] = nil -- 重置时清空，下次从 MaxHealth 开始
end

local function createR6Dummy(name, position)
    local model = Instance.new("Model")
    model.Name = name

    local partDefs = {
        { name = "HumanoidRootPart", size = Vector3.new(2, 2, 1), offset = Vector3.new(0, 3, 0), transparency = 1 },
        { name = "Head", size = Vector3.new(2, 1, 1), offset = Vector3.new(0, 4.5, 0), color = Color3.fromRGB(200, 200, 200) },
        { name = "Torso", size = Vector3.new(2, 2, 1), offset = Vector3.new(0, 3, 0), color = Color3.fromRGB(180, 50, 50) },
        { name = "Left Arm", size = Vector3.new(1, 2, 1), offset = Vector3.new(-1.5, 3, 0), color = Color3.fromRGB(200, 200, 200) },
        { name = "Right Arm", size = Vector3.new(1, 2, 1), offset = Vector3.new(1.5, 3, 0), color = Color3.fromRGB(200, 200, 200) },
        { name = "Left Leg", size = Vector3.new(1, 2, 1), offset = Vector3.new(-0.5, 1, 0), color = Color3.fromRGB(100, 100, 100) },
        { name = "Right Leg", size = Vector3.new(1, 2, 1), offset = Vector3.new(0.5, 1, 0), color = Color3.fromRGB(100, 100, 100) },
    }

    local parts = {}
    for _, def in ipairs(partDefs) do
        local part = Instance.new("Part")
        part.Name = def.name
        part.Size = def.size
        part.Position = position + def.offset
        part.Anchored = false
        part.CanCollide = (def.name == "HumanoidRootPart" or def.name == "Torso")
        part.Transparency = def.transparency or 0
        if def.color then part.Color = def.color end
        part.Material = Enum.Material.SmoothPlastic
        part.Parent = model
        parts[def.name] = part
    end

    model.PrimaryPart = parts["HumanoidRootPart"]

    local function makeMotor(motorName, part0, part1, c0, c1)
        local motor = Instance.new("Motor6D")
        motor.Name = motorName
        motor.Part0 = part0
        motor.Part1 = part1
        motor.C0 = c0
        motor.C1 = c1
        motor.Parent = part0
    end

    makeMotor("RootJoint", parts["HumanoidRootPart"], parts["Torso"], CFrame.new(), CFrame.new())
    makeMotor("Neck", parts["Torso"], parts["Head"], CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
    makeMotor("Left Shoulder", parts["Torso"], parts["Left Arm"], CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
    makeMotor("Right Shoulder", parts["Torso"], parts["Right Arm"], CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
    makeMotor("Left Hip", parts["Torso"], parts["Left Leg"], CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
    makeMotor("Right Hip", parts["Torso"], parts["Right Leg"], CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = CONFIG.DummyHP
    humanoid.Health = CONFIG.DummyHP
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.Parent = model

    parts["HumanoidRootPart"].Anchored = true

    local tag = Instance.new("BoolValue")
    tag.Name = "IsDummy"
    tag.Value = true
    tag.Parent = model

    -- 头顶信息面板（血条 + DPS 统计）
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "HealthDisplay"
    billboard.Adornee = parts["Head"]
    billboard.Size = UDim2.new(6, 0, 1.8, 0)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = parts["Head"]
    
    -- 标题：假人靶标
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0.15, 0)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    titleLabel.TextStrokeTransparency = 0.3
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "🎯 训练假人"
    titleLabel.Parent = billboard

    -- 血条文字
    local hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "HPLabel"
    hpLabel.Size = UDim2.new(1, 0, 0.15, 0)
    hpLabel.Position = UDim2.new(0, 0, 0.15, 0)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = Color3.new(1, 1, 1)
    hpLabel.TextStrokeTransparency = 0.3
    hpLabel.TextScaled = true
    hpLabel.Font = Enum.Font.GothamBold
    hpLabel.Text = string.format("HP: %d / %d", CONFIG.DummyHP, CONFIG.DummyHP)
    hpLabel.Parent = billboard

    -- 血条背景
    local hpBarBg = Instance.new("Frame")
    hpBarBg.Name = "HPBarBg"
    hpBarBg.Size = UDim2.new(0.9, 0, 0.08, 0)
    hpBarBg.Position = UDim2.new(0.05, 0, 0.32, 0)
    hpBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    hpBarBg.BorderSizePixel = 0
    hpBarBg.Parent = billboard

    local hpBar = Instance.new("Frame")
    hpBar.Name = "HPBar"
    hpBar.Size = UDim2.new(1, 0, 1, 0)
    hpBar.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
    hpBar.BorderSizePixel = 0
    hpBar.Parent = hpBarBg
    
    -- DPS 统计面板
    local dpsLabel = Instance.new("TextLabel")
    dpsLabel.Name = "DPSLabel"
    dpsLabel.Size = UDim2.new(1, 0, 0.15, 0)
    dpsLabel.Position = UDim2.new(0, 0, 0.42, 0)
    dpsLabel.BackgroundTransparency = 1
    dpsLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    dpsLabel.TextStrokeTransparency = 0.3
    dpsLabel.TextScaled = true
    dpsLabel.Font = Enum.Font.GothamBold
    dpsLabel.Text = "DPS: 0"
    dpsLabel.Parent = billboard
    
    -- 累计伤害
    local totalDmgLabel = Instance.new("TextLabel")
    totalDmgLabel.Name = "TotalDmgLabel"
    totalDmgLabel.Size = UDim2.new(1, 0, 0.13, 0)
    totalDmgLabel.Position = UDim2.new(0, 0, 0.57, 0)
    totalDmgLabel.BackgroundTransparency = 1
    totalDmgLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
    totalDmgLabel.TextStrokeTransparency = 0.3
    totalDmgLabel.TextScaled = true
    totalDmgLabel.Font = Enum.Font.Gotham
    totalDmgLabel.Text = "累计伤害: 0  |  峰值DPS: 0"
    totalDmgLabel.Parent = billboard
    
    -- 持续时间
    local durationLabel = Instance.new("TextLabel")
    durationLabel.Name = "DurationLabel"
    durationLabel.Size = UDim2.new(1, 0, 0.12, 0)
    durationLabel.Position = UDim2.new(0, 0, 0.70, 0)
    durationLabel.BackgroundTransparency = 1
    durationLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
    durationLabel.TextStrokeTransparency = 0.3
    durationLabel.TextScaled = true
    durationLabel.Font = Enum.Font.Gotham
    durationLabel.Text = "战斗时长: 0.0s"
    durationLabel.Parent = billboard
    
    -- 提示文字
    local hintLabel = Instance.new("TextLabel")
    hintLabel.Name = "HintLabel"
    hintLabel.Size = UDim2.new(1, 0, 0.12, 0)
    hintLabel.Position = UDim2.new(0, 0, 0.85, 0)
    hintLabel.BackgroundTransparency = 1
    hintLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
    hintLabel.TextStrokeTransparency = 0.5
    hintLabel.TextScaled = true
    hintLabel.Font = Enum.Font.Gotham
    hintLabel.Text = "靠近按 [F] 重置血量和统计"
    hintLabel.Parent = billboard
    
    -- ProximityPrompt：靠近按E重置
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "ResetPrompt"
    prompt.ActionText = "重置假人"
    prompt.ObjectText = "训练假人"
    prompt.KeyboardKeyCode = Enum.KeyCode.F -- 用F键，不干扰技能E键
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = parts["HumanoidRootPart"]

    model.Parent = workspace
    return model
end

local function setupDummyRespawn(dummy, originalPos, dummyIndex)
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- 初始化 DPS 统计
    resetDummyStats(dummyIndex)
    
    -- ProximityPrompt 重置血量和统计
    local rootPart = dummy:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local prompt = rootPart:FindFirstChild("ResetPrompt")
        if prompt then
            prompt.Triggered:Connect(function(player)
                -- 重置血量
                humanoid.Health = humanoid.MaxHealth
                -- 重置统计
                resetDummyStats(dummyIndex)
                -- 更新面板
                local head = dummy:FindFirstChild("Head")
                if head then
                    local billboard = head:FindFirstChild("HealthDisplay")
                    if billboard then
                        local dpsLabel = billboard:FindFirstChild("DPSLabel")
                        local totalDmgLabel = billboard:FindFirstChild("TotalDmgLabel")
                        local durationLabel = billboard:FindFirstChild("DurationLabel")
                        if dpsLabel then dpsLabel.Text = "DPS: 0" end
                        if totalDmgLabel then totalDmgLabel.Text = "累计伤害: 0  |  峰值DPS: 0" end
                        if durationLabel then durationLabel.Text = "战斗时长: 0.0s" end
                    end
                end
                print("[MapGenerator] " .. player.Name .. " 重置了假人 #" .. dummyIndex)
            end)
        end
    end

    -- 血条 + DPS 统计更新
    humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local head = dummy:FindFirstChild("Head")
        if not head then return end
        local billboard = head:FindFirstChild("HealthDisplay")
        if not billboard then return end
        local hpLabel = billboard:FindFirstChild("HPLabel")
        local hpBarBg = billboard:FindFirstChild("HPBarBg")
        local dpsLabel = billboard:FindFirstChild("DPSLabel")
        local totalDmgLabel = billboard:FindFirstChild("TotalDmgLabel")
        local durationLabel = billboard:FindFirstChild("DurationLabel")
        
        -- 更新血条
        if hpLabel then
            hpLabel.Text = string.format("HP: %d / %d", math.floor(math.max(0, humanoid.Health)), humanoid.MaxHealth)
        end
        if hpBarBg then
            local bar = hpBarBg:FindFirstChild("HPBar")
            if bar then
                local ratio = math.max(0, humanoid.Health / humanoid.MaxHealth)
                bar.Size = UDim2.new(ratio, 0, 1, 0)
                if ratio > 0.5 then
                    bar.BackgroundColor3 = Color3.fromRGB(80, 220, 80):Lerp(Color3.fromRGB(255, 255, 50), (1 - ratio) * 2)
                else
                    bar.BackgroundColor3 = Color3.fromRGB(255, 255, 50):Lerp(Color3.fromRGB(255, 50, 50), (0.5 - ratio) * 2)
                end
            end
        end
        
        -- 更新 DPS 统计（使用增量计算，不受回血影响）
        local stats = dummyStats[dummyIndex]
        if stats then
            local now = tick()
            local currentHealth = math.max(0, humanoid.Health)
            
            -- 初始化上一帧血量
            if dummyPrevHealth[dummyIndex] == nil then
                dummyPrevHealth[dummyIndex] = humanoid.MaxHealth
            end
            
            local prevHealth = dummyPrevHealth[dummyIndex]
            local healthDelta = prevHealth - currentHealth -- 正值=受到伤害，负值=回血
            dummyPrevHealth[dummyIndex] = currentHealth
            
            -- 只在受到伤害时累计（忽略回血）
            if healthDelta > 0 then
                -- 首次受击
                if not stats.isTracking then
                    stats.isTracking = true
                    stats.startTime = now
                    stats.lastHitTime = now
                end
                
                stats.totalDamage = stats.totalDamage + healthDelta
                stats.lastHitTime = now
            end
            
            if stats.isTracking then
                -- 计算 DPS
                local elapsed = math.max(0.1, now - stats.startTime)
                local currentDPS = math.floor(stats.totalDamage / elapsed)
                stats.peakDPS = math.max(stats.peakDPS, currentDPS)
                
                if dpsLabel then
                    dpsLabel.Text = string.format("DPS: %d", currentDPS)
                end
                if totalDmgLabel then
                    totalDmgLabel.Text = string.format("累计伤害: %d  |  峰值DPS: %d", math.floor(stats.totalDamage), stats.peakDPS)
                end
                if durationLabel then
                    durationLabel.Text = string.format("战斗时长: %.1fs", elapsed)
                end
            end
        end
    end)

    humanoid.Died:Connect(function()
        -- 统计最终数据
        local stats = dummyStats[dummyIndex]
        if stats and stats.isTracking then
            local elapsed = math.max(0.1, tick() - stats.startTime)
            local finalDPS = math.floor(stats.totalDamage / elapsed)
            print(string.format("[Dummy#%d] 被击杀! 累计伤害: %d  DPS: %d  峰值DPS: %d  耗时: %.1fs",
                dummyIndex, math.floor(stats.totalDamage), finalDPS, stats.peakDPS, elapsed))
        end
        
        if remotes and remotes.TargetDied then
            remotes.TargetDied:FireAllClients({
                targetModel = dummy,
                respawnTime = CONFIG.DummyRespawnTime,
            })
        end
        task.delay(CONFIG.DummyRespawnTime, function()
            if dummy and dummy.Parent then dummy:Destroy() end
            local newDummy = createR6Dummy("Dummy_" .. dummyIndex, originalPos)
            dummies[dummyIndex] = newDummy
            setupDummyRespawn(newDummy, originalPos, dummyIndex)
        end)
    end)
end

--============================================================
-- 泉水回血逻辑
--============================================================

local function startFountainHealing()
    RunService.Heartbeat:Connect(function(dt)
        for teamName, fountain in pairs(fountains) do
            if not fountain or not fountain.Parent then continue end
            
            local fountainPos = fountain.Position
            local fountainSize = fountain.Size
            local halfX = fountainSize.X / 2
            local halfZ = fountainSize.Z / 2
            
            for _, player in ipairs(Players:GetPlayers()) do
                local character = player.Character
                if not character then continue end
                local rootPart = character:FindFirstChild("HumanoidRootPart")
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if not rootPart or not humanoid or humanoid.Health <= 0 then continue end
                
                -- 检查是否在泉水范围内
                local pos = rootPart.Position
                if math.abs(pos.X - fountainPos.X) <= halfX
                    and math.abs(pos.Z - fountainPos.Z) <= halfZ
                    and math.abs(pos.Y - fountainPos.Y) <= 5 then
                    
                    -- 队伍匹配检查：只有本队泉水才回血
                    local playerTeam = player.Team
                    if playerTeam and playerTeam.Name ~= teamName then
                        continue -- 敌方泉水不回血
                    end
                    -- 回血
                    humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + CONFIG.FountainHealRate * dt)
                    -- 回蓝
                    local mp = character:FindFirstChild("MP")
                    local maxMP = character:FindFirstChild("MaxMP")
                    if mp and maxMP then
                        mp.Value = math.min(maxMP.Value, mp.Value + CONFIG.FountainManaRate * dt)
                    end
                end
            end
        end
    end)
end

--============================================================
-- 公共接口
--============================================================

function MapGenerator.init(remotesRef)
    remotes = remotesRef
end

function MapGenerator.generate()
    -- 移除默认 Baseplate（在 project.json 中定义的）
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then baseplate:Destroy() end
    
    -- 1. 地面
    createGround()
    
    -- 2. 基地
    bases.Red = createBase("Red", CONFIG.RedBasePos, Color3.fromRGB(255, 80, 80))
    bases.Blue = createBase("Blue", CONFIG.BlueBasePos, Color3.fromRGB(80, 130, 255))
    
    -- 3. 泉水
    fountains.Red = createFountain("Red", CONFIG.RedFountainPos, Color3.fromRGB(255, 120, 120))
    fountains.Blue = createFountain("Blue", CONFIG.BlueFountainPos, Color3.fromRGB(120, 150, 255))
    
    -- 4. 出生点
    createSpawnPoints()
    
    -- 5. 墙壁/掩体
    createWalls()
    
    -- 6. 装饰
    createDecorations()
    
    -- 7. 假人
    for i = 1, CONFIG.DummyCount do
        local pos = CONFIG.DummyPositions[i] or Vector3.new((i - 2) * 10, 3, -20)
        local dummy = createR6Dummy("Dummy_" .. i, pos)
        dummies[i] = dummy
        setupDummyRespawn(dummy, pos, i)
    end
    
    -- 8. 启动泉水回血
    startFountainHealing()
    
    print("[MapGenerator] MOBA 地图生成完成")
    print("  - 2 个基地 (Red/Blue)")
    print("  - 2 个泉水回血区")
    print("  - " .. (#CONFIG.Walls * 2) .. " 个掩体")
    print("  - " .. CONFIG.DummyCount .. " 个假人靶标")
end

-- 获取出生位置
function MapGenerator.getSpawnPosition(teamName: string): Vector3
    if teamName == "Red" then
        return CONFIG.RedSpawnPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
    else
        return CONFIG.BlueSpawnPos + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
    end
end

-- 获取泉水位置
function MapGenerator.getFountainPosition(teamName: string): Vector3
    if teamName == "Red" then
        return CONFIG.RedFountainPos
    else
        return CONFIG.BlueFountainPos
    end
end

-- 获取基地模型
function MapGenerator.getBase(teamName: string)
    return bases[teamName]
end

-- 获取所有假人
function MapGenerator.getDummies()
    return dummies
end

function MapGenerator.getDummyHP()
    return CONFIG.DummyHP
end

return MapGenerator
