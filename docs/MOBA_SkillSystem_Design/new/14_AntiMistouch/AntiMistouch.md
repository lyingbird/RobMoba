# 14 — 防误触机制

> **所属模块**: `SkillController.lua` 内部方法 `_IsAllowUseSkill()`  
> **HOK 来源**: `SkillControlIndicator.IsAllowUseSkill()` 第418-441行 + `OnSkillButtonUp()` 中的快速点击处理

---

## 设计说明

防误触解决的核心问题：**玩家不小心碰到了技能按钮，技能就释放了？**

HOK 针对不同技能类型有不同的防误触策略：

### Pos 型防误触

| 条件 | 值 | 判断 |
|---|---|---|
| controlMove | false（未拖动） | 用户没有拖出有效偏移 |
| pressTime | ≤ 1000ms（1秒） | 按压时间很短 |
| bIgnoreTouchRejection | false（未豁免） | 没有特殊配置豁免 |
| **结果** | **不释放** | 判定为误触 |

**设计意图**：Pos 型技能需要选择落点。如果用户只是点了一下没拖（controlMove=false），而且按压时间不到1秒，很可能是误触。但如果用户按住超过1秒（哪怕没拖），说明是"长按释放在脚下"的有意操作。

### Directional 型快速点击

| 条件 | 值 | 行为 |
|---|---|---|
| pressDuration | ≤ 0.4秒 | 快速点击 |
| **结果** | **允许释放** | 但使用角色当前朝向 |

**设计意图**：Directional 型不阻止释放。快速点击时，玩家来不及拖出方向，此时使用角色当前面对的方向释放。这是一个"快速出招"的便捷操作。

### Target 型

无特殊防误触。按下即开始索敌，抬起即释放。

### Auto 型

不经过 OnButtonUp，在 OnButtonDown 中直接释放，无需防误触。

---

## 完整伪代码

```lua
-- 属于 SkillController 的方法
-- 来源: HOK SkillControlIndicator.IsAllowUseSkill() 第418-441行

function SC:_IsAllowUseSkill(rangeType: number, pressDuration: number): boolean
    local R = Enums.SkillRangeType

    -- ========================================
    -- Pos 型防误触
    -- ========================================
    -- 来源: HOK IsAllowUseSkill() 第418-441行
    -- 原文:
    --   if (!bControlMove && !bIgnoreTouchRejection && pressTimeMs <= 1000)
    --       return false
    --
    -- 条件:
    --   controlMove == false  — 用户没有拖动（Pos 型拖动时会设 controlMove=true）
    --   pressDuration <= 1.0s — 按压时间不超过1秒
    --   (bIgnoreTouchRejection 在 Roblox 版中默认 false，不实现)
    --
    -- 含义:
    --   "点了一下就放手，没有选择落点" → 误触，不释放
    --   如果拖动了(controlMove=true) 或 长按了(>1s) → 允许释放

    if rangeType == R.Pos then
        if not self._controlMove
            and pressDuration <= GCfg.POS_PRESS_TIME_THRESHOLD then
            return false  -- 误触，不释放
        end
    end

    -- ========================================
    -- Directional 型快速点击
    -- ========================================
    -- 来源: HOK OnSkillButtonUp() 中
    --   if (抬起时间 <= 0.4s) → ignoreDirectionalRespondMinRadius = true
    --
    -- 这里不阻止释放，而是调整参数:
    --   如果快速点击且没有拖出方向 → 使用角色当前朝向

    if rangeType == R.Directional then
        if pressDuration <= GCfg.DIR_QUICK_TAP_THRESHOLD then
            -- 快速点击: 检查是否有有效方向
            if self._targetDir.Magnitude < 0.01 then
                -- 没有拖出方向 → 使用角色当前朝向
                local c = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if r then
                    self._targetDir = r.CFrame.LookVector
                end
            end
        end
    end

    return true  -- 允许释放
end
```

---

## 判断流程图

```
_IsAllowUseSkill(rangeType, pressDuration)
    │
    ├── rangeType == Pos ?
    │   ├── controlMove == false ?
    │   │   ├── pressDuration <= 1.0s ?
    │   │   │   └── YES → return false (误触)
    │   │   │   └── NO  → 继续 (长按，允许)
    │   │   └── NO → 继续 (拖动了，允许)
    │   └── NO → 继续
    │
    ├── rangeType == Directional ?
    │   ├── pressDuration <= 0.4s ?
    │   │   ├── targetDir 有效 ?
    │   │   │   └── YES → 继续 (用拖出的方向)
    │   │   │   └── NO  → 用角色朝向替代
    │   │   └── NO → 继续 (正常拖动释放)
    │   └── NO → 继续
    │
    └── return true (允许释放)
```

---

## 场景示例

### 场景1: Pos 型误触

```
玩家手指不小心碰到"二技能"按钮，立刻松开
  → pressDuration = 0.1s (< 1.0s)
  → controlMove = false (没有拖动)
  → _IsAllowUseSkill() 返回 false
  → 技能不释放 ✓
```

### 场景2: Pos 型长按释放

```
玩家按住"二技能"按钮2秒后松开（没有拖动）
  → pressDuration = 2.0s (> 1.0s)
  → controlMove = false
  → _IsAllowUseSkill() 返回 true
  → 技能在角色脚下释放 ✓ （有意的"原地释放"操作）
```

### 场景3: Pos 型拖动释放

```
玩家按住"二技能"并拖动到目标位置后松开
  → pressDuration = 0.5s (< 1.0s)
  → controlMove = true（拖动超过 5% 阈值）
  → _IsAllowUseSkill() 返回 true
  → 技能在拖动位置释放 ✓
```

### 场景4: Directional 快速点击

```
玩家快速点了一下"大招"按钮
  → pressDuration = 0.15s (< 0.4s)
  → targetDir 可能为零（没来得及拖）
  → _IsAllowUseSkill() 用角色朝向替代 targetDir
  → 技能向角色面对方向释放 ✓
```

### 场景5: Directional 正常拖动

```
玩家按住"大招"并拖出方向后松开
  → pressDuration = 0.8s (> 0.4s)
  → targetDir = 拖动方向
  → _IsAllowUseSkill() 返回 true（不做修改）
  → 技能向拖动方向释放 ✓
```

---

## 常量速查

| 常量 | 值 | 来源 | 含义 |
|---|---|---|---|
| `POS_PRESS_TIME_THRESHOLD` | 1.0 秒 | HOK `IsAllowUseSkill` 硬编码 1000ms | Pos 型按压时间阈值 |
| `DIR_QUICK_TAP_THRESHOLD` | 0.4 秒 | HOK `OnSkillButtonUp` 硬编码 400ms | Directional 快速点击阈值 |
| `controlMove` 触发阈值 | normOff > 0.05 | `_ST_Pos()` 中设置 | 约 6 像素（120*0.05） |

---

> **下一步**: `15_Reference/`
