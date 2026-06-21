---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 📚 RobMoba 知识索引 (Domain Knowledge Router)

> **用途**: Agent 根据需求内容匹配相关领域，按需加载知识模块，避免全量读取巨型文档
> **使用方式**: 任何 Agent 在分析需求时，先读此索引 → 匹配关键词 → 只加载命中的领域模块
> **更新时机**: 新增领域模块 或 需求交付改变了系统架构时

---

## 🗂️ 领域知识模块清单

| # | 领域 | 文件 | 大小 | 匹配关键词 |
|---|------|------|------|-----------|
| D1 | **战斗系统** | `domain-combat/combat-system.md` | ~4KB | 技能, 伤害, Buff, 效果, 被动, 能量, 普攻, CD, 冷却, Archetype, BaseSkill, EffectConfig, BuffSystem, ApplyEffect, CombatUtils, StatsManager |
| D2 | **英雄系统** | `domain-hero/hero-system.md` | ~3KB | 英雄, 角色, HeroID, 属性, 等级, 技能配置, 新英雄, HeroRegistry, 英雄选择, HeroSelect, 职业, 定位 |
| D3 | **移动与输入** | `domain-movement/input-movement-system.md` | ~4KB | 摇杆, 移动, 输入, 触摸, 手机端, Mobile, joystick, MobileInputManager, MovementManager, CameraManager, 操控, WASD, 方向 |
| D4 | **UI组件** | `domain-ui/ui-components.md` | ~3KB | UI, 界面, HUD, 面板, 按钮, 布局, ScreenGui, 小地图, 背包, 匹配按钮, DisplayOrder, 弧形, 王者布局 |
| D4b | **移动端UI自适应规范** | `domain-ui/mobile-ui-adaptive-standard.md` | ~8KB | 自适应, 响应式, Scale, Offset, UDim2, 屏幕适配, 分辨率, SafeArea, ScreenInsets, UIAspectRatioConstraint, UISizeConstraint, UITextSizeConstraint, RelativeYY, 移动端规范, 触摸目标, 最小尺寸, 圆角, TextScaled |
| D5 | **通信协议** | `domain-networking/networking.md` | ~2KB | RemoteEvent, 网络, 通信, 同步, 服务端, 客户端, Event, FireClient, FireServer, 协议 |
| D6 | **经济系统** | `domain-economy/economy-system.md` | ~1.5KB | 装备, 符文, 物品, 购买, 出售, 背包, ItemConfig, RuneConfig, 金币, 经济 |
| D7 | **游戏流程** | `domain-gameflow/game-flow.md` | ~3KB | 大厅, 匹配, 对决, 训练场, 状态流转, LOBBY, MATCHING, DUELING, Client.client.lua, 初始化, 生命周期 |
| D8 | **项目状态** | `domain-project/project-status.md` | ~2KB | 进度, 需求, REQ, 状态, 完成, 进行中, 依赖, 版本 |

---

## 🔧 已有技术 Skill 模块

| # | 领域 | 文件 | 匹配关键词 |
|---|------|------|-----------|
| S1 | 事件通信模式 | `architecture/event-system.md` | RemoteEvent最佳实践, BindableEvent, 信号模式, Connect/Disconnect |
| S2 | MOBA技能模式 | `gamedev/moba-skill-patterns.md` | 新增技能, 弹道, 区域, 效果配置, 技能逻辑编写 |
| S3 | 英雄移植SOP | `gamedev/hero-translation-sop.md` | 王者荣耀, 移植, HoK, AGE XML, 21号表, 22号表 |
| S4 | 英雄移植参考 | `gamedev/hero-translation-reference.md` | 已有英雄对照, ID映射参考 |
| S5 | AGE XML | `gamedev/age-xml-schema.md` | AGE文件, XML解析, SpawnBulletTick |
| S6 | HoK映射 | `gamedev/hok-to-roblox-mapping.md` | 字段映射, 单位转换 |
| S7 | Luau Nil安全 | `luau/nil-safety.md` | nil, FindFirstChild, pcall, Guard Clause, 类型检查 |
| S8 | Roblox Instance | `roblox/instance-patterns.md` | require, ModuleScript, RunService, Attribute, WaitForChild |
| S9 | Roblox UI模式 | `roblox/ui-patterns.md` | ScreenGui, UIListLayout, TweenService, AnchorPoint |
| S10 | 调试SOP | `testing/debug-collaboration-sop.md` | Bug, 截图分析, MCP诊断, execute_luau, 调试 |
| S11 | Studio测试 | `testing/roblox-studio-testing.md` | PlaySolo, 测试方案, AC验收, 代码审计 |

---

## 📖 使用指南

### Agent 加载流程

```
1. 读取需求描述 / 用户输入
2. 提取关键词
3. 对照上表匹配命中的领域 (通常 1-3 个)
4. 只加载命中的 domain-*/skill 文件
5. 如需更详细信息 → 读取对应 REQ 目录下的具体文档
```

### 典型匹配示例

| 需求描述 | 应加载的模块 |
|---------|------------|
| "摇杆在英雄选择时不应该能移动" | D3(移动与输入) + D4(UI) + D7(游戏流程) |
| "新增一个坦克英雄" | D2(英雄) + D1(战斗) + S2(技能模式) + S3(移植SOP) |
| "背包购买装备后属性没更新" | D6(经济) + D1(战斗/StatsManager) |
| "匹配成功后传送失败" | D7(游戏流程) + D5(通信) |
| "技能CD显示不正确" | D1(战斗) + D4(UI) + D5(通信) |
| "查看项目进度" | D8(项目状态) |
| "手机端横屏设置" | D3(移动与输入) |

### 全量文档（仅在索引不够时使用）

只有当领域模块无法覆盖需求时才回退读取:
- `全局策划案.md` — 完整游戏设计（~409行）
- `全局技术文档.md` — 完整技术架构（~534行）
- `需求池.md` — 所有需求详细记录（~643行）
- `进度看板.md` — 实时进度跟踪（~286行）

---

## ⚠️ 维护规则

1. **需求交付后**: 更新受影响的领域模块 + `domain-project/project-status.md`
2. **新增系统**: 创建新的 `domain-{name}/` 目录 + 更新本索引
3. **领域模块大小**: 保持每个模块 ≤150行，超过则拆分
4. **关键词覆盖**: 确保每个游戏概念至少被一个领域模块的关键词覆盖
