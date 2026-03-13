# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-003 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | DuelManager 对决管理 |
| 执行者 | 程序 Agent |
| 优先级 | 1 |

## 任务描述
创建对决生命周期管理器，负责：
1. 创建对决实例 (从LobbyManager调用)
2. 阵营分配 (Teams: RedTeam/BlueTeam)
3. 传送到竞技场 (双方出生在两端，间距80 studs)
4. 3秒倒计时 (DuelEvent countdown)
5. 启动战斗 (调用 shared.MatchSystem.StartBattle)
6. 监听胜负 (MatchSystem回调或轮询)
7. 结算+传送回大厅 (5秒后回出生点)
8. 处理掉线 (PlayerRemoving强制结束对决)

## 技术要求
- 新建文件: `src/ServerScriptService/DuelManager.server.lua`
- 预估行数: ~200行

## 输入依赖
- 依赖的事件: DuelEvent (由T1创建)
- 依赖的模块: shared.MatchSystem (StartBattle/EndBattle/ResetMatch)
- 依赖的模块: shared.LobbyManager (SetPlayerState回调)

## 输出要求
- 产出文件: `src/ServerScriptService/DuelManager.server.lua`

## 接口约定
```lua
-- 对外 API (通过 shared.DuelManager)
shared.DuelManager = {
    CreateDuel = function(player1, player2) end, -- LobbyManager 匹配成功后调用
}

-- DuelEvent 协议 (S→C)
-- { type = "matched", opponent = { name, heroId } }
-- { type = "countdown", seconds = 3 }
-- { type = "start", team = "RedTeam"|"BlueTeam", arenaCenter = Vector3 }
-- { type = "result", winner = "RedTeam"|"BlueTeam", stats = {} }

-- 竞技场参数
local ARENA_CENTER = Vector3.new(0, 50, 0)  -- 竞技场中心 (需根据地图调整)
local SPAWN_DISTANCE = 40  -- 各自距中心40 studs (总间距80)
local COUNTDOWN_SECONDS = 3
local RESULT_DISPLAY_TIME = 5
```

## 与其他模块的关系
- 被依赖: T2(LobbyManager调用CreateDuel)
- 依赖: T1(RemoteEvent), shared.MatchSystem, shared.LobbyManager
