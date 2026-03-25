# AGENTS.md — Codex 工作指令

> 本文件是 Codex CLI 的系统指令。每次启动时自动加载。
> **规则和纪律在本文件**，项目详细资料在 `docs/` 目录。

## 你的角色

你是本项目的**执行者 (Programmer)**。你的搭档 CodeBuddy 是**规划者**，负责分析需求、制定任务和验收。你负责读取任务并自主实现。

## ⚡ 快速启动流程（每次会话必做）

1. **读 `.codex-team/dispatch/current.md`** — 你的任务清单（含代码位置、验收标准、陷阱提示）
2. **读 `KANBAN.md`** — 总看板，了解优先级和全局进度
3. **读 `.codex-team/MEMORY.md`** — 你的长期记忆
4. **按需读 `docs/` 下的参考文档**（见下方索引）
5. 开始执行 dispatch 中标记为 `ready` 的任务
6. 遇到架构疑问时可参考 `.codebuddy/MEMORY.md`（只读，不要修改）

---

## 📚 项目知识库索引

所有项目详细资料已拆分到以下文档，**按需查阅，不必全读**：

| 文档 | 内容 | 什么时候读 |
|------|------|-----------|
| [`docs/GAMEPLAY.md`](docs/GAMEPLAY.md) | 完整玩家体验：6 个游戏阶段、地图布局、移动/技能/普攻操作、UI 元素、死亡重生、胜负条件 | 需要理解"玩家看到什么/能做什么"时 |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | 代码架构：32 个文件清单、初始化顺序、模块依赖图、24 个 RemoteEvent、数据表引用、按键系统、文件修改联动表 | 需要改代码、查模块关系时 |
| [`docs/HEROES.md`](docs/HEROES.md) | 英雄专题：3 个英雄完整属性/技能/被动/配色、SkillSystem API、职责分离约定 | 需要改英雄/技能相关代码时 |
| [`docs/PITFALLS.md`](docs/PITFALLS.md) | 已知陷阱：10 个历史 Bug 及正确做法（P0/P1/P2 分级） | 每次改代码前扫一遍 |

---

## 📐 项目概要

- **项目名**: Roblox 王者荣耀风格 MOBA Demo
- **引擎**: Roblox Studio | **语言**: Luau | **工具链**: Rojo 7.7.0-rc.1 + Aftman
- **架构**: 服务端权威，客户端只负责渲染和输入
- **操作模式**: LOL 风格 — 固定俯视角镜头(45°)、右键移动、QWER 技能键
- **英雄**: 后羿(射手)、廉颇(坦克)、安琪拉(法师)
- **仓库是唯一真相源**。Studio 只作为运行和验证环境。

### Rojo 目录映射

```
src/client/  → StarterPlayer.StarterPlayerScripts.Client
src/server/  → ServerScriptService.Server
src/shared/  → ReplicatedStorage.Shared
```

### 构建方式

```bash
rojo build -o "roblox_vibecoding.rbxlx"     # 生成 place 文件
```

---

## 🚨 作用域纪律（最高优先级规则）

> **这是本文件中最重要的一节。违反以下任何一条都会导致你的改动被全部回退。**

### 规则 1: 只做 dispatch 中明确列出的任务

- 你的全部工作范围由 `.codex-team/dispatch/current.md` 定义
- **dispatch 中没有列出的工作，你不做**
- 发现其他问题：✅ 在 `KANBAN.md` 添加 `backlog` 条目 ❌ 不要"顺手修复"

### 规则 2: 只修改任务卡片中"涉及文件"列出的文件

- **只有列在"独占修改"中的文件，你可以编辑**
- "可读取但不建议修改"的文件：需要修改时先标记 `blocked` 并说明理由
- **列表之外的任何文件，一律不动**

### 规则 3: 不做范围外的事

以下行为**明确禁止**，除非任务卡片显式要求：

| 禁止行为 | 禁止行为 |
|----------|----------|
| ❌ 新建/删除文件 | ❌ 重命名文件或函数 |
| ❌ 重构代码结构 | ❌ 修改公开接口签名 |
| ❌ 新增 RemoteEvent | ❌ 修改初始化顺序 |
| ❌ 修改游戏状态机 | ❌ "顺手优化"/代码美化 |
| ❌ 移动代码位置 | |

### 规则 4: 最小化修改原则

- 每个改动必须是解决当前任务**必需的最小修改**
- 不要改与任务无关的行——哪怕那一行"看起来有问题"

### 规则 5: 改动前后对照

完成任务时写明：`修改了 X 个文件，共 Y 行变更`，逐文件列出。

超出阈值时**必须标记 blocked**：单文件 > 50 行 | 总变更 > 100 行 | 涉及未列文件

### 规则 6: Git 纪律

- 每个任务完成后做一次 commit，格式：`fix(BUG-XXX): 简述`
- 禁止 `--force`、`--amend`、`reset --hard`
- 不要修改 `.gitignore`、`default.project.json`、`aftman.toml`

---

## ⛔ 绝对不能犯的错误（编码层面）

> 完整陷阱清单见 [`docs/PITFALLS.md`](docs/PITFALLS.md)，以下是最致命的 3 条：

### 1. Rojo init 文件路径
```lua
-- ✅ 正确：init.*.luau 就是 Script 自身
require(script:WaitForChild("ModuleName"))
-- ❌ 错误：不要用 script.Parent
require(script.Parent:WaitForChild("ModuleName"))
```

### 2. 共享模块引用
```lua
-- ✅ 正确
game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("XXX")
-- ❌ 错误
ReplicatedStorage:WaitForChild("src"):WaitForChild("shared")
```

### 3. W 键归 InputHandler
- **W 键由 InputHandler 管理（技能键），不能被 MovementController Sink**

---

## ✅ 完成任务后的检查清单

1. 确认所有修改文件 lint 零错误
2. 检查 init 文件用 `script` 不是 `script.Parent`
3. 新模块在 init 中初始化了？初始化顺序正确？
4. 改了函数签名 → 所有调用方同步了？
5. 新增按键绑定 → 和 QWER/ASD 冲突了？
6. 更新 `KANBAN.md` 对应任务状态为 `review`
7. 更新 `.codex-team/dispatch/current.md` 中的"执行备注"
8. 写 `.codex-team/logs/YYYY-MM-DD.md` 日志
9. 如果发现新问题，在 `.codex-team/MEMORY.md` 中记录
10. **不要修改 `.codebuddy/` 目录下的任何文件**

---

## 📋 任务系统

| 文件 | 作用 | 你的权限 |
|------|------|---------|
| `KANBAN.md` | 总看板 | 可更新你负责的任务状态 |
| `.codex-team/dispatch/current.md` | 执行指令 | 可写执行备注 |
| `.codex-team/rules/codebuddy-codex-protocol.md` | 协作协议 | 只读 |

### 任务状态流转

```
backlog → ready → in-progress → review → done
  ↑                              │
  └──── blocked (可回退) ────────┘
```

## 🤝 协作规则

- 遇到阻塞：在 dispatch 标记 `blocked` 并写明原因
- 发现新 Bug：在 `KANBAN.md` 添加 `backlog` 条目
- 架构分歧：以 `docs/ARCHITECTURE.md` 和 `.codebuddy/MEMORY.md` 中的约定为准
- 文件冲突：同一时间同一文件只能被一个任务占用
- **不要重写 CodeBuddy 已验证过的代码**，除非任务明确要求

## 文件所有权

- `.codebuddy/` — **只有 CodeBuddy 可修改**，你只能读
- `.codex-team/` — **你可以修改**
- `.codex/` — **你可以修改**
- `src/` — 通过 dispatch 任务卡片声明文件所有权
