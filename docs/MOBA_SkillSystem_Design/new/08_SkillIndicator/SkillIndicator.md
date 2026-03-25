# 08 — 技能指示器 SkillIndicator

> **文件路径**: `StarterPlayerScripts/SkillSystem/SkillIndicator.lua`  
> **HOK 来源**: `SkillControlIndicator.cs` (4650行) + `SkillIndicatorBase.cs` (351行)  
> **职责**: 三层 Part 生命周期管理 + 位置/方向平滑插值

---

## 设计说明

HOK 的指示器系统涉及 4650 行的 `SkillControlIndicator` 和 351 行的 `SkillIndicatorBase`，包含大量特殊英雄定制逻辑（安琪拉多箭头、孙膑双圈等）。

Roblox 版精简为：
- **SkillIndicator** — 三层资源的生命周期 + 位置/方向 Lerp 插值
- **IndicatorRenderer** — Part 创建/回收/缩放/显隐（见 `09_IndicatorRenderer/`）

## 三层资源模型

```
┌─────────────────────────────────────────────────────────┐
│ Guide 层 (引导层)                                        │
│ · 始终挂在角色脚下                                       │
│ · 显示最大施法范围圆（通常是一个半透明圆环）                │
│ · 按下时创建，抬起/取消时销毁                             │
│ · HOK: 挂角色 Transform                                  │
│ · Roblox: Part 位置跟随 HumanoidRootPart                 │
├─────────────────────────────────────────────────────────┤
│ Effect 层 (作用层)                                       │
│ · 显示技能实际作用范围（扇形/圆形/箭头/矩形）              │
│ · Target: 跟踪目标位置                                    │
│ · Pos: 跟随拖动移动                                       │
│ · Directional: 固定脚下，跟随拖动旋转                     │
│ · 拖动开始后才显示（normOff > 0.05）                      │
│ · HOK: 挂场景根 Transform, 含 Normal/Block/Grass 三套材质 │
│ · Roblox: Part 独立定位                                   │
├─────────────────────────────────────────────────────────┤
│ Fixed 层 (固定层)                                        │
│ · 始终挂在角色脚下（与 Guide 类似但用途不同）              │
│ · 通常用于 Directional 型：脚下的圆环+箭头组合             │
│ · HOK: 挂角色 Transform                                   │
│ · Roblox: Part 位置跟随 HumanoidRootPart                  │
└─────────────────────────────────────────────────────────┘
```

## 完整伪代码

```lua
-- 文件: StarterPlayerScripts/SkillSystem/SkillIndicator.lua

local Enums = require(game.ReplicatedStorage.SkillSystem.Enums.SkillEnums)

local SI = {}; SI.__index = SI

function SI.new(deps)
    local self = setmetatable({}, SI)
    self._renderer = deps.indicatorRenderer   -- IndicatorRenderer 实例
    
    -- 三层资源引用
    self._guide  = nil   -- BasePart: Guide 层
    self._effect = nil   -- BasePart: Effect 层
    self._fixed  = nil   -- BasePart: Fixed 层
    
    -- 配置
    self._config = nil   -- 当前 IndicatorConfig
    self._active = false -- 是否启用
    
    -- 平滑插值状态
    self._curPos = Vector3.zero          -- 当前插值位置
    self._curDir = Vector3.new(0, 0, 1)  -- 当前插值方向
    self._tgtPos = Vector3.zero          -- 目标位置
    self._tgtDir = Vector3.new(0, 0, 1)  -- 目标方向
    
    return self
end
```

### Enable — 按下时创建指示器

```lua
-- 来源: HOK EnableSkillCursor → CreateIndicatePrefab
-- 按下技能按钮时调用，创建三层 Part

function SI:Enable(slot, cfg)
    self._config = cfg
    self._active = true
    local cPos = self:_CPos()
    
    -- Guide 层: 最大施法范围圆
    if cfg.guideEnabled then
        self._guide = self._renderer:Create(
            Enums.IndicatorLayer.Guide,
            cfg.guideResType,
            {radius = cfg.guideDistance, angle = 360}
        )
        self._renderer:SetPos(self._guide, cPos)
        self._renderer:Show(self._guide, true)
    end
    
    -- Fixed 层: 固定脚下指示器
    if cfg.fixedEnabled then
        self._fixed = self._renderer:Create(
            Enums.IndicatorLayer.Fixed,
            cfg.fixedResType,
            {radius = cfg.guideDistance, angle = 360}
        )
        self._renderer:SetPos(self._fixed, cPos)
        self._renderer:Show(self._fixed, true)
    end
    
    -- Effect 层: 技能作用范围（初始隐藏，等 Drag 再显示）
    if cfg.effectEnabled then
        self._effect = self._renderer:Create(
            Enums.IndicatorLayer.Effect,
            cfg.effectResType,
            {
                radius = cfg.effectRadius,
                angle  = cfg.effectAngle,
                width  = cfg.effectWidth,
                length = cfg.effectLength,
            }
        )
        self._renderer:Show(self._effect, false)  -- 初始隐藏!
    end
    
    self._curPos = cPos; self._tgtPos = cPos
end
```

### Disable — 抬起/取消时销毁

```lua
-- 来源: HOK DisableSkillCursor → UnInitIndicatePrefab

function SI:Disable()
    self._active = false
    for _, p in ipairs({self._guide, self._effect, self._fixed}) do
        if p then self._renderer:Destroy(p) end
    end
    self._guide  = nil
    self._effect = nil
    self._fixed  = nil
    self._config = nil
end
```

### UpdatePosition — 每次 Drag 更新目标

```lua
-- 来源: HOK LateUpdate() 中的位置设置逻辑
-- 由 SkillController.OnButtonDrag() 在 SelectSkillTarget 之后调用

function SI:UpdatePosition(tPos, tDir, move, rotate)
    if not self._active then return end
    
    local cPos = self:_CPos()
    
    -- Guide 和 Fixed 始终跟随角色位置
    if self._guide then self._renderer:SetPos(self._guide, cPos) end
    if self._fixed then self._renderer:SetPos(self._fixed, cPos) end
    
    -- Effect 层目标位置:
    --   move == true  → 跟随拖动（Pos/Track 型）
    --   move == false → 固定在角色脚下（Directional/Target 型）
    self._tgtPos = move and tPos or cPos
    
    -- Effect 层目标方向:
    --   rotate == true → 跟随拖动方向
    if rotate and tDir.Magnitude > 0.01 then
        self._tgtDir = tDir
    end
end
```

### SetLayerVisible — 显隐控制

```lua
-- 来源: HOK RefreshIndicatorState() 第3790-3825行
-- HOK 通过 Layer 切换 (Actor/Particles ↔ Hide) 实现
-- Roblox 通过 Transparency 实现

function SI:SetLayerVisible(layer, vis)
    local p = ({
        [1] = self._guide,    -- IndicatorLayer.Guide
        [2] = self._effect,   -- IndicatorLayer.Effect
        [3] = self._fixed,    -- IndicatorLayer.Fixed
    })[layer]
    if p then self._renderer:Show(p, vis) end
end
```

### Tick — Heartbeat 驱动的平滑插值

```lua
-- 来源: HOK LateUpdate(int nDelta) 第2645-2903行 中的 Lerp/Slerp 逻辑
-- 由 SkillController._StartHB() 中的 Heartbeat 回调调用
-- 节流: 每 INDICATOR_UPDATE_INTERVAL 帧调用一次

function SI:Tick(dt)
    if not self._active or not self._effect then return end
    
    -- 插值系数: dt * 15 保证约 60fps 时 t≈0.25，手感平滑
    -- HOK 中不同旋转模式有不同的插值算法
    -- Roblox 统一用 CFrame:Lerp 简化
    local t = math.clamp(dt * 15, 0, 1)
    
    -- 位置插值
    self._curPos = self._curPos:Lerp(self._tgtPos, t)
    
    -- 方向插值（CFrame Slerp）
    if self._tgtDir.Magnitude > 0.01 then
        local cf0 = CFrame.lookAt(Vector3.zero, self._curDir)
        local cf1 = CFrame.lookAt(Vector3.zero, self._tgtDir)
        self._curDir = cf0:Lerp(cf1, t).LookVector
    end
    
    -- 应用到 Effect Part
    self._renderer:SetPosRot(self._effect, self._curPos, self._curDir)
end
```

### 辅助方法

```lua
function SI:_CPos()
    local c = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return r and r.Position or Vector3.zero
end
```

---

## 插值参数调优指南

| 参数 | 值 | 效果 | 调优建议 |
|---|---|---|---|
| `t = dt * 15` | 约 0.25 @60fps | 平滑但有延迟 | 增大→更灵敏，减小→更平滑 |
| `dt * 30` | 约 0.5 @60fps | 接近即时响应 | 适合 Directional |
| `dt * 8` | 约 0.13 @60fps | 慢速平滑 | 适合 Pos 大范围移动 |

HOK 原版不同技能类型用不同插值速度，Roblox 版统一用 `15` 作为起始值。实现者可根据手感需要对不同类型使用不同系数。

---

> **下一步**: `09_IndicatorRenderer/`
