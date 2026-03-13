# RobMoba 🎮

Roblox Studio 上的轻量 MOBA 对战游戏 Demo。

A lightweight MOBA demo built on Roblox Studio.

---

## 📋 目录 / Table of Contents

- [功能特性](#-功能特性--features)
- [英雄一览](#-英雄一览--heroes)
- [环境准备](#-环境准备--prerequisites)
- [快速开始](#-快速开始--quick-start)
- [项目结构](#-项目结构--project-structure)
- [多人测试指引](#-多人测试指引--multiplayer-testing-guide)
- [AI Agent 开发流水线](#-ai-agent-开发流水线--ai-agent-pipeline)
- [核心系统](#-核心系统--core-systems)
- [配置说明](#-配置说明--configuration)

---

## ✨ 功能特性 / Features

| 系统 | 说明 |
|------|------|
| 🗡️ 技能系统 | 数据驱动，15 个技能 × 6 种类型（方向/范围/自身/引导/汇聚/突进） |
| ⚔️ 战斗系统 | CombatUtils 统一目标验证，ATK×暴击÷防御减伤公式 |
| 🏟️ 1v1 对决 | 自由大厅 → 匹配区域/按钮 → 阵营分配 → 竞技场传送 → 先3杀获胜 → 返回大厅 |
| 📊 属性系统 | 16 项属性 (HP/MP/ATK/DEF/SPD/暴击/穿透…)，base + level + equip 叠加 |
| 🎒 装备系统 | 6 格背包 + 商店 + 拖拽换位 |
| 🎯 操控系统 | PC 键鼠 LOL 风格 (QWER + 鼠标瞄准 + 右键移动) |
| 🎬 电影特写 | 大招释放时镜头锁定 + 缩放 + 慢动作 |
| 🤖 AI Agent | 8 角色流水线 (制作人/PM/策划/主程/程序/美术/QA/UX) |

---

## 🦸 英雄一览 / Heroes

| 英雄 | 定位 | Q | W | R |
|------|------|---|---|---|
| **Lux** 光辉女郎 | 法师 | 光之束缚 (方向) | 棱光屏障 (方向) | 终极闪光 (方向) |
| **Angela** 安琪拉 | 法师 | 火球术 (方向) | 火焰风暴 (范围) | 浴火重生 (自身) |
| **HouYi** 后羿 | 射手 | 多重箭 (方向) | 落日弓 (汇聚) | 炽热灼烧 (引导) |
| **LianPo** 廉颇 | 坦克 | 勇往直前 (突进) | 大地震击 (范围) | 不屈意志 (自身) |

---

## 🔧 环境准备 / Prerequisites

| 工具 | 版本 | 说明 |
|------|------|------|
| [Roblox Studio](https://create.roblox.com/) | 最新版 | 游戏引擎 |
| [Aftman](https://github.com/LPGhatguy/aftman) | 0.3+ | Roblox 工具链管理器 |
| [Rojo](https://rojo.space/) | 7.x | 文件系统 ↔ Studio 实时同步 |
| [Git](https://git-scm.com/) | 2.x | 版本控制 |

---

## 🚀 快速开始 / Quick Start

```bash
# 1. 克隆项目
git clone https://github.com/your-name/roblox_moba.git
cd roblox_moba

# 2. 安装 Rojo (通过 Aftman)
aftman install

# 3. 启动 Rojo 服务
rojo serve

# 4. 打开 Roblox Studio
#    → 安装 Rojo 插件 (Plugins → Manage Plugins → 搜索 Rojo)
#    → 点击 Rojo 插件面板 "Connect" 连接到 localhost:34872

# 5. 单人测试
#    按 F5 或 TEST → Play Solo

# 6. 多人测试（见下方详细指引）
#    TEST → Players: 2 → Start
```

---

## 🗂️ 项目结构 / Project Structure

```
roblox_moba/
├── src/
│   ├── ReplicatedStorage/          # 共享配置
│   │   ├── HeroConfig.lua          # 英雄属性/技能/主题色配置
│   │   ├── SkillConfig.lua         # 技能数据表 (15技能)
│   │   ├── ItemConfig.lua          # 装备数据表
│   │   ├── RuneConfig.lua          # 符文系统
│   │   └── LevelConfig.lua         # 等级经验曲线
│   │
│   ├── ServerScriptService/        # 服务端逻辑
│   │   ├── RemoteEventInit.server.lua   # 16个 RemoteEvent 初始化
│   │   ├── GameManager.server.lua       # PvP 状态机 (当前禁用)
│   │   ├── LobbyManager.server.lua      # 大厅 + 匹配队列
│   │   ├── DuelManager.server.lua       # 对决生命周期管理
│   │   ├── MatchSystem.server.lua       # 击杀计数/死亡重生/胜负判定
│   │   ├── PlayerSkillManager.server.lua # 技能装备
│   │   └── ServerModules/
│   │       ├── BaseSkill.lua            # 技能基类 (OOP)
│   │       ├── CombatUtils.lua          # 目标验证统一接口
│   │       ├── StatsManager.lua         # 属性管理 (16项)
│   │       ├── AutoAttackManager.server.lua # 普攻系统
│   │       ├── EnemyClass.lua           # NPC 敌人基类
│   │       ├── EnemyManager.lua         # NPC 生命周期
│   │       ├── InventoryManager.lua     # 装备背包
│   │       └── Skills/                  # 15个技能实现
│   │
│   ├── StarterPlayer/StarterPlayerScripts/  # 客户端
│   │   ├── Client.client.lua            # 客户端入口
│   │   ├── UIManager.lua                # UI 总控
│   │   ├── Modules/
│   │   │   ├── InputManager.lua         # 输入系统 (QWER+鼠标)
│   │   │   ├── CameraManager.lua        # MOBA 俯视角相机
│   │   │   ├── MovementManager.lua      # 右键移动
│   │   │   ├── CooldownManager.lua      # 技能冷却同步
│   │   │   ├── CinematicManager.lua     # 电影特写
│   │   │   └── HeroAnimator.lua         # 英雄动画控制
│   │   └── UIComponents/
│   │       ├── UI_HUD.lua               # 主 HUD (技能栏/血条/计分板)
│   │       ├── UI_HeroSelect.lua        # 英雄选择 (首选+切换双模式)
│   │       ├── UI_Backpack.lua          # 背包 UI
│   │       ├── UI_DragDrop.lua          # 拖拽系统
│   │       ├── UI_MatchButton.lua       # 匹配按钮
│   │       └── UI_OverheadUI.lua        # 头顶名字/血条
│   │
│   └── ServerStorage/
│       └── SkillEditorPlugin/           # Studio 技能编辑器插件
│
├── .codebuddy/                     # AI Agent 开发流水线系统
│   ├── rules/                      # 规则体系 (入口规则/Agent定义/工作流)
│   │   ├── rule.md                 # 主规则 (always)
│   │   ├── rule_workflow.md        # 需求类型与流转路径
│   │   ├── rule_commands.md        # /gd: 快捷命令体系
│   │   ├── rule_guards.md          # 事件驱动守卫规则
│   │   ├── rule_iteration.md       # 迭代机制与知识库
│   │   ├── agent-system.mdc        # Agent 系统激活规则
│   │   └── agents/                 # 8个 Agent 角色定义 (入口+步骤+模板)
│   └── memory/                     # 每日工作日志
│
├── .GameDev/                       # 项目管理文档
│   ├── _ProjectManagement/         # 需求池/进度看板/时长统计
│   ├── REQ-004/                    # 需求文档 (策划案/技术设计/测试报告等)
│   ├── 全局策划案.md
│   └── 全局技术文档.md
│
├── CLAUDE.md                       # AI 上下文文档
├── default.project.json            # Rojo 项目配置
├── aftman.toml                     # 工具链版本锁定
└── README.md
```

---

## 🧪 多人测试指引 / Multiplayer Testing Guide

### 方式一：Local Server (推荐，本地多人)

适用于测试 **匹配、对决、阵营分配、击杀计数、胜负结算** 等多人功能。

#### 步骤

1. **确保 Rojo 已连接** — 启动 `rojo serve`，Studio 中 Rojo 插件显示 "Connected"
2. **打开 TEST 标签** — Studio 顶部菜单栏 → `TEST`
3. **设置玩家数量** — `Players` 下拉框选择 **2**（最少 2 人触发匹配）
4. **点击 Start** — ⚠️ 不是 "Play Solo"，是 **"Start"** 按钮
5. **等待窗口打开** — 会打开 3 个窗口：
   - 🖥️ **Server 窗口** — 服务端视角，Output 面板显示所有服务端日志
   - 👤 **Player1 窗口** — 第一个玩家客户端
   - 👤 **Player2 窗口** — 第二个玩家客户端

#### 测试流程

```
Player1 窗口                      Player2 窗口
─────────────                    ─────────────
1. 选择英雄 (如 Angela)           1. 选择英雄 (如 HouYi)
2. 点击 🔒锁定选择                2. 点击 🔒锁定选择
3. 走到匹配区域 或 点击⚔️匹配按钮  3. 走到匹配区域 或 点击⚔️匹配按钮
   ↓ 两人都进入队列后自动匹配 ↓
4. 看到 "对手已找到！" + 3秒倒计时
5. 传送到竞技场 (红队左/蓝队右)
6. 开始对战！先达 3 杀获胜
7. 结算 → 5秒后自动返回大厅
```

#### 服务端日志 (Server 窗口 Output)

正常应看到以下日志链：

```
[LobbyManager] Player1 entered lobby
[LobbyManager] Player2 entered lobby
[LobbyManager] Player1 joined matchmaking queue (1/2)
[LobbyManager] Player2 joined matchmaking queue (2/2)
[LobbyManager] Match found! Player1 vs Player2
[DuelManager] Duel #1 created: Player1 vs Player2
[DuelManager] Duel #1 started!
[MatchSystem] Battle tracking started!
[MatchSystem] Player1 killed Player2! (1 kills)
...
[DuelManager] Duel #1 ended! Winner: RedTeam
[DuelManager] Duel #1 cleanup complete, players returned to lobby
```

#### Command Bar 快捷脚本 (可选)

如果不想手动操作两个客户端，可以在 **Server 窗口** 的 Command Bar 中运行以下脚本，强制两个玩家进入匹配：

```lua
-- 在 Server 窗口 Command Bar 中运行
local Players = game:GetService("Players")
local ps = Players:GetPlayers()
if #ps >= 2 then
    local re = game.ReplicatedStorage:FindFirstChild("MatchmakingEvent")
    if re then
        re:FireServer() -- 注意: 实际是客户端 FireServer，此处需通过 LobbyManager API
    end
    print("尝试匹配 " .. ps[1].Name .. " vs " .. ps[2].Name)
end
```

### 方式二：Play Solo (单人)

适用于测试 **UI 流程、英雄选择、技能释放、木桩练习** 等单人功能。

```
TEST → Play Solo (F5)
```

- 仅自己一个人，不会触发匹配和对决
- 可以在大厅自由移动、打木桩、切换英雄

### 方式三：Team Test (团队协作)

适用于 **多人联网真机测试**。需要 Roblox 发布游戏后使用。

```
TEST → Team Test → Start
```

---

## 🤖 AI Agent 开发流水线 / AI Agent Pipeline

本项目内置了一套 **8 角色游戏开发 Agent 流水线系统**，模拟真实游戏公司的工种分工，通过 [CodeBuddy](https://www.codebuddy.ai/) 的规则系统驱动。

### Agent 角色

| # | Agent | 职责 |
|---|-------|------|
| 00 | 🎬 **制作人** | 需求分析、类型判定、规模评估、流转决策 |
| 01 | 📊 **项目管理** | 需求初始化、进度追踪、文档管理 |
| 02 | 📋 **策划** | 玩法设计、验收标准、MOBA 机制设计 |
| 03 | 🔧 **主程** | 技术方案设计、架构评审、任务拆分 |
| 04 | 💻 **程序** | Luau 编码实现、代码审查 |
| 05 | 🎨 **美术** | Roblox 代码 UI、配色系统、视觉设计 |
| 06 | 🧪 **QA** | Studio 测试验证 (PlaySolo/LocalServer/MCP) |
| 07 | ✨ **UX** | 交互设计、MOBA 操控体验 |

### 使用方式

通过 `/gd:` 前缀命令与 Agent 系统交互：

```
# 需求类命令 — 启动开发流水线
/gd:new "需求描述"              # 新建需求 (进入制作人标准分析)
/gd:feature "功能描述"          # 直接按 FEATURE 类型启动
/gd:bugfix "问题描述"           # 直接按 BUGFIX 类型启动
/gd:optimize "优化目标"         # 直接按 OPTIMIZE 类型启动

# 管理类命令 — 查询/管理
/gd:status                      # 查看所有需求状态
/gd:progress                    # 查看进度看板
/gd:resume [REQ-ID]             # 恢复上次中断的需求

# 迭代类命令 — 反思/改进
/gd:reflect                     # 周期级结构化内省
/gd:audit                       # 全面审计规则体系健康度
/gd:learn "经验内容"            # 向 Agent 教授知识
```

### 流转路径

| 需求类型 | 流转路径 |
|---------|---------|
| FEATURE | 制作人 → PM → 策划 → [UX] → 主程 → 程序 → QA → 策划(交付) |
| BUGFIX | 制作人 → PM → 程序 → QA → 策划(交付) |
| OPTIMIZE | 制作人 → PM → 主程 → 程序 → QA → 策划(交付) |
| CONFIG | 制作人 → PM → 程序 → QA → 策划(交付) |

### 文件结构

```
.codebuddy/rules/
├── rule.md                  # 主规则 (自动加载)
├── rule_workflow.md         # 需求类型与流转路径
├── rule_commands.md         # /gd: 命令体系
├── rule_guards.md           # 守卫规则 (编码/文件操作)
├── rule_iteration.md        # 迭代机制与知识库
├── agent-system.mdc         # Agent 系统激活规则
└── agents/
    ├── 00_制作人Agent.md    # 入口文件 (身份/职责/步骤索引)
    ├── 00_制作人Agent/      # 步骤文件 (每步详细执行流程)
    ├── 01_项目管理Agent.md
    ├── 01_项目管理Agent/
    ├── ... (02~07 同理)
    └── 主从Agent架构.md     # L/XL 规模任务的主从模式说明
```

---

## ⚙️ 核心系统 / Core Systems

### 大厅 + 匹配 + 对决流程

```
玩家进入游戏
    │
    ▼
┌─────────────┐
│  自由大厅    │  ← 可移动、打木桩、选英雄、切换英雄
│  LobbyManager│
└──────┬──────┘
       │ 走进匹配区域 / 点击匹配按钮
       ▼
┌─────────────┐
│  匹配队列    │  ← FIFO，≥2人自动匹配
│  LobbyManager│
└──────┬──────┘
       │ 匹配成功
       ▼
┌─────────────┐
│  对决阶段    │  ← 3秒倒计时 → 阵营分配 → 竞技场传送
│  DuelManager │
└──────┬──────┘
       │ 开始战斗
       ▼
┌─────────────┐
│  战斗追踪    │  ← 击杀计数、死亡重生(5s)、先3杀获胜
│  MatchSystem │
└──────┬──────┘
       │ 胜负确定
       ▼
┌─────────────┐
│  结算 → 返厅 │  ← 5秒展示 → 传送回大厅 → 重置
│  DuelManager │
└─────────────┘
```

### 技能系统架构

```
SkillConfig (数据) → BaseSkill (基类) → Skill_XXXX (实现)
                                            │
                                     CombatUtils (目标验证)
                                            │
                              AutoAttackManager (普攻) / StatsManager (属性)
```

### 通信协议

客户端与服务端通过 16 个 RemoteEvent 通信：

| RemoteEvent | 方向 | 用途 |
|-------------|------|------|
| CastSkillEvent | Client→Server | 释放技能 |
| AttackTargetEvent | Client→Server | 普攻 |
| MatchmakingEvent | 双向 | 匹配队列 |
| DuelEvent | Server→Client | 对决状态 |
| HeroSwapEvent | 双向 | 英雄切换 |
| MatchStateEvent | Server→Client | 比赛状态 |
| DeathTimerEvent | Server→Client | 死亡倒计时 |
| ... | | 其余 9 个事件 |

---

## 📝 配置说明 / Configuration

| 配置文件 | 内容 |
|----------|------|
| `HeroConfig.lua` | 英雄属性 (Skills/Theme/Poses/CastDurations/MoveLock) |
| `SkillConfig.lua` | 技能数据 (Damage/CD/Range/Type/Cost/各种参数) |
| `ItemConfig.lua` | 装备数据 (Price/Stats/Passive) |
| `RuneConfig.lua` | 符文数据 (Buff/Duration) |
| `LevelConfig.lua` | 等级经验曲线 (XP/StatGrowth) |

### 竞技场参数

```lua
ARENA_CENTER   = Vector3.new(0, 62, 0)     -- 竞技场中心
SPAWN_DISTANCE = 40                         -- 出生点距中心距离
LOBBY_SPAWN    = Vector3.new(-197, 62.5, 204) -- 大厅出生点
KILLS_TO_WIN   = 3                          -- 先达此杀数获胜
RESPAWN_TIME   = 5                          -- 死亡重生倒计时(秒)
```

---

*Last updated: 2026-03-14*
