# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-04 |
| 父需求 | REQ-015 移动端UI布局重设计 |
| 子任务名称 | 技能按钮锁定态+弧形参数+UpdateSkills |
| 执行者 | 程序 Agent |
| 优先级 | 1 |

## 任务描述
为 `UI_SkillButtons.lua` 新增:

1. **Init(parent, nil) 锁定态**:
   - 当 `skillSlots` 参数为 nil 时，创建锁定态按钮
   - 锁定态视觉: 深灰背景(0.7) + "?" 文字 + 暗灰边框
   - 按钮位置使用 MobileConfig 弧形参数计算
   - 锁定态不响应触摸输入

2. **新增 `UpdateSkills(skillSlots)` API**:
   - 选完英雄后调用，将锁定态按钮更新为实际技能图标
   - 参数格式: `{ Q={skillId=1006, aimType="directional"}, ... }`
   - 更新每个按钮的图标、aimType、状态(Idle)
   - 激活触摸输入响应

3. **弧形布局参数从MobileConfig读取**:
   - 当前 BTN_POSITIONS 是固定坐标
   - 新增弧形计算: 以 ATK 按钮为中心，半径=ATK直径×ARC_RADIUS_RATIO，角度=ARC_START_ANGLE/ARC_STEP_ANGLE
   - 保留 BTN_POSITIONS 作为 fallback (如果弧形参数无效则使用固定位置)

## 技术要求
- 文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_SkillButtons.lua`
- 现有触摸处理、CD动画、方向轮盘逻辑不变
- 锁定态通过现有按钮状态系统扩展

## 输入依赖
- TASK-01 MobileConfig (ARC_RADIUS_RATIO, ARC_START_ANGLE, ARC_STEP_ANGLE)

## 输出要求
- 修改文件: `UI_SkillButtons.lua`
- 新增约50行

## 接口约定
```lua
-- 更新技能槽(从锁定态→正常态)
function UI_SkillButtons.UpdateSkills(skillSlots: {[string]: {skillId: number, aimType: string}}?)

-- Init 行为变更:
-- Init(parent, nil) → 锁定态(大厅用)
-- Init(parent, skillSlots) → 正常态(不变)
```

## 与其他模块的关系
- 被依赖: TASK-02 (Client.client.lua 调用 Init(nil) 和 UpdateSkills)
- 依赖: TASK-01 (MobileConfig 弧形参数)
