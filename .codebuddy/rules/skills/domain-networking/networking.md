---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：通信协议 (Networking)

> **领域**: domain-networking
> **适用Agent**: 主程 / 程序
> **加载时机**: 涉及客户端-服务端通信、RemoteEvent、数据同步时
> **大小**: ~2KB

## 📌 RemoteEvent 协议表

所有 RemoteEvent 在 `RemoteEventInit.server.lua` 中集中创建。

| 分类 | 事件名 | 方向 | 用途 |
|------|--------|------|------|
| **技能** | CastSkillEvent | C→S | 技能释放(skillID, direction) |
| **技能** | SkillDirectionEvent | C→S | 技能方向更新(skillID, direction) |
| **技能** | SyncCooldownEvent | S→C | CD同步(slotKey, remaining, total) |
| **普攻** | AttackTargetEvent | C→S | 普攻请求(targetId) |
| **战斗** | DamageNumberEvent | S→C | 伤害飘字(target, amount, type) |
| **Buff** | SyncBuffEvent | S→C | Buff状态同步(buffData) |
| **能量** | SyncEnergyEvent | S→C | 能量同步(current, max, type) |
| **英雄** | HeroSwapEvent | C→S | 英雄切换(heroId) |
| **背包** | InventoryEvent | 双向 | 装备/出售操作 |
| **符文** | RuneEvent | C→S | 符文绑定(runeId, slotKey) |
| **匹配** | MatchmakingEvent | 双向 | 匹配加入/退出/状态通知 |
| **对决** | DuelEvent | S→C | 对决生命周期(start/end/countdown/result) |
| **特写** | CinematicEvent | S→C | 电影特写控制 |
| **训练场** | TrainingEvent | C→S | 训练场控制(toggleCD/refreshHP/spawnDummy/clearDummies/setLevel/resetPosition) |
| **训练场** | TrainingSyncEvent | S→C | 训练场状态同步(面板显隐/设置状态) |

**总计**: 19个RemoteEvent

## 📌 通信原则

1. **服务端权威**: 所有游戏逻辑在服务端，客户端只发意图
2. **数据最小化**: 只传ID/坐标/枚举，不传整个table
3. **防刷验证**: OnServerEvent必须验证player和参数合法性
4. **Rate Limit**: 高频操作服务端加节流(如训练场0.2s/操作)

## 📌 同侧通信

- 服务端模块间: `require()` 直接调用(天然单例)
- `shared` 表: `shared.LobbyManager` / `shared.TrainingManager` 跨脚本共享
- 客户端模块间: `require()` + 回调函数注册

## 🔗 关联模块
- [事件与通信模式](../architecture/event-system.md)
- [Roblox Instance模式](../roblox/instance-patterns.md)
