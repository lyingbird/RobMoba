---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：战斗系统 (Combat System)

> **领域**: domain-combat
> **适用Agent**: 策划 / 主程 / 程序 / QA
> **加载时机**: 涉及技能释放、伤害计算、Buff/效果、普攻、被动技能时
> **大小**: ~4KB

## 📌 战斗数据流

```
客户端: CastSkillEvent(skillID, direction) → 服务端
服务端: PlayerSkillManager.OnSkillCast
  → BaseSkill:CanCast(CD/蓝量/状态)
  → Skill_XXXX:execute(caster, direction, targetPos)
    → 弹道/区域/瞬发 (Archetype层)
    → CombatUtils.getEnemiesInRange(caster, center, radius)
    → BuffSystem:ApplyEffect(source, target, effectId)
      → EffectExecutor.Execute(effectData)
  → SyncCooldownEvent → 客户端CD UI
```

## 📌 技能系统架构

### 数据层 (ReplicatedStorage/ — 客户端+服务端共享)
| 文件 | 用途 | ID格式 |
|------|------|--------|
| `Heroes/{Name}.lua` | 英雄元数据(HeroID/Role/Skills映射/Passives/EnergyType) | HeroID=字符串 |
| `Skills/{Name}_Skills.lua` | 技能数值(CD/Range/Archetype/Effects) | HoK原始ID(5位) |
| `EffectConfig.lua` | 效果定义(6种:Damage/CC/Shield/DoT/HoT/StatMod) | HoK原始ID(6位) |
| `PassiveConfig.lua` | 被动配置(事件驱动触发) | HoK原始ID(5位) |
| `EnergyConfig.lua` | 能量类型(Mana/Rage/Energy/None) | 类型名字符串 |
| `HeroRegistry.lua` / `SkillRegistry.lua` | 自动发现注册(遍历目录require) | — |

### 逻辑层 (ServerScriptService/ServerModules/)
| 模块 | 职责 |
|------|------|
| `BaseSkill.lua` | OOP基类: CD验证、蓝量消耗、符文系统 |
| `Archetypes/` | 5个中间层: Projectile/Area/Dash/Instant/Beam |
| `Skills/Skill_{ID}.lua` | 具体技能实现(继承Archetype) |
| `SkillHelper.lua` | 效果施加管线(ApplyEffects/ApplyAreaEffects) |
| `BuffSystem.lua` | Buff管理(ApplyEffect/移除/叠加/互斥, Heartbeat tick) |
| `EffectExecutor.lua` | 效果执行(6类型统一入口) |
| `CombatUtils.lua` | 敌我判断(GetTeam)+范围查找(距离平方优化) |
| `StatsManager.lua` | 16属性计算(base+level+equip) |
| `PassiveSystem.lua` | 被动运行时(事件驱动, 无Heartbeat) |
| `EnergySystem.lua` | 能量运行时(Heartbeat tick, 4类型) |
| `AutoAttackManager.lua` | 普攻管理(间隔/动画/Heartbeat) |

### ID 分配规范
- **优先HoK原始ID**: 技能5位(如10510)、效果6位(如105100)、被动5位(如10500)
- 旧临时ID: Lux 1002-1005/3001-3019, Angela 1006-1008/3020-3039, HouYi 1009-1011/3040-3059
- 通用/测试: 3900-3999

## 📌 效果系统

### 6种效果类型
| 类型 | 说明 | 关键字段 |
|------|------|---------|
| Damage | 瞬间伤害 | Amount, DamageType(Physical/Magic) |
| CC | 控制 | Duration, CCType(Stun/Knockup/Root/Slow) |
| Shield | 护盾 | Amount, Duration |
| DoT | 持续伤害 | Amount, Duration, Interval |
| HoT | 持续治疗 | Amount, Duration, Interval |
| StatMod | 属性修改 | Stat, Amount, Duration, IsPercent |

### 叠加规则: Replace / Stack / Refresh / Independent
### 互斥组: 硬控必设 MutexGroup="HardCC"

## 📌 当前数据
- **英雄**: 4名(拉克丝/安琪拉/后羿/廉颇)
- **技能**: 15个主动技能
- **效果**: 25+种效果定义
- **装备**: 2件(狂徒铠甲/无尽之刃)
- **符文**: 3个(冷却缩减/多重施法/伤害增幅)

## 🔗 关联模块
- [英雄系统](../domain-hero/hero-system.md)
- [MOBA技能实现模式](../gamedev/moba-skill-patterns.md)
- [事件与通信模式](../architecture/event-system.md)
