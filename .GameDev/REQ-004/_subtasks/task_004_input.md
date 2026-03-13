# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-004 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | Client.client.lua 重写 |
| 执行者 | 程序 Agent |
| 优先级 | 2 |

## 任务描述
将 Client.client.lua 从 PvP 状态机模式重写为大厅模式：
1. 移除全部 PvP 状态处理函数 (onWaiting/onHeroSelect/onLoading/onBattle/onResult)
2. 保留基础初始化 (UIManager.Init, OverheadUI.Init, StatsBinding.Init)
3. 保留 equipHeroSkills() 函数
4. 进入即初始化 InputManager (无需等待GameState)
5. 监听 DuelEvent/MatchmakingEvent 做状态提示
6. 初始化 UI_HeroSelect 左下角面板 (显示+首次选英雄)

## 技术要求
- 修改文件: `src/StarterPlayer/StarterPlayerScripts/Client.client.lua`
- 目标行数: ~120行 (从当前~386行大幅精简)

## 输入依赖
- 需要读取: 当前 `Client.client.lua` (保留可复用部分)
- 依赖的事件: MatchmakingEvent, DuelEvent (由T1创建)
- 依赖的模块: UIManager, InputManager, OverheadUI, StatsBinding, CameraManager

## 输出要求
- 修改文件: `src/StarterPlayer/StarterPlayerScripts/Client.client.lua`

## 接口约定
```lua
-- 新流程 (伪代码):
-- 1. 等待角色加载 (CharacterAdded)
-- 2. 基础 UI 初始化 (UIManager.Init, OverheadUI.Init, StatsBinding.Init)
-- 3. 显示英雄选择面板 (UI_HeroSelect.ShowPanel)
-- 4. 等待玩家选英雄 → equipHeroSkills(heroId)
-- 5. InputManager.Init()
-- 6. 监听 HeroSwapEvent 切换英雄
-- 7. 监听 DuelEvent 做UI更新 (倒计时/结算等)
-- 8. 监听 MatchmakingEvent 做匹配状态显示
```

## 与其他模块的关系
- 被依赖: T5(HeroSelect面板), T6(MatchButton)
- 依赖: T1(RemoteEvent), T2(LobbyManager的事件)
