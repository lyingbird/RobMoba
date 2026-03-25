# 06 — 技能控制器 SkillController — 总览

> **文件路径**: `StarterPlayerScripts/SkillSystem/SkillController.lua`  
> **拆分说明**: 此模块拆为 Overview / Down / Drag / Up 四个子文档，以及 07_SelectSkillTarget 独立章节

---

## 设计说明

的技能控制分散在两个类中：
- 技能按钮控制器 — UI 事件分发（OnButtonDown/Drag/Up）
- 技能指示器控制 — 指示器逻辑 + 目标选择 + 状态管理

Roblox 版合并为单个 `SkillController`，因为两者职责高度耦合。

## 完整类结构

```lua
-- 文件: StarterPlayerScripts/SkillSystem/SkillController.lua

local RunService = game:GetService("RunService")
local Enums   = require(game.ReplicatedStorage.SkillSystem.Enums.SkillEnums)
local GCfg    = require(game.ReplicatedStorage.SkillSystem.Config.GlobalConfig)
local SKCfg   = require(game.ReplicatedStorage.SkillSystem.Config.SkillConfig)
local IndCfg  = require(game.ReplicatedStorage.SkillSystem.Config.IndicatorConfig)

local SC = {}; SC.__index = SC

function SC.new(deps)
    local self = setmetatable({}, SC)
    -- ========== 依赖 ==========
    self._indicator  = deps.skillIndicator       -- SkillIndicator 实例
    self._cancelDet  = deps.cancelAreaDetector    -- CancelAreaDetector 实例
    self._cache      = deps.skillCacheManager     -- SkillCacheManager 实例
    
    -- ========== 技能槽位 ==========
    self._slots      = {}           -- [slotType] = SkillSlot

    -- ========== 状态机 ==========
    -- 可选值: "Idle" | "Pressing" | "Dragging" | "Released" | "Cancelled" | "Buffered"
    self._state      = "Idle"

    -- ========== 当前操作 ==========
    self._activeSlot = -1           -- 当前操作的技能槽位
    self._rangeType  = 0            -- 当前技能的 SkillRangeType
    self._indCfg     = nil          -- 当前技能的 IndicatorConfig

    -- ========== 按下记录 ==========
    self._pressStart = 0            -- os.clock() 按下时刻
    self._pressPos   = Vector2.zero -- 按下时屏幕坐标
    self._btnCenter  = Vector2.zero -- 按钮中心屏幕坐标
    self._pressTime  = 0            -- 按压累计时间(ms)
    self._hasDragged = false        -- 是否产生过拖动
    self._controlMove = false       -- Pos型：是否产生过有效拖动

    -- ========== 目标结果（SelectSkillTarget 输出）==========
    self._targetPos  = Vector3.zero -- 技能目标世界坐标
    self._targetDir  = Vector3.zero -- 技能目标方向
    self._targetActor= 0            -- Target型锁定的敌方ActorId
    self._rotateFlag = false        -- 指示器是否需要旋转
    self._moveFlag   = false        -- 指示器是否需要移动

    -- ========== 释放状态 ==========
    self._casting    = false        -- 当前是否有技能正在释放
    self._castSlot   = -1           -- 正在释放的技能槽位

    -- ========== Heartbeat ==========
    self._hbConn     = nil          -- Heartbeat 连接
    self._frame      = 0            -- 帧计数器

    -- ========== Track 专用 ==========
    self._trackPts   = nil          -- Track型轨迹点列表 {Vector3, ...}
    self._lastTrackPt= Vector3.zero -- 上一个记录的轨迹点

    return self
end
```

## 状态机图

```
                              ┌──────────────────────────────┐
                              │                              │
                              ▼                              │
┌───────┐  ButtonDown   ┌──────────┐  位移>阈值  ┌──────────┐│
│ Idle  │──────────────▶│ Pressing │────────────▶│ Dragging ││
└───────┘               └──────────┘             └──────────┘│
   ▲                         │                     │    │     │
   │                  ButtonUp│                     │    │     │
   │                  (快速点击)                    │    │     │
   │                         ▼                     │    │     │
   │                    ┌──────────┐  ButtonUp     │    │     │
   │                    │ Released │◀──────────────┘    │     │
   │                    └──────────┘ (正常区域)         │     │
   │                         │                          │     │
   │              发送技能命令│                          │     │
   │              +清理指示器 │                          │     │
   │                         ▼                          │     │
   │◀────────────────────(回到 Idle)                    │     │
   │                                                    │     │
   │    ┌───────────┐  ButtonUp(取消区域>0.15s)         │     │
   │◀───│ Cancelled │◀──────────────────────────────────┘     │
   │    └───────────┘                                         │
   │                                                          │
   │    ┌──────────┐  当前有技能释放中                         │
   └────│ Buffered │◀─────────── 入缓冲队列 ──────────────────┘
        └──────────┘       等待前序技能结束后自动触发
```

## 公共方法列表

| 方法 | 触发时机 | 详见 |
|---|---|---|
| `SC:SetSkillSlot(slot, data)` | 初始化/更新技能数据 | 本文件 |
| `SC:OnButtonDown(slot, screenPos, btnCenter)` | 手指按下 | `SkillController_Down.md` |
| `SC:OnButtonDrag(slot, screenPos, btnCenter)` | 手指拖动 | `SkillController_Drag.md` |
| `SC:OnButtonUp(slot, screenPos)` | 手指抬起 | `SkillController_Up.md` |
| `SC:OnSkillCastFinished(slot)` | 技能释放完毕回调 | 本文件 |
| `SC:_SelectSkillTarget(rt, axis, normOff)` | 内部：目标选择分发 | `07_SelectSkillTarget/` |
| `SC:_IsAllowUseSkill(rangeType, pressDuration)` | 内部：防误触判定 | `14_AntiMistouch/` |

## 内部方法

```lua
function SC:SetSkillSlot(slot, data) self._slots[slot] = data end

function SC:_StartHB()
    if self._hbConn then return end
    self._frame = 0
    self._hbConn = RunService.Heartbeat:Connect(function(dt)
        if self._state == "Idle" then return end
        self._pressTime += dt * 1000  -- 累加按压时间(ms)
        self._frame += 1
        -- 节流：每 INDICATOR_UPDATE_INTERVAL 帧才更新指示器
        if self._frame % GCfg.INDICATOR_UPDATE_INTERVAL ~= 0 then return end
        if self._indicator then self._indicator:Tick(dt) end
    end)
end

function SC:_StopHB()
    if self._hbConn then self._hbConn:Disconnect(); self._hbConn = nil end
end

function SC:_Execute(slot, param)
    if self._cache:TryExecuteOrBuffer(param) then
        self._casting = true; self._castSlot = slot
    end
end

-- 外部调用：技能释放完毕（由服务端回调或动画结束事件触发）
function SC:OnSkillCastFinished(slot)
    if self._castSlot == slot then
        self._casting = false; self._castSlot = -1
        self._cache:TryUseCache()  -- 尝试释放缓冲区中的下一个技能
    end
end

function SC:_Cancel()
    self:_Cleanup()
end

function SC:_Cleanup()
    if self._indicator then self._indicator:Disable() end
    self._cancelDet:Reset()
    self:_StopHB()
    self._state = "Idle"; self._activeSlot = -1; self._indCfg = nil
    self._hasDragged = false; self._controlMove = false
end
```

## 辅助方法

```lua
-- 屏幕2D轴 → 世界XZ方向
-- 来源: Camera 适配逻辑
function SC:_AxisToWorld(axis: Vector2): Vector3
    local cam = workspace.CurrentCamera
    if not cam then return Vector3.new(axis.X, 0, -axis.Y) end
    local look = cam.CFrame.LookVector
    local fwd = Vector3.new(look.X, 0, look.Z).Unit   -- 摄像机前方投影到XZ平面
    local rt  = Vector3.new(fwd.Z, 0, -fwd.X)         -- 右方向
    local w = rt * axis.X + fwd * (-axis.Y)            -- 组合
    return w.Magnitude > 0.01 and w.Unit or Vector3.zero
end

-- 获取本地角色位置
function SC:_CharPos(): Vector3
    local c = game.Players.LocalPlayer and game.Players.LocalPlayer.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return r and r.Position or Vector3.zero
end

-- 搜索敌方（实现者接入自己的角色管理系统）
function SC:_FindEnemy(pos: Vector3, radius: number): number
    -- 返回最近敌方的 ActorId，无目标返回 0
    return 0
end

-- 获取指定 Actor 的世界位置
function SC:_ActorPos(id: number): Vector3
    return Vector3.zero
end

-- 刷新三层指示器显隐
-- 来源: RefreshIndicatorState() 第3790-3825行
function SC:_RefreshIndicatorShow(normOff)
    if not self._indicator or not self._indCfg then return end
    local L = Enums.IndicatorLayer; local cfg = self._indCfg
    if cfg.guideEnabled  then self._indicator:SetLayerVisible(L.Guide, true) end
    if cfg.effectEnabled then self._indicator:SetLayerVisible(L.Effect, normOff > 0.05) end
    if cfg.fixedEnabled  then self._indicator:SetLayerVisible(L.Fixed, true) end
end
```

---

> **下一步**: 阅读 `SkillController_Down.md` → `SkillController_Drag.md` → `SkillController_Up.md`
