---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：游戏流程 (Game Flow)

> **领域**: domain-gameflow
> **适用Agent**: 策划 / 主程 / 程序
> **加载时机**: 涉及游戏状态流转、大厅/匹配/对决/训练场逻辑时
> **大小**: ~3KB

## 📌 核心游戏循环

```
自由大厅(训练场模式)
  → 选择英雄 (UI_HeroSelect)
  → 练习技能/测试连招
  → 进入匹配区域 (MatchmakingEvent)
  → 匹配成功
  → 3秒倒计时
  → 竞技场1v1对决 (DuelManager)
  → 3杀获胜
  → 5秒结算展示
  → 返回大厅(训练场)
```

## 📌 玩家状态机

```
LOBBY (大厅) ──匹配请求──→ MATCHING (匹配中)
  ↑                            │ 匹配成功
  │                            ↓
  ←──结算完毕──── DUELING (对决中) ──击杀3次──→ 结算
```

**管理**: `LobbyManager.server.lua` (shared.LobbyManager.GetPlayerState)

## 📌 大厅系统 (LobbyManager)

- 玩家加入游戏 → 默认LOBBY状态 → 训练场模式
- 英雄选择 → HeroSwapEvent → 服务端更新角色模型
- 匹配区域 → 进入后显示匹配按钮
- **文件**: `src/ServerScriptService/LobbyManager.server.lua`

## 📌 对决系统 (DuelManager)

- 匹配成功 → `DuelManager.CreateDuel(player1, player2)`
- 分配阵营: RedTeam / BlueTeam
- 传送到竞技场对称出生点
- **击杀/重生**: MatchSystem (3杀胜利, 5秒重生)
- **结算**: 播放结算UI → 5秒后传送回大厅
- **断线处理**: 对手获胜
- **文件**: `src/ServerScriptService/DuelManager.server.lua` + `ServerModules/DuelManager.lua`

## 📌 训练场系统 (REQ-009/010)

| 功能 | 实现 |
|------|------|
| CD开关 | `TrainingManager.IsNoCooldown()` → BaseSkill检查 |
| HP刷新 | Humanoid.Health=Max + MP/能量回满 + 清Buff |
| 训练假人 | R15 Dummy(Anchored, HP=10000, 5s自回, 最多3个) |
| 等级调整 | StatsManager.SetLevel → 重算属性 |
| 重置位置 | CFrame传送出生点 |

**安全**: 仅LOBBY状态允许; 进入MATCHING/DUELING自动重置
**文件**: `src/ServerScriptService/TrainingManager.server.lua`
**API**: `shared.TrainingManager.IsNoCooldown(player)` / `.IsNoCost(player)` / `.ResetTrainingState(player)`

## 📌 Client.client.lua 初始化流程

```
1. 变量声明 + require 模块
2. setupCharacter(character) → 英雄选择/属性初始化
3. if isMobile → 创建MobileUI + 初始化摇杆/技能按钮/HUD/小地图
   else → 创建MainUI + InputManager初始化
4. onHeroConfirmed → 切换英雄模型 + 重新初始化输入
5. DuelEvent监听 → start/end/countdown/result处理
6. CharacterAdded连接 → 角色重生重新setup
```

**行数**: ~445行
**文件**: `src/StarterPlayer/StarterPlayerScripts/Client.client.lua`

## 🔗 关联模块
- [英雄系统](../domain-hero/hero-system.md)
- [移动与输入系统](../domain-movement/input-movement-system.md)
- [通信协议](../domain-networking/networking.md)
