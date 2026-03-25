# 代码架构 — ARCHITECTURE.md

> 最后更新: 2026-03-20
> 维护者: CodeBuddy（新增/删除/重命名模块时同步更新）

---

## 项目技术栈

- **引擎**: Roblox Studio
- **语言**: Luau
- **工具链**: Rojo 7.7.0-rc.1 + Aftman
- **架构**: 服务端权威，客户端只负责渲染和输入
- **仓库是唯一真相源**

### 构建方式

```bash
rojo build -o "roblox_vibecoding.rbxlx"
# 然后 Studio 中打开 place → rojo serve
```

---

## Rojo 目录映射

```
src/client/  → StarterPlayer.StarterPlayerScripts.Client
src/server/  → ServerScriptService.Server
src/shared/  → ReplicatedStorage.Shared
```

- `init.client.luau` 编译后成为 `Client` Script **自身**
- `init.server.luau` 编译后成为 `Server` Script **自身**
- 子模块是 init Script 的 **children**，不是 siblings

---

## 完整文件清单（32 .luau）

### 客户端 src/client/ (11 文件)

| 文件 | 行数约 | 职责 |
|------|--------|------|
| `init.client.luau` | 145 | 客户端入口，串联所有模块初始化 |
| `CameraController.luau` | ~210 | LOL 固定俯视角镜头：Scriptable 摄像机+45°俯角+滚轮缩放+边缘滚屏+空格回中 |
| `InputHandler.luau` | ~310 | 输入处理：QWER 技能键(CAS)+鼠标左键确认+ESC 取消+预输入(0.2s) |
| `MovementController.luau` | ~135 | 右键点击移动+禁用 WASD(三重方案)+绿色目标指示器 |
| `SkillBarUI.luau` | ~220 | 技能栏 HUD：4 槽位(70x70)+图标+冷却遮罩+蓝量条 |
| `HealthBarUI.luau` | ~200 | 血条系统：头顶血条(敌红友绿)+HUD 血蓝条 |
| `CombatUI.luau` | ~180 | 浮动伤害数字+击杀信息+复活倒计时 |
| `VFXController.luau` | ~250 | 特效调度：监听 PlayVFX/PlayAnim，fallback 颜色映射 |
| `VFXLibrary.luau` | ~200 | 特效模板库：配置缓存+预制件缓存 |
| `HeroSelectUI.luau` | ~280 | 左上角英雄切换面板：3 卡片+展开收起 |
| `SkillIndicator.luau` | ~250 | 技能指示器：5 种类型(Arrow/Circle/Fan/Rectangle/SelfCircle) |

### 服务端 src/server/ (10 文件)

| 文件 | 行数约 | 职责 |
|------|--------|------|
| `init.server.luau` | 109 | 服务端入口，串联所有模块初始化 |
| `GameManager.luau` | ~300 | 游戏状态机(Waiting→HeroSelect→Countdown→InProgress→Ended) |
| `HeroManager.luau` | ~350 | 英雄生命周期：选择/切换/属性设置/蓝量回复/重生 |
| `SkillSystem.luau` | ~400 | 技能释放校验+执行器分发+冷却管理+普攻+被动触发 |
| `CombatManager.luau` | ~200 | 伤害计算+友军过滤+击杀判定 |
| `StatusEffectManager.luau` | ~250 | 状态效果：减速/晕眩/护盾/免控 |
| `MapGenerator.luau` | ~700 | MOBA 对称地图生成+泉水回血+假人 DPS 面板 |
| `TeamManager.luau` | ~150 | 队伍管理：分配/平衡 |
| `EventHandlers.luau` | ~800 | 技能事件处理器：弹道/AOE/DOT/位移等所有效果执行 |
| `EventScheduler.luau` | ~150 | 事件调度器：延迟事件/序列事件 |

### 共享 src/shared/ (11 文件)

| 文件 | 职责 |
|------|------|
| `Remotes.luau` | RemoteEvent 统一注册/获取（24 个事件） |
| `GameConfig.luau` | 游戏常量：状态枚举/时间/地图尺寸 |
| `GameTypes.luau` | 类型枚举定义 |
| `HeroTable.luau` | 英雄配置：属性/按键映射/配色 |
| `SkillTable.luau` | 技能配置：CD/蓝耗/施法类型/levelData |
| `SkillEventTable.luau` | 技能事件链：弹道参数/AOE 参数/序列 |
| `SkillEffectTable.luau` | 技能效果配置 |
| `SkillIndicatorTable.luau` | 技能指示器配置：6 种类型参数 |
| `VFXTemplateTable.luau` | VFX 模板配置：粒子参数/颜色/大小(45 个模板) |
| `EventTypes.luau` | 事件类型枚举 |
| `DataManager.luau` | 数据聚合模块：统一 require 所有 Table |

---

## 模块初始化顺序

### 客户端 (init.client.luau)

```
1.  Remotes.getRemotes()                     -- 获取所有 Remote，失败则整个客户端无法启动
1.3 CameraController.init()                  -- 无依赖
2.  MovementController.init()                -- 无依赖
3.  InputHandler.init(remotes)               -- 依赖 SkillIndicator, MovementController
4.  SkillBarUI.init(remotes)                 -- 无模块依赖
5.  HealthBarUI.init(remotes)                -- 依赖 GameConfig
6.  CombatUI.init(remotes)                   -- 无模块依赖
7.  VFXController.init(remotes)              -- 依赖 VFXLibrary
8.  HeroSelectUI.init(remotes)               -- 依赖 HeroTable, SkillTable
```

### 服务端 (init.server.luau)

```
1.   Remotes.createRemotes()
2.   MapGenerator.init(remotes) + generate()
3.   TeamManager.init(remotes)
4.   StatusEffectManager.init(remotes)            -- 依赖 SkillEffectTable
5.   CombatManager.init(remotes, SEM)             -- 依赖 StatusEffectManager
6.   EventHandlers.init(remotes, CM, SEM)         -- 依赖 CombatManager, StatusEffectManager
7.   EventScheduler.init(EH)                      -- 依赖 EventHandlers
8.   SkillSystem.init(remotes, ES, SEM)           -- 依赖 EventScheduler, StatusEffectManager
8.5a CombatManager.setSkillSystem(SS)             -- 延迟注入
8.5b EventHandlers.setSkillSystem(SS)             -- 延迟注入
8.5c StatusEffectManager.setEventScheduler(ES)    -- 延迟注入
9.   HeroManager.init(remotes, TM, MG, SEM, SS)  -- 依赖 TeamManager, MapGenerator, SEM, SkillSystem
10.  GameManager.init({all deps})                 -- 依赖所有模块
10.5 HeroManager.setGameManager(GM)               -- 延迟注入
```

---

## 模块间依赖关系图

### 客户端

```
InputHandler → SkillIndicator (技能指示器)
InputHandler → MovementController (施法时停止移动)
InputHandler → SkillTable, HeroTable (运行时 lazy require)
VFXController → VFXLibrary (特效模板)
SkillIndicator → SkillIndicatorTable, SkillTable
HeroSelectUI → HeroTable, SkillTable
HealthBarUI → GameConfig
```

### 服务端

```
SkillSystem → DataManager → 所有 Table
SkillSystem → EventHandlers (缓存引用)
HeroManager → DataManager
HeroManager ↔ GameManager (延迟注入，击杀追踪)
EventHandlers → SkillTable, SkillEventTable (运行时 lazy require)
EventHandlers ↔ SkillSystem (延迟注入，被动触发+技能替换)
StatusEffectManager → SkillEffectTable
StatusEffectManager ↔ EventScheduler (延迟注入，打断施法)
CombatManager ↔ SkillSystem (延迟注入，战意减伤)
```

---

## RemoteEvent 清单 (24 个)

所有 Remote 在 `src/shared/Remotes.luau` 中集中定义。

### 客户端 → 服务端 (6 个)

| Remote | 参数 | 说明 |
|--------|------|------|
| `SkillCast` | { skillId, direction, targetPosition? } | 释放技能 |
| `BasicAttack` | { direction, targetPosition } | 普通攻击 |
| `HeroSelect` | { heroId } | 英雄选择阶段选英雄 |
| `HeroSwitch` | { heroId } | 游戏中切换英雄 |
| `ChannelCancel` | { skillId } | 取消引导施法 |
| `ChannelDirection` | { direction } | 持续施法方向更新 |

### 服务端 → 客户端 (18 个)

| Remote | 参数 | 说明 |
|--------|------|------|
| `DamageDealt` | { targetModel, amount, damageType, position } | 伤害数字 |
| `PlayVFX` | { templateId, position, direction?, params } | 播放特效 |
| `PlayAnim` | { targetModel, animId, speed?, duration?, loopCount? } | 播放动画 |
| `StopAnim` | { targetModel, animId } | 停止动画 |
| `CooldownUpdate` | { skillId, cooldownTime } | 技能 CD 同步 |
| `TargetDied` | { targetModel, respawnTime } | 击杀通知 |
| `StatusEffectUpdate` | { targetModel, effectType, action, duration?, value? } | 状态效果 |
| `ChannelInterrupt` | { playerId } | 引导打断 |
| `CameraShake` | { intensity, duration } | 镜头震动 |
| `ChannelBarUpdate` | { playerId, progress, maxDuration } | 引导条 |
| `SkillBarUpdate` | { skills } | 技能栏刷新 |
| `MarkUpdate` | { targetModel, markId, stacks, maxStacks } | 印记叠层 |
| `GameStateChanged` | { state, data } | 游戏状态变更 |
| `HeroRespawned` | { playerName } | 英雄重生 |
| `TeamAssigned` | { teamId, teamColor } | 队伍分配 |
| `KillFeed` | { killerName, victimName, skillName } | 击杀播报 |
| `ZhanYiUpdate` | { playerModel, value, maxValue, hasFullBonus } | 廉颇战意 |

---

## 数据表引用关系

```
DataManager = 聚合层，require 所有 Table
  ├── HeroTable      ← HeroManager, HeroSelectUI, InputHandler
  ├── SkillTable     ← SkillSystem, SkillIndicator, InputHandler, HeroSelectUI, EventHandlers
  ├── SkillEventTable ← EventHandlers
  ├── SkillEffectTable ← StatusEffectManager
  ├── SkillIndicatorTable ← SkillIndicator
  ├── VFXTemplateTable ← VFXLibrary
  └── EventTypes     ← EventScheduler
```

---

## 文件修改联动检查表

| 如果你修改了... | 必须同步检查... |
|----------------|----------------|
| `Remotes.luau` (新增 Remote) | init.client.luau 事件监听, 所有 FireClient/FireServer 调用方 |
| `SkillTable` (技能配置) | SkillEventTable, SkillBarUI, InputHandler, SkillIndicator, HeroSelectUI |
| `HeroTable` (英雄配置) | HeroManager, HeroSelectUI, InputHandler |
| 模块的 `init()` 签名 | 对应的 init.client/server.luau 调用处 |
| `EventTypes` (事件枚举) | EventScheduler, EventHandlers |
| `VFXTemplateTable` (特效模板) | VFXController fallback 映射, VFXLibrary |
| `GameConfig` (游戏常量) | GameManager, HealthBarUI |

---

## 按键系统架构

| 按键 | 处理模块 | 绑定方式 | 说明 |
|------|---------|---------|------|
| Q/W/E/R | InputHandler | ContextActionService（高优先级） | 技能键 |
| A/S/D | MovementController | ContextActionService Sink（低优先级） | 被吞掉，禁移动 |
| 右键 | MovementController | UserInputService | 点击移动 |
| 左键 | InputHandler | UserInputService | 技能确认 |
| ESC | InputHandler | UserInputService | 取消技能 |
| 空格 | CameraController | UserInputService | 镜头回中 |

**⚠️ W 键由 InputHandler 独占管理，不能被 MovementController Sink！**

---

## 游戏状态机

```
Waiting → HeroSelect → Countdown → InProgress → Ended → (重置) → Waiting
```

由 `GameManager.luau` 驱动，通过 `GameStateChanged` Remote 广播给客户端。

### 战斗数据流

```
客户端按键 → InputHandler → SkillCast Remote
                                    ↓
服务端 SkillSystem → 校验 → EventHandlers → CombatManager → 伤害
                                    ↓                          ↓
                              EventScheduler           DamageDealt Remote
                              (延迟/序列事件)                 ↓
                                    ↓               客户端 CombatUI (浮动数字)
                              PlayVFX Remote → 客户端 VFXController (特效)
```
