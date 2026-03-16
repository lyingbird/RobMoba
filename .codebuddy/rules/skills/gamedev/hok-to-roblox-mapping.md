---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：王者荣耀 → Roblox 映射规则

> **领域**: gamedev / hero-porting
> **适用Agent**: 程序 / 策划
> **加载时机**: 将王者英雄数据转换为 Roblox 配置时
> **大小**: ~8KB

## 📌 核心知识

本文件定义了从王者荣耀数据表 → Roblox MOBA 配置文件的完整映射规则。所有字段映射、单位转换、类型对照均在此文件中固化。

## 📊 配置表字段映射

### 11 号表 (英雄信息) → Heroes/{Name}.lua

| 王者字段 | Roblox 字段 | 转换规则 |
|---------|------------|---------|
| 武将ID | (索引用) | 3位数字编号，如 105=廉颇 |
| 英雄名 | DisplayName | 直接使用中文名 |
| 主要职业 | Role | 坦克→Tank, 战士→Fighter, 法师→Mage, 射手→Marksman, 刺客→Assassin, 辅助→Support |
| 细分职业 | (Tags) | 先锋坦克→"Engage", 团控坦克→"TeamCC" 等 |
| 技能1ID~技能6ID | Skills = {Q=, W=, R=} | 技能2ID→Q, 技能3ID→W, 技能4ID→R (技能1=普攻) |
| 被动技能1~4 | Passives = {[1]=passiveId} | 关联 PassiveConfig ID |
| 能量类型 | EnergyType | 看 15 号表映射 |
| 基础生命 | baseHP | 直接使用（Roblox 数值需按游戏性调整） |
| 基础攻击力 | baseAD | 直接使用 |
| 基础法术强度 | baseAP | 直接使用 |
| 基础护甲 | baseArmor | 直接使用 |
| 基础暴击率 | baseCritRate | ÷10000 → 小数 |
| 基础暴击效果 | baseCritDmg | ÷10000 → 小数 (如 8500→0.85) |
| 成长率字段 | xxxGrowth | 万分比，÷10000 → 每级成长系数 |

### 15 号表 (英雄能量) → EnergyConfig.lua

| 王者类型 | Roblox EnergyType | 说明 |
|---------|-------------------|------|
| 蓝量/法力 | "Mana" | 自然恢复 |
| 怒气 | "Rage" | 战斗获取，脱战衰减 |
| 能量 | "Energy" | 快速恢复 |
| 无消耗 | "None" | 不显示能量条 |

**15 号表字段映射**:

| 王者字段 | Roblox 字段 | 转换 |
|---------|------------|------|
| 能量上限 | BaseMax | 直接使用 |
| 回复频率(ms) | RegenPerSecond | 1000÷回复频率 × 每次回复量 |
| Zero能量效果 | (逻辑) | 22号表效果ID → 能量归零时触发 |
| Max能量效果 | (逻辑) | 22号表效果ID → 能量满时触发 |

### 21 号表 (技能基础) → Skills/{Name}_Skills.lua

| 王者字段 | Roblox 字段 | 转换规则 |
|---------|------------|---------|
| 技能ID | SkillConfig key | 映射到项目 ID 段位 |
| 技能名称 | UIName | 直接使用中文 |
| 技能槽位 | Slot | 0=普攻(AA), 1→Q, 2→W, 3→R |
| **冷却时间** | **CD** | **÷1000 → 秒** |
| 冷却时间成长 | cdPerLevel | ÷1000 → 秒/级 |
| **消耗** | **EnergyCost** | 直接使用（或按类型调整） |
| **指示器范围** | **Range** | **÷1000 → studs** (王者~1000=1个身位≈1 stud) |
| 固有指示器范围 | fixedRange | ÷1000 |
| 技能释放规则 | CastRule | 见下方释放规则映射 |
| 基础伤害 | baseDamage | 需结合 22 号表效果数据 |
| 动作路径 | (AGE路径) | 用于定位 XML 分析 Archetype |
| 自身技能效果组合 | SelfEffects → 22号表 | 施加自身的效果 |
| 目标技能效果组合 | TargetEffects → 22号表 | 施加目标的效果 |

**释放规则映射**:

| 王者释放规则 | Roblox CastRule | 说明 |
|-------------|----------------|------|
| 任意 | "Instant" | 无需指定方向/目标 |
| 指向 | "Direction" | 选方向释放 |
| 方向(固定距离) | "Direction" | 选方向+固定距离 |
| 目标 | "Target" | 选择目标 |
| 位置 | "Position" | 选择落点 |

### 22 号表 (技能效果组合) → EffectConfig.lua

**效果类型映射**:

| 王者效果类型 | Roblox EffectConfig Type | 额外字段 |
|------------|------------------------|---------|
| 物理伤害 | Damage (DamageType="Physical") | Amount |
| 法术伤害 | Damage (DamageType="Magic") | Amount |
| 真实伤害 | Damage (DamageType="True") | Amount |
| 回复生命 | HoT | TickHeal, TickInterval, Duration |
| 属性变化-护甲增加 | StatMod (Stat="DEF") | Value, Duration |
| 属性变化-攻速增加 | StatMod (Stat="AtkSpeed") | Value, Duration |
| 属性变化-移速增加 | StatMod (Stat="MoveSpeed") | Value, Duration |
| 属性变化-移速降低 | CC (CCType="Slow") | Percent, Duration |
| 控制-晕眩 | CC (CCType="Stun") | Duration, MutexGroup="HardCC" |
| 控制-晕眩+击飞 | CC (CCType="Knockup") | Duration, MutexGroup="HardCC" |
| 控制-沉默 | CC (CCType="Silence") | Duration |
| 控制-定身 | CC (CCType="Root") | Duration |
| 控制-嘲讽 | CC (CCType="Taunt") | Duration, MutexGroup="HardCC" |
| 护盾 | Shield | Amount, Duration |
| 持续伤害 | DoT | TickDamage, TickInterval, Duration |

**效果参数映射**:

| 22号表参数 | 含义 | Roblox 用法 |
|-----------|------|------------|
| 效果N参数1 | 基础值 | Amount / 基础伤害数值 |
| 效果N参数2 | 额外值/百分比值 | 百分比相关数值 |
| 效果N参数3 | AD加成万分比 | scalingAD = 值÷10000 |
| 效果N参数10 | 普攻强度加成万分比 | scalingAA = 值÷10000 |
| 持续时长 | ms (-1=永久) | Duration = 值÷1000 (-1→999) |
| 作用周期 | ms | TickInterval = 值÷1000 |

**叠加规则映射**:

| 王者叠加规则 | Roblox Stacking |
|-------------|----------------|
| 替换 | "Replace" |
| 刷新 | "Refresh" |
| 叠加 | "Stack" (需 MaxStacks) |
| 独立 | "Independent" |

**互斥组映射**: 互斥效果类型 → MutexGroup (硬控统一用 "HardCC")

### 26 号表 (技能被动) → PassiveConfig.lua

**被动触发事件映射**:

| 王者被动类型 | Roblox TriggerEvent | 说明 |
|------------|--------------------|----|
| 时间触发(参数1=0,参数2=1) | "OnSpawn" | 出生触发一次(如永久Buff) |
| 时间触发(参数1=N) | "Periodic" | 每 N 秒触发 |
| 使用技能条件 | "OnAbilityUse" | 释放技能时 |
| 血量区间 | "OnHealthBelow" / "OnHealthAbove" | 血量阈值 |
| 进入战斗 | "OnCombatEnter" | 进入战斗状态 |
| 脱离战斗 | "OnCombatLeave" | 脱离战斗状态 |
| 击杀 | "OnKill" | 击杀目标 |
| 助攻 | "OnAssist" | 助攻 |
| 普攻命中 | "OnHit" | 普攻命中 |
| 受到伤害 | "OnDamaged" | 受到伤害 |
| 技能升级 | "OnSkillLevelUp" | 技能升级时 |

**被动条件映射**:

| 王者条件类型 | Roblox Condition Type |
|------------|---------------------|
| CD就绪 | "CooldownReady" |
| 血量低于 | "HealthBelow" |
| 血量高于 | "HealthAbove" |
| 目标是英雄 | "TargetIsHero" |
| 拥有Buff | "HasBuff" |
| 没有Buff | "NotHasBuff" |

## 🔢 单位转换速查

| 王者单位 | 转换公式 | Roblox 单位 |
|---------|---------|------------|
| 毫秒(ms) | ÷1000 | 秒(s) |
| 距离(~1000=1身位) | ÷1000 | studs |
| 万分比(10000=100%) | ÷10000 | 小数(0~1) |
| 百万分比(1000000=100%) | ÷1000000 | 小数(0~1) |
| 持续时长=-1 | → 999 | 永久效果 |
| 逻辑帧(1帧=66ms) | ×66÷1000 | 秒(s) |

## 📐 Archetype 类型映射

| AGE 模式 | Roblox Archetype | ArchetypeType 值 |
|---------|-----------------|-----------------|
| SpawnBullet → 直线飞行 → 碰撞 | ProjectileSkill | "Projectile" |
| SpawnObject + SetCollision + HitTrigger | AreaSkill | "Area" |
| MoveActor (位移) | DashSkill | "Dash" |
| 瞬发自身 buff + 周围 AOE | InstantSkill | "Instant" |
| 长距离持续 HitTrigger | BeamSkill | "Beam" |

## ✅ 映射最佳实践

1. **先确定 Archetype** → 通过 AGE 事件类型判断（见 [AGE XML Schema](./age-xml-schema.md)）
2. **从 22 号表提取效果** → 每个效果组合 ID 映射为一个 EffectConfig 条目
3. **数值不要 1:1 照搬** → 王者数值需要按 Roblox 游戏性调整（HP/伤害量级差异大）
4. **保留原始参数注释** → 在生成的代码中注释王者原始值，方便后续调参
5. **AD/AP 加成暂存** → 当前 Roblox 侧暂无动态加成系统，注释存储待后续实现

## ❌ 常见陷阱

1. **忘记单位转换** → 王者 ms、Roblox 秒；王者万分比、Roblox 小数
2. **混淆效果组合 ID 和效果类型** → 22 号表一条记录可包含多个效果槽位
3. **忽略互斥组** → 硬控必须设 MutexGroup="HardCC"
4. **忽略叠加规则** → 默认用 "Replace"，有层数叠加的必须用 "Stack"+MaxStacks
5. **持续时间 -1 不处理** → 王者 -1=永久，Roblox 用 999 表示
6. **忽略 AD/AP 加成字段** → 参数3 (AD 加成) 和参数10 (普攻加成) 影响伤害计算

## 🔗 关联技能

- [AGE XML 结构解析](./age-xml-schema.md)
- [英雄移植标准 SOP](./hero-translation-sop.md)
- [英雄移植参考样本](./hero-translation-reference.md)
- [MOBA 技能实现模式](./moba-skill-patterns.md)
