# 06.3 — 阶段三：OnButtonUp（抬起）

> **所属模块**: `SkillController.lua`

---

## 流程图

```
OnButtonUp(slot, screenPos)
    │
    ├── 守卫: state 必须是 "Pressing" 或 "Dragging"
    │   └── 否 → return
    │
    ├── 守卫: slot 必须等于 _activeSlot
    │   └── 否 → return
    │
    ├── ① 最后一次 Drag（关键！用抬手位置再算一次目标）
    │   OnButtonDrag(slot, screenPos, _btnCenter)
    │
    ├── ② 计算按压时长
    │   dur = os.clock() - _pressStart
    │
    ├── ③ 取消判定
    │   cs = cancelDet:GetState()
    │   bNoCancel = !cs.isInCancelArea || cs.timeInCancelArea <= 0.15s
    │   └── bNoCancel == false → _Cancel() → return
    │
    ├── ④ 防误触判定
    │   _IsAllowUseSkill(rangeType, dur)
    │   └── false → _Cancel() → return
    │
    ├── ⑤ 构建 SkillParam
    │   {slotType, skillId, rangeType, targetPosition, targetDirection, targetActorId, trackPoints}
    │
    ├── ⑥ 执行
    │   _Execute(slot, param)
    │   → TryExecuteOrBuffer()
    │     → 可释放: FireServer(param)
    │     → 不可释放: PushToCache(param)
    │
    └── ⑦ 清理
        _Cleanup()
        → indicator:Disable()
        → cancelDet:Reset()
        → _StopHB()
        → state → "Idle"
```

## 完整伪代码

```lua

-- 精简说明:
--   原版还有: 蓄力 ForceUp、多手指冲突解决、方向锁定模式、延迟确认
--   Roblox 版保留: 最后一次Drag + 取消判定 + 防误触 + 构建参数 + 执行/缓冲

function SC:OnButtonUp(slot, screenPos)
    -- 守卫
    if self._state ~= "Pressing" and self._state ~= "Dragging" then return end
    if slot ~= self._activeSlot then return end

    -- ① 最后一次 Drag
    -- 做法: 抬手时用最终位置再 SelectSkillTarget 一次
    -- 这确保了抬手瞬间的位置被记录，而不是上一帧 Drag 的位置
    -- 来源: OnSkillButtonUp 第315-325行
    self:OnButtonDrag(slot, screenPos, self._btnCenter)

    -- ② 按压时长（秒）
    local dur = os.clock() - self._pressStart

    -- ③ 取消判定
    -- 来源: OnSkillButtonUp 第480-510行
    -- 原文逻辑:
    --   bNoCancel = !m_currentSkillIndicatorInCancelArea
    --              || (m_timeInCancelArea <= m_SkillInCancelAreaTimeInterval)
    -- 含义: 如果手指在取消区域内停留超过 0.15 秒 → 取消技能
    local cs = self._cancelDet:GetState()
    local bNoCancel = (not cs.isInCancelArea)
                   or (cs.timeInCancelArea <= GCfg.CANCEL_AREA_STAY_THRESHOLD)

    if not bNoCancel then
        -- 取消释放
        self:_Cancel()
        return
    end

    -- ④ 防误触判定
    -- 详见 14_AntiMistouch/AntiMistouch.md
    if not self:_IsAllowUseSkill(self._rangeType, dur) then
        self:_Cancel()
        return
    end

    -- ⑤ 构建 SkillParam
    local param = {
        slotType        = slot,
        skillId         = self._slots[slot].skillId,
        rangeType       = self._rangeType,
        targetPosition  = self._targetPos,       -- Vector3: 技能落点
        targetDirection = self._targetDir,        -- Vector3: 技能方向
        targetActorId   = self._targetActor,      -- number: Target型锁定的敌方
        trackPoints     = self._trackPts,         -- {Vector3}?: Track型轨迹
    }

    -- ⑥ 执行（尝试释放或缓冲）
    self:_Execute(slot, param)

    -- ⑦ 清理
    self:_Cleanup()
end
```

## 取消判定详解

### 条件表达式

```lua
bNoCancel = (NOT inCancelArea) OR (timeInCancelArea <= 0.15)
```

| 场景 | inCancelArea | time | bNoCancel | 结果 |
|---|---|---|---|---|
| 手指在正常区域抬起 | false | 0 | **true** | 释放技能 |
| 手指快速划过取消区域 | true | 0.08s | **true** | 释放技能（停留时间不够） |
| 手指在取消区域停留后抬起 | true | 0.3s | **false** | 取消技能 |

### 设计意图

0.15 秒的停留阈值是为了防止"误划过取消区域"。玩家快速拖动时手指可能短暂经过屏幕底部，但如果只是划过（<0.15秒）就不应该取消。

## 防误触判定详解

详见 `14_AntiMistouch/AntiMistouch.md`，此处简述判定结果：

| 类型 | 条件 | 结果 |
|---|---|---|
| Pos 型 | 未拖动(`controlMove=false`) + 按压≤1秒 | **不释放**（判定为误触） |
| Directional 型 | 按压≤0.4秒 | **释放**，但使用角色当前朝向 |
| 其他 | — | **释放** |

## 对照

| Roblox 版步骤 | 原始调用 | 行号 |
|---|---|---|
| 最后一次 Drag | `OnSkillButtonDrag(eventData)` 在 Up 开头调用 | 315-325 |
| 按压时长 | `elapsedTime = Time.realtimeSinceStartup - m_pressSkillStartRealTime` | 330 |
| 取消判定 | `bNoCancel = !m_currentSkillIndicatorInCancelArea \|\| ...` | 480-510 |
| 防误触 | `IsAllowUseSkill()` | 418-441 |
| 构建参数 | `RequestUseSkillSlot()` | 520-540 |
| 执行 | `CmdUseSkill()` → 帧命令 | 545-560 |
| 清理 | `CancelUseSkillSlot()` + `DisableSkillCursor()` | 570-580 |

## 关键设计决策

1. **最后一次 Drag 在 Up 开头执行**: 这不是多余的调用。如果用户快速拖动并抬起，最后一个 Drag 事件的位置可能不是抬起位置。在 Up 开头补一次 Drag 确保最终位置准确。

2. **取消优先于防误触**: 先判取消再判防误触。如果用户在取消区域抬起，无论按压时间多长都是取消。

3. **参数构建时冻结状态**: `SkillParam` 使用 `_targetPos`/`_targetDir`/`_targetActor` 的最终值，这些值在最后一次 Drag 中已经被 `_SelectSkillTarget` 更新过。

4. **Cleanup 在 Execute 之后**: 清理操作（关闭指示器、重置取消检测、停止 Heartbeat）放在 `_Execute` 之后，确保参数已经发送出去再清理。

---

> **下一步**: `07_SelectSkillTarget/`
