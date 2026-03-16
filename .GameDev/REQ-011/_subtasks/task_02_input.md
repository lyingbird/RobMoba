# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-02 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | UI_VirtualJoystick 虚拟摇杆系统 |
| 执行者 | 程序 Agent |
| 优先级 | 1（最高） |
| Phase | A |
| 预估行数 | ~200行 |

## 任务描述
实现虚拟摇杆 UI 模块。左半屏触摸时在触摸点显示摇杆(外圈+摇杆球)，拖拽输出方向向量，松手淡出。支持死区、钳位、速度分级。

## 技术要求
- 文件路径: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_VirtualJoystick.lua`
- 类型: ModuleScript
- 使用 `GuiObject.InputBegan/InputChanged/InputEnded` 追踪触摸（非全局 UserInputService，避免与技能按钮冲突）
- 使用 TweenService 实现淡出动画
- UI层级: ZIndex = 10

## 输入依赖
- 需要读取: `03_技术设计.md` 第3.2节(MOD-01设计), 第4.1节(接口), `02_UX设计.md` 第2.3节(摇杆设计)
- 依赖的类: `MobileConfig` (读取常量)

## 输出要求
- 产出文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_VirtualJoystick.lua`
- 代码规范: 遵循项目编码规范

## 接口约定
```lua
local UI_VirtualJoystick = {}

function UI_VirtualJoystick.Init(parentFrame: Frame): ()
-- 创建触摸捕获层(左半屏透明Frame) + 摇杆UI元素(外圈+球)
-- 绑定 InputBegan/InputChanged/InputEnded

function UI_VirtualJoystick.GetDirection(): Vector2
-- 返回当前方向(归一化), 无输入时返回 Vector2.zero

function UI_VirtualJoystick.GetMagnitude(): number
-- 返回0~1力度

function UI_VirtualJoystick.SetEnabled(enabled: boolean): ()
-- 禁用时隐藏并忽略输入

function UI_VirtualJoystick.OnDirectionChanged(callback: (Vector2, number) -> ()): ()
-- 注册回调，方向/力度变更时调用

function UI_VirtualJoystick.Destroy(): ()

return UI_VirtualJoystick
```

### 核心逻辑要点
1. **触摸区域**: 左半屏 Frame (Size=UDim2.new(0.5,0,0.5,0), Position从左下角), BackgroundTransparency=1
2. **摇杆出现**: InputBegan → 在 input.Position 处创建/移动摇杆UI
3. **方向计算**: offset = input.Position - centerPos, 归一化, 钳位到 MAX_RADIUS
4. **死区判断**: if magnitude < DEADZONE then direction = Vector2.zero
5. **速度分级**: magnitude < WALK_THRESHOLD → 50%速度
6. **淡出**: InputEnded → TweenService alpha→0 (FADE_TIME秒)
7. **触摸ID追踪**: 记住激活摇杆的 InputObject, 只响应该ID的后续事件

## 与其他模块的关系
- 被依赖: MobileInputManager (读取方向驱动移动)
- 依赖: MobileConfig (常量)
