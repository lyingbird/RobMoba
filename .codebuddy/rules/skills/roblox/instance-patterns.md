---
description: 
alwaysApply: false
enabled: false
updatedAt: 2026-03-25T02:32:14.483Z
provider: 
---

# 技能：Roblox Instance 与服务模式

> **领域**: roblox
> **适用Agent**: 程序 / 主程
> **加载时机**: 需要编写或设计 ModuleScript、Script、服务交互时按需加载
> **大小**: ~2KB

## 📌 核心知识

1. **脚本类型**: `Script`(服务端) / `LocalScript`(客户端) / `ModuleScript`(共享逻辑，require 加载)
2. **require() 缓存**: `require(ModuleScript)` 首次执行后缓存返回值，后续调用直接返回缓存 — 天然单例
3. **Rojo 目录映射**: `$path` 属性将文件系统目录映射为 Roblox DataModel，子目录自动成为子 Instance
4. **服务获取**: `game:GetService("Players")` / `game:GetService("RunService")` — 不要直接 `game.Players`（类型推断更好）
5. **Instance 生命周期**: `Instance.new()` → `:SetAttribute()` → `parent = targetParent` → 使用 → `:Destroy()`
6. **RunService 循环**: `Heartbeat`(物理后每帧，服务端优先) / `RenderStepped`(仅客户端，渲染前) / `Stepped`(物理前)
7. **task 库**: `task.spawn`(非阻塞启动) / `task.delay`(延迟执行) / `task.wait`(精确等待) — 替代旧版 spawn/wait/delay
8. **Attribute 桥**: `Instance:SetAttribute(key, value)` / `GetAttribute(key)` / `GetAttributeChangedSignal(key)` — 跨脚本数据共享

## ✅ 最佳实践

1. **ModuleScript 返回 table/函数**: 导出一个 table（类似类/模块），保持清晰的公共 API
   ```lua
   local MyModule = {}
   function MyModule.DoSomething() end
   return MyModule
   ```
2. **服务端/客户端分离**: 服务端逻辑放 `ServerScriptService`，客户端放 `StarterPlayerScripts`，共享数据放 `ReplicatedStorage`
3. **自动发现模式**: 遍历目录下所有 ModuleScript 并 require — 本项目 HeroRegistry/SkillRegistry 采用此模式
   ```lua
   for _, module in folder:GetChildren() do
       if module:IsA("ModuleScript") then
           local ok, data = pcall(require, module)
           if ok then registry[data.id] = data end
       end
   end
   ```
4. **pcall 保护 require**: 外部模块 require 必须用 pcall 包裹，防止单个模块错误阻塞整体初始化
5. **Instance 设置顺序**: 先设置所有属性，最后设置 Parent — 避免触发不完整的 ChildAdded 事件
6. **Heartbeat 遍历安全**: 遍历中不直接修改集合，先收集待处理项，遍历后批量处理（BuffSystem 模式）
7. **WaitForChild 超时**: `WaitForChild("name", 5)` 加超时参数，防止无限等待

## ❌ 常见陷阱

1. **require 循环依赖** → 正确做法：提取共享逻辑到独立 ModuleScript，或使用延迟 require
2. **在 Heartbeat 回调中创建/销毁大量 Instance** → 正确做法：对象池复用，或标记后批量处理
3. **忘记 `:Destroy()` 导致 Instance 泄漏** → 正确做法：管理者模块负责 Instance 生命周期，统一清理
4. **直接修改 ReplicatedStorage 中的数据（客户端）** → 正确做法：客户端只读，修改走 RemoteEvent → 服务端
5. **在 RenderStepped 中执行耗时操作** → 正确做法：只做轻量渲染相关逻辑（相机/UI），复杂逻辑放 Heartbeat
6. **Rojo 同步时文件名冲突** → 正确做法：文件名即 Instance 名，避免同目录重名
7. **spawn() 吞异常** → 正确做法：使用 `task.spawn`，或在 pcall 中执行并处理错误

## 📋 检查清单

- [ ] ModuleScript 是否返回清晰的 table/函数（非 Instance）
- [ ] 外部 require 是否有 pcall 保护
- [ ] Instance.new 是否先设属性再设 Parent
- [ ] Heartbeat 回调中是否避免了遍历中修改集合
- [ ] 是否使用 `task.*` 替代旧版 `spawn/wait/delay`
- [ ] WaitForChild 是否设置了超时参数
- [ ] 是否正确区分了 Server/Client/Shared 的代码位置

## 🔗 关联技能

- [事件与通信模式](../architecture/event-system.md)
- [Luau Nil 安全与类型模式](../luau/nil-safety.md)
- [Roblox UI 模式](./ui-patterns.md)