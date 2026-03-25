# 英雄专题 — HEROES.md

> 最后更新: 2026-03-20
> 维护者: CodeBuddy（新增/修改英雄时同步更新）

---

## 英雄总览

| 英雄 | 职业 | HP | MP | ATK | AP | DEF | MR | 移速 | 攻击间隔 |
|------|------|-----|-----|-----|-----|-----|-----|------|---------|
| 后羿 | 射手(Marksman) | 1000 | 500 | 50 | 0 | 20 | 15 | 20 | 1.0s |
| 廉颇 | 坦克(Tank) | 1800 | 300 | 80 | 0 | 50 | 40 | 16 | 1.0s |
| 安琪拉 | 法师(Mage) | 800 | 600 | 30 | 80 | 15 | 25 | 18 | 1.0s |

---

## 英雄配色

| 英雄 | 色系 | 主色 RGB | 技能图标 |
|------|------|---------|---------|
| 后羿 | 金色/火焰色 | (255,200,0)~(255,120,0) | Q🏹 W☀️ E🔥 R❄️(被动) |
| 廉颇 | 大地/铜铁色 | (200,160,80)~(220,170,60) | Q💨 W🛡️ E🔨 R👊(被动) |
| 安琪拉 | 紫色/暗魔法 | (170,60,220)~(200,80,255) | Q🔮 W🌀 E✨ (无R) |

---

## 后羿（射手）

### Q — 多重箭矢
- **类型**: Instant（瞬发）
- **效果**: 开启后普攻射 3 箭
  - 主箭: 正常方向，+75% AD 加成
  - 副箭(×2): 两侧偏移，各 +50% AD 加成
- **持续时间**: 开关式

### W — 灼日之矢
- **类型**: Direction（方向型）
- **效果**: 远程弹道，命中晕眩
- **指示器**: Arrow

### E — 落日余晖
- **类型**: Position（范围型）
- **效果**: 指定位置 AOE 减速区域
- **指示器**: Circle

### R(被动) — 迟缓之箭
- **类型**: Passive
- **效果**: 普攻叠攻速印记
  - 每层 +4% 实际修改 AttackSpeed
  - 满 3 层 → 惩戒射击 + 重置叠层

---

## 廉颇（坦克）

### Q — 三段跳斩
- **类型**: Direction（方向型）
- **效果**: 三段位移 + AOE 伤害
- **特殊**: 强化普攻命中可减 Q 的 CD 2 秒
- **指示器**: Arrow

### W — 守护之魂
- **类型**: Instant（瞬发）/ SelfCircle
- **效果**: 获得护盾 + 减速周围敌人

### E — 震地猛击
- **类型**: Direction（方向型）
- **效果**: 范围击飞
- **指示器**: Fan / Rectangle

### R(被动) — 勇士之魂
- **类型**: Passive
- **机制**:
  - **战意增涨**: 战斗中每秒 +10 战意（上限 100）
  - **减伤**: 线性减伤，最高 20%（满战意）
  - **攻速加成**: 满战意时 +30% 攻速
  - **脱战转化**: 脱战 5 秒后每秒 -20 战意 → 转化为回血（每点 = 0.5% 最大生命值）
- **UI**: 技能栏上方橙→红渐变进度条
- **Remote**: `ZhanYiUpdate` 同步战意值到客户端

---

## 安琪拉（法师）

### Q — 火球术
- **类型**: Position（位置型）
- **效果**: 5 颗火球朝指定位置飞射
  - 命中英雄后销毁
  - 同一目标递减 30% 伤害
- **指示器**: Circle

### W — 混沌火种
- **类型**: Direction（方向型）
- **效果**:
  - 单弹道命中 → 晕眩 1 秒 + 停止
  - 裂变 → 火焰漩涡 DOT 3 秒 + 减速
- **指示器**: Arrow

### E — 炽热光辉
- **类型**: Channel（引导型）
- **效果**:
  - 朝指定方向持续释放能量光束 3 秒
  - 判定范围: Box 3×4×12
  - 获得护盾（700/1050/1400 + 88%AP）
  - 免控
  - 可移动 + 可转向（通过 ChannelDirection Remote 更新）
- **指示器**: Rectangle

### R — 无
安琪拉只有 Q/W/E 三个主动技能。

### 被动 — 灼烧印记
- **触发**: 技能命中叠灼烧印记
- **DoT**: 每秒伤害 = stacks×8 + stacks×2%AP
- **移速加成**: 施法者每层 +2% 移速

---

## SkillSystem 公开 API

供其他模块调用的 SkillSystem 方法：

| 方法 | 调用方 | 说明 |
|------|--------|------|
| `syncPlayerHero(player, heroId)` | HeroManager | 同步英雄选择到技能系统 |
| `triggerSkillHitPassive(caster, target, heroId)` | EventHandlers (DealDamage) | 触发技能命中被动 |
| `setSkillReplacement(player, key, newSkillId)` | EventHandlers (ChangeSkill) | 技能替换 |
| `revertSkillReplacement(player, key)` | EventHandlers | 恢复原技能 |
| `getPlayerHero(player)` | 多处 | 查询玩家当前英雄 |
| `markInCombat(character)` | CombatManager | 标记进入战斗(触发廉颇战意) |
| `getZhanYiDamageReduction(character)` | CombatManager | 获取当前战意减伤 |
| `getZhanYiValue(character)` | 内部 | 获取战意值 |
| `resetZhanYi(character)` | HeroManager | 死亡/重生时重置 |

---

## 职责分离约定

- **HeroManager**: 英雄选择/切换、属性设置、蓝量回复、SkillBarUpdate 通知
- **SkillSystem**: 技能释放校验、执行器分发、冷却管理、普攻系统、被动触发
- **SkillSystem 不监听 HeroSelect** — 由 HeroManager 调用 `syncPlayerHero()`
