# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-02 |
| 父需求 | REQ-015 移动端UI布局重设计 |
| 子任务名称 | Client.client.lua 大厅条件分支重构 |
| 执行者 | 程序 Agent |
| 优先级 | 1(最高) |

## 任务描述
重构 `Client.client.lua` 的 L93-98 基础UI初始化代码和 L132-192 onHeroConfirmed 移动端路径：

### 改造1: L93-98 基础UI初始化
**当前代码**(L93-98):
```lua
UIManager.Init()
OverheadUI.Init()
UI_TrainingPanel.Init()
local UI_HUD = UIManager.GetHUD()
StatsBinding.Init(UI_HUD)
```
**改造为**:
```lua
if isMobile then
    -- 移动端大厅路径
    -- 1. 创建 MobileUI ScreenGui + MobileFrame
    -- 2. 初始化摇杆(大厅静态模式): UI_VirtualJoystick.Init(mobileFrame) + SetLobbyMode(true)
    -- 3. 初始化技能按钮(锁定态): UI_SkillButtons.Init(mobileFrame, nil)
    -- 4. 创建大厅功能按钮(训练场+匹配)
    -- 5. OverheadUI.Init()
    -- 6. HeroSelectUI.Show(9999)
else
    -- PC端路径(完全不变)
    UIManager.Init()
    OverheadUI.Init()
    UI_TrainingPanel.Init()
    local UI_HUD = UIManager.GetHUD()
    StatsBinding.Init(UI_HUD)
    HeroSelectUI.Show(9999)
end
```

### 改造2: onHeroConfirmed 移动端路径(L132-192)
**当前**: 创建 MobileUI ScreenGui + 初始化所有移动端UI
**改造为**: MobileUI已在大厅创建，onHeroConfirmed 只需:
1. `UI_VirtualJoystick.SetLobbyMode(false)` — 激活摇杆
2. `UI_SkillButtons.UpdateSkills(skillSlots)` — 更新技能图标
3. 初始化 `MobileInputManager` (不变)
4. 初始化 `UI_MobileHUD` + `UI_Minimap` (不变)
5. 隐藏大厅功能按钮中的训练场/匹配按钮(战斗后恢复)

### 改造3: 大厅功能按钮
新增 `createMobileLobbyButtons(parent)` 本地函数:
- 训练场按钮: 复用 TrainingEvent，位置从 MobileConfig.LOBBY_TRAIN_BTN_POS
- 匹配按钮: 复用 MatchmakingEvent，位置从 MobileConfig.LOBBY_MATCH_BTN_POS
- 英雄切换按钮: 选完英雄后显示，触摸后调用 HeroSelectUI.Show()

### 改造4: 移动 HeroSelectUI.Show 和注册回调
- 移动端: HeroSelectUI.Show(9999) 在 isMobile 分支末尾调用
- PC端: 保持在 else 分支末尾
- HeroSelectUI.OnHeroConfirmed(onHeroConfirmed) 保持在分支之前

## 技术要求
- 文件: `src/StarterPlayer/StarterPlayerScripts/Client.client.lua`
- ⚠️ 核心原则: PC端路径代码完全不变
- ⚠️ require 语句: UI_VirtualJoystick/UI_SkillButtons 需要从 onHeroConfirmed 内部移到文件顶部(大厅就要用)

## 输入依赖
- TASK-01 MobileConfig (参数)
- TASK-03 UI_VirtualJoystick.SetLobbyMode API
- TASK-04 UI_SkillButtons.UpdateSkills API

## 输出要求
- 修改文件: `Client.client.lua`
- 新增约80行，删除约30行(重构移动端路径)

## 与其他模块的关系
- 被依赖: 无(顶层入口)
- 依赖: MobileConfig, UI_VirtualJoystick, UI_SkillButtons, UI_MobileHUD, UI_Minimap, HeroSelectUI, UI_TrainingPanel (事件), MobileInputManager
