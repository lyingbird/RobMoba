# CodeBuddy ↔ Codex 协作协议

> 生效日期: 2026-03-20

## 1. 角色分工

| 角色 | 承担方 | 职责 |
|------|--------|------|
| **规划者** | CodeBuddy | 分析需求、制定任务、定义验收标准、审核结果、维护总看板 |
| **执行者** | Codex | 读取任务、自主实现、更新执行状态、写工作日志 |
| **仲裁者** | 人类(用户) | 最终决策权、优先级调整、冲突裁决 |

## 2. 公共看板体系

### 2.1 顶层总看板 — `KANBAN.md`（项目根目录）
- **作用**: 全局任务视图，人类和两个 AI team 的统一仪表盘
- **写入权限**: CodeBuddy 负责创建任务、更新状态为 `done`
- **读取权限**: 所有人
- **Codex 可写**: 仅更新自己负责的任务状态（`ready` → `in-progress` → `review`）

### 2.2 Codex 执行层 — `.codex-team/dispatch/current.md`
- **作用**: Codex 的具体执行指令，包含模块范围、文件列表、验收标准、陷阱提示
- **写入权限**: CodeBuddy 写任务定义部分，Codex 写执行状态和完成备注
- **格式**: 结构化任务卡片（见 `templates/task-card.template.md`）

## 3. 任务生命周期

```
backlog → ready → in-progress → review → done
   ↑                              │
   └──── blocked (可回退) ────────┘
```

| 状态 | 含义 | 谁触发 |
|------|------|--------|
| `backlog` | 已识别但未细化 | CodeBuddy |
| `ready` | 已细化，含完整执行指令 | CodeBuddy |
| `in-progress` | Codex 正在实施 | Codex |
| `review` | Codex 完成，等待验收 | Codex |
| `done` | 验收通过 | CodeBuddy / 人类 |
| `blocked` | 遇阻，需要协助 | Codex |

## 4. 文件所有权规则

### 4.1 工作流目录互不干扰
- `.codebuddy/` — **只有 CodeBuddy 可修改**
- `.codex-team/` — **只有 Codex 可修改**（除了 CodeBuddy 写入 dispatch 任务定义）
- `.codex/` — **只有 Codex 可修改**

### 4.2 src/ 代码文件的冲突避免
- 每个任务卡片必须声明**涉及文件列表**
- 同一时间同一文件只能被一个任务占用
- 如果 CodeBuddy 和 Codex 需要同时修改同一文件，由人类裁决优先级
- Codex 修改文件前应检查 `KANBAN.md` 确认没有 CodeBuddy 正在修改同一文件

### 4.3 共享只读文件
- `.codebuddy/MEMORY.md` — CodeBuddy 维护，Codex 可参考但不修改
- `.codex-team/MEMORY.md` — Codex 维护，CodeBuddy 可参考但不修改
- `KANBAN.md` — 按 §2.1 的权限规则共同维护

## 5. 交接格式

### 5.1 CodeBuddy → Codex（下发任务）
1. 在 `KANBAN.md` 添加任务行，状态标记为 `ready`
2. 在 `.codex-team/dispatch/current.md` 添加对应的结构化任务卡片
3. 任务卡片必须包含：
   - 任务 ID（与 KANBAN.md 对应）
   - 模块范围描述
   - 涉及文件列表（精确到文件路径）
   - 验收标准（可验证的条件列表）
   - 已知陷阱提示（引用 MEMORY.md 条目）

### 5.2 Codex → CodeBuddy（完成汇报）
1. 更新 `KANBAN.md` 中对应任务状态为 `review`
2. 更新 `.codex-team/dispatch/current.md` 中任务的执行备注
3. 在 `.codex-team/logs/` 写当日日志记录具体改动
4. 如果发现新问题，在 `.codex-team/MEMORY.md` 中记录

## 6. 冲突解决

| 冲突类型 | 解决方式 |
|----------|---------|
| 同文件并行修改 | 人类裁决谁优先；或拆分为不同函数/区域 |
| 任务理解分歧 | Codex 在 dispatch 标记 `blocked` 并说明疑问 |
| 架构方向分歧 | 以 `.codebuddy/MEMORY.md` 中的架构约定为准 |
| 新发现的 Bug | 发现方在 `KANBAN.md` 添加 `backlog` 任务 |

## 7. 注意事项

- Codex 执行任务时应参考 `.codebuddy/MEMORY.md` 的已知陷阱列表
- 项目的 Rojo 映射、模块初始化顺序等约定以 `.codebuddy/MEMORY.md` 为权威来源
- Codex 不应重写 CodeBuddy 已经实现并验证过的代码，除非任务明确要求
- 两个 AI team 的日志互相独立，各自在自己的目录下记录
