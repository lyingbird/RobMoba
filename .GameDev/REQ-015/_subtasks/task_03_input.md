# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-03 |
| 父需求 | REQ-015 移动端UI布局重设计 |
| 子任务名称 | 虚拟摇杆大厅模式 |
| 执行者 | 程序 Agent |
| 优先级 | 1 |

## 任务描述
为 `UI_VirtualJoystick.lua` 新增大厅模式支持:

1. **新增 `SetLobbyMode(lobby)` API**:
   - `lobby=true`: 在默认位置(MobileConfig.JOYSTICK_DEFAULT_X/Y)显示静态摇杆，低透明度(LOBBY_OUTER/INNER_ALPHA)，不响应触摸输入
   - `lobby=false`: 恢复正常操控模式(现有逻辑不变)

2. **新增默认位置显示**:
   - 大厅模式下摇杆始终在 (15%, 75%) 位置显示外圈和球
   - 不需要触摸激活，直接可见
   - 透明度: 外圈 0.2, 球 0.3

3. **状态变量**:
   - 新增 `local lobbyMode = false` 内部状态
   - `SetLobbyMode(true)` 时: 设置 enabled=false, 显示在默认位置, 设置低透明度
   - `SetLobbyMode(false)` 时: 设置 enabled=true, 恢复正常操控逻辑

## 技术要求
- 文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_VirtualJoystick.lua`
- 不改动现有触摸处理逻辑
- 仅新增 SetLobbyMode 函数和相关状态管理

## 输入依赖
- TASK-01 MobileConfig (JOYSTICK_DEFAULT_X/Y, LOBBY_OUTER/INNER_ALPHA)

## 输出要求
- 修改文件: `UI_VirtualJoystick.lua`
- 新增约40行

## 接口约定
```lua
function UI_VirtualJoystick.SetLobbyMode(lobby: boolean)
-- lobby=true: 静态指示模式(大厅), 不响应输入
-- lobby=false: 正常操控模式(战斗)
```

## 与其他模块的关系
- 被依赖: TASK-02 (Client.client.lua 调用 SetLobbyMode)
- 依赖: TASK-01 (MobileConfig 参数)
