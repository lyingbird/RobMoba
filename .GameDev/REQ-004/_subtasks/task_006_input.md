# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-006 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | UI_MatchButton 右下角匹配按钮 |
| 执行者 | 程序 Agent |
| 优先级 | 2 |

## 任务描述
创建右下角常驻匹配按钮模块：
1. 默认状态: "⚔️ 开始匹配" (蓝色)
2. 点击 → FireServer MatchmakingEvent {action="join"}
3. 匹配中: "❌ 取消匹配 (1/2)" (红色)，点击取消
4. 匹配成功: "对手已找到！" (金色)，不可点击
5. 对决中: 隐藏按钮
6. 监听 MatchmakingEvent 更新状态

## 技术要求
- 新建文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_MatchButton.lua`
- 预估行数: ~120行

## 输入依赖
- 依赖的事件: MatchmakingEvent (由T1创建, T2处理)

## 输出要求
- 产出文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_MatchButton.lua`

## 接口约定
```lua
local UI_MatchButton = {}

-- 初始化并显示匹配按钮
function UI_MatchButton.Init()

-- 设置按钮状态
function UI_MatchButton.SetState(state)
-- state: "idle" | "matching" | "matched" | "hidden"

-- 更新队列信息
function UI_MatchButton.UpdateQueueInfo(queueSize)

-- 隐藏/显示
function UI_MatchButton.SetVisible(visible)

return UI_MatchButton
```

## UI 布局
```
右下角 (AnchorPoint 1,1 | Position 1,-10,1,-80):
┌────────────────┐
│  ⚔️ 开始匹配   │  ← idle (蓝色背景)
└────────────────┘

匹配中:
┌────────────────┐
│ ❌ 取消匹配 1/2 │  ← matching (红色背景)
└────────────────┘
```

## 与其他模块的关系
- 被依赖: T4(Client初始化), UIManager(转发)
- 依赖: T1(MatchmakingEvent)
