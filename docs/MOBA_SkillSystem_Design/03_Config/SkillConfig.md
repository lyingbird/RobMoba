# 03-A — 技能基础配置表 SkillConfig

> **文件路径**: `ReplicatedStorage/SkillSystem/Config/SkillConfig.lua`

---

## 设计说明

的技能配置散布在多张 TDR 配置表中（技能配置表、技能功能表、技能参数表 等），字段超过100个。Roblox 版精简为**与技能释放交互直接相关**的字段，其余伤害/Buff 等字段由实现者根据自己的战斗系统补充。

---

## 完整实现

```lua
-- 文件: ReplicatedStorage/SkillSystem/Config/SkillConfig.lua
--
-- key = skillId (number)
-- 每个英雄的技能在此注册。运行时通过 SkillSlot.skillId 索引。
--
-- 字段说明:
--   skillId          技能唯一ID
--   skillName        技能名称（调试用）
--   slotType         默认槽位（0=普攻, 1=技能1, 2=技能2, 3=大招, 4/5=召唤师）
--   rangeType        SkillRangeType 枚举值，决定 SelectSkillTarget 分发路径
--   cooldown         基础CD（秒），运行时可被减CD效果修改
--   manaCost         基础蓝耗
--   castRange        施法范围（studs），决定 guideDistance 的上限
--   indicatorCfgId   指示器配置ID，0=无指示器
--
-- 示例数据（实际游戏中由策划配表填充）:

return {
    -- ==================== 英雄A 技能组 ====================
    [10011] = {
        skillId = 10011,
        skillName = "一技能-指向",
        slotType = 1,
        rangeType = 1,          -- Target: 指定目标
        cooldown = 8.0,
        manaCost = 60,
        castRange = 8.0,        -- 8 studs
        indicatorCfgId = 1001,  -- 对应 IndicatorConfig[1001]
    },
    [10012] = {
        skillId = 10012,
        skillName = "二技能-落点",
        slotType = 2,
        rangeType = 2,          -- Pos: 指定位置
        cooldown = 12.0,
        manaCost = 80,
        castRange = 12.0,
        indicatorCfgId = 1002,
    },
    [10013] = {
        skillId = 10013,
        skillName = "大招-方向",
        slotType = 3,
        rangeType = 3,          -- Directional: 指定方向
        cooldown = 40.0,
        manaCost = 100,
        castRange = 15.0,
        indicatorCfgId = 1003,
    },
    [10014] = {
        skillId = 10014,
        skillName = "闪现",
        slotType = 4,
        rangeType = 0,          -- Auto: 按下即释放
        cooldown = 120.0,
        manaCost = 0,
        castRange = 0,          -- 无范围概念
        indicatorCfgId = 0,     -- 无指示器
    },

    -- ==================== 英雄B 技能组（示例扩展）====================
    [10021] = {
        skillId = 10021,
        skillName = "B一技能-方向",
        slotType = 1,
        rangeType = 3,          -- Directional
        cooldown = 6.0,
        manaCost = 40,
        castRange = 10.0,
        indicatorCfgId = 1003,  -- 复用同一指示器配置
    },
}
```

---

## 运行时加载方式

```lua
local SkillConfig = require(game.ReplicatedStorage.SkillSystem.Config.SkillConfig)

-- 查询技能
local cfg = SkillConfig[10011]
print(cfg.skillName, cfg.rangeType)  --> "一技能-指向", 1
```

---

## 策划配表指南

| 字段 | 填写说明 | 取值范围 |
|---|---|---|
| `skillId` | 全局唯一，建议按 `英雄ID×100 + 技能序号` 编号 | 正整数 |
| `rangeType` | 0=Auto, 1=Target, 2=Pos, 3=Directional, 4=Track | 0-4 |
| `cooldown` | 基础CD秒数，技能等级提升可在运行时覆盖 | ≥0 |
| `castRange` | 单位 studs（1 stud ≈ 0.28m），决定指示器最大拖动距离 | ≥0 |
| `indicatorCfgId` | 对应 `IndicatorConfig.lua` 中的 key，0=不显示指示器 | ≥0 |
