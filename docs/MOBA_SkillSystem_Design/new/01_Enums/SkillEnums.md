# 01 — 枚举定义 SkillEnums

> **文件路径**: `ReplicatedStorage/SkillSystem/Enums/SkillEnums.lua`  
> **HOK 来源**: `Reskeywords2.cs` (SkillRangeAppointType 第225行) + `cc_commdef.cs` (SkillJoystickMode 第258行) + `IndicatorDef.cs` (全部枚举)

---

## 完整实现

```lua
-- 文件: ReplicatedStorage/SkillSystem/Enums/SkillEnums.lua
local SkillEnums = {}

--------------------------------------------------------------------------------
-- 1. 技能范围指定类型
--------------------------------------------------------------------------------
-- HOK 原始枚举: SkillRangeAppointType (7种)
-- Roblox 精简: 保留5种（去掉 Project8Directional / Project8Pos）
--
-- 决定了 SelectSkillTarget() 的分发路径和指示器表现形式
SkillEnums.SkillRangeType = {
    Auto        = 0,  -- 按下即释放，无指示器（如闪现）
    Target      = 1,  -- 指定目标，拖动锁定敌方单位（如点控技能）
    Pos         = 2,  -- 指定位置，拖动选择地面落点（如 AOE 技能）
    Directional = 3,  -- 指定方向，拖动选择释放朝向（如线性技能）
    Track       = 4,  -- 指定轨迹，拖动绘制路径（HOK 已废弃但保留枚举）
}

--------------------------------------------------------------------------------
-- 2. 技能槽位
--------------------------------------------------------------------------------
-- HOK 使用 0-7 共8个槽位，Roblox 精简为6个
-- SLOT_SKILL_0 = 普攻，走独立的 CommonAttackController
SkillEnums.SlotType = {
    SLOT_SKILL_0 = 0,  -- 普攻
    SLOT_SKILL_1 = 1,  -- 技能1
    SLOT_SKILL_2 = 2,  -- 技能2
    SLOT_SKILL_3 = 3,  -- 技能3（大招）
    SLOT_SKILL_4 = 4,  -- 召唤师技能1
    SLOT_SKILL_5 = 5,  -- 召唤师技能2
}

--------------------------------------------------------------------------------
-- 3. 指示器层
--------------------------------------------------------------------------------
-- HOK 三层资源架构:
--   Guide  → 挂角色 Transform，显示最大施法范围圆
--   Effect → 挂场景根节点，跟随目标位置移动
--   Fixed  → 挂角色 Transform，始终显示（如大招固定圈）
--
-- 来源: SkillIndicatorBase.cs (CreateIndicatePrefab 5种 Prefab)
-- Roblox: 每层用一个独立 Part/Model 表示
SkillEnums.IndicatorLayer = {
    Guide  = 1,
    Effect = 2,
    Fixed  = 3,
}

--------------------------------------------------------------------------------
-- 4. 指示器资源类型
--------------------------------------------------------------------------------
-- HOK 原始: RES_SKILL_EFFECT_INDICATOR_TYPE 共68种 (0-67)
-- Roblox 精简为7种核心几何形状
--
-- 实现者可根据游戏需求扩展，但核心逻辑只需要这7种
SkillEnums.IndicatorResType = {
    Arrow      = 0,  -- 箭头（Directional 默认），Block Part 拉长
    Sector     = 1,  -- 扇形（Target 近距离），Cylinder + SectorAngle Attribute
    Circle     = 2,  -- 圆形（Pos 默认），Cylinder Part
    Rectangle  = 3,  -- 矩形（Directional 宽度型），Block Part
    Ring       = 4,  -- 圆环（Guide 默认），Cylinder 半透明
    HalfCircle = 5,  -- 半圆，Cylinder + Attribute
    Line       = 6,  -- 线型（Track 默认），极细 Block Part 或 Beam
}

--------------------------------------------------------------------------------
-- 5. 控制器状态机
--------------------------------------------------------------------------------
-- SkillController 的状态流转:
--
--   Idle → (ButtonDown) → Pressing → (拖动>阈值) → Dragging
--                              │                         │
--                         ButtonUp(快速)            ButtonUp(正常/取消)
--                              ↓                         ↓
--                           Released              Released / Cancelled
--                              ↓                         ↓
--                         (发送命令)              (取消/回到Idle)
--                              ↓
--                        → Idle / Buffered
SkillEnums.ControllerState = {
    Idle      = "Idle",       -- 空闲，等待按下
    Pressing  = "Pressing",   -- 已按下，未确认拖动
    Dragging  = "Dragging",   -- 拖动中（位移已超过 DRAG_THRESHOLD）
    Released  = "Released",   -- 瞬态：正在处理释放
    Cancelled = "Cancelled",  -- 瞬态：取消释放
    Buffered  = "Buffered",   -- 已入缓冲，等待前序技能结束
}

--------------------------------------------------------------------------------
-- 6. 取消模式
--------------------------------------------------------------------------------
-- HOK 有3种: AreaCancle / DisitanceCancle / Unity3DTouchCancle
-- Roblox 精简为2种（去掉 3DTouch）
--
-- 两种模式是 OR 关系，任一满足即进入取消状态
SkillEnums.CancelMode = {
    AreaCancel     = 1,  -- UI矩形区域：手指进入屏幕底部 CancelFrame
    DistanceCancel = 2,  -- 拖动距离：从按下点到当前位置 > 270 像素
}

return SkillEnums
```

---

## 枚举值对照表（HOK → Roblox）

| HOK 枚举 | HOK 值 | Roblox 枚举 | Roblox 值 | 备注 |
|---|---|---|---|---|
| `SkillRangeAppointType.Auto` | 0 | `SkillRangeType.Auto` | 0 | 一致 |
| `SkillRangeAppointType.Target` | 1 | `SkillRangeType.Target` | 1 | 一致 |
| `SkillRangeAppointType.Pos` | 2 | `SkillRangeType.Pos` | 2 | 一致 |
| `SkillRangeAppointType.Directional` | 3 | `SkillRangeType.Directional` | 3 | 一致 |
| `SkillRangeAppointType.Track` | 4 | `SkillRangeType.Track` | 4 | HOK 已废弃 |
| `SkillRangeAppointType.Project8Directionnal` | 5 | — | — | 已裁剪 |
| `SkillRangeAppointType.Project8Pos` | 6 | — | — | 已裁剪 |

---

## 使用方式

```lua
local Enums = require(game.ReplicatedStorage.SkillSystem.Enums.SkillEnums)

-- 判断技能类型
if skill.rangeType == Enums.SkillRangeType.Target then
    -- Target 型逻辑
end

-- 判断控制器状态
if controller.state == Enums.ControllerState.Dragging then
    -- 拖动中逻辑
end
```
