# 已知陷阱 — PITFALLS.md

> 最后更新: 2026-03-20
> 维护者: CodeBuddy（踩到新坑时立即追加）
> 用途: 编码前必查，code review 时逐条对照

---

## 🔴 P0 — 曾导致功能完全不工作

### 陷阱 1: Rojo init 文件的 script.Parent 陷阱

- **错误**: `script.Parent:WaitForChild("InputHandler")`
- **正确**: `script:WaitForChild("InputHandler")`
- **原因**: `init.*.luau` 在 Rojo 中编译为目录对应的 Script 自身，子模块是它的 children
- **影响**: 所有模块加载失败，客户端/服务端完全瘫痪

```lua
-- ✅ 正确
require(script:WaitForChild("ModuleName"))
-- ❌ 错误
require(script.Parent:WaitForChild("ModuleName"))
```

### 陷阱 2: PlayerModule 覆盖 DevComputerMovementMode

- **错误**: 只设 `DevComputerMovementMode = Scriptable` 就以为 WASD 被禁了
- **正确**: 三重保障 — json 属性 + ContextActionService Sink + PlayerModule Disable
- **影响**: 玩家仍然可以 WASD 移动

### 陷阱 3: ContextActionService Sink 吞掉技能键

- **错误**: 用 CAS Sink 掉 W/A/S/D 所有键来禁移动
- **正确**: 只 Sink A/S/D，W 键由 InputHandler 的 CAS 绑定处理
- **影响**: W 技能无法使用

### 陷阱 4: VFXTemplateTable 多余闭合括号 ✅ 已修复

- **错误**: 表定义中间出现多余的 `}`，导致后续 30+ 模板在 table 外部
- **正确**: 确保整个 table 只有一对 `{}`，所有模板条目在内部
- **状态**: 已修复（2026-03-20 确认表结构完整，45 个模板均在内部）

---

## 🟡 P1 — 曾导致功能部分异常

### 陷阱 5: HeroManager 与 SkillSystem 职责重复

- **错误**: 两个模块都监听 HeroSelect、都设置英雄属性、都做蓝量回复
- **正确**: HeroManager 独占英雄生命周期管理，SkillSystem 只管技能释放
- **影响**: 属性设置冲突、蓝量双倍回复
- **当前约定**: SkillSystem 不监听 HeroSelect，由 HeroManager 调用 `syncPlayerHero()`

### 陷阱 6: FindFirstChild 做必要前提条件

- **错误**: `if not FindFirstChild("X") then return end` — 可能只是还没加载
- **正确**: `WaitForChild("X", timeout)` 等待加载，超时后 warn 并 fallback
- **影响**: 时序问题导致功能随机失效

```lua
-- ❌ 危险
local shared = ReplicatedStorage:FindFirstChild("Shared")
if not shared then return end  -- 静默失败！

-- ✅ 安全
local shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not shared then warn("[Module] Shared not found after 10s") return end
```

### 陷阱 7: 友军伤害未过滤

- **错误**: 只用 `filterSelf` 过滤施法者，队友照样被技能命中
- **正确**: 基于 Team 对象判断友军/敌方，假人始终可攻击
- **影响**: 技能伤害友军

### 陷阱 8: 安琪拉技能与王者荣耀不符

- **教训**: 实现英雄技能前必须先确认技能机制原型，不要凭印象编写
- **正确流程**: 查看 docs/HEROES.md 中的技能配置 → 确认 skillType/effects/参数 → 再编写代码

---

## 🟢 P2 — 代码质量/可维护性

### 陷阱 9: 共享模块路径硬编码

- **错误**: 在模块内硬编码 `ReplicatedStorage:WaitForChild("src"):WaitForChild("shared")`
- **正确**: 遵循 Rojo 映射，路径是 `ReplicatedStorage.Shared.ModuleName`

```lua
-- ✅ 正确
game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("XXX")
-- ❌ 错误
ReplicatedStorage:WaitForChild("src"):WaitForChild("shared")
```

### 陷阱 10: 缺少 fallback 和错误日志

- **错误**: pcall 失败后静默忽略
- **正确**: pcall 失败后 `warn("[ModuleName] 描述: " .. tostring(err))`
- **也不要**: 直接 `error()` 硬崩 — 找中间地带：warn + UI 提示

---

## 如何使用本文档

1. **编写新代码前**: 扫描一遍相关陷阱
2. **Code review 时**: 逐条检查是否有类似模式
3. **发现新陷阱时**: 立即追加（通过 CodeBuddy 更新此文件）
4. **任务卡片中**: dispatch 会引用相关陷阱编号提醒 Codex
