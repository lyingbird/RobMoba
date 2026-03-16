# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-04 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | MobileInputManager 输入系统适配层 |
| 执行者 | 程序 Agent |
| 优先级 | 1（最高） |
| Phase | A |
| 预估行数 | ~250行 |

## 任务描述
实现移动端输入管理器，替代 PC 端 InputManager 的角色。汇总摇杆方向、技能释放、普攻请求，转换为游戏逻辑调用（MovementManager移动、RemoteEvent技能释放、自动索敌普攻）。

## 技术要求
- 文件路径: `src/StarterPlayer/StarterPlayerScripts/Modules/MobileInputManager.lua`
- 类型: ModuleScript
- 状态机: IDLE → AIMING → CASTING → IDLE / IDLE → ATTACK_AIMING → IDLE
- 摇杆方向→世界方向转换: 固定摄像机朝-Z方向, 摇杆X→世界X, 摇杆Y→世界-Z
- 自动索敌: 客户端侧距离查找最近敌人（不依赖服务端CombatUtils）

## 输入依赖
- 需要读取: `03_技术设计.md` 第3.2节(MOD-04), 第3.3节(关键流程), 第4.1节(接口)
- 依赖的类: `UI_VirtualJoystick`(方向输入), `UI_SkillButtons`(技能/普攻输入), `MovementManager`(移动驱动), `CooldownManager`, `SkillRegistry`, `MobileConfig`

## 输出要求
- 产出文件: `src/StarterPlayer/StarterPlayerScripts/Modules/MobileInputManager.lua`
- 代码规范: 遵循项目编码规范

## 接口约定
```lua
local MobileInputManager = {}

function MobileInputManager.Init(character: Model, modules: table): ()
-- modules: { MovementManager, CooldownManager, CameraManager, UI_VirtualJoystick, UI_SkillButtons, ... }
-- 1. 关联 UI_VirtualJoystick 的 OnDirectionChanged 回调
-- 2. 关联 UI_SkillButtons 的 OnSkillCast/OnAttackPressed 回调
-- 3. 获取 RemoteEvent 引用(CastSkillEvent, SkillDirectionEvent, AttackTargetEvent)
-- 4. 状态初始化为 IDLE

function MobileInputManager.SetEnabled(enabled: boolean): ()
-- true: 启用所有输入 (对决开始/复活)
-- false: 禁用所有输入 (对决结束/死亡/被控)
-- 同步调用 UI_VirtualJoystick.SetEnabled() 和 UI_SkillButtons.SetEnabled()

function MobileInputManager.GetState(): string
-- 返回 "IDLE"/"AIMING"/"CASTING"/"ATTACK_AIMING"

function MobileInputManager.Destroy(): ()

return MobileInputManager
```

### 核心逻辑要点
1. **摇杆→移动管线**:
   ```
   OnDirectionChanged(screenDir, magnitude) 
   → worldDir = _screenToWorldDirection(screenDir)
   → speed = magnitude < WALK_THRESHOLD ? 0.5 : 1.0
   → MovementManager.SetMoveDirection(worldDir * speed)
   ```
2. **屏幕→世界方向转换**:
   ```
   固定摄像机朝-Z: worldDir = Vector3.new(screenDir.X, 0, -screenDir.Y).Unit
   ```
3. **技能释放管线**:
   ```
   OnSkillCast(skillId, direction)
   → if direction then SkillDirectionEvent:FireServer(direction) end
   → CastSkillEvent:FireServer(skillId, direction or Vector3.zero)
   ```
4. **普攻管线**:
   ```
   OnAttackPressed()
   → target = _getNearestEnemy()
   → if target then AttackTargetEvent:FireServer(target) end
   ```
5. **自动索敌 _getNearestEnemy()**:
   ```
   遍历 workspace 中非己方角色
   → 计算距离 → 取射程内(AUTO_ATTACK_RANGE)最近的
   → 返回 Model 或 nil
   ```

## 与其他模块的关系
- 被依赖: Client.client.lua (初始化调用)
- 依赖: UI_VirtualJoystick(方向), UI_SkillButtons(技能/普攻), MovementManager(移动), MobileConfig(常量), RemoteEvent(CastSkill/SkillDirection/AttackTarget)
