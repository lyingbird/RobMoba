---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：英雄系统 (Hero System)

> **领域**: domain-hero
> **适用Agent**: 策划 / 主程 / 程序
> **加载时机**: 涉及英雄配置、英雄选择、英雄属性、新英雄添加时
> **大小**: ~3KB

## 📌 英雄总览

| HeroID | 显示名 | 定位 | 难度 | 技能(Q/W/R) | 主题色 |
|--------|--------|------|------|-------------|--------|
| Angela | 安琪拉 | 法师 | ★★☆ | 火球术/混沌火种/炽热光辉 | 紫色 |
| Lux | 光辉女郎 | 法师 | ★★★ | 光之束缚/曲光屏障/终极闪光 | 金色 |
| HouYi | 后羿 | 射手 | ★☆☆ | 多重箭矢/日之塔/烈日裁决 | 橙色 |
| LianPo | 廉颇 | 坦克 | ★★☆ | 爆裂冲撞/熔岩重击/天崩地裂 | 蓝色 |

## 📌 英雄配置文件结构

```lua
-- ReplicatedStorage/Heroes/{HeroName}.lua
return {
    heroId = "HeroName",
    displayName = "显示名",
    role = "Mage/Marksman/Tank",
    difficulty = 2,  -- 1-3 星
    skills = { Q = skillID, W = skillID, R = skillID },
    passives = { passiveID1, passiveID2 },
    energyType = "Mana/Rage/Energy/None",
    themeColor = Color3.fromRGB(r, g, b),
    poses = { idle = "rbxassetid://xxx", ... },
}
```

## 📌 英雄选择流程 (UI_HeroSelect)

```
大厅阶段 → UI_HeroSelect.Show()
  → 英雄Grid(4宫格, 按职业Tab筛选)
  → 点击英雄 → 预览(3D模型+属性面板+技能说明)
  → 确认按钮 → HeroSwapEvent → 服务端切换英雄模型
  → UI_HeroSelect.Hide() → 0.45s延迟后Destroy
```

**关键文件**: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_HeroSelect.lua`
- `Show()`: L387, `isShowing = true`
- `Hide()`: L739, `isShowing = false`, L760-765 延迟 Destroy
- 确认回调: L670-677 → `Client.client.lua:onHeroConfirmed`

## 📌 英雄属性系统

### 16项属性 (StatsManager)
```
HP, MaxHP, MP, MaxMP, Attack, MagicPower,
Armor, MagicResist, ArmorPen, MagicPen,
AttackSpeed, MoveSpeed, CritRate, CritDamage,
CDReduction, LifeSteal
```

### 属性计算: `finalStat = baseStat + levelGrowth * (level - 1) + equipBonus + buffBonus`

### 等级系统 (LevelConfig)
- 最大等级: 18级
- XP曲线: LevelConfig 定义每级所需经验
- 升级效果: StatsManager.RecalculateStats + HP/MP回满

## 📌 能量类型

| 类型 | 英雄 | 上限 | 恢复方式 | 归零效果 |
|------|------|------|----------|---------|
| Mana | Lux/Angela | 100 | 自然回复+命中回蓝 | 无法释放技能 |
| Rage | LianPo | 100 | 受伤/命中积攒 | 减伤失效 |
| Energy | — | 100 | 快速回复(每tick) | 无法释放技能 |
| None | HouYi | — | 无消耗 | — |

## 📌 新增英雄流程

1. `ReplicatedStorage/Heroes/{Name}.lua` — 英雄元数据
2. `ReplicatedStorage/Skills/{Name}_Skills.lua` — 技能数值
3. `EffectConfig.lua` 中添加效果ID段
4. `ServerModules/Skills/Skill_{ID}.lua` — 技能逻辑(继承Archetype)
5. 被动: `PassiveConfig.lua` + `PassiveSystem` 自动注册
6. 能量: `EnergyConfig.lua` (已有类型直接引用)
7. **自动注册**: HeroRegistry/SkillRegistry 自动发现，无需手动注册

## 🔗 关联模块
- [战斗系统](../domain-combat/combat-system.md)
- [MOBA技能实现模式](../gamedev/moba-skill-patterns.md)
- [王者→Roblox移植SOP](../gamedev/hero-translation-sop.md)
