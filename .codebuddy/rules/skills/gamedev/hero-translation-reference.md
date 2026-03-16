---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：已有英雄配置参考样本

> **领域**: gamedev / hero-porting
> **适用Agent**: 程序 / 策划
> **加载时机**: 移植新英雄时需要参考已有实现的格式和数值量级
> **大小**: ~8KB

## 📌 核心知识

本文件收录项目中已有 4 个英雄（Angela/Lux/HouYi/LianPo）的完整配置，作为新英雄移植时的格式和数值参考。

## 📊 已有英雄总览

| 英雄 | 中文名 | Role | EnergyType | Skills | Passives | EffectID 段 |
|------|-------|------|-----------|--------|----------|------------|
| Angela | 安琪拉 | Mage | Mana | Q=1006 W=1007 R=1008 | — | 3020-3039 |
| Lux | 光辉女郎 | Mage | Mana | Q=1002 W=1003 R=1005 | — | 3001-3019 |
| HouYi | 后羿 | Marksman | Mana | Q=1009 W=1010 R=1011 | 5003(多重射击) | 3040-3059 |
| LianPo | 廉颇 | Tank | Rage | Q=10510 W=10520 R=10530 | 10500/10501/10502/10510 | 105000-105500 |

**ID 分配说明**:
- 廉颇已统一为王者原始ID（技能10500-10530, 效果105000-105500, 被动10500-10510）
- 其他英雄(Lux/Angela/HouYi)仍使用临时Roblox ID，待后续用户提供王者ID后统一
- 新英雄建议直接使用王者原始ID

## 🏗️ Archetype 实际使用分布

| Archetype | 使用技能 | 占比 |
|-----------|---------|------|
| **ProjectileSkill** | Fireball(1001), LuxQ(1002), LuxW(1003), AngelaQ(1006), AngelaW(1007), HouYiR(1011) | 40% |
| **AreaSkill** | LuxE(1004), HouYiW(1010), LianPoR(10530) | 20% |
| **DashSkill** | LianPoQ(10510) | 7% |
| **InstantSkill** | HouYiQ(1009), LianPoW(10520) | 13% |
| **BeamSkill** | LuxR(1005), AngelaR(1008) | 13% |

## 📋 技能配置完整样本

### 样本 1: ProjectileSkill — LuxQ (光之束缚)

**概念**: 直线弹道，穿透2个目标，命中造成伤害+定身

```lua
-- Skills/Lux_Skills.lua 中的条目
[1002] = {
    Name = "LuxQ",
    UIName = "光之束缚",
    Icon = "rbxassetid://128294170183609",
    Slot = "Q",
    CD = 11,
    Range = 50,
    EnergyCost = 50,
    CastRule = "Direction",
    ArchetypeType = "Projectile",
    -- Archetype 参数
    Speed = 55,
    Size = Vector3.new(2, 2, 2),
    Color = Color3.fromRGB(255, 240, 180),
    Material = Enum.Material.Neon,
    MaxLifetime = 3,
    MaxPierceCount = 2,      -- 穿透2个目标
    -- 效果引用
    OnHitEffects = { 3001 }, -- 伤害
    OnHitCC = { 3002 },      -- 定身
    DescAttrs = { Damage = 250, CC = "Root 1s", Type = "Magic" },
},

-- EffectConfig.lua 中的条目
[3001] = { Type = "Damage", DamageType = "Magic", Amount = 250 },
[3002] = { Type = "CC", CCType = "Root", Duration = 1.0, Stacking = "Replace" },
```

### 样本 2: AreaSkill — LuxE (透光奇点, 支持 Recast)

**概念**: 投掷到目标位置，持续减速区域，可提前引爆

```lua
[1004] = {
    Name = "LuxE",
    UIName = "透光奇点",
    Icon = "rbxassetid://136209389780773",
    Slot = "E",
    CD = 10,
    Range = 45,
    EnergyCost = 60,
    CastRule = "Position",
    ArchetypeType = "Area",
    -- Archetype 参数
    Radius = 15,
    Duration = 5,
    TickInterval = 0.5,
    CanRecast = true,         -- 支持二次释放引爆
    -- 效果引用
    TickEffects = { 3004 },       -- 持续减速
    OnExpireEffects = { 3005 },   -- 到期/引爆伤害
    DescAttrs = { Damage = 240, CC = "Slow 25%", Duration = "5s", Type = "Magic" },
},

-- EffectConfig.lua
[3004] = { Type = "CC", CCType = "Slow", Percent = 0.25, Duration = 2.0, Stacking = "Replace" },
[3005] = { Type = "Damage", DamageType = "Magic", Amount = 240 },
```

### 样本 3: DashSkill — LianPoQ (爆裂冲撞)

**概念**: 方向冲刺，路径上敌人受伤+击飞

```lua
[10510] = {
    Name = "LianPoQ",
    UIName = "爆裂冲撞",
    Icon = "rbxassetid://112235105032199",
    Slot = "Q",
    CD = 8,
    Range = 30,
    EnergyCost = 20,
    CastRule = "Direction",
    ArchetypeType = "Dash",
    -- Archetype 参数
    Speed = 40,
    Width = 6,
    MaxRange = 30,
    LockMovement = true,
    -- 效果引用
    OnDashHitEffects = { 105100 }, -- 伤害
    OnDashHitCC = { 105190 },      -- 击飞
    DescAttrs = { Damage = 350, CC = "Knockup 0.5s", Type = "Physical" },
},

-- EffectConfig.lua
[105100] = { Type = "Damage", DamageType = "Physical", Amount = 350 },
[105190] = { Type = "CC", CCType = "Knockup", Duration = 0.5, Stacking = "Replace", MutexGroup = "HardCC" },
```

### 样本 4: InstantSkill — LianPoW (熔岩重击)

**概念**: 瞬发自身护盾 + 周围 AOE 伤害+减速

```lua
[10520] = {
    Name = "LianPoW",
    UIName = "熔岩重击",
    Icon = "rbxassetid://72768482471616",
    Slot = "W",
    CD = 10,
    Range = 5,
    EnergyCost = 30,
    CastRule = "Instant",
    ArchetypeType = "Instant",
    -- Archetype 参数
    SelfEffects = { 105250 },    -- 自身护盾
    AreaRadius = 14,
    AreaEffects = { 105200 },    -- AOE 外圈伤害
    AreaCC = { 105290 },         -- AOE 减速
    -- 自定义
    ChargeDelay = 1,
    RefreshQOnHit = true,
    DescAttrs = { Shield = 400, Damage = 330, CC = "Slow 15%", Type = "Physical" },
},

-- EffectConfig.lua
[105250] = { Type = "Shield", Amount = 400, Duration = 5.0, Stacking = "Replace" },
[105290] = { Type = "CC", CCType = "Slow", Percent = 0.15, Duration = 1.0, Stacking = "Replace" },
[105200] = { Type = "Damage", DamageType = "Physical", Amount = 330 },
```

### 样本 5: BeamSkill — AngelaR (炽热光辉, Channel 模式)

**概念**: 引导持续激光，跟踪鼠标缓慢转向

```lua
[1008] = {
    Name = "AngelaR",
    UIName = "炽热光辉",
    Icon = "rbxassetid://85476569427906",
    Slot = "R",
    CD = 50,
    Range = 60,
    EnergyCost = 100,
    CastRule = "Direction",
    ArchetypeType = "Beam",
    IsUltimate = true,
    -- Archetype 参数
    Width = 8,
    Duration = 3,
    TickInterval = 0.3,
    Mode = "Channel",          -- 引导模式
    TrackMouse = true,         -- 跟踪鼠标
    TurnSpeed = 1.5,
    -- 效果引用
    TickEffects = { 3024 },
    DescAttrs = { Damage = "200/tick × 10", Duration = "3s", Type = "Magic" },
},

-- EffectConfig.lua
[3024] = { Type = "Damage", DamageType = "Magic", Amount = 200 },
```

### 样本 6: BeamSkill — LuxR (终极闪光, Instant 模式)

**概念**: 蓄力后瞬发贯穿激光

```lua
[1005] = {
    Name = "LuxR",
    UIName = "终极闪光",
    Icon = "rbxassetid://96074938800917",
    Slot = "R",
    CD = 60,
    Range = 200,
    EnergyCost = 100,
    CastRule = "Direction",
    ArchetypeType = "Beam",
    IsUltimate = true,
    -- Archetype 参数
    Width = 6,
    Duration = 0,
    Mode = "Instant",          -- 瞬发模式
    CastTime = 1,              -- 蓄力时间
    -- 效果引用
    OnHitEffects = { 3006 },
    DescAttrs = { Damage = 500, Type = "Magic" },
},
```

### 样本 7: 复合 ProjectileSkill — AngelaW (命中后衍生区域)

**概念**: 弹道命中→眩晕→生成漩涡区域持续伤害

```lua
[1007] = {
    Name = "AngelaW",
    UIName = "混沌火种",
    Icon = "rbxassetid://74736538945177",
    Slot = "W",
    CD = 8,
    Range = 40,
    EnergyCost = 70,
    CastRule = "Direction",
    ArchetypeType = "Projectile",
    Speed = 50,
    Size = Vector3.new(2, 2, 2),
    Color = Color3.fromRGB(255, 100, 0),
    Material = Enum.Material.Neon,
    MaxLifetime = 3,
    MaxPierceCount = 1,
    -- 主命中效果
    OnHitEffects = { 3021 },
    OnHitCC = { 3022 },
    -- 衍生区域（自定义参数，Skill_1007 中实现）
    VortexRadius = 8,
    VortexDuration = 3,
    VortexEffects = { 3023 },
    DescAttrs = { Damage = 400, CC = "Stun 1s", Vortex = "80/tick × 3s", Type = "Magic" },
},
```

> **复合技能要点**: 自定义参数写在 SkillConfig 中，Skill_XXXX.lua 重写 `OnProjectileHit` 回调来实现衍生逻辑。

### 样本 8: 被动 — HouYi (多重射击, 叠层)

```lua
-- PassiveConfig.lua
[5003] = {
    Name = "MultiShot",
    DisplayName = "多重射击",
    Description = "普攻命中叠加攻速，最多5层",
    TriggerEvent = "OnHit",
    Conditions = {},
    Effects = { 3080 },
    StackBehavior = {
        MaxStacks = 5,
        StackEffect = 3080,
        DecayDelay = 3,
        DecayRate = 1,
    },
    Cooldown = 0,
    Icon = "",
},

-- EffectConfig.lua (被动效果)
[3080] = {
    Type = "StatMod", Stat = "AtkSpeed", ModType = "Flat",
    Value = 0.1, Duration = 999, Stacking = "Stack", MaxStacks = 5,
},
```

### 样本 9: 被动 — LianPo (战意·坚韧, 怒气满减伤)

```lua
-- PassiveConfig.lua
[10500] = {
    Name = "RageResilience",
    DisplayName = "战意·坚韧",
    Description = "怒气达到上限时获得减伤效果",
    TriggerEvent = "OnRageMax",
    Conditions = {},
    Effects = { 105400 },
    Cooldown = 0,
    Icon = "",
},

-- EffectConfig.lua (被动效果)
[105400] = { Type = "StatMod", Stat = "DamageReduction", ModType = "Percent", Value = 0.20, Duration = 999, Stacking = "Refresh" },
```

## 📐 数值量级参考

基于已有英雄的数值分布，新英雄数值应在以下范围内：

| 类别 | 最小值 | 典型值 | 最大值 | 说明 |
|------|-------|-------|-------|------|
| CD (秒) | 6 | 10 | 60 | 大招 40-60 |
| Range (studs) | 5 | 30-50 | 200 | Beam 最远 |
| EnergyCost | 0 | 50-70 | 100 | 大招通常 100 |
| Damage (单次) | 150 | 250-400 | 500 | 大招伤害高 |
| CC Duration (秒) | 0.5 | 1.0 | 1.5 | 硬控通常 ≤1.5 |
| Shield Amount | 150 | 300-500 | 500 | — |
| Projectile Speed | 50 | 55 | 65 | — |
| Area Radius | 8 | 12-15 | 15 | — |
| Dash Speed | 30 | 40 | 50 | — |
| DoT TickDamage | 10 | 30-80 | 80 | — |

## 🔗 关联技能

- [AGE XML 结构解析](./age-xml-schema.md)
- [王者→Roblox 映射规则](./hok-to-roblox-mapping.md)
- [英雄移植标准 SOP](./hero-translation-sop.md)
- [MOBA 技能实现模式](./moba-skill-patterns.md)
