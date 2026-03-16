# 子任务卡片

## 基本信息
| 属性 | 值 |
|------|-----|
| 任务ID | TASK-06 |
| 父需求 | REQ-011 手机端MOBA UI与操控系统 |
| 子任务名称 | SkillConfig aimType 字段新增 |
| 执行者 | 程序 Agent |
| 优先级 | 1（最高） |
| Phase | A |
| 预估行数 | ~20行（分布在4个Config文件中） |

## 任务描述
为所有英雄的技能配置文件新增 `aimType` 字段，用于区分技能的触屏交互方式（指向性/范围/自身/引导/无目标）。

## 技术要求
- 修改文件:
  - `src/ReplicatedStorage/Skills/Angela_Skills.lua`
  - `src/ReplicatedStorage/Skills/Lux_Skills.lua`
  - `src/ReplicatedStorage/Skills/HouYi_Skills.lua`
  - `src/ReplicatedStorage/Skills/LianPo_Skills.lua`
- 增量修改: 在每个技能的 config table 中添加 `aimType` 字段
- **不影响现有功能**: 服务端不读取 aimType，纯客户端使用

## 输入依赖
- 需要读取: `03_技术设计.md` 第3.4节(aimType设计), 现有4个Skills文件
- 依赖的类: 无

## 输出要求
- 修改文件: 上述4个文件
- 代码规范: 遵循现有 SkillConfig 的数据格式

## aimType 映射表

| 英雄 | 技能 | skillId | aimType |
|------|------|---------|---------|
| Angela | Q (火球) | 1001 | "directional" |
| Angela | W (范围灼烧) | 1002 | "area" |
| Angela | R (引导光线) | 1003 | "channel" |
| Lux | Q (光之束缚) | 1004 | "directional" |
| Lux | W (曲光屏障) | 1005 | "self" |
| Lux | R (终极闪光) | 1006 | "directional" |
| HouYi | Q (多重箭) | 1007 | "self" |
| HouYi | W (火箭) | 1008 | "directional" |
| HouYi | R (烈日裁决) | 1009 | "directional" |
| LianPo | Q (冲锋) | 1010 | "directional" |
| LianPo | W (护盾) | 1011 | "self" |
| LianPo | R (地震) | 1012 | "area" |

> 注意: skillId 为示例，需确认实际 SkillConfig 中的 ID。查看技能文件后按实际ID设置。
> **默认规则**: UI_SkillButtons 中若读取到 nil，默认按 "directional" 处理。

## 修改示例
```lua
-- 在技能table中新增一行:
{
    id = 1001,
    name = "火球术",
    -- ...现有字段...
    aimType = "directional",  -- ← 新增
}
```

## 与其他模块的关系
- 被依赖: UI_SkillButtons (读取 aimType 决定交互方式)
- 依赖: 无（独立数据修改）
