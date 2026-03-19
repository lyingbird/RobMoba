--[[
    VFXTemplateTable.luau
    特效模板配置表
    定义每种特效模板的 ID、类型、默认参数
    技能通过 PlayVFX 事件的 templateId 引用
    VFXLibrary 根据此配置生成实际特效
    
    模板类型（9种）：
    - Projectile:    弹道拖尾/发光粒子（附着弹体）
    - MeleeSlash:    近战弧形刀光/冲击波
    - Impact:        命中爆花/火花/碎片
    - AOEField:      地面持续场（圆形/矩形）
    - BuffAura:      角色身上持续光环
    - ChannelBeam:   施法者延伸的光束/风暴
    - Explosion:     球形扩散爆炸
    - Trail:         移动路径拖痕
    - ScreenEffect:  镜头震动/闪白/模糊
]]

local VFXTemplateTable = {
    --============================================================
    -- Projectile（弹道特效）
    --============================================================
    arrow_normal = {
        type = "Projectile",
        color = Color3.fromRGB(255, 200, 80),
        secondaryColor = Color3.fromRGB(255, 120, 20),
        trailWidth = 0.2,
        particleRate = 15,
        glowIntensity = 1.0,
        particleSize = NumberSequence.new(0.3, 0.1),
        lifetime = NumberRange.new(0.2, 0.4),
    },

    arrow_fire = {
        type = "Projectile",
        color = Color3.fromRGB(255, 140, 0),
        secondaryColor = Color3.fromRGB(255, 60, 0),
        trailWidth = 0.4,
        particleRate = 30,
        glowIntensity = 2.0,
        particleSize = NumberSequence.new(0.5, 0.1),
        lifetime = NumberRange.new(0.3, 0.6),
    },

    arrow_giant_fire = {
        type = "Projectile",
        color = Color3.fromRGB(255, 100, 0),
        secondaryColor = Color3.fromRGB(255, 40, 0),
        trailWidth = 1.5,
        particleRate = 60,
        glowIntensity = 4.0,
        particleSize = NumberSequence.new(1.5, 0.3),
        lifetime = NumberRange.new(0.5, 1.0),
        extraEmitters = 2, -- 多层粒子
    },

    fireball_purple = {
        type = "Projectile",
        color = Color3.fromRGB(180, 50, 220),
        secondaryColor = Color3.fromRGB(80, 0, 120),
        trailWidth = 0.5,
        particleRate = 40,
        glowIntensity = 2.0,
        particleSize = NumberSequence.new(0.4, 0.1),
        lifetime = NumberRange.new(0.3, 0.5),
    },




    --============================================================
    -- MeleeSlash（近战刀光）
    --============================================================
    lianpo_charge_wave = {
        type = "MeleeSlash",
        color = Color3.fromRGB(200, 160, 80),       -- 暗金/铜色冲击波
        secondaryColor = Color3.fromRGB(140, 100, 40),
        arcAngle = 60,
        scale = 3.5,
        fadeTime = 0.3,
        thickness = 0.3,
    },

    lianpo_enhanced_punch = {
        type = "MeleeSlash",
        color = Color3.fromRGB(255, 180, 50),        -- 金色强化普攻
        secondaryColor = Color3.fromRGB(220, 140, 20),
        arcAngle = 90,
        scale = 5,
        fadeTime = 0.4,
        thickness = 0.5,
    },

    --============================================================
    -- Impact（命中特效）
    --============================================================
    impact_physical = {
        type = "Impact",
        color = Color3.fromRGB(255, 200, 100),
        secondaryColor = Color3.fromRGB(255, 150, 50),
        particleBurst = 12,
        flashDuration = 0.1,
        flashIntensity = 2.0,
        debrisCount = 4,
        debrisSize = 0.2,
    },

    impact_magic = {
        type = "Impact",
        color = Color3.fromRGB(180, 100, 255),
        secondaryColor = Color3.fromRGB(120, 50, 200),
        particleBurst = 16,
        flashDuration = 0.15,
        flashIntensity = 2.5,
        debrisCount = 6,
        debrisSize = 0.15,
    },

    impact_fire = {
        type = "Impact",
        color = Color3.fromRGB(255, 120, 0),
        secondaryColor = Color3.fromRGB(255, 60, 0),
        particleBurst = 20,
        flashDuration = 0.2,
        flashIntensity = 3.0,
        debrisCount = 8,
        debrisSize = 0.25,
    },

    --============================================================
    -- AOEField（范围场特效）
    --============================================================
    sunfall_outer = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(255, 180, 50),
        secondaryColor = Color3.fromRGB(255, 100, 0),
        radius = 3,
        pulseSpeed = 2,
        particleRate = 30,
        glowIntensity = 2.0,
        height = 0.2,
    },

    sunfall_inner = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(255, 80, 0),
        secondaryColor = Color3.fromRGB(200, 30, 0),
        radius = 1.5,
        pulseSpeed = 3,
        particleRate = 50,
        glowIntensity = 3.0,
        height = 0.3,
    },

    lianpo_ring_outer = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(180, 140, 60),        -- 暗金铜色外环
        secondaryColor = Color3.fromRGB(130, 90, 30),
        radius = 5,
        pulseSpeed = 1.5,
        particleRate = 25,
        glowIntensity = 1.5,
        height = 0.15,
    },

    lianpo_ring_mid = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(210, 170, 80),        -- 铜金色中环（递进更亮）
        secondaryColor = Color3.fromRGB(170, 120, 50),
        radius = 3.3,
        pulseSpeed = 2,
        particleRate = 35,
        glowIntensity = 2.0,
        height = 0.2,
    },

    lianpo_ring_inner = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(240, 200, 100),       -- 明亮金色内环（最强）
        secondaryColor = Color3.fromRGB(200, 150, 60),
        radius = 1.6,
        pulseSpeed = 3,
        particleRate = 45,
        glowIntensity = 2.5,
        height = 0.25,
    },




    lianpo_ground_crack = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(180, 140, 80),
        secondaryColor = Color3.fromRGB(120, 80, 40),
        radius = 5,
        pulseSpeed = 0,
        particleRate = 10,
        glowIntensity = 1.0,
        height = 0.05,
    },

    --============================================================
    -- BuffAura（Buff光环）
    --============================================================
    super_armor_aura = {
        type = "BuffAura",
        color = Color3.fromRGB(240, 200, 80),        -- 铜金色霸体光环
        secondaryColor = Color3.fromRGB(200, 150, 40),
        glowIntensity = 3,
        particleRate = 15,
        particleSize = NumberSequence.new(0.3, 0.1),
        lifetime = NumberRange.new(0.5, 1.0),
    },

    shield_aura = {
        type = "BuffAura",
        color = Color3.fromRGB(100, 200, 255),
        secondaryColor = Color3.fromRGB(50, 150, 220),
        glowIntensity = 2.0,
        particleRate = 10,
        particleSize = NumberSequence.new(0.4, 0.2),
        lifetime = NumberRange.new(0.8, 1.5),
    },

    speed_aura = {
        type = "BuffAura",
        color = Color3.fromRGB(100, 255, 150),
        secondaryColor = Color3.fromRGB(50, 200, 100),
        glowIntensity = 1.5,
        particleRate = 8,
        particleSize = NumberSequence.new(0.2, 0.05),
        lifetime = NumberRange.new(0.3, 0.6),
    },

    multi_arrow_aura = {
        type = "BuffAura",
        color = Color3.fromRGB(255, 200, 80),
        secondaryColor = Color3.fromRGB(255, 140, 0),
        glowIntensity = 2.5,
        particleRate = 12,
        particleSize = NumberSequence.new(0.3, 0.1),
        lifetime = NumberRange.new(0.4, 0.8),
    },

    lianpo_charge_aura = {
        type = "BuffAura",
        color = Color3.fromRGB(220, 170, 60),        -- 暗金色蓄力光环
        secondaryColor = Color3.fromRGB(180, 120, 30),
        glowIntensity = 3.0,
        particleRate = 20,
        particleSize = NumberSequence.new(0.5, 0.2),
        lifetime = NumberRange.new(0.6, 1.2),
    },

    --============================================================
    -- ChannelBeam（持续施法光束）
    --============================================================
    angela_e_beam = {
        type = "ChannelBeam",
        color = Color3.fromRGB(220, 80, 255),        -- 亮紫色炽热光辉光束
        secondaryColor = Color3.fromRGB(180, 40, 220),
        beamWidth = 3,
        beamLength = 12,
        pulseSpeed = 5,
        particleRate = 80,
        glowIntensity = 4.0,
        innerGlow = Color3.fromRGB(255, 200, 255),
    },

    --============================================================
    -- Explosion（爆炸）
    --============================================================
    aoe_explosion_fire = {
        type = "Explosion",
        color = Color3.fromRGB(255, 150, 50),
        secondaryColor = Color3.fromRGB(255, 80, 0),
        radius = 3.5,
        expandSpeed = 20,
        fadeTime = 0.5,
        particleBurst = 30,
        flashIntensity = 4.0,
        debrisCount = 10,
    },

    lianpo_slam_explosion = {
        type = "Explosion",
        color = Color3.fromRGB(180, 140, 80),
        secondaryColor = Color3.fromRGB(120, 80, 40),
        radius = 5,
        expandSpeed = 25,
        fadeTime = 0.6,
        particleBurst = 20,
        flashIntensity = 2.5,
        debrisCount = 12,
    },

    --============================================================
    -- Trail（拖痕）
    --============================================================
    charge_trail = {
        type = "Trail",
        color = Color3.fromRGB(200, 160, 80),        -- 铜褐色冲锋拖痕
        secondaryColor = Color3.fromRGB(140, 100, 40),
        width = 2,
        fadeTime = 0.8,
        segmentLength = 1,
    },

    arrow_trail = {
        type = "Trail",
        color = Color3.fromRGB(255, 200, 80),
        secondaryColor = Color3.fromRGB(255, 120, 0),
        width = 0.3,
        fadeTime = 0.3,
        segmentLength = 0.5,
    },

    fire_arrow_trail = {
        type = "Trail",
        color = Color3.fromRGB(255, 100, 0),
        secondaryColor = Color3.fromRGB(255, 40, 0),
        width = 1.0,
        fadeTime = 0.5,
        segmentLength = 0.8,
    },

    --============================================================
    -- 后羿专属补充特效
    --============================================================
    -- 被动减速印记 — 目标头顶金色箭头标记
    houyi_passive_mark = {
        type = "BuffAura",
        color = Color3.fromRGB(255, 200, 50),        -- 金色减速印记
        secondaryColor = Color3.fromRGB(255, 140, 0),
        glowIntensity = 1.5,
        particleRate = 6,
        particleSize = NumberSequence.new(0.15, 0.05),
        lifetime = NumberRange.new(0.3, 0.6),
    },

    -- Q施法时手部发光
    houyi_q_cast_flash = {
        type = "Impact",
        color = Color3.fromRGB(255, 220, 80),        -- 金色闪光
        secondaryColor = Color3.fromRGB(255, 160, 20),
        particleBurst = 8,
        flashDuration = 0.15,
        flashIntensity = 2.0,
        debrisCount = 0,
        debrisSize = 0,
    },

    -- W天空箭矢坠落拖尾
    houyi_w_skyfall_trail = {
        type = "Projectile",
        color = Color3.fromRGB(255, 180, 50),        -- 金色坠落拖尾
        secondaryColor = Color3.fromRGB(255, 100, 0),
        trailWidth = 0.6,
        particleRate = 35,
        glowIntensity = 2.5,
        particleSize = NumberSequence.new(0.4, 0.1),
        lifetime = NumberRange.new(0.3, 0.5),
    },

    -- 被动·惩戒射击状态光环（满3层触发）
    houyi_punish_aura = {
        type = "BuffAura",
        color = Color3.fromRGB(255, 80, 0),          -- 火焰橙红色
        secondaryColor = Color3.fromRGB(255, 40, 0),
        glowIntensity = 3.5,
        particleRate = 25,
        particleSize = NumberSequence.new(0.5, 0.15),
        lifetime = NumberRange.new(0.3, 0.7),
    },

    --============================================================
    -- 安琪拉专属补充特效
    --============================================================
    -- Q施法时脚下紫色魔法阵
    angela_cast_circle = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(180, 50, 220),        -- 深紫色施法魔法阵
        secondaryColor = Color3.fromRGB(120, 20, 180),
        radius = 1.2,
        pulseSpeed = 5,
        particleRate = 30,
        glowIntensity = 2.0,
        height = 0.03,
    },

    -- W火种弹道特效（暗红/紫色燃烧弹）
    angela_w_seed_vfx = {
        type = "Projectile",
        color = Color3.fromRGB(220, 60, 180),        -- 紫红色火种
        secondaryColor = Color3.fromRGB(180, 30, 120),
        trailWidth = 0.5,
        particleRate = 30,
        glowIntensity = 2.5,
        particleSize = NumberSequence.new(0.6, 0.2),
        lifetime = NumberRange.new(0.2, 0.4),
    },

    -- W裂变后火焰漩涡（持续3秒的AOE场）
    angela_w_vortex = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(200, 60, 220),        -- 紫红色火焰漩涡
        secondaryColor = Color3.fromRGB(140, 20, 160),
        radius = 3.5,
        pulseSpeed = 3,
        particleRate = 50,
        glowIntensity = 2.5,
        height = 0.3,
    },

    -- W裂变漩涡的魔法阵底纹
    angela_w_vortex_circle = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(160, 30, 200),        -- 暗紫色魔法阵
        secondaryColor = Color3.fromRGB(100, 10, 140),
        radius = 3.5,
        pulseSpeed = 6,
        particleRate = 20,
        glowIntensity = 1.5,
        height = 0.02,
    },

    -- E炽热光辉（自身周围的光柱/光波）
    angela_e_radiance = {
        type = "AOEField",
        shape = "Circle",
        color = Color3.fromRGB(220, 80, 255),        -- 亮紫色炽热光辉
        secondaryColor = Color3.fromRGB(180, 40, 220),
        radius = 4,
        pulseSpeed = 4,
        particleRate = 60,
        glowIntensity = 3.0,
        height = 0.5,
    },

    -- E护盾光环（套在自身的防护光罩）
    angela_e_shield_aura = {
        type = "BuffAura",
        color = Color3.fromRGB(200, 120, 255),       -- 明亮紫色护盾
        secondaryColor = Color3.fromRGB(160, 60, 220),
        glowIntensity = 4.0,
        particleRate = 25,
        particleSize = NumberSequence.new(0.4, 0.15),
        lifetime = NumberRange.new(0.4, 0.8),
    },

    -- 普攻小型法球（紫色）
    fireball_purple_small = {
        type = "Projectile",
        color = Color3.fromRGB(170, 60, 220),        -- 紫色小法球
        secondaryColor = Color3.fromRGB(120, 20, 160),
        trailWidth = 0.2,
        particleRate = 15,
        glowIntensity = 1.5,
        particleSize = NumberSequence.new(0.2, 0.05),
        lifetime = NumberRange.new(0.15, 0.3),
    },

    --============================================================
    -- 廉颇专属补充特效
    --============================================================
    -- Q冲锋时地面扬尘
    lianpo_charge_dust = {
        type = "Trail",
        color = Color3.fromRGB(160, 130, 80),        -- 泥土扬尘色
        secondaryColor = Color3.fromRGB(120, 90, 50),
        width = 3,
        fadeTime = 1.0,
        segmentLength = 0.8,
    },

    -- E落地时震裂大地波纹
    lianpo_shockwave = {
        type = "Explosion",
        color = Color3.fromRGB(200, 160, 80),        -- 铜金色震波
        secondaryColor = Color3.fromRGB(140, 100, 40),
        radius = 6,
        expandSpeed = 30,
        fadeTime = 0.4,
        particleBurst = 15,
        flashIntensity = 2.0,
        debrisCount = 8,
    },

    -- W蓄力完成瞬间的金色爆发
    lianpo_w_release = {
        type = "Explosion",
        color = Color3.fromRGB(240, 200, 80),        -- 明亮金色爆发
        secondaryColor = Color3.fromRGB(200, 150, 40),
        radius = 5,
        expandSpeed = 25,
        fadeTime = 0.3,
        particleBurst = 20,
        flashIntensity = 3.0,
        debrisCount = 6,
    },

    --============================================================
    -- ScreenEffect（屏幕效果）
    --============================================================
    screen_shake_light = {
        type = "ScreenEffect",
        effectType = "Shake",
        shakeIntensity = 0.2,
        shakeFrequency = 15,
        duration = 0.3,
    },

    screen_shake_medium = {
        type = "ScreenEffect",
        effectType = "Shake",
        shakeIntensity = 0.5,
        shakeFrequency = 12,
        duration = 0.4,
    },

    screen_shake_heavy = {
        type = "ScreenEffect",
        effectType = "Shake",
        shakeIntensity = 1.0,
        shakeFrequency = 10,
        duration = 0.5,
    },

    screen_flash_white = {
        type = "ScreenEffect",
        effectType = "Flash",
        flashColor = Color3.fromRGB(255, 255, 255),
        flashIntensity = 0.5,
        duration = 0.15,
    },
}

-- 获取模板配置
function VFXTemplateTable.getTemplate(templateId: string)
    return VFXTemplateTable[templateId]
end

-- 获取所有模板（排除函数成员，只返回模板数据）
function VFXTemplateTable.getAll(): { [string]: any }
    local result = {}
    for id, template in pairs(VFXTemplateTable) do
        if type(template) == "table" and template.type then
            result[id] = template
        end
    end
    return result
end

-- 获取某类型的所有模板
function VFXTemplateTable.getTemplatesByType(templateType: string): { any }
    local result = {}
    for id, template in pairs(VFXTemplateTable) do
        if type(template) == "table" and template.type == templateType then
            result[id] = template
        end
    end
    return result
end

return VFXTemplateTable
