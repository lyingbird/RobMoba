---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：Roblox 事件与通信模式

> **领域**: architecture
> **适用Agent**: 主程 / 程序
> **加载时机**: 需要设计或实现模块间通信、客户端-服务端交互时按需加载
> **大小**: ~2KB

## 📌 核心知识

1. **RemoteEvent**: 服务端 ↔ 客户端单向通信 — `FireClient` / `FireServer` / `FireAllClients`
2. **RemoteFunction**: 服务端 ↔ 客户端请求-响应 — `InvokeServer` / `InvokeClient`（谨慎使用 InvokeClient，客户端不可信）
3. **BindableEvent**: 同侧模块间通信（服务端-服务端 或 客户端-客户端） — `:Fire()` / `:Connect()`
4. **RBXScriptSignal**: Roblox 内置信号 — `Humanoid.Died`, `Players.PlayerAdded`, `RunService.Heartbeat` 等
5. **Signal 模式**: 自定义 Lua 信号实现 — 适合 ModuleScript 之间的松耦合通信
6. **本项目通信架构**: 16 个 RemoteEvent (RemoteEventInit 集中创建) + 直接 require() 模块调用
7. **事件生命周期**: `:Connect()` → 使用 → 断开连接（保存 connection 引用调用 `:Disconnect()`）

## ✅ 最佳实践

1. **RemoteEvent 集中注册**: 所有 RemoteEvent 在 `RemoteEventInit.server.lua` 中统一创建，客户端通过 `WaitForChild` 获取
2. **数据最小化原则**: RemoteEvent 只传必要数据（ID/坐标/枚举），不传整个 table 或实例引用
3. **服务端权威**: 所有游戏逻辑判断在服务端，客户端只发送意图（如技能方向、目标选择），服务端验证后执行
4. **连接管理**: 保存 `:Connect()` 返回的 `RBXScriptConnection`，在不需要时 `:Disconnect()` 防止泄漏
5. **ModuleScript 直接调用**: 同侧简单通信优先使用 `require()` 直接调用方法，避免过度使用事件
6. **事件命名规范**: `{功能}{动作}Event` 如 `CastSkillEvent`、`SyncCooldownEvent`、`DuelEvent`
7. **防刷验证**: 服务端 `OnServerEvent` 必须验证发送者身份和请求合法性（冷却/状态/权限）

## ❌ 常见陷阱

1. **RemoteEvent 不验证客户端数据** → 正确做法：服务端 handler 第一参数是 player，必须验证所有参数合法性
2. **忘记 Disconnect 导致内存泄漏** → 正确做法：保存 connection 引用，角色/对象销毁时断开
3. **InvokeClient 阻塞/超时** → 正确做法：避免使用 InvokeClient，改用 RemoteEvent 双向通信
4. **高频 RemoteEvent (每帧)** → 正确做法：合并/节流，如位置同步使用 UnreliableRemoteEvent 或降频
5. **在 RemoteEvent 中传递 Instance 引用** → 正确做法：传 ID 或路径，接收方自行查找
6. **:Connect() 回调中访问已销毁对象** → 正确做法：回调开头检查对象有效性

## 📋 检查清单

- [ ] 所有 RemoteEvent 是否在 RemoteEventInit 中统一注册
- [ ] 客户端是否使用 `WaitForChild` 获取 RemoteEvent
- [ ] 服务端 OnServerEvent handler 是否验证了 player 和参数
- [ ] 所有 `:Connect()` 是否有对应的 `:Disconnect()` 时机
- [ ] 高频事件是否有节流/合并策略
- [ ] 是否避免了在 RemoteEvent 中传递大量数据或敏感信息
- [ ] 事件命名是否符合 `{功能}{动作}Event` 规范

## 🔗 关联技能

- [Roblox Instance 与服务模式](../roblox/instance-patterns.md)
- [Roblox Studio 测试方法](../testing/roblox-studio-testing.md)
