# Codex Team Memory

最后更新：2026-03-19

## 项目定位
- 项目是一个基于 `Rojo + Luau` 的 Roblox 对战/MOBA 原型
- 仓库代码位于 `src/client`、`src/server`、`src/shared`
- 仓库是唯一真相源
- `Roblox Studio` 当前实例只作为运行与验证环境

## 关键现状
- 当前 `Studio` 实例 `RobMoba` 中存在明显多于仓库的系统
- 这说明 `Studio` 内有另一套已演进的主系统痕迹
- 后续开发不能以 `Studio` 内现有结构反推主线

## 当前已确认风险
- `src/server/HeroManager.luau` 使用了未声明的 `regenThreads`
- `HeroSelect` 正式流程与 `HeroSwitch` 测试流程已经分叉
- `Remotes.getRemotes()` 失败后客户端会半启动，导致联机排查困难

## 主入口核对清单
- 仓库预期入口：
  - `src/server/init.server.luau` -> `ServerScriptService.Server`
  - `src/client/init.client.luau` -> `StarterPlayer.StarterPlayerScripts.Client`
  - `src/shared/*` -> `ReplicatedStorage.Shared.*`
- Studio 必查路径：
  - `ServerScriptService.Server`
  - `StarterPlayer.StarterPlayerScripts.Client`
  - `ReplicatedStorage.Shared`
  - `ServerScriptService`
  - `StarterPlayer.StarterPlayerScripts`
  - `ReplicatedStorage`
- 一旦仍被引用或监听，就说明另一套系统仍在主流程里的实例：
  - `ServerScriptService.MatchSystem`
  - `ServerScriptService.LobbyManager`
  - `ServerScriptService.DuelManager`
  - `ServerScriptService.TrainingManager`
  - `ServerScriptService.PlayerSkillManager`
  - `ServerScriptService.RemoteEventInit`
  - `ServerScriptService.GameManager`
  - `ServerScriptService.ServerModules`
  - `StarterPlayer.StarterPlayerScripts.UIManager`
  - `StarterPlayer.StarterPlayerScripts.SkillEffectHandler`
  - `StarterPlayer.StarterPlayerScripts.Modules`
  - `StarterPlayer.StarterPlayerScripts.UIComponents`
  - `ReplicatedStorage.HeroRegistry`
  - `ReplicatedStorage.SkillRegistry`
  - `ReplicatedStorage.ItemConfig`
  - `ReplicatedStorage.RuneConfig`
  - `ReplicatedStorage.LevelConfig`
  - `ReplicatedStorage.PassiveConfig`
  - `ReplicatedStorage.EnergyConfig`
  - `ReplicatedStorage.EffectConfig`
  - `ReplicatedStorage.Heroes`
  - `ReplicatedStorage.Skills`
  - `ReplicatedStorage.CastSkillEvent`
  - `ReplicatedStorage.HeroSwapEvent`
  - `ReplicatedStorage.AttackTargetEvent`
  - `ReplicatedStorage.SyncCooldownEvent`
  - `ReplicatedStorage.SkillDirectionEvent`
  - `ReplicatedStorage.SkillVFXEvent`
  - `ReplicatedStorage.SkillCameraEvent`
  - `ReplicatedStorage.SkillSoundEvent`
  - `ReplicatedStorage.MatchmakingEvent`
  - `ReplicatedStorage.TrainingEvent`
  - `ReplicatedStorage.TrainingSyncEvent`
  - `ReplicatedStorage.DuelEvent`

## Codex Team 规则摘要
- 不以 `.codebuddy` 为运行依据
- 不覆盖或重写另一套 AI team 的工作流目录
- 尽量把长期约束写入本目录，而不是放在临时对话里

## GSD 使用原则
- 使用 `./.codex/` 中的 GSD 工具辅助规划、代码库映射和阶段执行
- 不把 GSD 生成物当项目业务源码
- 项目级判断和记忆仍归档到 `./.codex-team/`

## 当前阶段最适合的 GSD 能力
- `$gsd-help`
- `$gsd-map-codebase`
- `$gsd-plan-phase`
- `$gsd-debug`
- `$gsd-do`

## 当前阶段不优先使用的 GSD 能力
- `$gsd-new-project`
- `$gsd-autonomous`
- `$gsd-ship`
- `$gsd-ui-phase`
- `$gsd-next`
## Skill Memory
- The project now has a tracked skill source at `.codex-team/skills/roblox-training-validation/`
- A runtime mirror is installed at `.codex/skills/roblox-training-validation/`
- This skill is for validating the live Studio training flow: lobby -> training -> hero confirm -> combat -> dummy damage
- Use the skill when users ask for training-mode verification, regression checks, or end-to-end Studio gameplay validation

## 公共看板协作（2026-03-20 建立）
- CodeBuddy 已建立双层看板体系：`KANBAN.md`（总看板）+ `.codex-team/dispatch/current.md`（执行层）
- 协作协议：`.codex-team/rules/codebuddy-codex-protocol.md`
- 任务卡片模板：`.codex-team/templates/task-card.template.md`
- CodeBuddy 负责规划和验收，Codex 负责实现
- 任务状态流转：backlog → ready → in-progress → review → done
- 当前首批 3 个 Bug 修复任务（BUG-001/002/003）已在 dispatch 中就绪
- Codex 执行时参考 `.codebuddy/MEMORY.md` 的已知陷阱列表
- 完成后更新 `KANBAN.md` 状态 + 写 `logs/` 日志

## Training Validation Facts
- Live Studio training flow currently runs through the lobby/training stack, not the old repo `GameManager` gameplay loop
- Stable validation bridge for flaky hero-select GUI interaction: `GM_ForceHeroConfirm`
- Stable combat validation bridge when MCP GUI hit-testing is flaky: live client RemoteEvents `AttackTargetEvent`, `CastSkillEvent`, and `SkillDirectionEvent`
- A known live-system warning to record when seen: `SyncEnergyEvent` invocation queue exhaustion
