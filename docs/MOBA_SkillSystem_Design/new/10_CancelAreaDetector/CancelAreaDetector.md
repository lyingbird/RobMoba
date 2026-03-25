# 10 — 取消区域检测 CancelAreaDetector

> **文件路径**: `StarterPlayerScripts/SkillSystem/CancelAreaDetector.lua`  
> **HOK 来源**: `CSkillButtonManager.cs` 中 `RefreshIndicatorCancelUI()` 第6386-6429行 + `IsSkillCursorInCanceledArea()` + `CancelUseSkillSlot()` 第6664-6678行

---

## 设计说明

技能取消是 MOBA 操作中的重要安全阀——玩家在拖动技能摇杆瞄准时，如果改变主意，可以将手指拖入取消区域来中止本次施法。

### HOK 三种取消模式

HOK 通过枚举 `SkillCancleType`（`SettingDefine.cs`）定义了三种取消模式：

| 枚举值 | 模式 | 说明 |
|---|---|---|
| `AreaCancle = 0` | **区域取消** | 手指拖入**屏幕底部**的矩形 UI 区域 |
| `DisitanceCancle = 1` | **距离取消** | 手指从按下位置拖动超过 270 像素 |
| `Unity3DTouchCancle = 2` | 3D Touch 取消 | iOS 3D Touch 深按取消（**已淘汰**） |

玩家可在设置中切换模式（`GameSettingVariablePart.cs` → `TheSkillCancleType` 属性）。
Roblox 版保留前两种。

> **⚠️ 注意**: HOK 中 AreaCancel 的取消区域在**屏幕底部**（`cancleAera` UI 组件），不是右上角。DistanceCancel 则没有固定位置——以按下位置为圆心，拖动距离超过阈值即触发。

### 核心机制

```
Drag 中每帧检测:
  ├── 手指位置在 CancelFrame 内? → areaIn = true
  ├── 拖动总距离 > 270px?        → distIn = true
  └── nowIn = areaIn OR distIn

状态切换:
  刚进入取消区域 → 开始计时 (timeInCancelArea = 0)
  持续在取消区域 → 累加计时
  离开取消区域   → 重置计时

抬起判定 (在 OnButtonUp 中):
  bNoCancel = !isInCancelArea || timeInCancelArea <= 0.15s
  → bNoCancel == true  → 释放技能
  → bNoCancel == false → 取消技能
```

### HOK 完整调用链路

```
按下 (OnSkillButtonDown)
  └── EnableCancelArea()                    # 显示取消区域 UI
        ├── cancleAera.SetActive(true)      # AreaCancel: 底部矩形区域
        └── distanceCancelTips.SetActive(true)  # DistanceCancel: 距离提示

拖动 (OnSkillButtonDrag, 每帧)
  └── RefreshIndicatorCancelUI()            # CSkillButtonManager 第6386行
        ├── IsSkillCursorInCanceledArea()   # 判定当前是否在取消区域
        │     ├── AreaCancel模式: RectTransformUtility.RectangleContainsScreenPoint()
        │     └── DistanceCancel模式: magnitude > c_skillICancleRadius (270f)
        ├── 颜色切换: 蓝色⇄红色
        ├── 透明度渐变 (距离模式)
        └── 震动触发 (首次超阈值)
  └── SkillBtnController.Update()           # 累加 m_SkillInCancelAreaTime

抬起 (OnSkillButtonUp)
  └── SkillBtnController.OnSkillButtonUp()  # 第308-513行
        ├── bNoCancel = !isInCancelArea || timeInCancelArea <= SkillCancleTime
        ├── 取消优先于防误触判定
        ├── bNoCancel == false → CancelUseSkillSlot()  # 取消施法
        └── bNoCancel == true  → 继续释放流程
  └── DisableSkillCursor()                  # 隐藏取消区域 UI
        ├── cancleAera.SetActive(false)
        └── 重置所有取消相关状态
```

### 视觉反馈

| 状态 | 视觉 | HOK 来源 |
|---|---|---|
| 未进入取消区域 | CancelTips 隐藏；摇杆背景蓝色 | `RefreshIndicatorCancelUI` 6386行 |
| 刚进入取消区域 | CancelTips 显示(白色) | 6400行 |
| 停留 > 0.15s | CancelTips 变红色；摇杆背景变红色 | 6410行 `distanceCancleTipsRedImg` |
| 停留 > 0.15s 首次 | 触发震动 | `VibrationManager.PlaySkillCancelVibration()` |
| 距离模式拖动中 | 透明度随距离渐变 | `cancelAlpha` 计算 |

#### 颜色常量（HOK `ChangeSkillCursorBGSprite()` 第412-427行）

| 状态 | RGBA | 说明 |
|---|---|---|
| 正常（蓝色） | `(43/255, 194/255, 1, 1)` ≈ `#2BC2FF` | 技能摇杆正常状态 |
| 取消（红色） | `(248/255, 47/255, 47/255, 1)` ≈ `#F82F2F` | 进入取消区域后 |

### 距离模式透明度渐变（HOK 高级特性）

```
cancelAlpha = (cancelDeltaPositionDistance / c_skillICancleRadius) * 0.8f
```

拖动越远，取消提示越不透明（最大 0.8）。Roblox 版简化为二值（显示/隐藏）。

### 可配置参数

| 参数 | 默认值 | 配置位置 | 说明 |
|---|---|---|---|
| `SkillCancleTime` | 0.15 秒 | `CPlayerOpSettings.cs` | 停留时间阈值，可由玩家设置调节 |
| `c_skillICancleRadius` | 270f 像素 | `SkillCursorControler.cs` | 距离模式的取消半径 |

### 与防误触的关系

取消判定在防误触判定**之前**执行（参见 [14_AntiMistouch](../14_AntiMistouch/AntiMistouch.md)）。即：
- 如果玩家在取消区域停留超过阈值 → **直接取消**，不会进入防误触判定
- 如果未取消 → 才继续进行防误触检测

详见 [SkillController_Up.md](../06_SkillController/SkillController_Up.md) 中 `bNoCancel` 的判定流程。

### HOK UI 组件映射

HOK 在 `FightForm.cs` 的 `enBattleSkillCursorFormWidget` 枚举中定义了所有取消区域相关的 UI 组件：

| HOK 组件 | 功能 | Roblox 映射建议 |
|---|---|---|
| `cancleAera` | AreaCancel 模式的底部矩形取消区域 | `CancelFrame` (Frame) |
| `equipSkillCancleAera` | 装备技能的取消区域（独立的） | 同上（合并处理） |
| `distanceCancelTips` | DistanceCancel 模式的文字/图标提示 | `CancelTipsLabel` (TextLabel) |
| `distanceCancelTipsImg` | DistanceCancel 模式的提示图片（白色） | `CancelTipsIcon` (ImageLabel) |
| `distanceCancleTipsRedImg` | 停留超阈值后的红色提示图片 | 复用同一 ImageLabel，切换颜色 |

#### HOK 取消区域判定方法 (`IsSkillCursorInCanceledArea()`)

```csharp
// SkillCursorControler.cs 第1182-1200行
// AreaCancel 模式: 使用 Unity RectTransform 碰撞检测
RectTransformUtility.RectangleContainsScreenPoint(cancleAera, screenPos)

// DistanceCancel 模式: 判断拖动距离是否超过阈值
cancelDeltaPosition.magnitude > c_skillICancleRadius  // 270f
```

---

## 完整伪代码

```lua
-- 文件: StarterPlayerScripts/SkillSystem/CancelAreaDetector.lua

local GCfg = require(game.ReplicatedStorage.SkillSystem.Config.GlobalConfig)
local Haptic = game:GetService("HapticService")
local RunService = game:GetService("RunService")

local CAD = {}; CAD.__index = CAD

function CAD.new(cancelFrame: Frame)
    local self = setmetatable({}, CAD)
    
    self._frame = cancelFrame           -- 取消区域 Frame UI 引用
    self._inArea = false                -- 当前是否在取消区域内
    self._time = 0                      -- 停留累计时间(秒)
    self._vibrated = false              -- 是否已触发过震动
    self._hbConn = nil                  -- Heartbeat 连接
    self._lastScreenPos = Vector2.zero  -- 上一次屏幕位置
    self._pressStartScreenPos = Vector2.zero  -- 按下时屏幕位置
    
    return self
end

-- 在 OnButtonDown 时调用，记录按下位置（用于距离取消计算）
function CAD:SetPressStart(pos: Vector2)
    self._pressStartScreenPos = pos
end
```

### Update — 每次 Drag 调用

```lua
-- 来源: HOK RefreshIndicatorCancelUI() 第6386-6429行
-- 每次 Drag 时由 SkillButtonManager 或 SkillController 调用

function CAD:Update(screenPos: Vector2)
    self._lastScreenPos = screenPos

    -- ========== 判断是否在取消区域 ==========
    
    -- 模式1: AreaCancel — 屏幕坐标在 CancelFrame UI 范围内
    local areaIn = self:_IsInFrame(screenPos)

    -- 模式2: DistanceCancel — 拖动总距离超过阈值
    -- 来源: HOK c_skillICancleRadius = 270
    local distIn = (screenPos - self._pressStartScreenPos).Magnitude
                 > GCfg.CANCEL_DISTANCE_THRESHOLD

    local nowIn = areaIn or distIn

    -- ========== 状态切换 ==========
    
    if nowIn and not self._inArea then
        -- ★ 刚进入取消区域
        self._inArea = true
        self._time = 0
        self._vibrated = false
        self:_StartTimer()
        
    elseif not nowIn and self._inArea then
        -- ★ 离开取消区域
        self._inArea = false
        self._time = 0
        self:_StopTimer()
    end
    -- 如果持续在区域内，Timer 会自动累加 _time
end
```

### GetState — 获取当前状态

```lua
-- 由 SkillController.OnButtonUp() 调用来做取消判定
-- 由 SkillButtonManager._Drag() 调用来刷新 UI

function CAD:GetState()
    return {
        isInCancelArea = self._inArea,
        timeInCancelArea = self._time,
        hasTriggeredVibration = self._vibrated,
    }
end
```

### Reset — 重置状态

```lua
-- 由 SkillController._Cleanup() 在技能释放/取消后调用

function CAD:Reset()
    self._inArea = false
    self._time = 0
    self._vibrated = false
    self:_StopTimer()
end
```

### 内部方法

```lua
-- 判断屏幕坐标是否在 Frame UI 内
function CAD:_IsInFrame(pos: Vector2): boolean
    if not self._frame then return false end
    local ap = self._frame.AbsolutePosition
    local as = self._frame.AbsoluteSize
    return pos.X >= ap.X and pos.X <= ap.X + as.X
       and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
end

-- 启动停留计时器
function CAD:_StartTimer()
    if self._hbConn then return end
    self._hbConn = RunService.Heartbeat:Connect(function(dt)
        if self._inArea then
            self._time += dt
            -- 首次超过阈值时触发震动
            -- 来源: HOK VibrationManager.PlaySkillCancelVibration()
            if self._time > GCfg.CANCEL_AREA_STAY_THRESHOLD and not self._vibrated then
                self._vibrated = true
                pcall(function()
                    Haptic:SetMotor(
                        Enum.UserInputType.Gamepad1,
                        Enum.VibrationMotor.Small,
                        0.5  -- 振动强度
                    )
                    task.delay(0.1, function()
                        Haptic:SetMotor(
                            Enum.UserInputType.Gamepad1,
                            Enum.VibrationMotor.Small,
                            0    -- 停止振动
                        )
                    end)
                end)
            end
        end
    end)
end

-- 停止计时器
function CAD:_StopTimer()
    if self._hbConn then
        self._hbConn:Disconnect()
        self._hbConn = nil
    end
end

return CAD
```

---

## CancelFrame UI 布局建议

```
┌────────────────────────────────────┐
│              游戏画面               │
│                                    │
│                                    │
│            技能按钮区               │
│                                    │
├────────────────────────────────────┤
│   ▓▓▓▓▓▓ CancelFrame ▓▓▓▓▓▓      │ ← 底部区域
│   Size: {1, 0, 0.15, 0}           │    屏幕宽 × 15% 高
│   Position: {0, 0, 0.85, 0}       │    位于屏幕底部 85% 处
│   BackgroundTransparency: 0.8      │    半透明灰色
│                                    │
│   内含 CancelTips (ImageLabel)     │    "松手取消" 文字/图标
│   默认 Visible = false             │
└────────────────────────────────────┘
```

---

## 常量速查

| 常量 | 值 | 来源 |
|---|---|---|
| `CANCEL_AREA_STAY_THRESHOLD` | 0.15 秒 | HOK `m_SkillInCancelAreaTimeInterval` 默认值；可通过 `SkillCancleTime` 设置调节 |
| `CANCEL_DISTANCE_THRESHOLD` | 270 像素 | HOK `c_skillICancleRadius` (`SkillCursorControler.cs`) |
| 正常颜色（蓝） | `(43/255, 194/255, 1, 1)` | HOK `ChangeSkillCursorBGSprite()` |
| 取消颜色（红） | `(248/255, 47/255, 47/255, 1)` | 同上 |
| 透明度最大值 | 0.8 | 距离模式渐变上限 |
| 震动时长 | 0.1 秒 | HOK `VibrationManager` |
| 震动强度 | 0.5 | 适中 |

---

## HOK 源码文件索引

| 文件 | 关键内容 | 行号 |
|---|---|---|
| `CSkillButtonManager.cs` | `RefreshIndicatorCancelUI()` 每帧刷新取消 UI | 6386-6429 |
| 同上 | `EnableCancelArea()` 启用取消区域 | 7019-7050 |
| 同上 | `DisableSkillCursor()` 禁用/隐藏取消区域 | 7301-7347 |
| 同上 | `CancelUseSkillSlot()` 执行取消操作 | 6664-6678 |
| `SkillCursorControler.cs` | `IsSkillCursorInCanceledArea()` 核心碰撞检测 | 1182-1200 |
| 同上 | `ChangeSkillCursorBGSprite()` 颜色切换 | 412-427 |
| 同上 | `c_skillICancleRadius = 270f` 距离阈值常量 | — |
| `SkillBtnController.cs` | `OnSkillButtonUp()` 中 `bNoCancel` 判定 | 308-513 |
| 同上 | `Update()` 中停留时间累加 + Cursor 颜色切换 | 84-112 |
| `SettingDefine.cs` | `SkillCancleType` 枚举定义 | — |
| `GameSettingVariablePart.cs` | `TheSkillCancleType` 属性 | — |
| `CPlayerOpSettings.cs` | `SkillCancleTime` 可配置停留阈值 | — |
| `FightForm.cs` | `enBattleSkillCursorFormWidget` UI 组件枚举 | — |

---

## 交叉引用

| 文档 | 与取消相关的内容 |
|---|---|
| [SkillController_Down](../06_SkillController/SkillController_Down.md) | 按下时重置取消状态、调用 `EnableCancelArea()` |
| [SkillController_Drag](../06_SkillController/SkillController_Drag.md) | 每次 Drag 调用 `cancelDet:Update(screenPos)` |
| [SkillController_Up](../06_SkillController/SkillController_Up.md) | `bNoCancel` 判定逻辑，取消优先于防误触 |
| [AntiMistouch](../14_AntiMistouch/AntiMistouch.md) | 取消判定在防误触之前执行 |

---

> **下一步**: `11_SkillCacheManager/`
