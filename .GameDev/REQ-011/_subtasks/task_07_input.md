# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-07 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | UI_MobileHUD 战斗HUD重构 |
| 执行者 | 程序 Agent |
| 优先级 | 2 |
| Phase | B |
| 预估行数 | ~300行 |

## 任务描述
实现移动端战斗 HUD，包含：顶部信息栏（英雄头像+HP/MP条+等级+对局时间+击杀比分）、击杀播报（滑入/淡出动画）、复活倒计时遮罩。不修改现有 UI_HUD.lua，新建独立文件。

## 技术要求
- 文件路径: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_MobileHUD.lua`
- 类型: ModuleScript
- 使用 Attribute 桥监听 HP/MP 变化 (GetAttributeChangedSignal)
- 使用 TweenService 实现动画效果
- 监听 DuelEvent/SyncEnergyEvent/DeathTimerEvent
- HP条渐变: 绿(100~60%) → 黄(60~30%) → 红(<30%闪烁)
- UI层级: ZIndex = 5 (在操控元素之下)

## 输入依赖
- 需要读取: `03_技术设计.md` 第3.2节(MOD-03), `02_UX设计.md` 第2.6节(战斗HUD设计), 第4节(动画时序)
- 依赖的类: `MobileConfig`(常量), Character Attributes(HP/MP数据源), RemoteEvent(DuelEvent/SyncEnergyEvent)

## 输出要求
- 产出文件: `src/StarterPlayer/StarterPlayerScripts/UIComponents/UI_MobileHUD.lua`
- 代码规范: 遵循项目编码规范

## 接口约定
```lua
local UI_MobileHUD = {}

function UI_MobileHUD.Init(parentFrame: Frame): ()
-- 创建: 顶部信息栏 + 击杀播报区 + 复活遮罩
-- 绑定: Attribute变化信号 + DuelEvent + SyncEnergyEvent

function UI_MobileHUD.UpdateHP(current: number, max: number): ()
function UI_MobileHUD.UpdateMP(current: number, max: number): ()
function UI_MobileHUD.UpdateLevel(level: number): ()
function UI_MobileHUD.UpdateTimer(timeSeconds: number): ()
function UI_MobileHUD.UpdateScore(redKills: number, blueKills: number): ()

function UI_MobileHUD.ShowKillNotification(killerName: string, victimName: string): ()
-- 从上方滑入 → 停留2s → 淡出, 最多堆叠2条

function UI_MobileHUD.ShowRespawnCountdown(seconds: number): ()
-- 半透明黑色遮罩 + 大号倒计时数字 + "复活倒计时"文字

function UI_MobileHUD.HideRespawnCountdown(): ()

function UI_MobileHUD.SetVisible(visible: boolean): ()
-- 对决中显示 / 大厅隐藏

function UI_MobileHUD.Destroy(): ()

return UI_MobileHUD
```

### 核心逻辑要点
1. **HP条渐变**: Color3.fromRGB 根据百分比插值 (绿→黄→红)
2. **低HP闪烁**: <30% 时红色脉冲动画 (TweenService loop)
3. **击杀播报**: 维护一个 queue (最多2条), 新通知推入时旧通知上移
4. **复活倒计时**: 每秒更新数字 + 数字缩放脉冲动画
5. **Attribute监听**: `character:GetAttributeChangedSignal("HP"):Connect(...)` 实时更新

## 与其他模块的关系
- 被依赖: Client.client.lua (初始化), MobileInputManager (死亡状态通知)
- 依赖: MobileConfig(常量), Character Attributes(HP/MP), DuelEvent, SyncEnergyEvent
