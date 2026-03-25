# 03-B — 指示器配置表 IndicatorConfig

> **文件路径**: `ReplicatedStorage/SkillSystem/Config/IndicatorConfig.lua`

---

## 设计说明

有 **4种指示器配置表**（基础/动态/多段/特殊动态），总计超过200个字段。Roblox 版合并为**单表单结构**，用字段开关控制三层（Guide/Effect/Fixed）的启用和参数。

### 配置表精简映射

| 配置表 | 字节数 | Roblox 处理 |
|---|---|---|
| `基础指示器配置` | 48 | → IndicatorConfig 主结构 |
| `动态指示器配置` | 128 | → 合并到主结构（动态尺寸用 `effectRadius` 运行时修改） |
| `多段指示器配置` | 144 (3段) | → 多段技能拆成多条配置，运行时切换 |
| `特殊动态指示器配置` | 88 (3段) | → 同上 |

---

## 完整实现

```lua
-- 文件: ReplicatedStorage/SkillSystem/Config/IndicatorConfig.lua
--
-- key = cfgId (number)，由 SkillConfig.indicatorCfgId 索引
--
-- 核心字段说明:
--
-- ┌────────────────────────────────────────────────────────────┐
-- │ Guide 层 (最大施法范围圆，挂角色脚下)                        │
-- │  guideEnabled    是否启用                                   │
-- │  guideDistance    最大引导距离 (studs)                       │
-- │  guideResType    IndicatorResType 枚举值                    │
-- ├────────────────────────────────────────────────────────────┤
-- │ Effect 层 (实际作用范围，跟随目标位置)                       │
-- │  effectEnabled   是否启用                                   │
-- │  effectRadius    作用半径 (studs)，圆形/扇形使用             │
-- │  effectAngle     扇形角度 (°)，360=完整圆                   │
-- │  effectWidth     矩形宽度 (studs)，仅矩形/箭头使用          │
-- │  effectLength    矩形长度 (studs)，仅矩形/箭头使用          │
-- │  effectResType   IndicatorResType 枚举值                    │
-- │  effectResSize   资源原始宽度（缩放: scaleW = 实际宽/此值）  │
-- │  effectResLength 资源原始长度（缩放: scaleL = 距离/此值）    │
-- ├────────────────────────────────────────────────────────────┤
-- │ Fixed 层 (固定圈，始终在角色脚下)                           │
-- │  fixedEnabled    是否启用                                   │
-- │  fixedResType    IndicatorResType 枚举值                    │
-- └────────────────────────────────────────────────────────────┘
--
-- 缩放公式 :
--   scaleLength = guideDistance / effectResLength   -- effectResLength > 0
--   scaleLength = guideDistance / 10000            -- effectResLength == 0 (兼容旧配置)
--   scaleWidth  = expectWidth  / effectResSize

return {
    -------------------------------------------------------------------------
    -- Target 型：Guide(范围圆) + Effect(扇形)
    -------------------------------------------------------------------------
    [1001] = {
        cfgId = 1001,
        rangeType = 1,  -- Target

        guideEnabled = true,
        guideDistance = 8.0,     -- 最大锁定距离 8 studs
        guideResType = 4,       -- Ring (圆环)

        effectEnabled = true,
        effectRadius = 3.0,      -- 锁定扇形半径 3 studs
        effectAngle = 60,        -- 60° 扇形
        effectWidth = 0,
        effectLength = 0,
        effectResType = 1,       -- Sector (扇形)
        effectResSize = 1000,
        effectResLength = 1000,

        fixedEnabled = false,
        fixedResType = 0,
    },

    -------------------------------------------------------------------------
    -- Pos 型：Guide(范围圆) + Effect(落点圆)
    -------------------------------------------------------------------------
    [1002] = {
        cfgId = 1002,
        rangeType = 2,  -- Pos

        guideEnabled = true,
        guideDistance = 12.0,    -- 最大投放距离 12 studs
        guideResType = 4,       -- Ring

        effectEnabled = true,
        effectRadius = 4.0,      -- AOE 半径 4 studs
        effectAngle = 360,       -- 完整圆
        effectWidth = 0,
        effectLength = 0,
        effectResType = 2,       -- Circle
        effectResSize = 1000,
        effectResLength = 1000,

        fixedEnabled = false,
        fixedResType = 0,
    },

    -------------------------------------------------------------------------
    -- Directional 型：Effect(箭头) + Fixed(脚下圈)
    -------------------------------------------------------------------------
    [1003] = {
        cfgId = 1003,
        rangeType = 3,  -- Directional

        guideEnabled = false,    -- Directional 通常不需要范围圆
        guideDistance = 15.0,    -- 仍然定义最大距离（用于计算）
        guideResType = 0,

        effectEnabled = true,
        effectRadius = 15.0,     -- 箭头长度等于最大距离
        effectAngle = 0,         -- 非扇形
        effectWidth = 3.0,       -- 箭头宽度 3 studs
        effectLength = 15.0,     -- 箭头长度 15 studs
        effectResType = 0,       -- Arrow
        effectResSize = 1000,
        effectResLength = 5000,  -- 缩放: 15/5=3倍

        fixedEnabled = true,     -- 脚下固定圈
        fixedResType = 4,        -- Ring
    },

    -------------------------------------------------------------------------
    -- 扩展示例：宽矩形
    -------------------------------------------------------------------------
    [1004] = {
        cfgId = 1004,
        rangeType = 3,  -- Directional

        guideEnabled = false,
        guideDistance = 10.0,
        guideResType = 0,

        effectEnabled = true,
        effectRadius = 10.0,
        effectAngle = 0,
        effectWidth = 5.0,       -- 宽矩形 5 studs
        effectLength = 10.0,
        effectResType = 3,       -- Rectangle
        effectResSize = 1000,
        effectResLength = 3000,

        fixedEnabled = true,
        fixedResType = 4,
    },
}
```

---

## 三层资源生命周期

```
OnButtonDown:
  ├─ Guide:  Create → Show → SetPos(角色脚下)
  ├─ Fixed:  Create → Show → SetPos(角色脚下)
  └─ Effect: Create → Hide（等 Drag 再显示）

OnButtonDrag:
  ├─ Guide:  SetPos(角色脚下) — 跟随角色移动
  ├─ Fixed:  SetPos(角色脚下) — 跟随角色移动
  └─ Effect: Show → SetPosRot(targetPos, targetDir) — 跟随手指

OnButtonUp / Cancel:
  ├─ Guide:  Destroy
  ├─ Fixed:  Destroy
  └─ Effect: Destroy
```

---

## 策划配表指南

| 使用场景 | 推荐配置 |
|---|---|
| 单体指向技能 | Guide=Ring + Effect=Sector(60°) |
| AOE 落点技能 | Guide=Ring + Effect=Circle |
| 线性方向技能 | Effect=Arrow + Fixed=Ring |
| 宽矩形方向技能 | Effect=Rectangle + Fixed=Ring |
| 按下即放技能 | `indicatorCfgId = 0`（不配指示器） |
