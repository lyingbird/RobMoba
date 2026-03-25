---
description: 
alwaysApply: false
enabled: false
updatedAt: 2026-03-25T02:32:12.626Z
provider: 
---

# 技能：Roblox Studio 测试方法

> **领域**: testing
> **适用Agent**: QA / 程序
> **加载时机**: 需要编写测试方案、执行验证、或审查代码质量时按需加载
> **大小**: ~2KB

## 📌 核心知识

1. **PlaySolo (F5)**: 在 Studio 中启动本地服务端+客户端，最常用的测试方式
2. **Local Server (Alt+P)**: 启动独立服务端 + 多个客户端窗口，测试多人联网场景（本项目匹配/对决必须用此模式）
3. **Output 窗口**: 查看 `print()` / `warn()` / `error()` 输出，支持按 Server/Client 过滤
4. **Server/Client 切换**: 运行时在 Studio 中切换查看服务端或客户端视角/代码状态
5. **Explorer 运行时检查**: 运行时可查看 DataModel 中的实际 Instance、Attribute 值、Team 分配等
6. **Selene Linter**: Roblox Luau 的静态分析工具 — 检查未使用变量、类型错误、风格问题
7. **代码审计测试**: 在 AI 开发流水线中，无法直接运行 Studio，采用静态代码审计 + PlaySolo 测试方案的混合模式

## ✅ 最佳实践

### PlaySolo 测试方案编写规范

1. **测试命名**: `[AC-XXX] {测试描述}` — 每条验收标准对应一个测试方案
2. **测试步骤格式**: 分 3 段 — 前置条件 → 操作步骤 → 预期结果
   ```
   AC-001: HeroRegistry 自动发现所有英雄配置
   前置条件: Rojo 同步完成，Studio PlaySolo 启动
   操作步骤:
   1. 打开 Output 窗口
   2. 在 Command Bar 执行: print(require(game.ReplicatedStorage.HeroRegistry).GetAll())
   3. 观察输出
   预期结果: 输出包含 Angela, Lux, HouYi, LianPo 4 个英雄 ID
   ```
3. **每个测试独立**: 不依赖其他测试的执行顺序或结果
4. **使用 Command Bar**: 运行时在 Command Bar 中执行 Lua 代码进行快速验证

### 代码审计测试规范

1. **文件存在性验证**: 确认目标文件/目录存在且路径正确
2. **代码模式搜索**: 使用 grep/search 验证关键代码模式是否存在
3. **逻辑走读**: 逐行审查关键流程，验证分支覆盖、边界处理、错误处理
4. **引用完整性**: 验证所有 require 路径有效、RemoteEvent 名称一致、ID 引用正确
5. **安全模式检查**: pcall 保护、nil 检查、遍历安全性、连接清理

### Local Server 多人测试

1. **匹配测试**: 设置 Players=2，两个客户端分别进入匹配区域
2. **对决测试**: 验证阵营分配(RedTeam/BlueTeam)、传送、击杀计数、结算回送
3. **掉线测试**: 关闭一个客户端窗口，验证另一方正确获胜

## ❌ 常见陷阱

1. **只用 PlaySolo 测联网功能** → 正确做法：联网相关必须用 Local Server (Alt+P)
2. **测试中硬编码等待时间** → 正确做法：使用条件循环等待 + 超时保护
3. **不测边界情况** → 正确做法：每个功能必须包含正常/边界/异常三类测试
4. **代码审计忽略运行时行为** → 正确做法：明确标注"需 PlaySolo 验证"的项目
5. **Output 输出不分 Server/Client** → 正确做法：print 时附带标识 `print("[Server]", ...)`
6. **测试后不清理状态** → 正确做法：PlaySolo 停止后检查是否有残留 Instance/Attribute

## 📋 检查清单

- [ ] 每条验收标准是否都有对应的测试方案 (AC-XXX)
- [ ] 测试方案是否包含前置条件、操作步骤、预期结果
- [ ] 是否包含边界条件测试（空输入、极限值、并发操作）
- [ ] 是否包含异常情况测试（无效参数、掉线、Instance 被销毁）
- [ ] 联网功能是否标注需要 Local Server 测试
- [ ] 代码审计中的运行时项是否标注"需 PlaySolo 验证"
- [ ] 是否使用 Selene 检查了代码质量（未使用变量、类型警告）

## 🔗 关联技能

- [Luau Nil 安全与类型模式](../luau/nil-safety.md)
- [Roblox Instance 与服务模式](../roblox/instance-patterns.md)