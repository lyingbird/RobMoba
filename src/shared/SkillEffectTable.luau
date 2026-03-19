--[[
    SkillEffectTable.luau
    技能效果配置表
    定义所有 Buff/Debuff 效果的类型和默认参数
    技能通过 ApplyBuff 事件引用这些配置
]]

local SkillEffectTable = {}

--============================================================
-- Buff/Debuff 类型定义
--============================================================
SkillEffectTable.BuffTypes = {
    -- === Debuff（敌方） ===
    Slow      = "Slow",       -- 减速：降低移动速度
    Stun      = "Stun",       -- 眩晕：无法移动和施法
    Knockback = "Knockback",  -- 击退：向远离方向位移
    Airborne  = "Airborne",   -- 击飞：短暂浮空+无法操作
    Burn      = "Burn",       -- 灼烧：持续伤害 DoT
    
    -- === Buff（自身） ===
    Shield      = "Shield",      -- 护盾：吸收伤害
    MagicShield = "MagicShield", -- 法术护盾：仅吸收法术伤害
    SuperArmor  = "SuperArmor",  -- 霸体：免疫控制
    SpeedUp     = "SpeedUp",     -- 加速：提高移动速度
    AttackBuff  = "AttackBuff",  -- 攻击强化：提高攻击力或改变攻击模式
}

-- 控制类 Debuff（可被霸体免疫）
SkillEffectTable.ControlDebuffs = {
    [SkillEffectTable.BuffTypes.Slow]      = true,
    [SkillEffectTable.BuffTypes.Stun]      = true,
    [SkillEffectTable.BuffTypes.Knockback] = true,
    [SkillEffectTable.BuffTypes.Airborne]  = true,
}

--============================================================
-- 效果处理规则
--============================================================
SkillEffectTable.Rules = {
    -- 免疫规则：拥有霸体时，控制类 Debuff 被免疫
    immunityCheck = function(target, buffType)
        -- 如果是控制类 Debuff 且目标有霸体，则免疫
        return SkillEffectTable.ControlDebuffs[buffType] ~= nil
    end,
    
    -- 叠加规则：同类效果默认刷新持续时间（不叠加数值）
    stackingMode = "refresh", -- "refresh" | "stack" | "replace"
}

--============================================================
-- 印记系统配置
--============================================================
SkillEffectTable.Marks = {
    -- 后羿被动：惩戒射击攻速印记（每层+4%攻速，满3层进入惩戒状态射3箭）
    houyi_passive = {
        id         = "houyi_passive",
        name       = "惩戒射击",
        maxStack   = 3,
        duration   = 3,
        onStack = {
            { buffType = "AttackBuff", subType = "AttackSpeedStack", value = 0.04 }, -- 每层 +4%攻速
        },
    },
    -- 安琪拉被动：咒术火焰灼烧印记（每层每秒伤害，最多10层）
    angela_burn = {
        id         = "angela_burn",
        name       = "咒术火焰",
        maxStack   = 10,
        duration   = 3,
        onStack = {
            { buffType = "Burn", damagePerStack = 8, apRatioPerStack = 0.02, tickInterval = 1.0 },
        },
    },
}

return SkillEffectTable
