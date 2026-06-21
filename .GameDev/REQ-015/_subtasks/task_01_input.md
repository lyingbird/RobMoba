# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-01 |
| 父需求 | REQ-015 移动端UI布局重设计 |
| 子任务名称 | MobileConfig参数扩展 |
| 执行者 | 程序 Agent |
| 优先级 | 1(最高) |

## 任务描述
在 `MobileConfig.lua` 中新增 REQ-015 所需的布局参数，包括：
1. 摇杆默认位置参数(大厅显示用)
2. 大厅模式透明度参数
3. 弧形布局参数(弧形半径/起始角/步进角)
4. SafeArea安全区参数
5. 大厅功能按钮位置/大小参数

## 技术要求
- 文件: `src/StarterPlayer/StarterPlayerScripts/Modules/MobileConfig.lua`
- 在现有参数区块后添加新的 REQ-015 参数区块
- 使用 `-- ═══ REQ-015: ... ═══` 注释分隔

## 输入依赖
- 无（基础任务）

## 输出要求
- 修改文件: `MobileConfig.lua`
- 新增约30行参数定义

## 接口约定
```lua
-- 新增参数列表:
MobileConfig.JOYSTICK_DEFAULT_X = 0.15
MobileConfig.JOYSTICK_DEFAULT_Y = 0.75
MobileConfig.JOYSTICK_LOBBY_OUTER_ALPHA = 0.2
MobileConfig.JOYSTICK_LOBBY_INNER_ALPHA = 0.3
MobileConfig.SKILL_ARC_RADIUS_RATIO = 1.3
MobileConfig.SKILL_ARC_START_ANGLE = 135
MobileConfig.SKILL_ARC_STEP_ANGLE = 30
MobileConfig.SAFE_AREA_TOP = 36
MobileConfig.SAFE_AREA_BOTTOM = 34
MobileConfig.SAFE_AREA_SIDES = 44
MobileConfig.LOBBY_TRAIN_BTN_POS = { X = 0.05, Y = 0.08 }
MobileConfig.LOBBY_MATCH_BTN_POS = { X = 0.95, Y = 0.08 }
MobileConfig.LOBBY_BTN_SIZE = { W = 0.12, H = 0.06 }
MobileConfig.MINIMAP_POS_X = 0.02
MobileConfig.MINIMAP_POS_Y = 0.15
```

## 与其他模块的关系
- 被依赖: TASK-02(Client), TASK-03(Joystick), TASK-04(SkillButtons), TASK-05(HUD/Minimap)
- 依赖: 无
