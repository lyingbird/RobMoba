---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：UI组件系统 (UI Components)

> **领域**: domain-ui
> **适用Agent**: 程序 / 主程 / UX / 策划
> **加载时机**: 涉及UI界面、HUD、面板、屏幕布局、UI交互时
> **大小**: ~3KB

## 📌 UI架构概览

```
Client.client.lua (入口)
  ├─ PC端: ScreenGui "MainUI"
  │   ├─ UI_HUD.Init()        → 血量/等级/技能CD (PC布局)
  │   └─ InputManager          → 键鼠操控
  │
  └─ 移动端: ScreenGui "MobileUI" (DisplayOrder=10)
      ├─ UI_VirtualJoystick    → 虚拟摇杆
      ├─ UI_SkillButtons       → 技能按钮(弧形布局)
      ├─ UI_MobileHUD          → 移动端战斗HUD
      └─ UI_Minimap            → 小地图

共享UI (两端通用):
  ├─ UI_HeroSelect             → 英雄选择 (ScreenGui DisplayOrder=100)
  ├─ UI_Backpack               → 背包/装备
  ├─ UI_DragDrop               → 拖放绑定(符文)
  └─ UI_MatchButton            → 匹配按钮
```

## 📌 UI模块清单

| 模块 | 文件 | 职责 | 端 |
|------|------|------|-----|
| UI_HeroSelect | UIComponents/UI_HeroSelect.lua | 英雄选择面板(Grid+预览+确认) | 双端 |
| UI_HUD | UIComponents/UI_HUD.lua | PC端战斗HUD | PC |
| UI_VirtualJoystick | UIComponents/UI_VirtualJoystick.lua | 虚拟摇杆 | Mobile |
| UI_SkillButtons | UIComponents/UI_SkillButtons.lua | 技能按钮+方向轮盘 | Mobile |
| UI_MobileHUD | UIComponents/UI_MobileHUD.lua | 移动端战斗HUD(王者标准) | Mobile |
| UI_Minimap | UIComponents/UI_Minimap.lua | 小地图(纯UI, 坐标映射) | Mobile |
| UI_Backpack | UIComponents/UI_Backpack.lua | 背包/装备管理 | 双端 |
| UI_DragDrop | UIComponents/UI_DragDrop.lua | 符文拖放绑定 | PC |
| UI_MatchButton | UIComponents/UI_MatchButton.lua | 匹配区域按钮 | 双端 |

## 📌 UI层级管理

| ScreenGui | DisplayOrder | 用途 |
|-----------|-------------|------|
| MainUI | 默认(0) | PC端主界面 |
| MobileUI | 10 | 移动端主界面 |
| HeroSelectUI | 100 | 英雄选择面板(全屏) |

**原则**: 非交互Frame设 `Active=false` 避免穿透; 用DisplayOrder控制层级

## 📌 移动端UI布局 (王者荣耀标准, REQ-015)

```
┌─────────────────────────────────────────┐
│ [血量/等级] [击杀播报] [敌方血量]        │  ← HUD顶部栏
│                                         │
│  [小地图]                               │  ← 左上角
│                                         │
│  [摇杆区域]              [技能按钮弧形]  │  ← 底部
│  (左半屏)                (右下弧形)      │
│                          Q W R          │
│                         AA  D  F        │
└─────────────────────────────────────────┘
```

- 布局使用 Scale(比例) + SafeArea边距
- MobileConfig集中配置所有尺寸参数
- PC/Mobile条件分支隔离，互不干扰

## 📌 UI生命周期模式

```lua
-- 每个UI模块标准接口
local UIModule = {}
function UIModule.Init(parentGui, ...)  -- 创建UI元素
function UIModule.Update(data)          -- 数据驱动刷新
function UIModule.SetEnabled(bool)      -- 启用/禁用
function UIModule.Destroy()             -- 清理
return UIModule
```

## 📌 UI数据驱动

- 使用 `Attribute + GetAttributeChangedSignal` 驱动更新（非每帧轮询）
- CD更新: `CooldownManager → SyncCooldownEvent → 客户端UI_SkillButtons`
- HP更新: `Humanoid.HealthChanged → HUD/MobileHUD`
- 等级更新: `Level Attribute → HUD 文本`

## 🔗 关联模块
- [移动与输入系统](../domain-movement/input-movement-system.md)
- [Roblox UI模式](../roblox/ui-patterns.md)
- [游戏流程](../domain-gameflow/game-flow.md)
