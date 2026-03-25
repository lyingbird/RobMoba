# Codex Team

这是本项目中 `Codex` 专属的 agent 工作流目录。

## 定位
- 只服务 `Codex`
- 不给 `.codebuddy` 或其他 AI team 复用
- 与其他 AI team 并行存在，但互不干扰
- 以后以仓库为准，`Roblox Studio` 只作为验证环境，不作为真相源

## 目录约定
- `MEMORY.md`: Codex 视角下确认过的长期事实
- `rules/`: Codex team 的硬规则
- `roles/`: Codex team 内部角色定义
- `plans/`: Codex team 当前执行计划
- `logs/`: Codex team 工作日志
- `dispatch/`: 当前轮次的派工与状态
- `templates/`: 计划、日志、交接模板

## 与 GSD 的关系
- `./.codex/` 已安装 GSD 的 Codex 本地工具
- `./.codex-team/` 不替代 GSD，而是承接本项目自己的长期记忆、角色和调度
- 这两层都只服务 Codex

## 当前决定
- 仓库代码是唯一真相源
- 当前 `Studio` 实例含有另一套演进中的系统，不能直接当主线
- 接手优先级：
  1. 收敛真相源
  2. 固化 Codex team 工作流
  3. 修基础阻塞点
  4. 再做功能迭代

## GSD 工具
- 安装位置：`./.codex/`
- 本地安装命令：
  - `npx get-shit-done-cc@latest --codex --local`
- 常见入口：
  - `$gsd-help`
  - `$gsd-do`
  - `$gsd-plan-phase`
  - `$gsd-map-codebase`

## 维护原则
- 每次关键判断要更新 `MEMORY.md`
- 每次阶段性推进要更新 `plans/` 和 `dispatch/current.md`
- 每次完成重要工作要写 `logs/`
## Figma / UX Flow
- UX-related work should produce an interaction draft before implementation.
- The draft should go through at least one reflection pass and one iteration pass.
- If Figma is connected, Codex should use Figma as the drafting surface.
- If Figma is not connected, Codex should keep a structured draft in `.codex-team/` and sync later.

## Skills
- Project-tracked skill sources live under `.codex-team/skills/`
- Runtime Codex skill mirrors may also be installed under `.codex/skills/`
- Current project skill: `roblox-training-validation`
