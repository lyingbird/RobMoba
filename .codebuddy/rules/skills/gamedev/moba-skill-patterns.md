---
# 注意不要修改本文头文件，如修改，CodeBuddy（内网版）将按照默认逻辑设置
type: manual
---
# 技能：MOBA 技能实现模式

> **领域**: gamedev
> **适用Agent**: 程序 / 主程 / 策划
> **加载时机**: 需要设计或实现新技能、效果、Buff 时按需加载
> **大小**: ~2KB

## 📌 核心知识

1. **技能架构**: SkillRegistry(自动发现) → BaseSkill(OOP基类) → Skill_XXXX(具体实现)
2. **数据-逻辑分离**: 技能数据在 `ReplicatedStorage/Skills/` (共享)，技能逻辑在 `ServerScriptService/ServerModules/Skills/` (服务端)
3. **效果配置驱动**: EffectConfig 定义 6 种效果类型的纯数据，EffectExecutor 负责执行 — 技能只需调用 `BuffSystem:ApplyEffect(source, target, effectId)`
4. **SkillModuleMap**: 启动时构建 `{skillID → ModuleScript}` 查找表，O(1) 定位技能逻辑模块
5. **技能生命周期**: 客户端发起 CastSkillEvent → 服务端验证冷却/蓝量 → 执行技能逻辑 → VFX/SFX → 效果施加
6. **ID 分配规范**: 技能 ID 1001-1999, 效果 ID 3001-3999, 物品 ID 3001+, 符文 ID 2001+

## ✅ 最佳实践

### 新增英雄流程

1. **创建英雄配置**: `ReplicatedStorage/Heroes/{HeroName}.lua` — 定义 heroId, displayName, role, skills 映射
2. **创建技能数据**: `ReplicatedStorage/Skills/{HeroName}_Skills.lua` — 定义每个技能的 CD/射程/伤害等参数
3. **创建效果配置**: 在 `EffectConfig.lua` 中按 ID 段位添加效果数据
4. **创建技能逻辑**: `ServerScriptService/ServerModules/Skills/Skill_{ID}.lua` — 继承 BaseSkill，实现 `execute` 方法
5. **自动注册**: HeroRegistry/SkillRegistry 自动发现新文件，无需手动注册

### 技能逻辑编写模式

```lua
local BaseSkill = require(script.Parent.BaseSkill)
local Skill_XXXX = setmetatable({}, {__index = BaseSkill})
Skill_XXXX.__index = Skill_XXXX

function Skill_XXXX:execute(caster, direction, targetPos)
    -- 1. 获取技能数据
    local skillData = self.skillData
    -- 2. 创建弹道/区域/瞬发效果
    -- 3. 碰撞检测 (CombatUtils.getEnemiesInRange)
    -- 4. 施加效果 (BuffSystem:ApplyEffect)
    -- 5. 发送 VFX/SFX 事件到客户端
end

return Skill_XXXX
```

### 效果配置模式

```lua
[3XXX] = {
    Name = "描述性名称",
    Type = "Damage", -- Damage/CC/Shield/DoT/HoT/StatMod
    DamageType = "Magic", -- Physical/Magic (Damage/DoT 类型需要)
    Amount = 300,
    Duration = 2.0, -- CC/Shield/DoT/HoT/StatMod 需要
    Stacking = "Replace", -- Replace/Stack/Refresh/Independent
    MutexGroup = nil, -- "HardCC" 等互斥组（可选）
}
```

### 弹道技能模式
- 创建不可见 Part 作为弹道
- Heartbeat 驱动移动（非 BodyVelocity）
- 使用 `workspace:GetPartsInPart()` 或距离检测碰撞
- 命中后调用 `BuffSystem:ApplyEffect` 施加效果
- 超出射程或命中后 `:Destroy()` 清理

### 区域技能模式
- 创建透明 Part 标记区域
- 定时 Tick（DoT/HoT）或瞬发（Damage）
- `CombatUtils.getEnemiesInRange(caster, center, radius)` 获取目标
- 持续时间结束后销毁标记 Part

## ❌ 常见陷阱

1. **技能逻辑在客户端执行** → 正确做法：所有伤害/效果在服务端，客户端只做表现
2. **忘记验证蓝量/冷却** → 正确做法：BaseSkill 基类统一处理前置验证
3. **弹道 Part 未清理** → 正确做法：设超时销毁 + 命中后立即销毁
4. **效果 ID 冲突** → 正确做法：按英雄 ID 段位分配，每英雄 20 个 ID 位
5. **硬控不走互斥组** → 正确做法：Stun/Knockup/Root 等硬控必须设 MutexGroup="HardCC"
6. **技能伤害直接扣血** → 正确做法：通过 EffectExecutor 走统一伤害管线（计算防御/穿透/护盾）

## 📋 检查清单

- [ ] 新英雄是否包含完整 4 件套（英雄配置/技能数据/效果配置/技能逻辑）
- [ ] 技能 ID 是否在正确的段位范围内
- [ ] 效果 ID 是否不与已有 ID 冲突
- [ ] 所有伤害是否走 BuffSystem:ApplyEffect 管线
- [ ] 弹道/区域 Part 是否有超时清理机制
- [ ] 硬控效果是否设置了 MutexGroup
- [ ] VFX/SFX 事件是否正确发送到客户端

## 🔗 关联技能

- [Roblox Instance 与服务模式](../roblox/instance-patterns.md)
- [事件与通信模式](../architecture/event-system.md)
- [Luau Nil 安全与类型模式](../luau/nil-safety.md)

### 王者→Roblox 英雄移植系统
- [AGE XML 结构解析](./age-xml-schema.md) — 王者 AGE 事件类型与 XML 结构
- [王者→Roblox 映射规则](./hok-to-roblox-mapping.md) — 配置表字段映射与单位转换
- [英雄移植标准 SOP](./hero-translation-sop.md) — 5步移植流程 + Luau 代码模板
- [英雄移植参考样本](./hero-translation-reference.md) — 已有 4 英雄配置对照
