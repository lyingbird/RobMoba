---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：移动与输入系统 (Input & Movement)

> **领域**: domain-movement
> **适用Agent**: 程序 / 主程 / UX
> **加载时机**: 涉及角色移动、摇杆、输入管理、摄像机、设备适配时
> **大小**: ~4KB

## 📌 双端输入架构

```
┌─ PC端 ─────────────────────────────┐  ┌─ 移动端 ──────────────────────────┐
│ InputManager.lua                    │  │ MobileInputManager.lua            │
│  ├─ 键鼠: WASD→移动, 鼠标→技能瞄准 │  │  ├─ UI_VirtualJoystick→移动       │
│  ├─ Q/W/R/D/F→技能释放             │  │  ├─ UI_SkillButtons→技能释放      │
│  └─ 右键→普攻目标                  │  │  └─ 统一接口→MovementManager      │
└────────────────────────────────────┘  └────────────────────────────────────┘
                     ↓                                    ↓
              MovementManager.lua (统一移动驱动)
              ├─ PATHFIND模式: Humanoid:MoveTo (PC点击)
              └─ DIRECT模式: RenderStepped HumanoidRootPart.CFrame (移动端)
                     ↓
              CameraManager.lua (跟随 + 移动端Lerp平滑)
```

## 📌 设备检测与分支

**位置**: `Client.client.lua` 入口

```lua
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if isMobile then
    -- 移动端: MobileUI + VirtualJoystick + SkillButtons + MobileHUD + Minimap
    -- LandscapeSensor 强制横屏 (REQ-020)
else
    -- PC端: InputManager 键鼠操控
end
```

## 📌 移动端输入系统

### MobileInputManager (适配层)
| 属性/方法 | 说明 |
|-----------|------|
| `enabled` | 默认 false, SetEnabled(true)后才处理输入 |
| `Init(character, modules)` | 初始化, 绑定摇杆/技能按钮回调 |
| `SetEnabled(bool)` | 启用/禁用, 传播到摇杆+技能按钮 |
| `Destroy()` | 清理连接 |

**REQ-022**: `screenToWorldDirection()` 基于摄像机 CFrame.LookVector 做2D→3D坐标变换，摇杆方向始终对应屏幕视觉方向（投影到XZ平面，不依赖世界轴对齐）

**关键文件**: `src/StarterPlayer/StarterPlayerScripts/Modules/MobileInputManager.lua`

### UI_VirtualJoystick (虚拟摇杆)
| API | 说明 |
|-----|------|
| `Init(parentFrame)` | 创建摇杆UI(左半屏触摸区) |
| `OnDirectionChanged(callback)` | 注册方向变化回调(Vector3) |
| `SetEnabled(bool)` | 启用/禁用触摸响应 |
| `SetLobbyMode(bool)` | 大厅模式(锁定位置, 半透明) |
| `GetDirection()` / `GetMagnitude()` | 当前方向和力度 |

**关键文件**: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_VirtualJoystick.lua`

### UI_SkillButtons (技能按钮)
| API | 说明 |
|-----|------|
| `Init(parentFrame, skillSlots)` | 创建弧形技能按钮(Q/W/R/D/F/AA) |
| `OnSkillCast(callback)` | 注册技能释放回调 |
| `SetEnabled(bool)` | 启用/禁用所有按钮 |
| `SetSkillState(slotKey, state)` | 单按钮状态(ready/cooldown/locked/disabled) |
| `UpdateCooldown(slotKey, remaining, total)` | CD扇形遮罩更新 |

**关键文件**: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_SkillButtons.lua`

### MobileConfig (集中配置)
**文件**: `src/StarterPlayer/StarterPlayerScripts/Modules/MobileConfig.lua`
- 摇杆尺寸/位置/颜色/透明度
- 技能按钮弧形布局参数
- HUD布局参数
- SafeArea边距
- 大厅模式特有参数

## 📌 MovementManager (移动驱动层)
| API | 说明 |
|-----|------|
| `SetMoveDirection(direction: Vector3)` | 移动端DIRECT模式驱动 |
| `GetMoveMode()` | "PATHFIND" / "DIRECT" |
| `MoveToPosition(pos)` | PC端点击移动 |
| `StopMoving()` | 停止移动 |

**REQ-022**: `Humanoid:Move(dir, false)` — 使用世界绝对坐标，方向已由 MobileInputManager 做摄像机变换

**关键文件**: `src/StarterPlayer/StarterPlayerScripts/Modules/MovementManager.lua`

## 📌 CameraManager (摄像机)
- PC端: 固定俯视角, 鼠标边缘滚动
- 移动端: 锁定跟随, Lerp平滑, `SetMobileMode(true/false)`
- **关键文件**: `src/StarterPlayer/StarterPlayerScripts/Modules/CameraManager.lua`

## 📌 已知问题
- ~~**Bug A**: 英雄选择面板打开时摇杆仍可移动角色~~ ✅ REQ-021 已修复 (OnVisibilityChanged→SetEnabled(false))
- ~~**Bug B**: 确认英雄后摇杆失灵~~ ✅ REQ-021 已修复 (MIM.Init末尾SetEnabled(true))
- **REQ-021 新增API**: `UI_HeroSelect.OnVisibilityChanged(callback)` — 面板显示/隐藏通知
- **REQ-021 新增配置**: `MobileConfig.JOYSTICK_DISABLED_ALPHA = 0.3` — 摇杆禁用态透明度
- **已知限制**: 对决结束后 MIM.SetEnabled(false) 禁用摇杆，回到训练场需要额外恢复逻辑（超出REQ-021范围）

## 🔗 关联模块
- [UI组件系统](../domain-ui/ui-components.md)
- [Roblox UI模式](../roblox/ui-patterns.md)
- [通信协议](../domain-networking/networking.md)
