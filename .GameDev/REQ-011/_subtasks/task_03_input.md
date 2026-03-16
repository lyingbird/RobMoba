# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-03 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | UI_SkillButtons 技能按钮与方向轮盘 |
| 执行者 | 程序 Agent |
| 优先级 | 1（最高） |
| Phase | A |
| 预估行数 | ~350行 |

## 任务描述
实现技能按钮面板（Q/W/R/普攻/D/F 弧形布局）和方向轮盘瞄准系统。按住指向性技能→显示方向轮盘→拖拽→松手释放或取消。包含8种按钮状态管理和CD扇形遮罩。

## 技术要求
- 文件路径: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_SkillButtons.lua`
- 类型: ModuleScript
- 每个按钮使用独立 `ImageButton` + `InputBegan/InputChanged/InputEnded` 追踪独立触摸点
- CD遮罩: 使用旋转的半圆 Frame 或 ImageLabel.Rotation 模拟扇形消退
- 方向轮盘: 旋转 Frame(细线) + 箭头 ImageLabel
- UI层级: 按钮 ZIndex=10, 方向轮盘 ZIndex=15

## 输入依赖
- 需要读取: `03_技术设计.md` 第3.2节(MOD-02), 第4.1节(接口), `02_UX设计.md` 第2.4-2.5节
- 依赖的类: `MobileConfig`(常量), `SkillRegistry`(技能配置), `CooldownManager`(CD查询)

## 输出要求
- 产出文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_SkillButtons.lua`
- 代码规范: 遵循项目编码规范

## 接口约定
```lua
local UI_SkillButtons = {}

function UI_SkillButtons.Init(parentFrame: Frame, skillSlots: table): ()
-- skillSlots格式: { Q={skillId=1001, aimType="directional"}, W={...}, R={...}, D={...}, F={...} }
-- 创建6个圆形按钮(弧形布局) + 普攻按钮

function UI_SkillButtons.SetSkillState(slotKey: string, state: string): ()
-- state: "Idle"/"Pressed"/"Aiming"/"Cooldown"/"Ready"/"NoMana"/"Disabled"/"Dead"

function UI_SkillButtons.UpdateCooldown(slotKey: string, remaining: number, total: number): ()
-- 更新CD扇形遮罩角度 + 秒数文字

function UI_SkillButtons.SetEnabled(enabled: boolean): ()

function UI_SkillButtons.OnSkillCast(callback: (number, Vector3?) -> ()): ()
-- 技能释放回调: (skillId, worldDirection or nil)

function UI_SkillButtons.OnAttackPressed(callback: () -> ()): ()

function UI_SkillButtons.Destroy(): ()

return UI_SkillButtons
```

### 核心逻辑要点
1. **弧形布局**: 6个按钮按UX设计的UDim2坐标定位(见MobileConfig.BTN_POSITIONS)
2. **触摸独立追踪**: 每个按钮 InputBegan 记录 touchId, 只响应该 touchId 的后续事件
3. **aimType 分支**: 
   - directional/area → 进入AIMING, 显示方向轮盘
   - self/channel/none → 直接触发 OnSkillCast(skillId, nil)
4. **方向轮盘**: 
   - 以按钮中心为原点, 计算手指偏移角度 → atan2(dy, dx)
   - 旋转方向指示线到该角度
   - 偏移 < AIM_CANCEL_THRESHOLD * buttonRadius → 显示取消标记
5. **取消逻辑**: 松手时判断是否在取消区, 是则不触发OnSkillCast
6. **方向→世界坐标**: 2D屏幕角度 → 3D世界方向(固定摄像机, X→WorldX, Y→WorldZ)
7. **CD扇形遮罩**: 两个半圆Frame旋转实现顺时针消退效果, RenderStepped更新Rotation
8. **8种状态**: 通过修改按钮颜色/透明度/覆盖层切换

## 与其他模块的关系
- 被依赖: MobileInputManager (读取技能释放/普攻事件)
- 依赖: MobileConfig(常量), SkillRegistry(技能aimType), CooldownManager(CD数据)
