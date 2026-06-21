# 移动端 UI 自适应标准规范

> 版本: v1.0 | 创建: 2026-03-17
> 定位: **强制规范** — 所有移动端 UI 新增/修改必须遵守本规范

---

## 一、当前项目自适应现状评估

### 1.1 做得好的部分 ✅

| 特性 | 使用位置 | 说明 |
|------|---------|------|
| **Scale 比例定位** | MobileConfig 所有位置参数 | 摇杆/技能按钮/大厅按钮等使用 0~1 屏幕比例 |
| **屏高比尺寸 (RelativeYY)** | UI_SkillButtons, UI_Minimap | 按钮/小地图用 `SizeConstraint = RelativeYY` 保证等比缩放 |
| **MobileConfig 集中配置** | 全局 | 所有移动端参数集中管理，方便调参 |
| **运行时宽高比计算** | UI_SkillButtons 弧形布局 | `camera.ViewportSize` 动态获取，非硬编码 16:9 |
| **TextScaled** | UI_SkillButtons, UI_MobileHUD, Client | 文本随容器缩放 |
| **UITheme.autoScale()** | PC 端 UI | 基于参考分辨率的 UIScale 全局缩放 |

### 1.2 存在的问题 ❌

| 问题 | 严重度 | 涉及文件 | 说明 |
|------|--------|---------|------|
| **PC端UI大量硬编码像素** | 🔴高 | UI_HUD(16处), UI_TrainingPanel(12处), UI_Backpack(8处), UI_HeroSelect(8处) | `UDim2.new(0, 300, 0, 40)` 等固定像素值，在不同分辨率下不自适应 |
| **SafeArea 用固定像素** | 🟡中 | MobileConfig L157-159 | `SAFE_AREA_TOP=36, BOTTOM=34, SIDES=44` 是硬编码像素，不同设备安全区不同 |
| **UITheme.corner() 固定像素** | 🟡中 | UITheme 全局使用 | `UDim.new(0, radius)` 圆角不随元素缩放 |
| **UITheme.circleFrame() 固定像素** | 🟡中 | UITheme | `UDim2.new(0, diameter, 0, diameter)` 圆形尺寸固定 |
| **UITheme.slot() 固定像素** | 🟡中 | UITheme | 默认 `46x46` 像素 |
| **UIStroke 固定像素** | 🟢低 | UI_SkillButtons | `Thickness = 2~3` 像素，小屏可能太粗/大屏太细 |
| **零 UIAspectRatioConstraint** | 🟡中 | 全项目 | 没有使用宽高比约束，依赖手动计算 |
| **零 UISizeConstraint** | 🟡中 | 全项目 | 没有最大/最小尺寸约束，极端分辨率可能异常 |
| **零 UITextSizeConstraint** | 🟡中 | 全项目 | TextScaled 无上下限约束，极小屏文字可能不可读 |
| **未使用 ScreenInsets** | 🟡中 | 所有 ScreenGui | 依赖手动 SafeArea 偏移而非系统级安全区 |
| **UIListLayout 仅用于少数面板** | 🟢低 | UI_HeroSelect, UI_Backpack 等 | 大量手动定位，未利用自动布局 |

### 1.3 总结评分

| 维度 | 移动端专用UI | PC端UI |
|------|------------|--------|
| 位置自适应 | ⭐⭐⭐⭐ 80% (Scale为主) | ⭐⭐ 40% (大量Offset) |
| 尺寸自适应 | ⭐⭐⭐⭐ 75% (屏高比为主) | ⭐⭐ 30% (固定像素) |
| 安全区适配 | ⭐⭐ 40% (硬编码SafeArea) | ⭐ 10% (未处理) |
| 文本自适应 | ⭐⭐⭐ 60% (TextScaled有但无约束) | ⭐⭐ 30% |
| 约束系统 | ⭐ 20% (仅RelativeYY) | ⭐ 10% |

**结论**: 移动端专用 UI (摇杆/技能/HUD) 自适应较好(Scale+屏高比)，但 PC/共享 UI 和安全区处理严重不足。缺少系统性的约束机制。

---

## 二、Roblox 平台 UI 自适应机制全解

### 2.1 坐标系统: UDim2 (Scale + Offset)

```
UDim2.new(ScaleX, OffsetX, ScaleY, OffsetY)

Position/Size 最终值 = Scale × 父容器尺寸 + Offset(像素)
```

| 参数 | 含义 | 自适应性 | 适用场景 |
|------|------|---------|---------|
| **Scale** | 父容器百分比 (0~1) | ✅ 自适应 | 位置、尺寸的主要方式 |
| **Offset** | 固定像素偏移 | ❌ 不自适应 | 仅用于微调(间距/边距) |

**黄金规则**: Position 和 Size 的 **主值用 Scale，微调用 Offset**

### 2.2 锚点: AnchorPoint

```lua
element.AnchorPoint = Vector2.new(0.5, 0.5) -- 中心为锚点
element.Position = UDim2.new(0.5, 0, 0.5, 0) -- 屏幕正中央
```

- `(0, 0)` = 左上角(默认)
- `(0.5, 0.5)` = 中心 — **推荐用于居中元素**
- `(1, 0)` = 右上角 — 右对齐元素
- `(1, 1)` = 右下角

### 2.3 SizeConstraint — 等比约束基准

```lua
-- 以屏幕高度为基准的正方形/圆形
element.Size = UDim2.new(0.1, 0, 0.1, 0)
element.SizeConstraint = Enum.SizeConstraint.RelativeYY
-- 实际宽 = 0.1 × 屏高, 实际高 = 0.1 × 屏高 → 正方形
```

| 值 | 宽基准 | 高基准 | 适用场景 |
|----|--------|--------|---------|
| `RelativeXY` (默认) | 父宽 | 父高 | 普通矩形元素 |
| `RelativeXX` | 父宽 | 父宽 | 水平方向等比 |
| `RelativeYY` | 父高 | 父高 | **按钮/图标/小地图** (高度为基准的正方形) |

### 2.4 UIAspectRatioConstraint — 宽高比锁定

```lua
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 16 / 9  -- 宽:高 = 16:9
aspect.AspectType = Enum.AspectType.FitWithinMaxSize
aspect.DominantAxis = Enum.DominantAxis.Height
aspect.Parent = element
```

- **AspectType**: `FitWithinMaxSize`(不超出) / `ScaleWithParentSize`(填满)
- **DominantAxis**: `Width` 或 `Height` — 哪个轴为主
- **适用**: 头像、地图、视频容器等需要保持固定比例的元素

### 2.5 UISizeConstraint — 最大/最小尺寸

```lua
local sizeC = Instance.new("UISizeConstraint")
sizeC.MinSize = Vector2.new(80, 30)   -- 最小像素
sizeC.MaxSize = Vector2.new(400, 120) -- 最大像素
sizeC.Parent = element
```

- 防止 Scale 元素在极小屏上变得不可用，或极大屏上过于巨大
- **MOBA 按钮推荐**: MinSize 约 40px，MaxSize 约 200px

### 2.6 UITextSizeConstraint — 文本大小限制

```lua
local textC = Instance.new("UITextSizeConstraint")
textC.MinTextSize = 10   -- 最小字号(防止不可读)
textC.MaxTextSize = 48   -- 最大字号(防止溢出)
textC.Parent = textLabel
```

- **必须与 `TextScaled = true` 配合使用**
- 最小值不低于 9（Roblox 建议）
- **MOBA HUD 推荐**: Min=10, Max=36

### 2.7 AutomaticSize — 内容驱动尺寸

```lua
container.AutomaticSize = Enum.AutomaticSize.Y  -- Y轴随内容自动伸缩
container.Size = UDim2.new(0.3, 0, 0, 30)       -- Size 作为最小尺寸
```

- `X` / `Y` / `XY` / `None`
- 父容器的 Size 成为**最小尺寸**
- 适用于：聊天框、通知列表、物品描述等内容长度不定的容器

### 2.8 UIListLayout / UIGridLayout — 自动排列

```lua
-- 垂直列表
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.Padding = UDim.new(0.01, 0)  -- Scale 间距也自适应
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.Parent = container

-- 网格布局
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.2, 0, 0.15, 0)  -- Scale 单元格
grid.CellPadding = UDim2.new(0.01, 0, 0.01, 0)
grid.Parent = container
```

- **Padding/CellPadding 也支持 Scale** — 保持间距比例一致
- 配合 `ScrollingFrame` + `AutomaticCanvasSize` 实现滚动列表

### 2.9 UIScale — 全局缩放因子

```lua
local uiScale = Instance.new("UIScale")
uiScale.Scale = math.min(viewW / refW, viewH / refH)
uiScale.Parent = screenGui
```

- 对子树所有元素(包括 UIStroke、UICorner)等比缩放
- **适用于 PC 端 UI 快速适配**：以参考分辨率设计，运行时按比例缩放
- **移动端推荐**: 不使用全局 UIScale，而是用 Scale + 约束组合

### 2.10 ScreenGui.ScreenInsets — 系统级安全区 ⭐

```lua
local screenGui = Instance.new("ScreenGui")
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets  -- 默认值
```

| 值 | 效果 | 适用场景 |
|----|------|---------|
| `CoreUISafeInsets` (默认) | 避开 Roblox 顶栏 + 设备刘海/挖孔 | **大多数游戏UI** |
| `DeviceSafeInsets` | 仅避开设备刘海，可覆盖 Roblox 顶栏 | 自定义全屏体验 |
| `None` | 不避开任何区域 | 仅用于纯背景图 |

- **`ClipToDeviceSafeArea`**: 超出安全区的 UI 是否被裁剪(默认 true)
- **`IgnoreGuiInset = true`** 时 `CoreUISafeInsets` 自动切换为 `DeviceSafeInsets`
- **🔑 核心**: 用 `ScreenInsets` 替代手动硬编码 SafeArea 像素值

### 2.11 UIPadding — 内边距

```lua
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 0)     -- Roblox顶栏已由ScreenInsets处理
padding.PaddingBottom = UDim.new(0.02, 0) -- 底部留2%间距
padding.PaddingLeft = UDim.new(0.02, 0)
padding.PaddingRight = UDim.new(0.02, 0)
padding.Parent = container
```

- Scale 间距自适应，Offset 间距固定
- 推荐内边距用 Scale

---

## 三、RobMoba 移动端 UI 自适应标准 (强制)

### 3.1 核心原则

```
1. Scale First     — 位置和尺寸优先使用 Scale(0~1 比例)
2. Offset Minimal  — Offset 仅用于 ≤10px 的微调间距
3. Constrain Always — 所有 Scale 元素必须加 UISizeConstraint 防极端情况
4. Text Bounded    — 所有 TextScaled 必须加 UITextSizeConstraint
5. System SafeArea — 用 ScreenInsets 替代手动 SafeArea
6. Test 3 Screens  — 所有 UI 必须在 3 种分辨率下验证
```

### 3.2 参考分辨率与测试矩阵

| 设备类型 | 分辨率 | 宽高比 | 代表设备 | 验证重点 |
|---------|--------|--------|---------|---------|
| 小屏手机 | 1334×750 | 16:9 | iPhone SE/8 | 按钮是否可点击、文字是否可读 |
| 标准手机 | 2532×1170 | 19.5:9 | iPhone 14/15 | 刘海/灵动岛遮挡、安全区 |
| 平板 | 2360×1640 | ~3:2 | iPad Air | 元素是否过大、布局是否合理 |

### 3.3 尺寸规范

#### 3.3.1 Position (位置)

```lua
-- ✅ 正确: 全 Scale 定位
element.Position = UDim2.new(0.88, 0, 0.82, 0)

-- ✅ 可接受: Scale + 微小 Offset 微调
element.Position = UDim2.new(0.5, 0, 0, 36) -- 仅安全区偏移用Offset

-- ❌ 错误: 大量 Offset
element.Position = UDim2.new(0, 300, 0, 200) -- 不自适应!
```

#### 3.3.2 Size (尺寸)

```lua
-- ✅ 正确: Scale 尺寸 + 约束
element.Size = UDim2.new(0.12, 0, 0.06, 0)

-- ✅ 推荐: 屏高比等比元素 (按钮/图标)
element.Size = UDim2.new(0.12, 0, 0.12, 0)
element.SizeConstraint = Enum.SizeConstraint.RelativeYY

-- ❌ 错误: 固定像素尺寸
element.Size = UDim2.new(0, 200, 0, 50) -- 不自适应!
```

#### 3.3.3 圆角 (UICorner)

```lua
-- ✅ 正确: Scale 圆角 (基于短边比例)
corner.CornerRadius = UDim.new(0.5, 0)  -- 完美圆形
corner.CornerRadius = UDim.new(0.15, 0) -- 圆角矩形

-- 🟡 可接受: 小固定圆角 (≤8px)
corner.CornerRadius = UDim.new(0, 6)

-- ❌ 避免: 大固定圆角
corner.CornerRadius = UDim.new(0, 20) -- 大屏/小屏比例失调
```

#### 3.3.4 文本

```lua
-- ✅ 正确: TextScaled + 约束
label.TextScaled = true
local textC = Instance.new("UITextSizeConstraint")
textC.MinTextSize = 10
textC.MaxTextSize = 36
textC.Parent = label

-- ❌ 错误: 固定字号
label.TextSize = 18 -- 小屏太大/大屏太小
```

#### 3.3.5 边框 (UIStroke)

```lua
-- ✅ 推荐: 与文本/元素缩放同步
stroke.Thickness = 2   -- 小数值可接受(1~3px通用)

-- ✅ 高级: 运行时动态计算
local baseThickness = 2
local scaleFactor = viewportHeight / 1080
stroke.Thickness = math.clamp(baseThickness * scaleFactor, 1, 4)
```

#### 3.3.6 间距 (Padding/Margin)

```lua
-- ✅ 正确: Scale 间距
padding.PaddingLeft = UDim.new(0.02, 0)  -- 2% 间距
list.Padding = UDim.new(0.01, 0)         -- 1% 列表间距

-- ❌ 错误: 大像素间距
padding.PaddingLeft = UDim.new(0, 20) -- 不自适应
```

### 3.4 约束规范 (所有 UI 必须遵守)

#### 3.4.1 可交互元素最小尺寸

```lua
-- 所有按钮/可点击元素必须加最小尺寸约束
local sizeC = Instance.new("UISizeConstraint")
sizeC.MinSize = Vector2.new(44, 44)  -- Apple HIG 最小触摸目标
sizeC.Parent = button
```

**移动端最小触摸目标**: 44×44 像素 (Apple HIG) / 48×48 dp (Material Design)

#### 3.4.2 等比元素必须约束

```lua
-- 图标/头像/小地图等正方形元素
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.AspectRatio = 1  -- 正方形
aspect.Parent = element

-- 或使用 SizeConstraint
element.SizeConstraint = Enum.SizeConstraint.RelativeYY
```

#### 3.4.3 文本必须约束

```lua
-- 所有 TextScaled = true 的文本元素
local textC = Instance.new("UITextSizeConstraint")
textC.MinTextSize = 10  -- 不低于 9 (Roblox 官方建议)
textC.MaxTextSize = 40  -- 根据容器合理设定
textC.Parent = textElement
```

### 3.5 安全区规范

#### 3.5.1 ScreenGui 配置

```lua
-- ✅ 标准游戏 UI: 使用系统安全区
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- 默认值
screenGui.ClipToDeviceSafeArea = true

-- ✅ 全屏背景/装饰: 铺满屏幕
bgGui.ScreenInsets = Enum.ScreenInsets.None

-- ✅ 自定义全屏 UI (需覆盖 Roblox 顶栏):
customGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
```

#### 3.5.2 弃用手动 SafeArea

```
❌ 旧方案 (硬编码):
MobileConfig.SAFE_AREA_TOP = 36
topBar.Position = UDim2.new(0, 0, 0, MobileConfig.SAFE_AREA_TOP)

✅ 新方案 (系统级):
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
topBar.Position = UDim2.new(0, 0, 0, 0) -- 系统自动处理安全区
```

### 3.6 布局模式选择指南

| 场景 | 推荐布局方式 | 示例 |
|------|------------|------|
| 固定位置元素 (摇杆/技能按钮) | Scale Position + RelativeYY | UI_SkillButtons 弧形布局 |
| 列表/菜单 | UIListLayout + AutomaticSize | 英雄选择卡片列表 |
| 网格 (英雄面板/物品栏) | UIGridLayout + Scale CellSize | UI_HeroSelect 英雄网格 |
| 居中弹窗 | AnchorPoint(0.5,0.5) + Scale | 结算面板、确认对话框 |
| 顶部/底部固定栏 | Scale Position + Scale Height | HUD TopBar, 底部操控区 |
| 滚动内容 | ScrollingFrame + AutomaticCanvasSize | 长列表、聊天窗口 |

### 3.7 MOBA 特定布局参数

```lua
-- 右下角技能区 (以屏高为基准)
SKILL_BTN_NORMAL = 0.10~0.13  -- Q/W/R 按钮直径(屏高比)
SKILL_BTN_ATTACK = 0.14~0.17  -- 普攻按钮(略大)
SKILL_BTN_SUMM   = 0.07~0.10  -- D/F 召唤师技能(略小)

-- 左下角摇杆区
JOYSTICK_OUTER   = 0.25~0.35  -- 外圈直径(屏高比)
JOYSTICK_INNER   = 0.10~0.14  -- 内球直径(屏高比)

-- 小地图 (左上角)
MINIMAP_SIZE     = 0.18~0.25  -- 正方形边长(屏高比)

-- HUD 顶栏
TOP_BAR_HEIGHT   = 0.04~0.06  -- 顶栏高度(屏高比)
HP_BAR_WIDTH     = 0.12~0.18  -- 血条宽度(屏宽比)
```

---

## 四、代码模板

### 4.1 创建自适应按钮

```lua
local function createAdaptiveButton(parent, name, posScale, sizeScale)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.AnchorPoint = Vector2.new(0.5, 0.5)
    btn.Position = UDim2.new(posScale.X, 0, posScale.Y, 0)
    btn.Size = UDim2.new(sizeScale, 0, sizeScale, 0)
    btn.SizeConstraint = Enum.SizeConstraint.RelativeYY
    btn.BackgroundColor3 = Color3.fromRGB(30, 32, 48)
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.BorderSizePixel = 0
    btn.Parent = parent

    -- 圆角 (Scale)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.15, 0)
    corner.Parent = btn

    -- 最小触摸尺寸
    local sizeC = Instance.new("UISizeConstraint")
    sizeC.MinSize = Vector2.new(44, 44)
    sizeC.Parent = btn

    -- 文本尺寸约束
    local textC = Instance.new("UITextSizeConstraint")
    textC.MinTextSize = 10
    textC.MaxTextSize = 32
    textC.Parent = btn

    return btn
end
```

### 4.2 创建自适应 ScreenGui

```lua
local function createAdaptiveScreenGui(name, displayOrder)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.DisplayOrder = displayOrder or 5
    gui.ResetOnSpawn = false
    gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    gui.ClipToDeviceSafeArea = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player.PlayerGui
    return gui
end
```

### 4.3 创建自适应文本标签

```lua
local function createAdaptiveLabel(parent, name, text, heightScale)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Text = text
    label.TextScaled = true
    label.Font = Enum.Font.GothamMedium
    label.TextColor3 = Color3.new(1, 1, 1)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, heightScale or 0.04, 0)
    label.Parent = parent

    local textC = Instance.new("UITextSizeConstraint")
    textC.MinTextSize = 10
    textC.MaxTextSize = 36
    textC.Parent = label

    return label
end
```

---

## 五、验收检查清单 (每个 UI PR 必须)

- [ ] **Position**: 所有 Position 的主值使用 Scale，Offset ≤ 10px 微调
- [ ] **Size**: 所有 Size 的主值使用 Scale (等比元素用 RelativeYY)
- [ ] **UISizeConstraint**: 可交互元素有 MinSize ≥ 44×44
- [ ] **UITextSizeConstraint**: 所有 TextScaled 文本有 Min/Max 约束
- [ ] **UICorner**: 圆角使用 Scale (`UDim.new(0.15, 0)`) 而非大像素值
- [ ] **ScreenInsets**: ScreenGui 使用 CoreUISafeInsets (非手动 SafeArea)
- [ ] **3 分辨率验证**: 在 750p / 1170p / 1640p 三种分辨率下无异常
- [ ] **无 Offset-Only 尺寸**: 不存在 `UDim2.new(0, px, 0, px)` 的大元素

---

## 六、渐进迁移策略

当前项目不需要一次性重构所有 UI，采用渐进策略：

### Phase 1: 新增 UI 强制遵守 (立即)
- 所有新增/修改的 UI 代码必须遵守本规范
- MobileConfig 新增参数必须是 Scale 值

### Phase 2: 移动端 UI 补充约束 (随需求修改时)
- 修改移动端 UI 时顺带添加 UISizeConstraint / UITextSizeConstraint
- 用 ScreenInsets 替代 MobileConfig.SAFE_AREA_* 硬编码

### Phase 3: PC 端 UI 迁移 (专项优化时)
- UI_HUD、UI_HeroSelect、UI_TrainingPanel 等 PC 端 UI 迁移至 Scale
- UITheme 工具函数升级为 Scale 版本

---

## 更新记录

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-03-17 | v1.0 | 初始版本: 现状评估 + Roblox机制调研 + 标准制定 |
