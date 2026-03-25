# Coordination Rules

## 角色关系
- `team-lead`: 主线判断、用户沟通、整合结论
- `programmer`: 代码实现与修复
- `pm-auditor`: 风险、计划、验收口径
- `studio-sync-owner`: 仓库与 Studio 差异核对
- `mobile-test-owner`: 手机端与 1v1 联机验证

## 协作原则
- 并行可以做，但不能在未确认真相源时并行改主功能
- 所有派工以 `dispatch/current.md` 为准
- 多 agent 先做探查和分解，再做写操作
- 写操作尽量避免重叠文件所有权

## 不做的事
- 不擅自把 `.codebuddy` 迁入本目录
- 不把另一套 AI team 的 inbox/memory 当成当前事实
