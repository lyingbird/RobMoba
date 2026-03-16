---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：王者英雄 → Roblox 移植标准 SOP

> **领域**: gamedev / hero-porting
> **适用Agent**: 程序 / 策划
> **加载时机**: 当用户要求移植一个王者英雄到 Roblox 时
> **大小**: ~10KB

## 📌 标准移植流程 (5 步 SOP)

```
Step 1: 输入解析 → Step 2: 技能分类 → Step 3: 数值映射 → Step 4: 代码生成 → Step 5: 校验检查
```

### Step 1: 输入解析

**输入**: 用户提供的完整索引清单（包含技能/效果/被动/AGE路径/来源标注）

> **关键认知**: 索引清单本身已经是结构化的完整信息源，包含了各表的数据引用和AGE路径。
> 无需用户分别提供每张表的数据 — 索引清单中的行条目就蕴含了表间关系。

#### 1a. 索引清单结构化提取

索引清单中的关键行类型及提取方式:

| 行前缀 | 含义 | 提取目标 |
|--------|------|---------|
| `技能:XXXXX` | 21号表技能ID | 技能列表 + 来源(11号表字段/AGE ChangeSkill) |
| `技能效果组合:XXXXXX<描述>` | 22号表效果ID | 效果清单 + 效果类型描述 + 来源AGE事件 |
| `被动技能:XXXXX` | 26号表被动ID | 被动列表 + 来源(11号表字段) |
| `英雄能量:NNN` | 15号表能量类型 | 能量配置 |
| `动画:XXX` | 动画名称 | 技能动画映射(参考用) |
| `Age:路径` | AGE XML文件路径 | AGE文件清单 + 来源(21/22/26号表字段) |
| `声音:XXX` | 音效 | **忽略** |
| `UnityAsset:XXX` | 特效资源 | **忽略** |
| `ActorInfo:XXX` | 角色模型配置 | **忽略** |
| `行为树:XXX` | AI配置 | **忽略** |

#### 1b. 来源标注解读

每行的 `来源:` 字段揭示了数据的层级关系:
- `来源: DataTable:英雄|105  11.英雄信息表:武将ID=>技能2ID` → 该技能是11号表中英雄105的2技能(Q)
- `来源: Action:...S1.xml  Age:HitTriggerDuration:目标技能效果组合ID1` → 该效果在S1的AGE中作为HitTrigger目标效果
- `来源: DataTable:技能效果组合|105332  22.技能效果组合:效果组合ID=>效果1参数1` → 该效果被另一个效果的参数1引用(链式效果)

#### 1c. 结构化输出

从索引清单提取后，生成以下分析结果:
1. **技能槽位映射**: 11号表 技能1~4ID → 普攻/Q/W/R
2. **普攻段数**: ChangeSkillTriggerTick 的切换链 (10500→10501→10502→10500)
3. **技能效果分组**: 按技能槽位(S1/S2/U1)和AGE来源归类所有效果组合ID
4. **被动系统**: 被动ID→触发AGE→关联效果
5. **AGE嵌套关系**: 主AGE(S1/S2/U1) → SpawnBulletTick → 子AGE(b0/b1) → 效果AGE(E1/E2...)

#### 1d. 补充数据请求

索引清单提供了**结构**，但某些具体**数值**需要用户额外提供:
- **21号表行数据**: CD(ms)、消耗、范围、释放规则 等数值字段
- **22号表行数据**: 效果类型、参数1-10、持续时间、作用周期 等数值字段
- **26号表行数据**: 被动触发类型、条件、CD 等

> AI 应先从索引清单中完成结构分析(Step 1a-1c)，然后列出需要补充的具体表行数据清单(Step 1d)。

**输出**: 完整的结构分析 + 需要补充的表数据清单

### Step 2: 技能分类 (Archetype 识别)

对每个技能:
1. 分析主 AGE XML 的核心事件组合
2. 根据 [AGE Archetype 模式识别](./age-xml-schema.md#-age-archetype-模式识别) 确定类型
3. 输出: `{技能名} → {Archetype}` 映射表

**判定优先级**:
1. 有 `MoveActorDuration` → **DashSkill**
2. 有 `SpawnBulletTick` + 子 AGE 含 `MoveBulletDuration` → **ProjectileSkill**
3. 有 `SpawnObjectDuration` + `SetCollisionTick` → **AreaSkill**
4. 只有 `SimpleSpawnBuffTick` 或 `HitTriggerTick`(无碰撞载体) → **InstantSkill**
5. 有长距离 `MoveBulletDuration` + 连续 `HitTriggerDuration` → **BeamSkill**

### Step 3: 数值映射

使用 [映射规则](./hok-to-roblox-mapping.md) 进行字段转换:

1. **21 号表 → SkillConfig 字段**: CD(÷1000), Range(÷1000), EnergyCost 等
2. **22 号表 → EffectConfig 条目**: 每个效果组合 ID → 一个或多个 EffectConfig 条目
3. **26 号表 → PassiveConfig 条目**: 触发事件+条件+效果引用
4. **15 号表 → EnergyConfig**: 确认能量类型（通常已存在，无需新建）
5. **数值调整**: 王者数值量级与 Roblox 不同，需按已有英雄比例调整

**数值调整参考** (以已有英雄为锚点):
- HP: 王者 3000~8000 → Roblox 已有 LianPo 类似量级，保持
- 伤害: 根据已有效果量级对齐
- 持续时间: 基本保持 (CC 持续时间 0.5~2s 合理)
- 范围: ÷1000 后通常 5~30 studs 合理

### Step 4: 代码生成

按以下顺序生成代码 (使用下方模板):

1. **Heroes/{HeroName}.lua** — 英雄元数据配置
2. **Skills/{HeroName}_Skills.lua** — 技能数值配置
3. **EffectConfig.lua 条目** — 新增效果（追加到已有文件）
4. **PassiveConfig.lua 条目** — 新增被动（如有）
5. **EnergyConfig.lua 条目** — 新增能量类型（如有新类型）
6. **Skills/Skill_{ID}.lua** — 技能逻辑实现（继承 Archetype）

### Step 5: 校验检查

- [ ] 所有技能 ID 不与已有 ID 冲突
- [ ] 所有效果 ID 在正确的段位范围内且不冲突
- [ ] 每个效果 ID 被至少一个技能引用
- [ ] 每个硬控效果(Stun/Knockup/Root/Taunt)设置了 MutexGroup="HardCC"
- [ ] 每个技能的 Archetype 参数完整（Speed/Range/Width/Radius 等）
- [ ] 每个 SkillConfig 条目有 Name/UIName/Icon/Slot/CD/Range/CastRule/ArchetypeType
- [ ] HeroConfig 的 Skills 映射与 SkillConfig ID 对应
- [ ] 被动 Effects 引用的 EffectConfig ID 存在
- [ ] 能量类型在 EnergyConfig 中存在
- [ ] 代码文件放置在正确的目录

---

## 📋 代码模板

### Template 1: Heroes/{HeroName}.lua

```lua
-- ==========================================
-- {HeroName} ({中文名}) 英雄配置
-- 自动被 HeroRegistry 发现和注册
-- 王者ID: {王者武将ID} | 来源: 11号表
-- ==========================================
return {
    HeroID = "{HeroName}",
    DisplayName = "{中文名}",
    Theme = Color3.fromRGB({R}, {G}, {B}),

    -- 元数据
    Role = "{Tank|Fighter|Mage|Marksman|Assassin|Support}",
    Difficulty = {1-3},
    SortOrder = {N}, -- 英雄列表排序
    Enabled = true,
    Tags = { "{标签1}", "{标签2}" },
    FreeRotation = false,

    -- 被动 (PassiveConfig ID)
    Passives = { [1] = {passiveId} },
    -- 能量类型 (EnergyConfig key)
    EnergyType = "{Mana|Rage|Energy|None}",

    -- 技能映射 (SkillConfig ID)
    Skills = { Q = {qId}, W = {wId}, R = {rId} },
    AllowBackpack = true,

    -- 动画配置 (按实际调整)
    Poses = {
        Cast_Q = {
            RightShoulder = {0, 0, 0},
            LeftShoulder = {0, 0, 0},
        },
        Cast_W = {
            RightShoulder = {0, 0, 0},
            LeftShoulder = {0, 0, 0},
        },
        Cast_R = {
            RightShoulder = {0, 0, 0},
            LeftShoulder = {0, 0, 0},
        },
    },
    CastDurations = { Q = 0.4, W = 0.3, R = 0.8 },
    CastLift = { Q = 0, W = 0, R = 0 },
    MoveLock = { Q = "none", W = "none", R = "none" },
    -- MoveLock: "none"=不锁定, "until_fire"=施法前锁定, "full"=全程锁定
}
```

### Template 2: Skills/{HeroName}_Skills.lua

```lua
-- ==========================================
-- {HeroName} ({中文名}) 技能配置
-- 新格式: 通用字段 + ArchetypeType + EffectRefs
-- 自动被 SkillRegistry 发现和注册
-- 王者ID: {王者武将ID}
-- ==========================================
return {
    -- ============ Q 技能 ============
    [{qId}] = {
        Name = "{HeroName}Q",
        UIName = "{Q技能中文名}",
        Icon = "rbxassetid://0", -- 待替换
        Slot = "Q",
        CD = {cd_seconds},        -- 王者原值: {原始ms}ms
        Range = {range_studs},    -- 王者原值: {原始值}
        EnergyCost = {cost},      -- 王者原值: {原始值}
        CastRule = "{Direction|Position|Instant|Target}",
        ArchetypeType = "{Projectile|Area|Dash|Instant|Beam}",
        -- Archetype 专用参数 (见下方 Archetype 参数表)
        {archetype_params},
        -- 效果引用
        {effect_refs},
        -- UI 描述
        DescAttrs = { {desc_attrs} },
    },

    -- ============ W 技能 ============
    [{wId}] = {
        -- ... 同上结构
    },

    -- ============ R 技能 (大招) ============
    [{rId}] = {
        -- ... 同上结构
        IsUltimate = true,
    },
}
```

**Archetype 专用参数表**:

| Archetype | 必填参数 | 可选参数 |
|-----------|---------|---------|
| Projectile | Speed, OnHitEffects | Size, Color, MaxPierceCount, OnHitCC, MaxLifetime |
| Area | Radius, Duration, TickEffects | TickInterval, OnEnterEffects, OnExpireEffects, CanRecast |
| Dash | Speed, Width, MaxRange, OnDashHitEffects | OnDashHitCC, LockMovement |
| Instant | SelfEffects or (AreaRadius+AreaEffects) | AreaCC, TargetEffects |
| Beam | Width, Range, OnHitEffects or TickEffects | Mode("Instant"/"Channel"), Duration, TickInterval, TrackMouse, CastTime |

### Template 3: EffectConfig.lua 条目

```lua
-- {HeroName}{Slot}: {效果中文名} — {效果说明}
-- 王者效果组合ID: {原始ID}, 来源: {AGE/表}
[{effectId}] = {
    Type = "{Damage|CC|Shield|DoT|HoT|StatMod}",
    -- Damage 类型:
    DamageType = "{Physical|Magic|True}",
    Amount = {数值},

    -- CC 类型:
    CCType = "{Stun|Knockup|Root|Slow|Silence|Taunt}",
    Duration = {秒},
    Percent = {0~1},  -- 仅 Slow
    Stacking = "{Replace|Stack|Refresh|Independent}",
    MutexGroup = "HardCC", -- 仅硬控

    -- Shield 类型:
    Amount = {数值},
    Duration = {秒},

    -- DoT 类型:
    DamageType = "{Physical|Magic}",
    TickDamage = {每跳伤害},
    TickInterval = {秒},
    Duration = {秒},

    -- StatMod 类型:
    Stat = "{DEF|MR|AtkSpeed|MoveSpeed|...}",
    ModType = "{Flat|Percent}",
    Value = {数值},
    Duration = {秒},
    MaxStacks = {N}, -- 仅 Stacking="Stack"
},
```

### Template 4: PassiveConfig.lua 条目

```lua
-- ============================================================
-- {HeroName} ({中文名}) 被动 ID: {passiveId}
-- {被动名} — {描述}
-- 王者被动ID: {原始ID}, 来源: 26号表
-- ============================================================
[{passiveId}] = {
    Name = "{EnglishName}",
    DisplayName = "{中文名}",
    Description = "{描述文本}",
    TriggerEvent = "{OnHit|OnDamaged|OnKill|Periodic|OnAbilityUse|OnHealthBelow|OnSpawn}",
    Conditions = {
        Logic = "AND", -- 或 "OR"
        { Type = "{CooldownReady|HealthBelow|TargetIsHero|...}", Value = {参数} },
    },
    Effects = { {effectId1}, {effectId2} },
    StackBehavior = { -- 可选: 有叠层机制时
        MaxStacks = {N},
        StackEffect = {effectId},
        DecayDelay = {秒},
        DecayRate = {层/秒},
    },
    Cooldown = {秒},
    Icon = "",
},
```

### Template 5: Skills/Skill_{ID}.lua (技能逻辑)

```lua
-- ==========================================
-- Skill_{ID}: {HeroName}{Slot} ({技能中文名})
-- Archetype: {ArchetypeType}Skill
-- 效果: {effectId}({类型}), ...
-- 王者技能ID: {原始ID}
-- ==========================================
local ServerScriptService = game:GetService("ServerScriptService")
-- 按需引入额外服务
-- local TweenService = game:GetService("TweenService")
-- local Debris = game:GetService("Debris")

local {Archetype}Skill = require(
    ServerScriptService:WaitForChild("ServerModules")
    :WaitForChild("Archetypes")
    :WaitForChild("{Archetype}Skill")
)

local {HeroName}{Slot} = setmetatable({}, {Archetype}Skill)
{HeroName}{Slot}.__index = {HeroName}{Slot}

function {HeroName}{Slot}.new(skillID)
    return setmetatable({Archetype}Skill.new(skillID), {HeroName}{Slot})
end

-- 如需自定义 Archetype 配置:
-- function {HeroName}{Slot}:Get{Archetype}Config()
--     local base = {Archetype}Skill.Get{Archetype}Config(self)
--     -- 覆盖特殊参数
--     return base
-- end

-- 如需自定义回调:
-- function {HeroName}{Slot}:On{Event}(player, ...)
--     -- 自定义逻辑 (VFX, 多段, 状态机等)
-- end

return {HeroName}{Slot}
```

**Archetype 回调一览**:

| Archetype | 可重写回调 |
|-----------|----------|
| ProjectileSkill | `OnProjectileHit`, `OnProjectilePierce`, `OnProjectileExpire`, `GetProjectileConfig` |
| AreaSkill | `OnAreaCreate`, `OnAreaTick`, `OnAreaExpire`, `OnRecast`, `GetAreaConfig` |
| DashSkill | `OnDashStart`, `OnDashHit`, `OnDashEnd`, `GetDashConfig` |
| InstantSkill | `OnInstantCast`, `GetInstantConfig` |
| BeamSkill | `OnBeamHit`, `OnBeamTick`, `OnBeamEnd`, `GetBeamConfig` |

## ✅ 最佳实践

1. **先生成配置文件 (Hero+Skills+EffectConfig)**，再生成逻辑文件 (Skill_XXXX.lua)
2. **简单技能优先用 Archetype 默认行为**，不需要重写 OnCast — 只需配置数据
3. **复杂技能才重写回调** — 如多段伤害、状态切换、特殊 VFX
4. **保留王者原始数值注释** — 方便后续调参对照
5. **ID 段位递增分配** — 查看 EffectConfig.lua 头部注释确认下一个可用段位

## ❌ 常见陷阱

1. **直接在 Skill_XXXX.lua 中写伤害逻辑** → 应通过 EffectConfig + SkillHelper 管线
2. **忘记在 DescAttrs 中填写描述** → UI 面板需要显示伤害/CC/类型信息
3. **Archetype 参数名拼错** → 严格使用上方参数表中的字段名
4. **Icon 留空** → 使用 `rbxassetid://0` 占位，不要空字符串
5. **忘记 IsUltimate = true** → 大招必须标记

## 🔗 关联技能

- [AGE XML 结构解析](./age-xml-schema.md)
- [王者→Roblox 映射规则](./hok-to-roblox-mapping.md)
- [英雄移植参考样本](./hero-translation-reference.md)
- [MOBA 技能实现模式](./moba-skill-patterns.md)
