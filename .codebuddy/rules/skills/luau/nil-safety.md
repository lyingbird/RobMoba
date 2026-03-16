---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：Luau Nil 安全与类型模式

> **领域**: luau
> **适用Agent**: 程序 / 主程 / QA
> **加载时机**: 编码或审查涉及外部引用、实例查找、数据获取时按需加载
> **大小**: ~2KB

## 📌 核心知识

1. **Luau 的 nil**: 类似其他语言的 null，访问 nil 的字段会直接报错终止脚本
2. **FindFirstChild vs 点号访问**: `parent:FindFirstChild("Name")` 找不到返回 nil；`parent.Name` 找不到直接报错
3. **pcall 保护**: `pcall(func, ...)` 返回 `(success, result)` — 外部调用/不确定操作必须包裹
4. **Luau 类型注解**: `--!strict` 模式启用静态类型检查；`local x: number? = nil` 声明可空类型
5. **短路求值**: `a and a.b` 安全访问嵌套字段；`a or default` 提供默认值
6. **typeof()**: Roblox 扩展的类型检查 — `typeof(x) == "Instance"` / `typeof(x) == "Vector3"` 等
7. **table 安全访问**: `table[key]` 不存在的 key 返回 nil 而非报错（与 Instance 不同）

## ✅ 最佳实践

1. **实例查找**: 使用 `FindFirstChild` 替代直接点号访问
   ```lua
   -- ✅ 安全
   local weapon = character:FindFirstChild("Weapon")
   if weapon then weapon:Destroy() end

   -- ❌ 不安全 — 不存在时报错
   character.Weapon:Destroy()
   ```
2. **WaitForChild 加超时**: 客户端等待服务端创建的对象，务必加超时
   ```lua
   local gui = player:WaitForChild("PlayerGui", 10)
   if not gui then warn("PlayerGui not found in 10s") return end
   ```
3. **pcall 保护 require**: 所有外部 ModuleScript 的 require 使用 pcall
   ```lua
   local ok, module = pcall(require, moduleScript)
   if not ok then warn("Failed to load:", module) return end
   ```
4. **Guard Clause (提前返回)**: 方法开头验证前置条件，不满足直接 return
   ```lua
   function Module.Process(player, data)
       if not player then return end
       if not data or not data.id then return end
       -- 正常逻辑...
   end
   ```
5. **默认值模式**: 使用 `or` 提供安全默认值
   ```lua
   local speed = config.MoveSpeed or 16
   local name = player:GetAttribute("DisplayName") or player.Name
   ```
6. **类型检查**: 关键路径使用 `typeof()` 或 `type()` 验证
   ```lua
   if typeof(target) ~= "Instance" then return end
   if type(amount) ~= "number" or amount <= 0 then return end
   ```
7. **table.find 安全**: `table.find(t, value)` 找不到返回 nil，使用前检查

## ❌ 常见陷阱

1. **直接点号访问子 Instance** → 正确做法：`FindFirstChild` + nil 检查
2. **pcall 捕获后不处理错误** → 正确做法：至少 `warn()` 记录，关键路径加降级策略
3. **假设 Attribute 一定存在** → 正确做法：`GetAttribute` 返回值可能为 nil，必须检查
4. **字符串拼接 nil 值** → 正确做法：`tostring(value)` 或先检查非 nil
5. **for 循环中访问被销毁的 Instance** → 正确做法：检查 `instance.Parent ~= nil` 或 `instance:IsDescendantOf(game)`
6. **RemoteEvent 参数不验证** → 正确做法：服务端 handler 逐个验证参数类型和范围
7. **字典遍历中删除键** → 正确做法：先收集要删除的键，遍历后统一删除（BuffSystem 模式）

## 📋 检查清单

- [ ] 所有 Instance 子对象访问是否使用 `FindFirstChild`（非点号）
- [ ] 所有外部 require 是否有 pcall 保护
- [ ] 所有 GetAttribute 返回值是否检查了 nil
- [ ] WaitForChild 是否设置了超时参数
- [ ] RemoteEvent 服务端 handler 是否验证了所有参数
- [ ] 公共函数入口是否有 Guard Clause
- [ ] 遍历中是否避免了直接修改被遍历的集合

## 🔗 关联技能

- [Roblox Instance 与服务模式](../roblox/instance-patterns.md)
- [事件与通信模式](../architecture/event-system.md)
