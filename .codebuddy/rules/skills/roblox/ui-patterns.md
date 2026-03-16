---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：Roblox UI 模式

> **领域**: roblox
> **适用Agent**: 程序 / 主程
> **加载时机**: 需要开发或设计 Roblox UI 功能时按需加载
> **大小**: ~2KB

## 📌 核心知识

1. **UI 层级**: `ScreenGui` > `Frame` / `ScrollingFrame` > 子元素（TextLabel/TextButton/ImageLabel 等）
2. **StarterGui 复制机制**: StarterGui 中的 ScreenGui 在角色生成时复制到 `PlayerGui` — 注意 `ResetOnSpawn` 属性
3. **布局组件**: `UIListLayout`(列表) / `UIGridLayout`(网格) / `UIPageLayout`(翻页) — 自动排列子元素
4. **尺寸系统**: `UDim2.new(scaleX, offsetX, scaleY, offsetY)` — Scale(0~1比例) + Offset(像素)
5. **锚点系统**: `AnchorPoint`(Vector2 0~1) 决定元素自身参考点，配合 Position 实现居中等效果
6. **Attribute 驱动 UI**: 服务端设置 Attribute → `GetAttributeChangedSignal` 在客户端触发 UI 更新
7. **本项目 UI 架构**: 5 个独立 UI 模块(HUD/HeroSelect/DragDrop/Backpack/MatchButton)，由 Client.client.lua 入口初始化

## ✅ 最佳实践

1. **代码创建 UI（Rojo 项目）**: 本项目使用 Rojo，UI 通过 Lua 代码动态创建，非 Studio 手动拖拽
   ```lua
   local frame = Instance.new("Frame")
   frame.Size = UDim2.new(0, 200, 0, 50)
   frame.Position = UDim2.new(0.5, -100, 0, 10) -- 居中
   frame.AnchorPoint = Vector2.new(0.5, 0)
   frame.Parent = screenGui
   ```
2. **数据驱动刷新**: UI 监听数据变化信号刷新，而非每帧轮询
   ```lua
   character:GetAttributeChangedSignal("HP"):Connect(function()
       hpBar.Size = UDim2.new(character:GetAttribute("HP") / character:GetAttribute("MaxHP"), 0, 1, 0)
   end)
   ```
3. **UI 模块化**: 每个功能面板一个 ModuleScript，导出 `init(screenGui)` / `update()` / `destroy()` 方法
4. **ScrollingFrame + UIListLayout**: 列表自动计算 CanvasSize
   ```lua
   layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
       scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
   end)
   ```
5. **TweenService 动画**: 使用 `TweenService:Create()` 做 UI 动画（透明度/位置/大小过渡）
6. **层级管理**: 使用 `ZIndex` 或 `DisplayOrder`(ScreenGui 级) 控制 UI 遮挡关系
7. **输入穿透**: 非交互性 Frame 设置 `Active = false`，避免拦截底层 UI/3D 点击

## ❌ 常见陷阱

1. **所有 UI 在同一个 ScreenGui** → 正确做法：按功能拆分多个 ScreenGui，用 DisplayOrder 控制层级
2. **ScrollingFrame 手动设置 CanvasSize** → 正确做法：用 UIListLayout.AbsoluteContentSize 自动计算
3. **Heartbeat/RenderStepped 中更新 UI 文本** → 正确做法：监听 Attribute/事件变化时更新
4. **忘记设置 ResetOnSpawn = false** → 正确做法：持久 UI（如 HUD）必须设 `ResetOnSpawn = false`
5. **硬编码像素尺寸不适配** → 正确做法：优先使用 Scale (比例) 配合 UIAspectRatioConstraint
6. **TextLabel 文字截断** → 正确做法：启用 `TextScaled = true` 或使用 `AutomaticSize = Enum.AutomaticSize.XY`
7. **大量子元素的 Frame 不使用布局组件** → 正确做法：用 UIListLayout/UIGridLayout 自动排列

## 📋 检查清单

- [ ] 持久 UI 的 ScreenGui 是否设置了 `ResetOnSpawn = false`
- [ ] UI 数据是否通过事件/Attribute 驱动（非每帧轮询）
- [ ] ScrollingFrame 是否通过 Layout.AbsoluteContentSize 自动计算 CanvasSize
- [ ] 非交互性 Frame 是否设置了 `Active = false`
- [ ] UI 尺寸是否优先使用 Scale 而非纯 Offset
- [ ] TweenService 动画是否有合理的持续时间和缓动曲线
- [ ] UI 模块是否有 destroy/cleanup 方法防止泄漏

## 🔗 关联技能

- [Roblox Instance 与服务模式](./instance-patterns.md)
- [事件与通信模式](../architecture/event-system.md)
