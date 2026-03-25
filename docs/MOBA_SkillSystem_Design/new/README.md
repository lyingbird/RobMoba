# MOBA 技能释放系统 — Roblox (Luau) 程序设计文档

> **版本**: v1.0 | **参考工程**: HOK 客户端源码 | **目标平台**: Roblox Studio / Luau  
> **设计目标**: 让实现者能够**逐文件、逐函数复刻**，不需要自行发挥

---

## 文件清单

```
MOBA_SkillSystem_Design/
│
├── README.md                          ← 你在这里（总入口 + 架构 + 实现指南）
│
├── 01_Enums/
│   └── SkillEnums.md                  ← 所有枚举定义 + 每个值的语义说明
│
├── 02_Types/
│   └── SkillTypes.md                  ← 数据结构 type annotation
│
├── 03_Config/
│   ├── SkillConfig.md                 ← 技能基础配置表
│   ├── IndicatorConfig.md             ← 指示器配置表
│   └── GlobalConfig.md                ← 全局常量配置
│
├── 04_InputAdapter/
│   └── InputAdapter.md                ← 输入适配层（Touch/Mouse 统一封装）
│
├── 05_SkillButtonManager/
│   └── SkillButtonManager.md          ← 技能按钮管理 + 取消区域 UI 刷新
│
├── 06_SkillController/
│   ├── SkillController_Overview.md    ← 控制器总览 + 状态机 + 内部方法
│   ├── SkillController_Down.md        ← 阶段一：OnButtonDown
│   ├── SkillController_Drag.md        ← 阶段二：OnButtonDrag
│   └── SkillController_Up.md          ← 阶段三：OnButtonUp
│
├── 07_SelectSkillTarget/
│   └── SelectSkillTarget.md           ← 4种技能类型的目标选择（Target/Pos/Dir/Track）
│
├── 08_SkillIndicator/
│   └── SkillIndicator.md              ← 三层 Part 生命周期 + 平滑插值
│
├── 09_IndicatorRenderer/
│   └── IndicatorRenderer.md           ← Part 创建/缩放/显隐/颜色
│
├── 10_CancelAreaDetector/
│   └── CancelAreaDetector.md          ← 取消区域检测（停留计时 + 双模式 + 震动）
│
├── 11_SkillCacheManager/
│   └── SkillCacheManager.md           ← 技能缓冲区（入队/出队/连续普攻/受控保护）
│
├── 12_CommonAttackController/
│   └── CommonAttackController.md      ← 普攻控制器
│
├── 13_Server/
│   └── Server.md                      ← 服务端校验 + 技能执行 + 入口脚本
│
├── 14_AntiMistouch/
│   └── AntiMistouch.md                ← 防误触机制（Pos型 + Directional型）
│
└── 15_Reference/
    └── Reference.md                   ← 常量速查 + 平台适配 + 目录结构 + 实现优先级
```

---

## 架构总览

### 三层结构

```
┌─────────────────────────────────────────────────────────┐
│                    UI 层 (ScreenGui)                     │
│  SkillButtonManager  — 接收触摸/鼠标输入，分发 Down/Drag/Up │
│  CancelAreaUI        — 取消区域 UI 元素                    │
└──────────────┬──────────────────────────────┬───────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│    SkillController       │  │ CommonAttackController   │
│  · 状态机                │  │ · 基础索敌               │
│  · 目标选择              │  │ · 自动普攻               │
│  · 防误触 / 取消判定     │  └──────────┬───────────────┘
└──────────┬───────────────┘              │
           ▼                              ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│    SkillIndicator        │  │  SkillCacheManager       │
│  · 三层资源管理          │  │  · 技能缓冲队列          │
│  · 显隐/颜色切换         │  │  · 普攻缓冲标记          │
└──────────┬───────────────┘  │  · 连续普攻窗口          │
           ▼                  └──────────┬───────────────┘
┌──────────────────────────┐              ▼
│   IndicatorRenderer      │  ┌──────────────────────────┐
│  · Part 创建/回收/缩放   │  │  RemoteEvent → Server    │
└──────────────────────────┘  └──────────────────────────┘
```

### 核心状态机

```
                              ┌──────────────────────────────┐
                              │                              │
                              ▼                              │
┌───────┐  ButtonDown   ┌──────────┐  位移>阈值  ┌──────────┐│
│ Idle  │──────────────▶│ Pressing │────────────▶│ Dragging ││
└───────┘               └──────────┘             └──────────┘│
   ▲                         │                     │    │     │
   │                  ButtonUp│                     │    │     │
   │                  (快速点击)                    │    │     │
   │                         ▼                     │    │     │
   │                    ┌──────────┐  ButtonUp     │    │     │
   │                    │ Released │◀──────────────┘    │     │
   │                    └──────────┘ (正常区域)         │     │
   │                         │                          │     │
   │              发送技能命令│                          │     │
   │              +清理指示器 │                          │     │
   │                         ▼                          │     │
   │◀────────────────────(回到 Idle)                    │     │
   │                                                    │     │
   │    ┌───────────┐  ButtonUp(取消区域>0.15s)         │     │
   │◀───│ Cancelled │◀──────────────────────────────────┘     │
   │    └───────────┘                                         │
   │                                                          │
   │    ┌──────────┐  当前有技能释放中                         │
   └────│ Buffered │◀─────── 入缓冲队列 ──────────────────────┘
        └──────────┘       等待前序技能结束后自动触发
```

### 一次完整释放的数据流

```
用户按下技能按钮
  → InputAdapter.onInputBegan()
    → SkillButtonManager:_OnButtonDown(slotIndex)
      → SkillController:OnButtonDown(slotIndex)
        记录 pressStartTime / pressStartPosition
        获取 skillConfig + indicatorConfig
        SkillIndicator:Enable(slotIndex, config)     -- 显示指示器
        状态 → Pressing

用户拖动
  → InputAdapter.onInputChanged()
    → SkillButtonManager:_OnButtonDrag(slotIndex, screenPos)
      → SkillController:OnButtonDrag(slotIndex, screenPos)
        计算 axis = normalize(screenPos - buttonCenter)
        计算 normalizedOffset = magnitude / maxDragRadius (0~1)
        SelectSkillTarget(rangeType, axis, normalizedOffset)
        SkillIndicator:UpdatePosition(targetPos, targetDir)
        CancelAreaDetector:Update(screenPos)
        状态 → Dragging（如果位移>阈值）

用户抬起
  → InputAdapter.onInputEnded()
    → SkillButtonManager:_OnButtonUp(slotIndex)
      → SkillController:OnButtonUp(slotIndex)
        最后一次 Drag（用抬起位置再 SelectSkillTarget 一次）
        取消判定：cancelState.timeInCancelArea > 0.15s → 取消
        防误触判定：IsAllowUseSkill() → 不通过则取消
        构建 SkillParam
        SkillCacheManager:TryExecuteOrBuffer(param)
          可释放 → RemoteEvent:FireServer(param)
          不可释放 → PushToCache(param)
        SkillIndicator:Disable()
        状态 → Idle
```

---

## 模块依赖关系

```
SkillEnums ◀─── 所有模块
SkillTypes ◀─── 所有模块
GlobalConfig ◀─── SkillController, SkillCacheManager, CancelAreaDetector
SkillConfig  ◀─── SkillController, SkillValidator
IndicatorConfig ◀─── SkillController, SkillIndicator

InputAdapter ◀─── SkillButtonManager
SkillButtonManager ─▶ SkillController, CommonAttackController, CancelAreaDetector

SkillController ─▶ SkillIndicator, CancelAreaDetector, SkillCacheManager
SkillIndicator ─▶ IndicatorRenderer

SkillCacheManager ─▶ RemoteEvent (FireServer)
SkillValidator ◀─── ServerScriptService (接收 RemoteEvent)
SkillExecutor ◀─── SkillValidator
```

---

## 推荐实现顺序

> 按依赖链从底到顶，每完成一个模块可以独立测试。

| 步骤 | 模块 | 对应文件 | 可测试内容 |
|---:|---|---|---|
| 1 | 枚举 + 类型 + 配置 | `01_Enums/`, `02_Types/`, `03_Config/` | require 不报错 |
| 2 | 输入适配 | `04_InputAdapter/` | 打印 Down/Drag/Up 事件 |
| 3 | 指示器渲染器 | `09_IndicatorRenderer/` | 手动调用 Create/Show 看到 Part |
| 4 | 指示器主控 | `08_SkillIndicator/` | Enable → 看到圆圈出现在角色脚下 |
| 5 | 取消区域 | `10_CancelAreaDetector/` | 手指拖到底部 → 打印 inArea=true |
| 6 | 技能控制器 | `06_SkillController/` + `07_SelectSkillTarget/` | 按下→指示器→拖动跟手→抬起消失 |
| 7 | 缓冲区管理 | `11_SkillCacheManager/` | 快速连按 → 缓冲生效 |
| 8 | 按钮管理 | `05_SkillButtonManager/` | 完整 UI 绑定 |
| 9 | 普攻控制 | `12_CommonAttackController/` | 普攻按钮 |
| 10 | 服务端 | `13_Server/` | RemoteEvent 端到端 |

---

## HOK 源码参考索引

每个模块文档中都标注了对应的 HOK 源文件和行号。以下是汇总：

| 模块 | HOK 源文件 | 行号 |
|---|---|---|
| SkillController.Down | `SkillBtnController.cs` | 187-306 |
| SkillController.Drag | `SkillBtnController.cs` | 590-723 |
| SkillController.Up | `SkillBtnController.cs` | 308-588 |
| SelectSkillTarget | `SkillControlIndicator.cs` | 3563-3775 |
| 防误触 IsAllowUseSkill | `SkillControlIndicator.cs` | 418-441 |
| 指示器三层管理 | `SkillIndicatorBase.cs` | 全文(351行) |
| 指示器渲染工具 | `IndicatorHelper.cs` | 全文(1161行) |
| 指示器配置加载 | `SkillIndicatorConfig.cs` | 全文(462行) |
| 取消区域 UI | `CSkillButtonManager.cs` | 6386-6429 |
| 缓冲入队 | `SkillCache.cpp` | 333-382 |
| 缓冲出队 | `SkillCache.cpp` | 618-755 |
| 连续普攻窗口 | `SkillCache.cpp` | 959-990 |
| 受控保护 | `SkillCache.cpp` | 168-212 |
| 缓存窗口控制 | `SkillInputCacheDuration.cpp` | 27-211 |
| 服务端校验 | `ActorControler.cpp` | CmdUseSkill |

---

*从 01_Enums 开始阅读，按编号顺序即可。每份文档独立完整，包含伪代码、接口定义和实现说明。*
