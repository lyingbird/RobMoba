# 05 — 技能按钮管理 SkillButtonManager

> **文件路径**: `StarterPlayerScripts/SkillSystem/SkillButtonManager.lua`

---

## 设计说明

的 按钮管理器 是一个万行级巨类，包含按钮管理、指示器创建、取消 UI、蓄力、锁定框、多技能联动等。Roblox 版拆分后，此模块只保留：

1. **按钮绑定**: 将 UI 按钮的 InputBegan 绑定到 InputAdapter
2. **事件分发**: Down/Drag/Up → SkillController 或 CommonAttackController
3. **取消 UI 刷新**: 根据 CancelAreaDetector 状态更新取消提示的颜色/显隐

---

## 完整实现

```lua
-- 文件: StarterPlayerScripts/SkillSystem/SkillButtonManager.lua
--
-- 依赖注入:
--   skillController       → SkillController 实例
--   commonAttackController → CommonAttackController 实例
--   inputAdapter          → InputAdapter 实例
--   cancelAreaDetector    → CancelAreaDetector 实例
--
-- UI 元素:
--   buttonMap  → { [slotType] = ImageButton }
--   cancelUI   → { CancelFrame = Frame, CancelTips = ImageLabel }

local GlobalConfig = require(game.ReplicatedStorage.SkillSystem.Config.GlobalConfig)

local SkillButtonManager = {}
SkillButtonManager.__index = SkillButtonManager

function SkillButtonManager.new(deps)
    local self = setmetatable({}, SkillButtonManager)

    -- 依赖
    self._skillCtrl = deps.skillController
    self._atkCtrl   = deps.commonAttackController
    self._input     = deps.inputAdapter
    self._cancelDet = deps.cancelAreaDetector

    -- UI 引用
    self._buttons    = {}    -- [slotType] = ImageButton
    self._btnCenters = {}    -- [slotType] = Vector2 (按钮中心屏幕坐标)
    self._activeSlot = -1    -- 当前按下的槽位 (-1 = 无)
    self._cancelTips = nil   -- ImageLabel (取消提示图标)

    return self
end

-- ================================================================
-- Init: 初始化按钮绑定和回调注册
-- ================================================================
-- 参数:
--   buttonMap  { [slotType] = ImageButton } — 由 UI 层传入
--   cancelUI   { CancelFrame = Frame, CancelTips = ImageLabel }
--
-- 来源: 按钮管理器 初始化阶段（分散在多个 Init 方法中）
function SkillButtonManager:Init(buttonMap, cancelUI)
    self._cancelTips = cancelUI.CancelTips

    -- 为每个按钮绑定 InputBegan
    for slotType, btn in pairs(buttonMap) do
        self._buttons[slotType] = btn

        -- 计算按钮中心（一次性，假设按钮不移动）
        -- 如果 UI 可能重排，需要在 Drag 时实时计算
        self._btnCenters[slotType] = Vector2.new(
            btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2,
            btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
        )

        -- 绑定按下事件
        btn.InputBegan:Connect(function(inputObject)
            if inputObject.UserInputType == Enum.UserInputType.Touch
                or inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
                self._activeSlot = slotType
                self._input:BeginTracking(inputObject)
            end
        end)
    end

    -- 注册 InputAdapter 回调
    self._input.onInputBegan = function(screenPos)
        self:_OnDown(self._activeSlot, screenPos)
    end

    self._input.onInputChanged = function(screenPos)
        if self._activeSlot >= 0 then
            self:_OnDrag(self._activeSlot, screenPos)
        end
    end

    self._input.onInputEnded = function(screenPos)
        if self._activeSlot >= 0 then
            self:_OnUp(self._activeSlot, screenPos)
            self._activeSlot = -1
        end
    end
end

-- ================================================================
-- _OnDown: 按下
-- ================================================================
function SkillButtonManager:_OnDown(slot, screenPos)
    -- 普攻走独立控制器
    if slot == 0 then
        self._atkCtrl:OnButtonDown()
        return
    end

    -- 设置取消检测器的按下起点
    self._cancelDet:SetPressStart(screenPos)

    -- 分发给 SkillController
    self._skillCtrl:OnButtonDown(slot, screenPos, self._btnCenters[slot])
end

-- ================================================================
-- _OnDrag: 拖动
-- ================================================================
-- 来源: OnSkillButtonDrag() 第590-723行 中的 UI 刷新部分
function SkillButtonManager:_OnDrag(slot, screenPos)
    if slot == 0 then
        self._atkCtrl:OnButtonDrag(screenPos)
        return
    end

    -- 分发给 SkillController
    self._skillCtrl:OnButtonDrag(slot, screenPos, self._btnCenters[slot])

    -- 刷新取消区域 UI
    -- 来源: RefreshIndicatorCancelUI() 第6386-6429行
    self:_RefreshCancelUI()
end

-- ================================================================
-- _OnUp: 抬起
-- ================================================================
function SkillButtonManager:_OnUp(slot, screenPos)
    if slot == 0 then
        self._atkCtrl:OnButtonUp()
        return
    end

    self._skillCtrl:OnButtonUp(slot, screenPos)

    -- 隐藏取消提示
    if self._cancelTips then
        self._cancelTips.Visible = false
    end
end

-- ================================================================
-- _RefreshCancelUI: 刷新取消区域视觉反馈
-- ================================================================

--
-- 逻辑:
--   在取消区域内:
--     停留时间 > 0.15s → 红色提示（确认取消）
--     停留时间 ≤ 0.15s → 白色提示（可能只是路过）
--   不在取消区域: 隐藏提示
--
-- 额外有距离模式的箭头透明度渐变:
--   alpha = (cancelDeltaPositionDistance / c_skillICancleRadius) * 0.8
--   本版本精简为纯显隐 + 颜色切换
function SkillButtonManager:_RefreshCancelUI()
    if not self._cancelTips then return end

    local cancelState = self._cancelDet:GetState()

    if cancelState.isInCancelArea then
        self._cancelTips.Visible = true
        if cancelState.timeInCancelArea > GlobalConfig.CANCEL_AREA_STAY_THRESHOLD then
            -- 停留超过阈值 → 红色（确认取消状态）
            self._cancelTips.ImageColor3 = Color3.fromRGB(255, 60, 60)
        else
            -- 刚进入 → 白色（提示中）
            self._cancelTips.ImageColor3 = Color3.fromRGB(255, 255, 255)
        end
    else
        self._cancelTips.Visible = false
    end
end

-- ================================================================
-- 动态更新按钮中心（可选）
-- ================================================================
-- 如果 UI 布局可能在运行时变化（如横竖屏切换），需要重新计算
function SkillButtonManager:RefreshButtonCenters()
    for slotType, btn in pairs(self._buttons) do
        self._btnCenters[slotType] = Vector2.new(
            btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2,
            btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
        )
    end
end

return SkillButtonManager
```

---

## UI 布局建议

```
ScreenGui "SkillUI"
├── SkillButtonBar (Frame, 右下角)
│   ├── Skill1Button (ImageButton)  ← slotType = 1
│   ├── Skill2Button (ImageButton)  ← slotType = 2
│   ├── Skill3Button (ImageButton)  ← slotType = 3
│   ├── Skill4Button (ImageButton)  ← slotType = 4 (召唤师)
│   └── AttackButton (ImageButton)  ← slotType = 0
│
└── CancelArea (Frame, 屏幕底部居中)
    └── CancelTips (ImageLabel, 红X图标)
```

---

## 初始化示例

```lua
local InputAdapter = require(script.Parent.InputAdapter)
local SkillButtonManager = require(script.Parent.SkillButtonManager)
local SkillController = require(script.Parent.SkillController)
-- ... 其他 require

-- 创建实例
local input = InputAdapter.new()
local cancelDet = CancelAreaDetector.new(skillUI.CancelArea.CancelFrame)
local indicator = SkillIndicator.new({ indicatorRenderer = IndicatorRenderer.new() })
local cache = SkillCacheManager.new({ ... })
local skillCtrl = SkillController.new({
    skillIndicator = indicator,
    cancelAreaDetector = cancelDet,
    skillCacheManager = cache,
})
local atkCtrl = CommonAttackController.new({ skillCacheManager = cache, ... })

local btnMgr = SkillButtonManager.new({
    skillController = skillCtrl,
    commonAttackController = atkCtrl,
    inputAdapter = input,
    cancelAreaDetector = cancelDet,
})

-- 初始化
input:Start()
btnMgr:Init({
    [1] = skillUI.SkillButtonBar.Skill1Button,
    [2] = skillUI.SkillButtonBar.Skill2Button,
    [3] = skillUI.SkillButtonBar.Skill3Button,
    [4] = skillUI.SkillButtonBar.Skill4Button,
    [0] = skillUI.SkillButtonBar.AttackButton,
}, {
    CancelFrame = skillUI.CancelArea,
    CancelTips = skillUI.CancelArea.CancelTips,
})
```
