# 06.2 — 阶段二：OnButtonDrag（拖动）

> **所属模块**: `SkillController.lua`

---

## 流程图

```
OnButtonDrag(slot, screenPos, btnCenter)
    │
    ├── 守卫: state 必须是 "Pressing" 或 "Dragging"
    │   └── 否 → return
    │
    ├── 守卫: slot 必须等于 _activeSlot
    │   └── 否 → return
    │
    ├── 计算拖动向量:
    │   delta = screenPos - btnCenter
    │   mag = delta.Magnitude
    │   axis = delta / mag（归一化2D方向）
    │
    ├── 拖动判定:
    │   mag > DRAG_THRESHOLD && !_hasDragged ?
    │   └── YES → _hasDragged = true, state → "Dragging"
    │
    ├── 归一化偏移:
    │   maxR = 120（按钮最大拖动半径，像素）
    │   normOff = clamp(mag / maxR, 0, 1)
    │
    ├── 目标选择:
    │   _SelectSkillTarget(_rangeType, axis, normOff)
    │   → 写入 _targetPos, _targetDir, _targetActor, _moveFlag, _rotateFlag
    │
    ├── 指示器更新:
    │   indicator:UpdatePosition(_targetPos, _targetDir, _moveFlag, _rotateFlag)
    │
    └── 取消区域更新:
        cancelDet:Update(screenPos)
```

## 完整伪代码

```lua

-- 精简说明:
--   原版还有: 蓄力角度更新、锁定框目标切换、JoystickMode 特殊处理、MoveSkillCursorInScene
--   Roblox 版保留: 基础拖动检测 + SelectSkillTarget + 指示器更新 + 取消检测

function SC:OnButtonDrag(slot, screenPos, btnCenter)
    -- 守卫
    if self._state ~= "Pressing" and self._state ~= "Dragging" then return end
    if slot ~= self._activeSlot then return end

    -- ① 计算拖动向量（屏幕空间）
    local delta = screenPos - btnCenter
    local mag = delta.Magnitude
    local axis = mag > 0.001 and (delta / mag) or Vector2.zero

    -- ② 拖动判定
    -- DRAG_THRESHOLD 默认 10 像素
    -- 超过阈值才认为用户在拖动（避免手指抖动误判）
    if mag > GCfg.DRAG_THRESHOLD and not self._hasDragged then
        self._hasDragged = true
        self._state = "Dragging"
    end

    -- ③ 归一化偏移 (0~1)
    -- maxR = 120 是按钮区域的最大拖动半径（像素）
    -- 当 mag >= 120 时 normOff = 1.0，对应最大施法距离
    local maxR = 120
    local normOff = math.clamp(mag / maxR, 0, 1)

    -- ④ 目标选择（写入 _targetPos/_targetDir/_targetActor）
    -- 详见 07_SelectSkillTarget/
    self:_SelectSkillTarget(self._rangeType, axis, normOff)

    -- ⑤ 指示器位置更新
    if self._indCfg then
        self._indicator:UpdatePosition(
            self._targetPos,
            self._targetDir,
            self._moveFlag,
            self._rotateFlag
        )
    end

    -- ⑥ 取消区域检测
    self._cancelDet:Update(screenPos)
end
```

## 关键参数说明

### axis（屏幕空间归一化方向）

```
       axis.Y = -1 (上)
           ↑
           │
axis.X = -1 ←──⊙──→ axis.X = +1
(左)       │         (右)
           ↓
       axis.Y = +1 (下)

注意: 屏幕坐标 Y 轴向下为正
在 _AxisToWorld() 中会翻转: fwd * (-axis.Y)
```

### normOff（归一化偏移量）

```
0.0 ─── 手指在按钮中心
0.5 ─── 手指拖到半程（Target型：简易/高级模式分界线）
1.0 ─── 手指拖到最远（对应 guideDistance 最大值）
```

### maxR（最大拖动半径）

- 硬编码 120 像素
- 中这个值由 JoystickMode 和按钮配置决定
- Roblox 简化为固定值，后续可通过配置调整

## 对照

| Roblox 版步骤 | 原始调用 | 行号 |
|---|---|---|
| 计算 delta | `MoveSkillCursor()` 中的 `delta = eventData.position - buttonCenter` | 604-610 |
| 拖动判定 | `bDraging = true` when `distance > dragThreshold` | 620-625 |
| normOff | `guideDistance = maxGuide * (distance/maxDrag)` | 632-640 |
| SelectSkillTarget | `MoveSkillCursorInScene()` → `SelectSkillTarget()` | 650-660 |
| 指示器更新 | `RefreshIndicatorState()` 在 `SelectSkillTarget()` 末尾调用 | 3790 |
| 取消检测 | `RefreshIndicatorCancelUI()` | 6386-6429 |

## 每帧调用频率

Drag 回调的频率由输入系统决定：
- **触屏**: 60fps（每帧触发一次 InputChanged）
- **鼠标**: 随鼠标移动频率，通常 60-120fps

`SelectSkillTarget()` 本身很轻量（纯数学计算），每帧调用不需要节流。  
指示器的 `Tick()`（平滑插值）通过 `INDICATOR_UPDATE_INTERVAL` 节流。

---

> **下一步**: `SkillController_Up.md`
