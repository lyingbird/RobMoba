---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 领域知识：项目状态速查 (Project Status)

> **领域**: domain-project
> **适用Agent**: 制作人 / PM / 策划
> **加载时机**: 需要了解项目进度、已完成功能、进行中需求时
> **大小**: ~2KB
> **⚠️ 需求交付后应同步更新此文件**

## 📌 项目概况

- **项目**: RobMoba — Roblox MOBA 游戏(复刻王者荣耀)
- **技术栈**: Luau + Roblox Studio + Rojo
- **代码规模**: ~87个.lua文件, ~15000行
- **英雄**: 4名(拉克丝/安琪拉/后羿/廉颇)
- **技能**: 15主动 + 25效果 + 4被动
- **游戏模式**: 训练场(默认) + 1v1匹配对决

## 📌 当前进行中

| REQ | 名称 | 类型/规模 | 当前阶段 | 关键信息 |
|-----|------|----------|---------|---------|
| REQ-021 | 摇杆输入状态管理重设计 | FEATURE_UI/M | 程序Agent(编码) | 3态模型+回调修复, 4个编码Task |
| REQ-016 | (待确认) | — | 策划 | — |

## 📌 已完成需求速查

| REQ | 名称 | 类型 | 规模 | 核心产出 |
|-----|------|------|------|---------|
| REQ-020 | 手机端默认横屏 | CONFIG | XS | LandscapeSensor +5行 |
| REQ-015 | 移动端UI布局重设计 | FEATURE_UI | L | 王者标准布局, 5模块, 23AC |
| REQ-013 | CD开关立即重置 | BUGFIX | XS | CooldownManager.ResetAll() |
| REQ-011 | 手机端MOBA UI与操控 | FEATURE_UI | XL | 6模块, 33AC, 1951行新增 |
| REQ-010 | 训练假人修复 | BUGFIX | S | CombatUtils假人识别 |
| REQ-009 | 训练场模式 | FEATURE | M | TrainingManager+控制面板 |
| REQ-007 | 英雄量产能力 | FEATURE | L | 被动+能量+英雄选择UI |
| REQ-006 | 技能框架升级 | OPTIMIZE | L | 5 Archetype中间层 |
| REQ-005 | 基础设施重构 | OPTIMIZE | L | Registry+Buff+Effect |
| REQ-004 | 大厅+匹配对决 | FEATURE | L | 自由大厅+1v1系统 |

## 📌 功能依赖图

```
基础设施重构(REQ-005)
  ├──→ 技能框架升级(REQ-006)
  │      └──→ 英雄量产能力(REQ-007)
  ├──→ 训练场模式(REQ-009/010)
  └──→ 手机端UI(REQ-011)
         └──→ UI布局重设计(REQ-015)
                └──→ 横屏(REQ-020) + 摇杆修复(REQ-021)
```

## 📌 详细文档指向

需要深入了解某个需求时，读取对应需求目录:
- 策划案: `.GameDev/REQ-{ID}/01_策划案.md`
- UX设计: `.GameDev/REQ-{ID}/02_UX设计.md`
- 技术设计: `.GameDev/REQ-{ID}/03_技术设计.md`
- 测试报告: `.GameDev/REQ-{ID}/06_测试报告.md`
- **需求池完整数据**: `.GameDev/_ProjectManagement/需求池.md`
- **进度看板实时**: `.GameDev/_ProjectManagement/进度看板.md`

## 🔗 关联模块
- 各领域知识包: `skills/domain-*/`
