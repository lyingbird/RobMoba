# 10 — 取消区域检测 CancelAreaDetector

> **文件路径**: `StarterPlayerScripts/SkillSystem/CancelAreaDetector.lua`

---

## 设计说明

有三种取消模式：
1. **AreaCancel** — 手指进入屏幕底部 UI 矩形
2. **DistanceCancel** — 拖动距离超过 270 像素
3. **Unity3DTouchCancel** — 3D Touch 深按取消（已淘汰）

Roblox 版保留前两种。

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

### 视觉反馈

| 状态 | 视觉 | 来源 |
|---|---|---|
| 未进入取消区域 | CancelTips 隐藏 | `RefreshIndicatorCancelUI` 6386行 |
| 刚进入取消区域 | CancelTips 显示(白色) | 6400行 |
| 停留 > 0.15s | CancelTips 变红色 | 6410行 `distanceCancleTipsRedImg` |
| 停留 > 0.15s 首次 | 触发震动 | `VibrationManager.PlaySkillCancelVibration()` |

### 距离模式透明度渐变（高级特性）

```
cancelAlpha = (cancelDeltaPositionDistance / c_skillICancleRadius) * 0.8f
```

拖动越远，取消提示越不透明。Roblox 版简化为二值（显示/隐藏）。

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
-- 来源: RefreshIndicatorCancelUI() 第6386-6429行
-- 每次 Drag 时由 SkillButtonManager 或 SkillController 调用

function CAD:Update(screenPos: Vector2)
    self._lastScreenPos = screenPos

    -- ========== 判断是否在取消区域 ==========
    
    -- 模式1: AreaCancel — 屏幕坐标在 CancelFrame UI 范围内
    local areaIn = self:_IsInFrame(screenPos)

    -- 模式2: DistanceCancel — 拖动总距离超过阈值
    -- 来源: c_skillICancleRadius = 270
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
| `CANCEL_AREA_STAY_THRESHOLD` | 0.15 秒 | `m_SkillInCancelAreaTimeInterval` 默认值 |
| `CANCEL_DISTANCE_THRESHOLD` | 270 像素 | `c_skillICancleRadius` |
| 震动时长 | 0.1 秒 | `VibrationManager` |
| 震动强度 | 0.5 | 适中 |

---

> **下一步**: `11_SkillCacheManager/`
