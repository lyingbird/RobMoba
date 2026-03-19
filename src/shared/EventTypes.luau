--[[
    EventTypes.luau
    原子事件类型枚举 + 参数结构定义
    参考 AGE Action Editor 的 870+ 事件体系，简化为 Roblox 适用的核心集
    
    扩展方式：
    1. 在 Types 中新增枚举
    2. 在 EventHandlers 中 registerHandler(eventType, handlerFn)
    3. 可选：在客户端注册对应表现处理函数
    
    事件分两种时态：
    - Tick: 在 startTime 瞬间执行一次
    - Duration: 从 startTime 开始，持续 duration 秒
]]

local EventTypes = {}

--============================================================
-- 事件类型枚举
--============================================================
EventTypes.Types = {
    -- ========== 控制类 ==========
    SetAttackDir  = "SetAttackDir",   -- Duration: 锁定攻击朝向（前摇期间不可转向）
    ForbidAbility = "ForbidAbility",  -- Duration: 禁止移动/技能/转向
    RotateActor   = "RotateActor",    -- Duration: 持续施法期间可缓慢转向
    ChangeSkill   = "ChangeSkill",    -- Tick: 临时替换技能（如大招取消键）

    -- ========== 表现类（与逻辑事件在同一时间轴对齐） ==========
    PlayAnim    = "PlayAnim",     -- Duration: 播放角色动画
    PlayVFX     = "PlayVFX",      -- Tick: 播放特效（通过 templateId 调用 VFXLibrary）
    CameraShake = "CameraShake",  -- Duration: 镜头震动
    ChannelBar  = "ChannelBar",   -- Duration: 持续施法进度条

    -- ========== 弹道类 ==========
    SpawnBullet = "SpawnBullet",  -- Tick: 生成子弹弹体
    MoveBullet  = "MoveBullet",   -- Duration: 子弹飞行移动

    -- ========== 碰撞类 ==========
    SpawnCollider = "SpawnCollider", -- Duration: 生成碰撞检测区域

    -- ========== 战斗类 ==========
    HitDetect  = "HitDetect",   -- Duration: 命中检测（可关联 onHit 子事件链）
    DealDamage = "DealDamage",  -- Tick: 造成伤害
    ApplyBuff  = "ApplyBuff",   -- Tick: 施加 Buff/Debuff
    RemoveBuff = "RemoveBuff",  -- Tick: 移除 Buff
    SuperArmor = "SuperArmor",  -- Duration: 霸体（免疫控制）

    -- ========== 位移类 ==========
    MoveActor = "MoveActor",    -- Duration: 角色冲锋/闪现位移

    -- ========== 印记类 ==========
    AddMark     = "AddMark",      -- Tick: 增加技能印记
    TriggerMark = "TriggerMark",  -- Tick: 触发印记效果（满层时）

    -- ========== 系统类 ==========
    TriggerCD = "TriggerCD",    -- Tick: 触发技能冷却
}

--============================================================
-- 事件时态分类
--============================================================
EventTypes.TickEvents = {
    [EventTypes.Types.SpawnBullet] = true,
    [EventTypes.Types.DealDamage]  = true,
    [EventTypes.Types.ApplyBuff]   = true,
    [EventTypes.Types.RemoveBuff]  = true,
    [EventTypes.Types.PlayVFX]     = true,
    [EventTypes.Types.TriggerCD]   = true,
    [EventTypes.Types.ChangeSkill] = true,
    [EventTypes.Types.AddMark]     = true,
    [EventTypes.Types.TriggerMark] = true,
}

EventTypes.DurationEvents = {
    [EventTypes.Types.SetAttackDir]  = true,
    [EventTypes.Types.ForbidAbility] = true,
    [EventTypes.Types.PlayAnim]      = true,
    [EventTypes.Types.MoveBullet]    = true,
    [EventTypes.Types.SpawnCollider] = true,
    [EventTypes.Types.HitDetect]     = true,
    [EventTypes.Types.SuperArmor]    = true,
    [EventTypes.Types.MoveActor]     = true,
    [EventTypes.Types.CameraShake]   = true,
    [EventTypes.Types.RotateActor]   = true,
    [EventTypes.Types.ChannelBar]    = true,
}

--============================================================
-- 事件参数模板（文档 + 运行时校验参考）
-- 实际参数在 SkillEventTable 的每个事件 params 中填写
--============================================================
EventTypes.ParamTemplates = {
    [EventTypes.Types.SetAttackDir] = {
        -- 无额外参数，duration 字段控制锁定时长
    },

    [EventTypes.Types.ForbidAbility] = {
        forbidMove  = true,   -- boolean: 禁止移动
        forbidSkill = true,   -- boolean: 禁止释放技能
        forbidRotate = false, -- boolean: 禁止转向（默认 false）
    },

    [EventTypes.Types.PlayAnim] = {
        animId    = "",       -- string: 动画标识（映射到 AnimController 中的具体动画）
        speed     = 1.0,      -- number: 播放速度
        priority  = "Action", -- string: 动画优先级 Idle/Movement/Action
        loopCount = 1,        -- number: 循环次数（0=不循环，>1=循环N次）
        blendTime = 0.1,      -- number: 混合过渡时间(秒)
    },

    [EventTypes.Types.PlayVFX] = {
        templateId   = "",      -- string: VFXTemplateTable 中的模板 ID
        attachToSelf = false,   -- boolean: 是否附着到施法者身上
        attachToBullet = false, -- boolean: 是否附着到弹体上
        offset       = nil,     -- Vector3?: 位置偏移
        scale        = 1.0,     -- number: 缩放
        duration     = nil,     -- number?: 特效持续时间（nil=使用模板默认值）
        color        = nil,     -- Color3?: 颜色覆盖（nil=使用模板默认值）
    },

    [EventTypes.Types.CameraShake] = {
        intensity = 0.3,   -- number: 震动强度
        frequency = 10,    -- number: 震动频率
    },

    [EventTypes.Types.ChannelBar] = {
        barType = "channel", -- string: "channel" | "charge"
    },

    [EventTypes.Types.SpawnBullet] = {
        bulletId  = "",       -- string: 弹体配置 ID（在 SkillEventTable 中关联 MoveBullet + HitDetect）
        angle     = 0,        -- number: 相对施法方向的角度偏移(度)
        speed     = 50,       -- number: 弹体飞行速度
        maxDist   = 30,       -- number: 最大飞行距离
        size      = Vector3.new(1, 1, 1), -- Vector3: 弹体碰撞体大小
        isPiercing = false,   -- boolean: 是否贯穿
    },

    [EventTypes.Types.MoveBullet] = {
        bulletId = "",        -- string: 对应 SpawnBullet 的 bulletId
        speed    = 50,        -- number: 飞行速度
        maxDist  = 30,        -- number: 最大距离
    },

    [EventTypes.Types.SpawnCollider] = {
        shape       = "Sphere", -- string: "Sphere" | "Box" | "Cylinder"
        size        = nil,      -- Vector3?: Box 尺寸
        radius      = nil,      -- number?: Sphere/Cylinder 半径
        attachToSelf = false,   -- boolean: 是否跟随施法者
        offset      = nil,      -- Vector3?: 位置偏移
    },

    [EventTypes.Types.HitDetect] = {
        shape       = "Sphere",   -- string: 检测形状
        radius      = 5,          -- number: 检测半径（Sphere）
        size        = nil,        -- Vector3?: 检测尺寸（Box）
        maxTargets  = 32,         -- number: 最大命中目标数
        interval    = 0,          -- number: 重复检测间隔（0=只检测一次）
        friendlyFire = false,     -- boolean: 是否友伤
        -- onHit 子事件链在事件定义的 onHit 字段中配置
    },

    [EventTypes.Types.DealDamage] = {
        damage     = 0,          -- number: 伤害值
        damageType = "Physical", -- string: "Physical" | "Magic" | "True"
        ratio      = 1.0,        -- number: 伤害系数
    },

    [EventTypes.Types.ApplyBuff] = {
        buffType  = "",     -- string: "Slow" | "Stun" | "Knockback" | "Airborne" | "Burn" | "Shield" | "SpeedUp" | "SuperArmor"
        duration  = 0,      -- number: Buff 持续时间
        value     = 0,      -- number: 效果数值（减速比例/护盾值/加速比例等）
        toSelf    = false,  -- boolean: 是否施加给自身（默认施加给目标）
    },

    [EventTypes.Types.RemoveBuff] = {
        buffType = "",      -- string: 要移除的 Buff 类型
        fromSelf = false,   -- boolean: 是否从自身移除
    },

    [EventTypes.Types.SuperArmor] = {
        -- 无额外参数，duration 字段控制霸体时长
    },

    [EventTypes.Types.MoveActor] = {
        moveType  = "direction", -- string: "direction" | "toPosition" | "toTarget"
        distance  = 0,           -- number: 移动距离（direction 模式）
        speed     = 50,          -- number: 移动速度
        position  = nil,         -- Vector3?: 目标位置（toPosition 模式）
    },

    [EventTypes.Types.AddMark] = {
        markId   = "",     -- string: 印记 ID
        amount   = 1,      -- number: 叠加层数
        duration = 3,      -- number: 印记持续时间
        maxStack = 10,     -- number: 最大层数
    },

    [EventTypes.Types.TriggerMark] = {
        markId    = "",    -- string: 印记 ID
        threshold = 10,    -- number: 触发所需层数
        -- 触发后的效果在 onHit 子事件链中配置
    },

    [EventTypes.Types.RotateActor] = {
        rotateSpeed = 45,  -- number: 转向速度（度/秒）
    },

    [EventTypes.Types.ChangeSkill] = {
        replaceKey  = "",   -- string: 要替换的按键 "Q" | "W" | "E" | "R"
        newSkillId  = "",   -- string: 替换成的技能 ID
        revertTime  = 0,    -- number: 自动恢复时间（秒）
    },

    [EventTypes.Types.TriggerCD] = {
        -- 无额外参数，自动从 SkillTable 读取 CD 时间
        cdOverride = nil,   -- number?: 覆盖 CD 时间（nil=使用默认）
    },
}

--============================================================
-- 工具函数
--============================================================

-- 判断事件是 Tick 还是 Duration
function EventTypes.isTick(eventType: string): boolean
    return EventTypes.TickEvents[eventType] == true
end

function EventTypes.isDuration(eventType: string): boolean
    return EventTypes.DurationEvents[eventType] == true
end

-- 获取事件类型列表（用于遍历）
function EventTypes.getAllTypes(): { string }
    local types = {}
    for _, v in pairs(EventTypes.Types) do
        table.insert(types, v)
    end
    return types
end

return EventTypes
