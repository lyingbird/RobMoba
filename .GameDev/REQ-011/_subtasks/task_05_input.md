# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-05 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | 系统集成（MovementManager扩展 + CameraManager扩展 + Client分支） |
| 执行者 | 程序 Agent |
| 优先级 | 1（最高） |
| Phase | A |
| 预估行数 | ~75行（分布在3个现有文件中） |

## 任务描述
三项增量修改合并为一个集成任务：
1. **MovementManager.lua**: 新增 `SetMoveDirection()` 支持摇杆持续方向移动
2. **CameraManager.lua**: 新增 Lerp 平滑跟随 + `SetMobileMode()`
3. **Client.client.lua**: 新增设备检测 + 移动端初始化分支

## 技术要求
- 修改文件: 
  - `src/StarterPlayer/StarterPlayerScripts/Modules/MovementManager.lua` (+25行)
  - `src/StarterPlayer/StarterPlayerScripts/Modules/CameraManager.lua` (+20行)
  - `src/StarterPlayer/StarterPlayerScripts/Client.client.lua` (+30行)
- **增量修改**: 不改变现有功能，只添加新API和分支
- **向后兼容**: PC端路径保持完全不变

## 输入依赖
- 需要读取: `03_技术设计.md` 第3.2节(MOD-05, CameraManager扩展), 第7节(集成点), 现有3个文件的完整代码
- 依赖的类: `MobileInputManager`, `MobileConfig`

## 输出要求
- 修改文件: 上述3个文件
- 代码规范: 遵循项目编码规范，增量修改不破坏现有功能

## 接口约定

### MovementManager 新增接口
```lua
-- 新增: 设置持续移动方向 (摇杆模式)
function MovementManager.SetMoveDirection(direction: Vector3): ()
-- direction = Vector3.zero 时停止移动
-- 非零时每帧 Humanoid:Move(direction) 持续移动

-- 新增: 获取当前移动模式
function MovementManager.GetMoveMode(): string
-- "PATHFIND" (PC端, 原有) / "DIRECT" (摇杆模式)
```

### CameraManager 新增接口
```lua
-- 新增: 设置移动端模式
function CameraManager.SetMobileMode(enabled: boolean): ()
-- true: 启用 Lerp 平滑 (系数 = CAMERA_SMOOTH_FACTOR)
-- false: 保持原有直接赋值模式

-- 修改: Update() 内部逻辑
-- if mobileMode then
--   Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothFactor)
-- else
--   Camera.CFrame = targetCFrame  -- 原有逻辑
-- end
```

### Client.client.lua 修改
```lua
-- 在英雄选择后的初始化逻辑中添加:
local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

if isMobile then
    -- 移动端路径: 加载移动UI + MobileInputManager
    local UI_VirtualJoystick = require(UIComponents.UI_VirtualJoystick)
    local UI_SkillButtons = require(UIComponents.UI_SkillButtons)
    local UI_MobileHUD = require(UIComponents.UI_MobileHUD)
    local UI_Minimap = require(UIComponents.UI_Minimap)
    local MobileInputManager = require(Modules.MobileInputManager)
    
    -- 初始化...
    CameraManager.SetMobileMode(true)
else
    -- PC端路径: 保持现有 InputManager.Init() 逻辑不变
    InputManager.Init(character, ...)
end
```

## 核心逻辑要点

### MovementManager.lua 改造
```
现有: StopMovement() / MoveToPosition(pos) / ShowClickEffect(pos)
新增: 
  - 模块顶部新增 local moveDirection = Vector3.zero
  - 模块顶部新增 local moveMode = "PATHFIND"
  - SetMoveDirection(dir): moveDirection = dir, moveMode = "DIRECT"
  - 在 Init() 中连接 RunService.RenderStepped:
    if moveMode == "DIRECT" and moveDirection ~= Vector3.zero then
      humanoid:Move(moveDirection)
    end
```

### CameraManager.lua 改造
```
现有: Camera.CFrame = CFrame.new(pos + CAMERA_OFFSET, pos) (直接赋值)
新增:
  - 模块顶部新增 local mobileMode = false
  - 模块顶部新增 local SMOOTH_FACTOR = MobileConfig.CAMERA_SMOOTH_FACTOR
  - SetMobileMode(enabled): mobileMode = enabled
  - Update() 修改:
    local targetCFrame = CFrame.new(pos + CAMERA_OFFSET, pos)
    if mobileMode then
      camera.CFrame = camera.CFrame:Lerp(targetCFrame, SMOOTH_FACTOR)
    else
      camera.CFrame = targetCFrame  -- 原逻辑
    end
```

## 与其他模块的关系
- 被依赖: 最终集成点，所有 MOD 在此汇聚
- 依赖: MobileInputManager, UI_VirtualJoystick, UI_SkillButtons, UI_MobileHUD, UI_Minimap, MobileConfig
