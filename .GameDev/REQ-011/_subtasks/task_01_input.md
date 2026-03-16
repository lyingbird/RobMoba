# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-01 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | MobileConfig 配置常量模块 |
| 执行者 | 程序 Agent |
| 优先级 | 1（最高） |
| Phase | A |
| 预估行数 | ~50行 |

## 任务描述
创建移动端所有可调参数的集中配置模块 `MobileConfig.lua`。这是所有移动端模块的基础依赖，必须首先完成。

## 技术要求
- 文件路径: `src/StarterPlayer/StarterPlayerScripts/Modules/MobileConfig.lua`
- 类型: ModuleScript (返回 table)
- 所有常量使用 UPPER_SNAKE_CASE 命名

## 输入依赖
- 需要读取: `03_技术设计.md` 第4.2节"配置常量"
- 依赖的类: 无

## 输出要求
- 产出文件: `src/StarterPlayer/StarterPlayerScripts/Modules/MobileConfig.lua`
- 代码规范: 遵循项目编码规范（camelCase局部变量, UPPER_SNAKE常量）

## 接口约定
```lua
-- MobileConfig.lua
local MobileConfig = {
    -- 摇杆参数
    JOYSTICK_MAX_RADIUS = 60,
    JOYSTICK_DEADZONE = 0.15,
    JOYSTICK_FADE_TIME = 0.3,
    JOYSTICK_WALK_THRESHOLD = 0.4,
    JOYSTICK_OUTER_SIZE = 0.25,      -- 外圈直径(屏高比)
    JOYSTICK_INNER_SIZE = 0.10,      -- 摇杆球直径(屏高比)
    JOYSTICK_OUTER_ALPHA = 0.4,
    JOYSTICK_INNER_ALPHA = 0.8,

    -- 技能按钮参数
    SKILL_BTN_NORMAL = 0.11,
    SKILL_BTN_ATTACK = 0.14,
    SKILL_BTN_SUMM = 0.08,
    AIM_CANCEL_THRESHOLD = 0.3,
    CD_DISPLAY_DECIMAL = 1,

    -- 按钮位置(UDim2参考值, 来自UX设计)
    BTN_POSITIONS = {
        Attack = UDim2.new(0.94, 0, 0.92, 0),
        R = UDim2.new(0.88, 0, 0.78, 0),
        W = UDim2.new(0.82, 0, 0.67, 0),
        Q = UDim2.new(0.75, 0, 0.78, 0),
        D = UDim2.new(0.70, 0, 0.85, 0),
        F = UDim2.new(0.70, 0, 0.93, 0),
    },

    -- 摄像机
    CAMERA_SMOOTH_FACTOR = 0.15,
    CAMERA_MOBILE_DEPTH = 25,

    -- 小地图
    MINIMAP_SIZE = 0.18,
    MINIMAP_UPDATE_INTERVAL = 0.5,

    -- HUD
    KILL_NOTIFY_DURATION = 2.0,
    KILL_NOTIFY_MAX_STACK = 2,

    -- 普攻索敌
    AUTO_ATTACK_RANGE = 20,
}

return MobileConfig
```

## 与其他模块的关系
- 被依赖: UI_VirtualJoystick, UI_SkillButtons, MobileInputManager, UI_MobileHUD, UI_Minimap, CameraManager扩展
- 依赖: 无（基础模块）
