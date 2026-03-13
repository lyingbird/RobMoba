# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-001 |
| 父需求 | REQ-004 自由大厅+匹配对决 |
| 子任务名称 | 基础设施修复 |
| 执行者 | 程序 Agent |
| 优先级 | 1 |

## 任务描述
修复两个阻断大厅模式的基础设施问题：
1. 在 RemoteEventInit.server.lua 中新增 3 个 RemoteEvent
2. 移除 MatchSystem.server.lua 中的 `CharacterAutoLoads = false`

## 技术要求
- 文件: `src/ServerScriptService/RemoteEventInit.server.lua`
- 文件: `src/ServerScriptService/MatchSystem.server.lua`

## 输入依赖
- 需要读取: `src/ServerScriptService/RemoteEventInit.server.lua`
- 需要读取: `src/ServerScriptService/MatchSystem.server.lua`

## 输出要求
- RemoteEventInit: REMOTE_EVENTS 表新增 `"MatchmakingEvent"`, `"DuelEvent"`, `"HeroSwapEvent"`
- MatchSystem: 删除 `Players.CharacterAutoLoads = false` 这一行（约第32行）
- 代码规范: 遵循项目编码规范

## 接口约定
```lua
-- RemoteEventInit 新增 3 个事件，总计 16 个
local REMOTE_EVENTS = {
    -- ... 现有 13 个 ...
    "MatchmakingEvent",  -- 新增: 匹配队列通信
    "DuelEvent",         -- 新增: 对决状态通信
    "HeroSwapEvent",     -- 新增: 英雄切换通信
}
```

## 与其他模块的关系
- 被依赖: T2(LobbyManager), T3(DuelManager), T4(Client), T5(HeroSelect), T6(MatchButton) 全部依赖这些 RemoteEvent
- 依赖: 无
