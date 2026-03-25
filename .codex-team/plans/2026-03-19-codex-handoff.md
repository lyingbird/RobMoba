# Codex Handoff Plan

状态：进行中

## 阶段 1：接手校准
- [x] 确认并记录仓库为唯一真相源
- [x] 明确 Studio 仅作为验证环境
- [x] 固化 Codex team 工作流目录
- [x] 接入 GSD 本地工具

## 阶段 2：主线收敛
- [x] 对比仓库与 Studio 的主入口差异
- [ ] 形成“需要保留/清理/忽略”的清单
- [ ] 避免后续功能开发被另一套系统干扰

## 阶段 3：基础阻塞修复
- [x] 修复 `HeroManager` 的 `regenThreads`
- [ ] 收敛 `HeroSelect` / `HeroSwitch`
- [ ] 让 `Remotes` 初始化失败时明确失败

## 阶段 4：后续功能迭代
- [ ] 恢复稳定的对局主流程
- [ ] 按仓库主线继续技能、UI、联机验证
