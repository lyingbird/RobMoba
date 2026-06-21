# 项目长期记忆

> 最后更新: 2026-03-18

## 项目概况

- **项目**: RobMoba — Roblox MOBA 游戏（复刻王者荣耀英雄）
- **技术栈**: Luau (Roblox) + Rojo 项目结构 + Client-Server 架构
- **当前英雄**: Lux / Angela / HouYi / LianPo (4英雄, 15技能)
- **AI 开发流水线**: 制作人→PM→策划→主程→程序→QA→交付 (`.GameDev/` 目录)
- **规则体系**: `.codebuddy/rules/skills/` 下 8 个领域知识模块 + 11 个技术 Skill

## 移动端 UI 自适应标准 (2026-03-17 建立，强制规范)

> 规范文档: `rules/skills/domain-ui/mobile-ui-adaptive-standard.md`
> 所有新增/修改的移动端 UI 代码必须遵守。

### 核心原则 (6条)
1. **Scale First** — Position/Size 主值用 Scale(0~1)，Offset 仅用于 ≤10px 微调
2. **Offset Minimal** — 禁止 `UDim2.new(0, largePixels, 0, largePixels)` 的大元素
3. **Constrain Always** — 所有 Scale 元素必须加 UISizeConstraint (可交互最小44×44px)
4. **Text Bounded** — 所有 TextScaled 必须加 UITextSizeConstraint (Min≥10, Max≤40)
5. **System SafeArea** — 用 ScreenGui.ScreenInsets = CoreUISafeInsets，不手动硬编码安全区像素
6. **Test 3 Screens** — 必须在 750p/1170p/1640p 三种分辨率下验证

### 关键实践
- 等比元素(按钮/图标)用 `SizeConstraint = RelativeYY` 以屏高为基准
- 圆角用 Scale: `UDim.new(0.15, 0)` 而非 `UDim.new(0, 20)`
- UIStroke 粗细 1~3px 可接受，大于3px 需动态计算
- Layout 容器优先用 UIListLayout/UIGridLayout + Scale Padding
- ScreenGui 默认 CoreUISafeInsets (避开刘海+Roblox顶栏)，纯背景用 None

### 当前项目现状
- 移动端专用 UI (摇杆/技能/HUD): 自适应 75%+，基于 Scale + 屏高比
- PC/共享 UI (HUD/背包/英雄选择/训练面板): 自适应 30%，大量硬编码像素
- 缺少: UIAspectRatioConstraint / UISizeConstraint / UITextSizeConstraint
- 安全区: 硬编码像素值，需迁移到 ScreenInsets
- 采用渐进迁移策略: Phase1(新增强制) → Phase2(修改时补充) → Phase3(专项优化)

## 领域知识索引系统 (2026-03-17 建立)

> 解决全局文档全量加载浪费上下文的问题，知识按需加载，减少 ~70% 上下文消耗。

- **索引入口**: `rules/skills/domain-index.md` — 关键词→领域模块映射
- **8大领域模块** (每个 60-150行):
  - D1 `domain-combat/combat-system.md` — 技能/伤害/Buff/效果/被动/能量
  - D2 `domain-hero/hero-system.md` — 英雄配置/选择/属性/等级/新增英雄
  - D3 `domain-movement/input-movement-system.md` — 摇杆/移动/输入/摄像机
  - D4 `domain-ui/ui-components.md` — UI面板/HUD/布局/交互
  - D5 `domain-networking/networking.md` — RemoteEvent/通信协议
  - D6 `domain-economy/economy-system.md` — 装备/符文/经济
  - D7 `domain-gameflow/game-flow.md` — 大厅/匹配/对决/训练场
  - D8 `domain-project/project-status.md` — 项目进度/需求状态
- **加载流程**: 提取关键词 → 读索引 → 只加载命中模块(1-3个) → 不够再回退全局文档
- **全局文档降级为回退**: 全局策划案(409行)/全局技术文档(534行) 仅在领域模块不足时使用

## 上下文分段执行策略 (2026-03-18 建立)

> 解决完整FEATURE流程在单一会话中上下文爆炸的问题。配合领域知识索引系统，两套优化累计减少约 80% 的上下文浪费。

- **核心机制**: 3段式执行 — 设计段→实现段→验收段，段间通过 `handoff.md` 交接
- **断点位置**: 主程step-04完成后(设计→实现) + 程序step-05完成后(实现→验收)
- **交接协议**: `rules/agents/01_项目管理Agent/templates/阶段交接协议.md`
- **编码阶段优化**: 任务级compact(≥4任务中途compact) + 智能文件读取(先搜后读/避免重复读)
- **预期效果**: 单段上下文峰值从 150K+ 降至 60-80K tokens (-50%)
- **影响的规则文件**:
  - `rule.md` — 上下文压缩策略章节新增分段执行+智能读取
  - `rule_workflow.md` — 新增分段执行策略章节
  - `04_程序Agent/step-03_编码实现.md` — 新增上下文管理策略章节
  - `03_主程Agent/step-04_产出物检查.md` — 完成标志新增交接摘要写入
  - `04_程序Agent/step-05_对抗审查.md` — 完成标志新增交接摘要写入
  - `01_项目管理Agent/templates/上下文恢复协议.md` — 新增交接摘要恢复分支
  - `agent-system.mdc` — 索引表新增交接协议引用

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
| 002 | 游戏主流程重设计(avatar漫游+PVP/训练场) | 🔄 进行中 |
| 003 | (跳过) | ❌ |
| 004 | Bug修复集 | ✅ |
| 005 | 基础设施重构(Registry+Effect+Buff) | ✅ |
| 006 | 技能框架升级(Archetype) | ✅ |
| 007 | 英雄量产能力(Passive+Energy+UI) | ✅ |
| 008 | 王者→Roblox移植系统 | 🔄 进行中 |
