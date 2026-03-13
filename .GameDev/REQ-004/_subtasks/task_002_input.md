# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-002 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | LobbyManager 服务端核心 |
| 执行者 | 程序 Agent |
| 优先级 | 1 |

## 任务描述
创建服务端大厅管理器，负责：
1. 玩家状态管理 (LOBBY/MATCHING/DUELING)
2. 匹配队列管理 (加入/离开/匹配成功)
3. 英雄切换处理 (HeroSwapEvent 监听)
4. 对决创建 (队列≥2时取出前2个，调用DuelManager)
5. 玩家加入/离开服务器处理

## 技术要求
- 新建文件: `src/ServerScriptService/LobbyManager.server.lua`
- 预估行数: ~250行

## 输入依赖
- 需要读取: `src/ReplicatedStorage/HeroConfig.lua` (验证heroId合法性)
- 依赖的事件: MatchmakingEvent, HeroSwapEvent (由T1创建)
- 依赖的模块: DuelManager (通过 shared 表调用，T3实现)

## 输出要求
- 产出文件: `src/ServerScriptService/LobbyManager.server.lua`

## 接口约定
```lua
-- 数据结构
local playerStates = {}  -- { [Player] = "LOBBY" | "MATCHING" | "DUELING" }
local playerHeroes = {}  -- { [Player] = "HouYi" | nil }
local matchQueue = {}    -- { Player, Player, ... } 有序数组
local activeDuels = {}   -- { [duelId] = { player1, player2 } }

-- 对外 API (通过 shared.LobbyManager)
shared.LobbyManager = {
    GetPlayerState = function(player) end,    -- → "LOBBY"|"MATCHING"|"DUELING"
    GetPlayerHero = function(player) end,     -- → heroId or nil
    SetPlayerState = function(player, state) end, -- DuelManager 回调用
}

-- MatchmakingEvent 协议
-- C→S: { action = "join" | "leave" }
-- S→C: { status = "queued"|"cancelled"|"matched", queueSize, opponent }

-- HeroSwapEvent 协议
-- C→S: { heroId = "HouYi" }
-- S→C: { success = bool, heroId = string, message = string|nil }
```

## 与其他模块的关系
- 被依赖: T3(DuelManager调用API), T4(Client监听事件), T7(匹配区域触发)
- 依赖: T1(RemoteEvent), T3(DuelManager通过shared调用)
