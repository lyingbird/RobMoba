# 项目长期记忆

> 最后更新: 2026-03-15

## 项目概况

- **项目**: RobMoba — Roblox MOBA 游戏（复刻王者荣耀英雄）
- **技术栈**: Luau (Roblox) + Rojo 项目结构 + Client-Server 架构
- **当前英雄**: Lux / Angela / HouYi / LianPo (4英雄, 15技能)
- **AI 开发流水线**: 制作人→PM→策划→主程→程序→QA→交付 (`.GameDev/` 目录)
- **规则体系**: `.codebuddy/rules/skills/` 下 6 个 Skill 技能包

## 技能系统架构 (REQ-005/006/007 已完成)

### 核心配置文件 (ReplicatedStorage/)
| 文件 | 用途 | ID 段 |
|------|------|-------|
| `Heroes/{Name}.lua` | 英雄元数据(HeroID/Role/Skills映射/Passives/EnergyType/Poses) | HeroID=字符串 |
| `Skills/{Name}_Skills.lua` | 技能数值(CD/Range/Archetype/Effects) | HoK原始ID(如10510) / 旧临时ID(1001-1999) |
| `EffectConfig.lua` | 效果定义(Damage/CC/Shield/DoT/HoT/StatMod) | HoK原始ID(如105100) / 旧临时ID(3001-3999) |
| `PassiveConfig.lua` | 被动配置(事件驱动触发) | HoK原始ID(如10500) / 旧临时ID(5001-5999) |
| `EnergyConfig.lua` | 能量类型(Mana/Rage/Energy/None) | 类型名字符串 |
| `HeroRegistry.lua` | 自动发现 Heroes/ | — |
| `SkillRegistry.lua` | 自动发现 Skills/ | — |

### 技能逻辑层 (ServerScriptService/ServerModules/)
- `BaseSkill.lua` → 基类(CD/蓝量/符文)
- `Archetypes/` → 5 个中间层: ProjectileSkill / AreaSkill / DashSkill / InstantSkill / BeamSkill
- `Skills/Skill_{ID}.lua` → 具体技能实现(继承 Archetype)
- `SkillHelper.lua` → 效果施加管线(ApplyEffects/ApplyAreaEffects)
- `BuffSystem.lua` → Buff 管理(ApplyEffect/移除/叠加/互斥)
- `EffectExecutor.lua` → 效果执行(6类型: Damage/CC/Shield/DoT/HoT/StatMod)

### ID 分配规范
- **优先使用王者原始ID** — 新移植英雄直接使用HoK原始ID（如技能10510, 效果105100, 被动10500）
- 已有临时ID的英雄(Lux/Angela/HouYi)待后续用户提供王者ID后统一
- 技能 ID: 王者5位数原始ID（如10500=廉颇普攻, 10510=Q）
- 效果 ID: 王者6位数原始ID（如105000=廉颇AA伤害, 105100=Q伤害）
- 被动 ID: 王者5位数原始ID（如10500=P0怒气→减伤, 10501=P10回怒）
- 旧临时ID: Lux 1002-1005/3001-3019, Angela 1006-1008/3020-3039, HouYi 1009-1011/3040-3059/5003
- 被动效果 ID: 3080(HouYi攻速) — 旧格式，HouYi统一后将迁移
- 通用/测试: 3900-3999

### 廉颇(LianPo) 移植后 ID 分配（已统一为HoK原始ID）
| 类型 | HoK ID | 名称 |
|------|--------|------|
| 技能 | 10510 | Q 爆裂冲撞 |
| 技能 | 10520 | W 熔岩重击 |
| 技能 | 10530 | R 天崩地裂 |
| 技能 | 10500/10501/10502 | 普攻A1/A2/A3 |
| 效果 | 105000-105500 | 全部26个效果 |
| 被动 | 10500/10501/10502/10510 | 4个被动 |

## 王者荣耀 → Roblox 移植系统

### 用户协作模式 (v2, 2026-03-15 更新)
用户提供 **完整索引清单** 作为核心输入（一次性包含结构+路径+来源）:
- 索引清单行类型: `技能:ID`, `技能效果组合:ID<描述>`, `被动技能:ID`, `英雄能量:ID`, `动画:名`, `Age:路径`, `声音:名`, `UnityAsset:名`
- 每行含 `来源:` 标注，揭示数据的表间引用关系
- AI 从索引清单中提取完整技能结构(Step 1a-1c)，然后列出需要补充的表行数据(Step 1d)
- 用户再提供 21/22/26 号表的具体数值行数据
- 忽略: 声音、UnityAsset、ActorInfo、行为树

### 王者侧核心数据源
| 表编号 | 名称 | 主键 | 关键内容 |
|-------|------|------|---------|
| 11号 | 英雄信息表 | 武将ID | 技能1-6ID, 被动1-4, 能量类型, 基础属性 |
| 15号 | 英雄能量表 | ID | 类型(怒气/蓝量等), 上限, 回复, Max/Zero效果 |
| 21号 | 技能基础表 | 技能ID | CD/消耗/范围/释放规则/目标筛选/效果引用/AGE路径 |
| 22号 | 技能效果组合 | 效果组合ID | 效果类型/叠加/互斥/持续/参数(1=基础,3=AD加成万分比) |
| 26号 | 技能被动表 | 被动技能ID | 触发类型/条件/CD/AGE路径 |

**表文件路径**: `E:\trunk\Tools\Tdr\Databin\Domestic\data_xls\Common\`
- 格式: `.dtxml` (XML), 可直接用 search_content 按ID精准搜索
- AI可自主读取，无需用户手动提供表数据

### 索引层级关系
```
11号表(英雄) → 技能1~4ID → 21号表(技能) → 动作路径 → AGE XML
                                            → 效果组合 → 22号表
            → 被动技能1~4 → 26号表(被动) → AGE XML
            → 能量类型 → 15号表(能量)
```

### AGE XML 关键知识
- **文件位置**: `Prefab_Hero/{编号}_{英雄名}/skill/`
- **命名**: A1/A2=普攻, S1/S2/S3=1/2/3技能, U1=大招, P=被动, B=子弹子AGE, E=效果子AGE
- **嵌套**: SpawnBulletTick 引用子 AGE → 必须递归追踪
- **时间**: Tick=不可打断, Duration=可被控制打断, 逻辑帧15fps
- **Track依赖**: 斜体Track=依赖其他轨道(条件→行为)
- **SkillFunc三类型**: Instant(单次)/Duration(持续)/Periodic(周期) — 必须匹配22号表数据

### 转换范围
- ✅ 普攻 (A1/A2/A3 三段)
- ✅ 被动 (完全复刻)
- ✅ 所有技能机制 (不做简化)
- ❌ 忽略: actorinfo、特效(UnityAsset)、音效、行为树

### Skill/Rule 文件
转换能力固化在 `.codebuddy/rules/skills/gamedev/` 下:
- `age-xml-schema.md` — AGE XML 结构解析规则
- `hok-to-roblox-mapping.md` — 映射规则表
- `hero-translation-sop.md` — 5步标准 SOP + 代码模板
- `hero-translation-reference.md` — 已有英雄参考样本

## 开发流水线历史 (REQ-001~007 全部完成)

| REQ | 名称 | 状态 |
|-----|------|------|
| 001 | 初始系统 | ✅ |
| 002 | 大厅UI+1v1对决 | ✅ |
| 003 | (跳过) | ❌ |
| 004 | Bug修复集 | ✅ |
| 005 | 基础设施重构(Registry+Effect+Buff) | ✅ |
| 006 | 技能框架升级(Archetype) | ✅ |
| 007 | 英雄量产能力(Passive+Energy+UI) | ✅ |
| 008 | 王者→Roblox移植系统 | 🔄 进行中 |
