--[[
    GameTypes.luau
    游戏类型定义 & 枚举
    供客户端和服务端共同引用，确保类型一致
]]

local GameTypes = {}

--============================================================
-- 队伍枚举
--============================================================
GameTypes.TeamId = {
    Red  = "Red",
    Blue = "Blue",
    None = "None",
}

--============================================================
-- 游戏状态枚举
--============================================================
GameTypes.GameState = {
    Waiting    = "Waiting",
    HeroSelect = "HeroSelect",
    Countdown  = "Countdown",
    InProgress = "InProgress",
    Ended      = "Ended",
}

--============================================================
-- 技能施法类型
--============================================================
GameTypes.CastType = {
    Instant   = "Instant",    -- 瞬发（无指示器）
    Direction = "Direction",  -- 方向型（箭头/扇形指示器）
    Position  = "Position",   -- 位置型（圆形指示器）
    Channel   = "Channel",    -- 持续施法
    Passive   = "Passive",    -- 被动
}

--============================================================
-- 伤害类型
--============================================================
GameTypes.DamageType = {
    Physical = "Physical",
    Magic    = "Magic",
    True     = "True",
}

--============================================================
-- 英雄职业
--============================================================
GameTypes.HeroRole = {
    Marksman = "Marksman",  -- 射手
    Tank     = "Tank",      -- 坦克
    Mage     = "Mage",      -- 法师
    Assassin = "Assassin",  -- 刺客
    Support  = "Support",   -- 辅助
    Warrior  = "Warrior",   -- 战士
}

--============================================================
-- 远程事件名称（文档参考）
--============================================================
GameTypes.RemoteEvents = {
    -- 客户端 → 服务端
    SkillCast        = "SkillCast",
    BasicAttack      = "BasicAttack",
    HeroSelect       = "HeroSelect",
    HeroSwitch       = "HeroSwitch",
    ChannelCancel    = "ChannelCancel",
    ChannelDirection = "ChannelDirection",
    
    -- 服务端 → 客户端
    DamageDealt        = "DamageDealt",
    PlayVFX            = "PlayVFX",
    PlayAnim           = "PlayAnim",
    StopAnim           = "StopAnim",
    CooldownUpdate     = "CooldownUpdate",
    TargetDied         = "TargetDied",
    StatusEffectUpdate = "StatusEffectUpdate",
    ChannelInterrupt   = "ChannelInterrupt",
    CameraShake        = "CameraShake",
    ChannelBarUpdate   = "ChannelBarUpdate",
    SkillBarUpdate     = "SkillBarUpdate",
    MarkUpdate         = "MarkUpdate",
    GameStateChanged   = "GameStateChanged",
    HeroRespawned      = "HeroRespawned",
    TeamAssigned       = "TeamAssigned",
    KillFeed           = "KillFeed",
    ZhanYiUpdate       = "ZhanYiUpdate",
}

return GameTypes
