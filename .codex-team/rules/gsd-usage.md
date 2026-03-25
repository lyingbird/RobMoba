# GSD Usage

## 目标
让 Codex 在这个项目里按 GSD 的思路工作，但不让项目长期记忆依赖 GSD 内部生成物。

## 已完成
- 本地已安装 GSD for Codex 到 `./.codex/`

## 使用方式
- 需要快速查看命令时：`$gsd-help`
- 需要梳理代码库时：`$gsd-map-codebase`
- 需要对阶段任务做规划时：`$gsd-plan-phase`
- 需要按阶段推进时：`$gsd-do` 或其他对应 skill

## 边界
- GSD 是工具层
- `.codex-team/` 是项目工作流层
- 最终判断、计划、日志、记忆要写回 `.codex-team/`
