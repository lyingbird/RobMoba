# 04 — 输入适配层 InputAdapter

> **文件路径**: `StarterPlayerScripts/SkillSystem/InputAdapter.lua`

---

## 设计说明

使用 Unity 的 `EventTrigger` 组件在 UI 元素上监听 Pointer 事件。Roblox 没有对等组件，需要用 `UserInputService` + `GuiButton.InputBegan` 组合实现。

**核心职责**: 追踪同一根手指（或鼠标按下）从 Down → Drag → Up 的完整生命周期，屏蔽平台差异。

### → Roblox 映射

| (Unity) | Roblox | 说明 |
|---|---|---|
| `OnPointerDown` (EventTrigger) | `GuiButton.InputBegan` | 按钮级别拦截 |
| `OnDrag` (EventTrigger) | `UserInputService.InputChanged` | 全局追踪 |
| `OnPointerUp` (EventTrigger) | `UserInputService.InputEnded` | 全局追踪 |
| `eventData.pointerId` | `InputObject` 引用相等性 | 追踪同一手指 |

---

## 完整实现

```lua
-- 文件: StarterPlayerScripts/SkillSystem/InputAdapter.lua
--
-- 使用方式:
--   1. SkillButtonManager 在按钮 InputBegan 事件中调用 adapter:BeginTracking(inputObject)
--   2. InputAdapter 自动追踪该 InputObject 的 Changed/Ended
--   3. 通过回调 onInputBegan/onInputChanged/onInputEnded 通知上层
--
-- 为什么不直接在按钮上监听 Drag?
--   Roblox 的 GuiButton 只有 InputBegan，没有 InputChanged/InputEnded。
--   手指按下按钮后移出按钮范围仍需持续追踪，所以用 UIS 全局监听。
--   通过 InputObject 引用相等来确保追踪的是同一根手指。

local UserInputService = game:GetService("UserInputService")

local InputAdapter = {}
InputAdapter.__index = InputAdapter

function InputAdapter.new()
    local self = setmetatable({}, InputAdapter)

    -- ==================== 回调（由 SkillButtonManager 设置）====================
    self.onInputBegan   = nil  -- function(screenPos: Vector2)
    self.onInputChanged = nil  -- function(screenPos: Vector2)
    self.onInputEnded   = nil  -- function(screenPos: Vector2)

    -- ==================== 内部状态 ====================
    self._activeInput = nil    -- 当前追踪的 InputObject 引用
    self._connections = {}     -- RBXScriptConnection 数组

    return self
end

-- Start: 注册全局输入监听
-- 必须在游戏开始时调用一次
function InputAdapter:Start()
    -- 追踪 InputChanged（手指/鼠标移动）
    local changedConn = UserInputService.InputChanged:Connect(function(inputObject, gameProcessed)
        -- 只处理我们正在追踪的那个 InputObject
        if inputObject ~= self._activeInput then return end

        -- 过滤输入类型: Touch 移动 或 鼠标移动
        if inputObject.UserInputType == Enum.UserInputType.Touch
            or inputObject.UserInputType == Enum.UserInputType.MouseMovement then
            if self.onInputChanged then
                self.onInputChanged(Vector2.new(
                    inputObject.Position.X,
                    inputObject.Position.Y
                ))
            end
        end
    end)
    table.insert(self._connections, changedConn)

    -- 追踪 InputEnded（手指抬起/鼠标松开）
    local endedConn = UserInputService.InputEnded:Connect(function(inputObject, gameProcessed)
        if inputObject ~= self._activeInput then return end

        -- 清除追踪
        self._activeInput = nil

        if self.onInputEnded then
            self.onInputEnded(Vector2.new(
                inputObject.Position.X,
                inputObject.Position.Y
            ))
        end
    end)
    table.insert(self._connections, endedConn)
end

-- BeginTracking: 开始追踪指定的 InputObject
-- 由 SkillButtonManager 在按钮 InputBegan 时调用
--
-- 关键: 通过保存 InputObject 引用，后续 Changed/Ended 中用 == 比较
-- 确保多指触摸时只追踪按下技能按钮的那根手指
function InputAdapter:BeginTracking(inputObject: InputObject)
    self._activeInput = inputObject
    if self.onInputBegan then
        self.onInputBegan(Vector2.new(
            inputObject.Position.X,
            inputObject.Position.Y
        ))
    end
end

-- IsTracking: 当前是否在追踪
function InputAdapter:IsTracking(): boolean
    return self._activeInput ~= nil
end

-- CancelTracking: 强制取消追踪（如被打断）
function InputAdapter:CancelTracking()
    self._activeInput = nil
end

-- Destroy: 清理所有连接
function InputAdapter:Destroy()
    for _, conn in ipairs(self._connections) do
        conn:Disconnect()
    end
    self._connections = {}
    self._activeInput = nil
end

return InputAdapter
```

---

## 调用时序图

```
用户按下技能按钮
  │
  ▼
GuiButton.InputBegan 触发
  │
  ├─ SkillButtonManager 收到事件
  │   └─ 调用 inputAdapter:BeginTracking(inputObject)
  │       └─ 保存 _activeInput = inputObject
  │       └─ 触发 onInputBegan(screenPos)
  │
  ▼
用户拖动手指
  │
  ▼
UserInputService.InputChanged 触发（全局）
  │
  ├─ inputObject == _activeInput ?
  │   ├─ YES → 触发 onInputChanged(screenPos)
  │   └─ NO  → 忽略
  │
  ▼
用户抬起手指
  │
  ▼
UserInputService.InputEnded 触发（全局）
  │
  ├─ inputObject == _activeInput ?
  │   ├─ YES → _activeInput = nil → 触发 onInputEnded(screenPos)
  │   └─ NO  → 忽略
```

---

## 注意事项

1. **多指触摸安全**: 通过 InputObject 引用比较而非 InputType 判断，天然支持多指场景
2. **手指移出按钮**: 因为用 UIS 全局监听，手指从按钮滑出后仍能持续追踪
3. **gameProcessed 参数**: 这里不检查 `gameProcessed`，因为技能按钮的输入由我们自己管理
4. **InputType 过滤**: Changed 只处理 Touch + MouseMovement，排除键盘等无关输入
