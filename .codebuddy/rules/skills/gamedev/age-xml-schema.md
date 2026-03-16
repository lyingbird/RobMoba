---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：王者荣耀 AGE XML 结构解析

> **领域**: gamedev / hero-porting
> **适用Agent**: 程序 / 策划
> **加载时机**: 当用户提供王者英雄的 AGE XML 文件需要解析时
> **大小**: ~6KB

## 📌 核心知识

### 1. AGE 基本概念

**AGE (ActionEditor)** 是王者荣耀的技能/动作编辑器，用时间轴 + 事件（Track/Action）描述技能行为。

- **主 AGE**: 同一时间只能执行一个（如施法中不能再施法）
- **子 AGE**: 由 `SpawnBulletTick` 引用，可嵌套多层（S1→S1B1→S1B1E1）
- **时间单位**: 逻辑帧 = 1/15s (66ms)，渲染帧 = 1/30s (33ms)
- **Tick**: 不可打断的瞬时事件
- **Duration**: 可被控制打断的持续事件（Track 长度/Action 长度=百分比时长）

### 2. 文件命名规则

| 前缀 | 含义 | 对应 |
|------|------|------|
| A1/A2/A3 | 普攻第 1/2/3 段 | AutoAttack |
| S1/S2/S3 | 1/2/3 技能 | Q/W/R |
| U1 | 大招 | R (Ultimate) |
| P/P1 | 被动 | Passive |
| B/B0/B1 | 子弹子 AGE | 弹道/碰撞载体 |
| E/E1/E2 | 效果子 AGE | Buff/伤害表现 |
| H | 回城 | 忽略 |

- **忽略**: `actorinfo` 文件（模型配置，不影响技能逻辑）
- **AGE 路径**: `Prefab_Hero/{编号}_{英雄名}/skill/{文件名}.xml`

### 3. AGE XML 结构

```xml
<AGE>
  <ActionGroup name="主轨道组">
    <Track name="轨道名" 
           dependTrackName="依赖轨道(可选)" 
           actionType="事件类型">
      <Action name="动作名"
              startFrame="起始帧"
              endFrame="结束帧(Duration类型)"
              参数1="值"
              参数2="值" />
    </Track>
  </ActionGroup>
</AGE>
```

**关键属性**:
- `actionType` → 决定事件类型（见下方事件表）
- `startFrame/endFrame` → 时间轴位置，÷15 = 秒
- `dependTrackName` → Track 依赖（条件→行为链）
- `Action` 内的参数因事件类型而异

### 4. Track 依赖关系（重要！）

AGE 的核心控制流机制：
- **被依赖 Track** = 条件（如 `FilterTargetType`）
- **依赖 Track** = 行为（如受击动画、伤害）
- 条件满足 → 触发行为；条件不满足 → 行为不执行
- 一个条件 Track 可以被多个行为 Track 依赖

## 📋 AGE 事件类型完整表

### 核心事件（必须转换）

| 事件类型 | 王者功能 | Roblox 映射 | 解析要点 |
|---------|---------|------------|---------|
| **SpawnBulletTick** | 生成子弹(引用子 AGE) | Projectile 创建 | `action` 参数 = 子弹 AGE 路径，**必须递归读取** |
| **SpawnObjectDuration** | 生成零时物件(碰撞载体) | Area 碰撞载体 | 通常配合 SetCollision + HitTrigger |
| **SetCollisionTick** | 设置碰撞体形状/大小 | hitboxSize | `shape`=BOX/CYLINDERSECTOR, `x,y,z`=尺寸 |
| **MoveBulletDuration** | 弹道移动 | Projectile 速度/距离 | `speed`, `distance`, `追踪`=homing |
| **MoveActorDuration** | 角色位移(突进) | Dash 距离/速度 | `speed`/`distance`, `teleport`=瞬移 |
| **HitTriggerDuration** | 持续碰撞+受击→加 Buff | SkillHelper:ApplyEffects | `目标技能效果组合ID` → 22号表 |
| **HitTriggerTick** | 单次受击事件 | 即时效果触发 | 同上，但仅触发一次 |
| **SimpleSpawnBuffTick** | 直接给目标施加 Buff | BuffSystem:ApplyEffect | `效果组合ID` → 22号表 |

### SkillFunc 事件（Buff AGE 中的效果结算）

| 事件类型 | 王者功能 | Roblox 映射 | ⚠️ 注意 |
|---------|---------|------------|---------|
| **SkillfuncInstant** | 单次结算(伤害/回血) | EffectExecutor(即时) | 触发时刻结算 |
| **SkillfuncDuration** | 持续时长结算 | EffectExecutor(持续) | Track长度=效果持续时间 |
| **SkillfuncPeriodic** | 周期性结算(周期Buff) | EffectExecutor(周期) | Track长度=持续, 22号表"作用周期"=间隔 |

> ⚠️ **SkillFunc 不能缺失**，否则 22 号表的效果数据不会生效。选错类型也会导致错误。

### 重要事件（影响技能结构）

| 事件类型 | 王者功能 | Roblox 映射 |
|---------|---------|------------|
| **FilterTargetType** | 过滤目标类型(条件 Track) | 条件判断逻辑(if 语句) |
| **ChangeSkillTriggerTick** | 切换技能(多段普攻) | 技能状态机/recast |
| **SkillCDTriggerTick** | 主动触发 CD | CD 配置（王者 CD 必须主动触发！） |
| **ForbidAbilityDuration** | 施法硬直(禁移/禁打断) | castTime/前后摇 |
| **DynamicSearchValidTargetDuration** | 动态搜索目标 | 目标选择逻辑 |

### 表现事件（通常忽略）

| 事件类型 | 功能 | 处理 |
|---------|------|------|
| PlayAnimDuration | 播放动画 | 提取动画名供参考 |
| SetBehaviour | 设置行为(打断+朝向) | 忽略 |
| SetAttackDir | 设置攻击方向 | 忽略 |
| SkillInputCacheDuration | 技能输入缓存 | 忽略 |
| SkillUseCacheTick | 释放缓存 | 忽略 |
| TriggerParticleTick | 触发特效 | 忽略 |
| PlayHeroSoundTick | 播放音效 | 忽略 |
| CameraShakeDuration | 摄像机震动 | 忽略 |

## 🔍 AGE Archetype 模式识别

通过 AGE 事件组合判断技能 Archetype：

| AGE 特征 | Roblox Archetype |
|---------|-----------------|
| SpawnBulletTick → 子AGE(MoveBulletDuration + HitTriggerDuration) | **ProjectileSkill** |
| SpawnObjectDuration + SetCollisionTick(CYLINDERSECTOR) + HitTriggerDuration | **AreaSkill** |
| MoveActorDuration(teleport) + 落点碰撞 | **DashSkill** |
| DynamicSearchValidTargetDuration + SpawnBulletTick(锁定目标) | **InstantSkill** |
| MoveBulletDuration(长距离) + 连续 HitTriggerDuration | **BeamSkill** |
| 极短AGE + SpawnBulletTick → 多个子AGE | 根据子 AGE 类型决定 |

### AGE 模板编号对照

| 编号 | 名称 | Archetype |
|------|------|-----------|
| 01 | 近身范围攻击 | AreaSkill |
| 02 | 发射子弹 | ProjectileSkill |
| 03 | 锁定目标位移 | DashSkill(锁定) |
| 04 | 选方向位移 | DashSkill(方向) |
| 05 | 选位置位移 | DashSkill(位置) |
| 06 | 自身AOE(不可移动) | AreaSkill(self, immobile) |
| 07 | 自身AOE(可移动) | AreaSkill(self, mobile) |
| 21 | 锁定子弹 | ProjectileSkill(homing) |
| 22 | 固定射程直射子弹 | ProjectileSkill(linear) |
| 23 | 选定位置子弹(无飞行) | AreaSkill(instant spawn) |
| 24 | 选定位置子弹(直线飞行) | ProjectileSkill(to position) |
| 25 | 选定位置子弹(抛投飞行) | ProjectileSkill(arc) |
| 31-38 | 受击效果模板 | → EffectConfig 条目 |

## ✅ 解析最佳实践

1. **先读主 AGE**，提取所有 `SpawnBulletTick` 的 action 路径
2. **递归读取所有子 AGE**（B1→B1E1→...），直到没有新的 SpawnBulletTick
3. **提取 HitTriggerDuration/Tick** 中的 `目标技能效果组合ID` → 建立效果 ID 清单
4. **提取 SimpleSpawnBuffTick** 中的 Buff ID → 同样加入效果清单
5. **结合 Track 依赖** 理解条件分支（如 FilterTargetType → 不同目标不同效果）
6. **识别 Archetype** — 根据核心事件组合判断

## ❌ 常见陷阱

1. **忽略子 AGE 嵌套** → 必须递归！S1→S1B1→S1B1E1 可能有 3+ 层
2. **不同技能共用 Buff** → 同一个效果组合 ID 可能被普攻和技能共用
3. **大招分发模式** → 极短 AGE(0.03s) + SpawnBulletTick×N → 多个子 AGE 才是真正逻辑
4. **SkillFunc 缺失** → 22 号表有数据但 AGE 没有对应 SkillFunc → 效果不生效
5. **CD 不触发** → 王者的 CD 必须由 `SkillCDTriggerTick` 主动触发，不写 = 无 CD

## 🔗 关联技能

- [王者→Roblox 映射规则](./hok-to-roblox-mapping.md)
- [英雄移植标准 SOP](./hero-translation-sop.md)
- [英雄移植参考样本](./hero-translation-reference.md)
- [MOBA 技能实现模式](./moba-skill-patterns.md)
