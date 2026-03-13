# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-005 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | UI_HeroSelect 左下角面板 |
| 执行者 | 程序 Agent |
| 优先级 | 2 |

## 任务描述
将 UI_HeroSelect 从全屏弹窗改造为左下角常驻小面板：
1. 常驻小面板: 当前英雄头像(ViewportFrame) + 英雄名 + "切换▼"按钮
2. 点击切换 → 展开英雄列表 (5英雄横排/竖排选择)
3. 选择英雄 → 发送 HeroSwapEvent → 收到确认 → 更新面板
4. 首次进入时自动展开列表
5. MATCHING/DUELING 状态下灰化不可操作

## 技术要求
- 重写文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_HeroSelect.lua`
- 目标行数: ~200行 (从当前~443行精简)

## 输入依赖
- 需要读取: 当前 `UI_HeroSelect.lua` (参考英雄卡片创建逻辑)
- 需要读取: `src/ReplicatedStorage/HeroConfig.lua` (英雄数据)
- 依赖的事件: HeroSwapEvent (由T1创建, T2处理)

## 输出要求
- 重写文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_HeroSelect.lua`

## 接口约定
```lua
local UI_HeroSelect = {}

-- 显示左下角常驻面板 (进入大厅后调用)
function UI_HeroSelect.ShowPanel()
-- 首次调用自动展开英雄列表

-- 设置当前英雄 (收到HeroSwapEvent确认后调用)
function UI_HeroSelect.SetCurrentHero(heroId)

-- 锁定/解锁面板 (匹配/对决时锁定)
function UI_HeroSelect.SetLocked(locked)

-- 获取当前选中英雄ID
function UI_HeroSelect.GetCurrentHero() --> heroId or nil

-- 隐藏面板
function UI_HeroSelect.HidePanel()

return UI_HeroSelect
```

## UI 布局
```
左下角 (AnchorPoint 0,1 | Position 0,10,1,-10):
┌──────────────┐
│  [头像]  后羿 │
│  [切换▼]     │
└──────────────┘

展开时:
┌──────────────┐
│ [拉克丝][安琪拉][后羿][廉颇][Test] │  ← 英雄列表
├──────────────┤
│  [头像]  后羿 │
│  [切换▼]     │
└──────────────┘
```

## 与其他模块的关系
- 被依赖: T4(Client调用ShowPanel/SetCurrentHero)
- 依赖: T1(HeroSwapEvent), HeroConfig
