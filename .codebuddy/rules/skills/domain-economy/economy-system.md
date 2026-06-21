---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：经济系统 (Economy)

> **领域**: domain-economy
> **适用Agent**: 策划 / 程序
> **加载时机**: 涉及装备、符文、物品、经济循环时
> **大小**: ~1.5KB

## 📌 装备系统

### 当前装备
| ItemID | 名称 | 类型 | 效果 |
|--------|------|------|------|
| 1 | 狂徒铠甲 | 防御 | +HP, +Armor |
| 2 | 无尽之刃 | 攻击 | +Attack, +CritRate, +CritDamage |

### 架构
- **数据**: `ReplicatedStorage/ItemConfig.lua` — 物品定义(ID, Name, Stats, Price)
- **逻辑**: `ServerModules/InventoryManager.lua` — 购买/出售/装备/卸载
- **UI**: `UIComponents/UI_Backpack.lua` — 背包面板
- **通信**: `InventoryEvent` (C↔S)

### 装备效果: 购买后 StatsManager 重新计算属性(base+level+**equip**)

## 📌 符文系统

### 当前符文
| RuneID | 名称 | 效果 |
|--------|------|------|
| 2001 | 冷却缩减 | +CDReduction |
| 2002 | 多重施法 | 技能触发额外效果 |
| 2003 | 伤害增幅 | +DamageBoost |

### 架构
- **数据**: `ReplicatedStorage/RuneConfig.lua`
- **UI**: `UIComponents/UI_DragDrop.lua` — 拖放绑定
- **通信**: `RuneEvent` (C→S)

## 📌 等级经济

- XP来源: 击杀敌方英雄/小兵
- 等级上限: 18级
- 每级: 属性成长(LevelConfig定义) + HP/MP回满
- 属性公式: `baseStat + levelGrowth * (level - 1)`

## 🔗 关联模块
- [战斗系统](../domain-combat/combat-system.md)
- [英雄系统](../domain-hero/hero-system.md)
