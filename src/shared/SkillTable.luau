--[[
    SkillTable.luau
    技能基础配置表
    定义每个技能的基础属性：冷却、蓝耗、指示器类型、描述等
    技能的事件时间轴在 SkillEventTable 中配置
    
    ✅ 所有技能以王者荣耀官方数据为准
]]

local SkillTable = {
    --============================================================
    -- 后羿技能 (169_HouYi) — 射手
    -- 被动：惩戒射击（普攻叠速+三箭）
    -- 1技能：多重箭矢（强化普攻）
    -- 2技能：落日余晖（指定位置AOE+减速）
    -- 3技能：灼日之矢（全图弹道+距离眩晕）
    --============================================================
    
    -- Q - 多重箭矢（瞬发自身Buff，强化普攻5秒）
    houyi_q = {
        id          = "houyi_q",
        heroId      = "houyi",
        name        = "多重箭矢",
        icon        = "🏹",
        keybind     = "Q",
        cooldown    = 10,
        manaCost    = 50,
        castType    = "Instant",
        indicatorId = nil,
        description = "强化自身攻击5秒，每次攻击造成额外物理伤害，惩戒射击状态下攻击面前区域另外2名敌人",
        levelData = {
            cooldown   = { 10, 9.6, 9.2, 8.8, 8.4, 8 },
            baseDamage = { 105, 130, 155, 180, 205, 230 }, -- +75%物理加成
            adRatio    = 0.75,
        },
    },

    -- W - 落日余晖（指定位置AOE）
    houyi_w = {
        id          = "houyi_w",
        heroId      = "houyi",
        name        = "落日余晖",
        icon        = "☀️",
        keybind     = "W",
        cooldown    = 8,
        manaCost    = 60,
        castType    = "Position",
        indicatorId = "circle_aoe",
        indicatorParams = { radius = 3, innerRadius = 1.5 },
        description = "命令日之塔攻击指定区域，造成法术伤害并减速30%持续2秒，中心区域额外50%伤害+50%减速",
        levelData = {
            cooldown   = { 8, 7.4, 6.8, 6.2, 5.6, 5 },
            baseDamage = { 300, 350, 400, 450, 500, 550 }, -- +50%物理攻击 法术伤害
            adRatio    = 0.50,
        },
    },

    -- E - 灼日之矢（全图方向弹道大招）
    houyi_e = {
        id          = "houyi_e",
        heroId      = "houyi",
        name        = "灼日之矢",
        icon        = "🔥",
        keybind     = "E",
        cooldown    = 45,
        manaCost    = 130,
        castType    = "Direction",
        indicatorId = "arrow_long",
        indicatorParams = { length = 60, width = 3.5 },
        description = "向指定方向射出火焰箭，命中首个敌方英雄时眩晕(飞行距离越远眩晕越久0.5~3.5秒)，造成物理伤害，溅射减速90%持续1秒",
        levelData = {
            cooldown   = { 45, 40, 35 },
            baseDamage = { 700, 1000, 1300 }, -- +90%物理加成
            adRatio    = 0.90,
        },
    },

    -- R - 被动·惩戒射击（自动触发，不占技能槽但显示在R位）
    houyi_r = {
        id          = "houyi_r",
        heroId      = "houyi",
        name        = "惩戒射击",
        icon        = "⚡",
        keybind     = "R",
        cooldown    = 0,
        manaCost    = 0,
        castType    = "Passive",
        indicatorId = nil,
        description = "被动：普攻命中叠加攻速(每层+4%,最多3层)，满3层进入惩戒射击状态，普攻射出3支箭矢(总计130%伤害)，持续3秒",
    },

    --============================================================
    -- 廉颇技能 (105_LianPo) — 坦克/战士
    -- 被动：勇士之魂（技能霸体+战意减伤+攻速）
    -- 1技能：爆裂冲撞（方向冲锋+击飞）附带被动（第3普攻额外伤害）
    -- 2技能：熔岩重击（护盾+崩裂伤害+减速+重置1技能CD）
    -- 3技能：天崩地裂（跳跃锤地3次：减速→减速→击飞）
    --============================================================
    
    -- Q - 爆裂冲撞（方向型冲锋+击飞）
    lianpo_q = {
        id          = "lianpo_q",
        heroId      = "lianpo",
        name        = "爆裂冲撞",
        icon        = "💨",
        keybind     = "Q",
        cooldown    = 9,
        manaCost    = 0,  -- 廉颇无蓝耗
        castType    = "Direction",
        indicatorId = "arrow_dash",
        indicatorParams = { length = 20, width = 3.5 },
        description = "向指定方向冲锋，对敌人造成物理伤害并击飞0.5秒。被动：第3次普攻为直拳重击，造成额外物理伤害",
        levelData = {
            cooldown   = { 9, 8.4, 7.8, 7.2, 6.6, 6 },
            baseDamage = { 150, 170, 190, 210, 230, 250 }, -- +65%物理攻击
            adRatio    = 0.65,
            -- 1技能附带被动：第3次普攻额外伤害
            passiveDamage = { 200, 260, 320, 380, 440, 500 }, -- +15%物理加成
            passiveAdRatio = 0.15,
        },
    },

    -- W - 熔岩重击（自身护盾 + 延迟崩裂AOE + 重置Q冷却）
    lianpo_w = {
        id          = "lianpo_w",
        heroId      = "lianpo",
        name        = "熔岩重击",
        icon        = "🛡️",
        keybind     = "W",
        cooldown    = 11,
        manaCost    = 0,
        castType    = "Instant",
        indicatorId = nil,
        description = "获得护盾，1秒后地面崩裂造成物理伤害(距中心越近越高,最高200%)，减速30%，重置爆裂冲撞CD",
        levelData = {
            cooldown    = { 11, 10.4, 9.8, 9.2, 8.6, 8 },
            shieldValue = { 350, 420, 490, 560, 630, 700 },
            baseDamage  = { 100, 125, 150, 175, 200, 225 }, -- +100%物理加成 +4%最大生命
            adRatio     = 1.00,
            maxHpRatio  = 0.04,
        },
    },

    -- E - 天崩地裂（跳跃到指定位置 + 三段锤地）
    lianpo_e = {
        id          = "lianpo_e",
        heroId      = "lianpo",
        name        = "天崩地裂",
        icon        = "🔨",
        keybind     = "E",
        cooldown    = 54,
        manaCost    = 0,
        castType    = "Position",
        indicatorId = "circle_aoe",
        indicatorParams = { radius = 5 },
        description = "跳到指定区域连续锤地3次：第1次减速30%，第2次减速50%，第3次击飞。伤害递增，释放期间霸体",
        levelData = {
            cooldown = { 54, 45, 36 },
            -- 三段伤害递增
            slam1Damage = { 60, 90, 120 },   -- +60%物理加成 +3%最大生命
            slam1AdRatio = 0.60, slam1HpRatio = 0.03,
            slam2Damage = { 90, 90, 90 },     -- +90%物理加成 +4%最大生命
            slam2AdRatio = 0.90, slam2HpRatio = 0.04,
            slam3Damage = { 120, 120, 120 },  -- +150%物理加成 +6%最大生命
            slam3AdRatio = 1.50, slam3HpRatio = 0.06,
        },
    },

    -- R - 被动·勇士之魂（不可主动释放，显示在R位）
    lianpo_r = {
        id          = "lianpo_r",
        heroId      = "lianpo",
        name        = "勇士之魂",
        icon        = "👊",
        keybind     = "R",
        cooldown    = 0,
        manaCost    = 0,
        castType    = "Passive",
        indicatorId = nil,
        description = "被动：释放技能时霸体。进入战斗后战意提升(减伤最高20%)，满战意提升攻击速度。脱战后战意降低",
    },

    --============================================================
    -- 安琪拉技能 (142_Angela) — 法师
    -- 被动：咒术火焰（技能灼烧叠加，最多10层）
    -- 1技能：火球术（5颗火球朝指定位置）
    -- 2技能：混沌火种（方向弹道→裂变漩涡DOT+减速+晕眩）
    -- 3技能：炽热光辉（朝指定方向持续释放能量光束3秒+护盾+免控）
    --============================================================
    
    -- Q - 火球术（指定位置，5颗火球）
    angela_q = {
        id          = "angela_q",
        heroId      = "angela",
        name        = "火球术",
        icon        = "🔮",
        keybind     = "Q",
        cooldown    = 5,
        manaCost    = 50,
        castType    = "Position",
        indicatorId = "circle_aoe",
        indicatorParams = { radius = 2, range = 15 },
        description = "召唤5颗火球朝指定位置攻击，命中英雄时停止移动并销毁，同目标第2颗起仅30%伤害",
        levelData = {
            cooldown    = { 5, 4.8, 4.6, 4.4, 4.2, 4 },
            baseDamage  = { 270, 310, 350, 390, 430, 470 },
            apRatio     = 0.30,
        },
    },

    -- W - 混沌火种（方向型弹道 → 裂变火焰漩涡）
    angela_w = {
        id          = "angela_w",
        heroId      = "angela",
        name        = "混沌火种",
        icon        = "🌀",
        keybind     = "W",
        cooldown    = 10,
        manaCost    = 60,
        castType    = "Direction",
        indicatorId = "arrow_line",
        indicatorParams = { length = 15, width = 2 },
        description = "释放混沌火种，命中或到达最远处裂变火焰漩涡，每0.5秒伤害持续3秒，减速50%持续1.5秒，直接命中晕眩1秒",
        levelData = {
            cooldown    = { 10, 9.6, 9.2, 8.8, 8.4, 8 },
            baseDamage  = { 130, 145, 160, 175, 190, 205 }, -- +17%法术加成
            apRatio     = 0.17,
            slowPercent = { 0.50, 0.50, 0.50, 0.50, 0.50, 0.50 },
        },
    },

    -- E - 炽热光辉（方向型引导 — 持续3秒能量光束）
    angela_e = {
        id          = "angela_e",
        heroId      = "angela",
        name        = "炽热光辉",
        icon        = "✨",
        keybind     = "E",
        cooldown    = 20,
        manaCost    = 100,
        castType    = "Direction",  -- ✅ 方向型引导：朝指定方向释放能量光束
        indicatorId = "arrow_channel",
        indicatorParams = { length = 12, width = 3, coneAngle = 30 },
        description = "朝指定方向持续释放炽热光辉3秒，每0.3秒对触碰敌人造成法术伤害，同时获得护盾并免控，施法1秒后可取消",
        levelData = {
            baseDamage    = { 150, 190, 230 },
            apRatio       = 0.21,
            shieldValue   = { 700, 1050, 1400 },  -- ✅ 官方数值: 700/1050/1400(+88%AP)
            shieldApRatio = 0.88,
        },
    },

    -- E取消键（1秒后可用）
    angela_e_cancel = {
        id          = "angela_e_cancel",
        heroId      = "angela",
        name        = "取消炽热光辉",
        icon        = "❌",
        keybind     = "E",
        cooldown    = 0,
        manaCost    = 0,
        castType    = "Instant",
        indicatorId = nil,
        description = "取消炽热光辉引导，保留护盾",
    },
}

-- 获取技能配置
function SkillTable.getSkill(skillId: string)
    return SkillTable[skillId]
end

-- 获取英雄所有技能
function SkillTable.getHeroSkills(heroId: string): { any }
    local skills = {}
    for id, skill in pairs(SkillTable) do
        if type(skill) == "table" and skill.heroId == heroId then
            table.insert(skills, skill)
        end
    end
    return skills
end

return SkillTable
