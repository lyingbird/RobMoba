--[[
    HeroTable.luau
    英雄属性数据表
    三英雄：后羿(射手)、廉颇(坦克/战士)、安琪拉(法师)
]]

local HeroTable = {
    --============================================================
    -- 后羿 (169_HouYi) - 射手
    --============================================================
    houyi = {
        id         = "houyi",
        name       = "后羿",
        role       = "Marksman",
        
        -- 基础属性
        maxHP      = 1000,
        maxMP      = 500,
        hpRegen    = 5,      -- 每秒回血
        mpRegen    = 4,      -- 每秒回蓝
        
        -- 攻击属性
        attackDamage  = 50,   -- 基础物理攻击力
        magicPower    = 0,    -- 法术强度
        attackSpeed   = 1.0,  -- 攻击速度(次/秒)
        attackRange   = 12,   -- 普攻射程
        
        -- 防御属性
        armor         = 20,   -- 护甲（减物理伤害）
        magicResist   = 15,   -- 魔抗（减法术伤害）
        
        -- 移动属性
        walkSpeed     = 20,   -- 移动速度
        
        -- 技能列表（按键映射）
        skills = {
            Q = "houyi_q",
            W = "houyi_w",
            E = "houyi_e",
            R = "houyi_r",
        },
        
        -- 角色外观
        bodyColors = {
            HeadColor   = Color3.fromRGB(245, 205, 48),
            TorsoColor  = Color3.fromRGB(40, 100, 180),
            LeftArmColor  = Color3.fromRGB(245, 205, 48),
            RightArmColor = Color3.fromRGB(245, 205, 48),
            LeftLegColor  = Color3.fromRGB(40, 60, 120),
            RightLegColor = Color3.fromRGB(40, 60, 120),
        },
    },

    --============================================================
    -- 廉颇 (105_LianPo) - 坦克/战士
    --============================================================
    lianpo = {
        id         = "lianpo",
        name       = "廉颇",
        role       = "Tank",
        
        maxHP      = 1800,
        maxMP      = 300,
        hpRegen    = 10,
        mpRegen    = 3,
        
        attackDamage  = 80,
        magicPower    = 0,
        attackSpeed   = 0.8,
        attackRange   = 4,
        
        armor         = 50,
        magicResist   = 30,
        
        walkSpeed     = 16,
        
        skills = {
            Q = "lianpo_q",
            W = "lianpo_w",
            E = "lianpo_e",
            R = "lianpo_r",
        },
        
        bodyColors = {
            HeadColor   = Color3.fromRGB(200, 180, 150),
            TorsoColor  = Color3.fromRGB(120, 80, 40),
            LeftArmColor  = Color3.fromRGB(200, 180, 150),
            RightArmColor = Color3.fromRGB(200, 180, 150),
            LeftLegColor  = Color3.fromRGB(80, 60, 40),
            RightLegColor = Color3.fromRGB(80, 60, 40),
        },
    },

    --============================================================
    -- 安琪拉 (142_Angela) - 法师
    --============================================================
    angela = {
        id         = "angela",
        name       = "安琪拉",
        role       = "Mage",
        
        maxHP      = 800,
        maxMP      = 600,
        hpRegen    = 4,
        mpRegen    = 8,
        
        attackDamage  = 30,
        magicPower    = 80,
        attackSpeed   = 0.7,
        attackRange   = 8,
        
        armor         = 15,
        magicResist   = 25,
        
        walkSpeed     = 18,
        
        skills = {
            Q = "angela_q",
            W = "angela_w",
            E = "angela_e",
        },
        
        bodyColors = {
            HeadColor   = Color3.fromRGB(255, 220, 220),
            TorsoColor  = Color3.fromRGB(140, 50, 180),
            LeftArmColor  = Color3.fromRGB(255, 220, 220),
            RightArmColor = Color3.fromRGB(255, 220, 220),
            LeftLegColor  = Color3.fromRGB(100, 30, 140),
            RightLegColor = Color3.fromRGB(100, 30, 140),
        },
    },
}

-- 获取英雄数据
function HeroTable.getHero(heroId: string)
    return HeroTable[heroId]
end

-- 获取所有英雄 ID 列表
function HeroTable.getAllHeroIds(): { string }
    return { "houyi", "lianpo", "angela" }
end

return HeroTable
