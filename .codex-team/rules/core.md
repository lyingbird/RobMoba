# Core Rules

1. 仓库代码是唯一真相源。
2. Roblox Studio 只负责验证，不负责定义主线架构。
3. `.codex-team/` 是 Codex 专属工作流目录，不给其他 AI team 使用。
4. `.codebuddy/` 可以参考，但不能作为当前运行依据。**不要修改 `.codebuddy/` 下的任何文件。**
5. 每次重要判断都要回写到 `MEMORY.md`。
6. 每次新阶段开始前都要更新 `plans/` 和 `dispatch/current.md`。
7. 优先收敛分叉，再做功能扩展。
8. UX-related work should produce an interaction draft before implementation, followed by reflection and at least one iteration.

## 作用域纪律（高于一切执行规则）

9. **只做 dispatch 中明确列出的任务**。dispatch 中没有的工作，不做。
10. **只修改任务卡片中"文件所有权"列出的文件**。列表外的文件一律不动。
11. **最小修改原则**：能改 3 行解决的，不改 30 行。不做额外优化、重构、美化。
12. **发现范围外的问题**：在 `KANBAN.md` 记 backlog，不要动手修。
13. **禁止**：新建文件、删除文件、重命名、改公开接口签名、新增 Remote、改初始化顺序——除非任务卡片显式要求。
14. **变更超过阈值时（单文件 >50 行或涉及列表外文件）**：必须标记 blocked 并说明理由，等人类确认。
