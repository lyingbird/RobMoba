--[[
    GameConfig.luau
    游戏全局常量配置
    集中管理所有可调参数，方便调试和平衡
]]

local GameConfig = {}

--============================================================
-- 队伍设置
--============================================================
GameConfig.Team = {
    MaxPlayersPerTeam = 3,
    TeamNames = { "Red", "Blue" },
    TeamColors = {
        Red  = Color3.fromRGB(255, 80, 80),
        Blue = Color3.fromRGB(80, 130, 255),
    },
    FriendlyColor = Color3.fromRGB(80, 220, 120),  -- 友军血条颜色
    EnemyColor    = Color3.fromRGB(255, 60, 60),    -- 敌军血条颜色
}

--============================================================
-- 地图设置
--============================================================
GameConfig.Map = {
    -- 整体尺寸
    Width  = 200,    -- X 方向总宽度
    Length = 300,    -- Z 方向总长度
    
    -- 基地
    BaseSize     = Vector3.new(30, 1, 30),
    BaseHealth   = 5000,
    
    -- 泉水（回血区域）
    FountainSize   = Vector3.new(16, 1, 16),
    FountainHealPerSecond = 100,   -- 泉水每秒回血
    FountainManaPerSecond = 50,    -- 泉水每秒回蓝
    
    -- 出生点位置（相对于地图中心的 Z 偏移）
    SpawnOffsetZ = 130,
    
    -- 障碍物
    WallCount    = 8,
    WallSize     = Vector3.new(6, 8, 2),
    
    -- 地面高度
    GroundY = 0,
}

--============================================================
-- 角色设置
--============================================================
GameConfig.Hero = {
    RespawnTime      = 5,       -- 基础复活时间（秒）
    RespawnTimePerDeath = 1,    -- 每次死亡额外增加的复活时间
    MaxRespawnTime   = 15,      -- 最大复活时间
    
    DefaultHeroId    = "houyi", -- 默认英雄（未选择时）
    
    -- 普攻
    BasicAttackCooldown = 1.0,  -- 默认普攻间隔
}

--============================================================
-- 战斗设置
--============================================================
GameConfig.Combat = {
    -- 伤害数字
    DamageNumberDuration = 1.0,     -- 伤害数字显示时长
    DamageNumberRiseSpeed = 2.0,    -- 伤害数字上升速度
    
    -- 经验 & 金币（预留）
    KillExpReward  = 100,
    KillGoldReward = 200,
    AssistExpReward  = 50,
    AssistGoldReward = 100,
}

--============================================================
-- 游戏流程
--============================================================
GameConfig.Game = {
    -- 状态
    States = {
        Waiting    = "Waiting",      -- 等待玩家
        HeroSelect = "HeroSelect",   -- 英雄选择阶段
        Countdown  = "Countdown",    -- 倒计时
        InProgress = "InProgress",   -- 游戏进行中
        Ended      = "Ended",        -- 游戏结束
    },
    
    MinPlayersToStart = 1,          -- 最少玩家数开始（调试用设为1）
    HeroSelectTime    = 30,         -- 英雄选择时间
    CountdownTime     = 5,          -- 开始倒计时
    MaxGameTime       = 600,        -- 最大游戏时长（10分钟）
    
    -- 胜利条件
    VictoryCondition = "BaseDestroy",  -- "BaseDestroy" | "TotalKills"
    TotalKillsToWin  = 20,
}

--============================================================
-- UI 设置
--============================================================
GameConfig.UI = {
    SkillBarSize    = UDim2.new(0, 60, 0, 60),
    SkillBarSpacing = 10,
    HealthBarWidth  = 200,
    HealthBarHeight = 20,
    ManaBarHeight   = 12,
    
    -- 头顶血条
    OverheadBarSize = UDim2.new(4, 0, 0.4, 0),
    OverheadBarOffset = Vector3.new(0, 3, 0),
}

return GameConfig
