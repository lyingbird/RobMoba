# 13 — 服务端校验与执行

> **文件路径**: `ServerScriptService/SkillSystem/SkillValidator.lua` + `SkillExecutor.lua`

---

## 设计说明

Roblox 的客户端-服务端模型通过 `RemoteEvent` 通信。客户端构建 `SkillParam` 后通过 `FireServer()` 发送到服务端，服务端需要：

1. **校验** — 防作弊，确认技能可以释放
2. **执行** — 扣蓝、启动CD、应用效果
3. **通知** — 告诉客户端播放动画和特效

### Roblox 通信架构

```
客户端                                    服务端
SkillController                     SkillValidator
  │                                      │
  ├─ FireServer(SkillParam) ──────────→  Validate()
  │                                      │
  │                                  SkillExecutor
  │                                      │
  │                                  Execute()
  │                                      │
  ←── FireClient(result) ────────────────┤
  │                                      
  ├─ 播放动画                            
  ├─ 通知 SkillCacheManager             
  └─ OnSkillCastFinished()              
```

---

## SkillValidator.lua — 服务端校验

```lua
-- 文件: ServerScriptService/SkillSystem/SkillValidator.lua


local SkillConfig = require(game.ReplicatedStorage.SkillSystem.Config.SkillConfig)

local SV = {}; SV.__index = SV

function SV.new()
    return setmetatable({}, SV)
end

-- 校验清单 
--
--   ① 技能配置是否存在
--   ② CD 是否就绪
--   ③ 蓝量是否足够
--   ④ 是否被沉默/眩晕（硬控状态下不能释放技能）
--   ⑤ 目标距离是否在施法范围内
--   ⑥ 目标是否合法（存活、可见、非友方）
--
-- 返回: (通过: boolean, 失败原因: string?)

function SV:Validate(player, param): (boolean, string?)
    -- ① 配置校验
    local cfg = SkillConfig[param.skillId]
    if not cfg then
        return false, "INVALID_SKILL"
    end
    
    -- ② CD 校验
    -- 实现者接入自己的 CD 管理系统
    -- local cdManager = getPlayerCDManager(player)
    -- if cdManager:IsOnCooldown(param.slotType) then
    --     return false, "ON_COOLDOWN"
    -- end
    
    -- ③ 蓝量校验
    -- local mana = getPlayerMana(player)
    -- if mana < cfg.manaCost then
    --     return false, "NOT_ENOUGH_MANA"
    -- end
    
    -- ④ 控制状态校验
    -- local cc = getPlayerCCState(player)
    -- if cc.isSilenced or cc.isStunned then
    --     return false, "UNDER_CONTROL"
    -- end
    
    -- ⑤ 距离校验 (针对 Target/Pos 型)
    -- if param.targetPosition then
    --     local dist = (param.targetPosition - getPlayerPosition(player)).Magnitude
    --     if dist > cfg.castRange * 1.1 then  -- 10% 容差
    --         return false, "OUT_OF_RANGE"
    --     end
    -- end
    
    -- ⑥ 目标合法性校验 (针对 Target 型)
    -- if param.targetActorId and param.targetActorId > 0 then
    --     local target = getActor(param.targetActorId)
    --     if not target or target.isDead or target.team == player.team then
    --         return false, "INVALID_TARGET"
    --     end
    -- end
    
    return true, nil
end

return SV
```

---

## SkillExecutor.lua — 技能执行

```lua
-- 文件: ServerScriptService/SkillSystem/SkillExecutor.lua


local SkillConfig = require(game.ReplicatedStorage.SkillSystem.Config.SkillConfig)

local SE = {}; SE.__index = SE

function SE.new()
    return setmetatable({}, SE)
end

-- 执行技能
-- 流程:
--   ① 扣蓝
--   ② 启动 CD
--   ③ 应用效果（伤害/buff/位移等）
--   ④ 通知所有客户端播放动画
--   ⑤ 通知释放者客户端技能释放完毕（触发缓冲区出队）

function SE:Execute(player, param)
    local cfg = SkillConfig[param.skillId]
    if not cfg then return end
    
    -- ① 扣蓝
    -- deductMana(player, cfg.manaCost)
    
    -- ② 启动 CD
    -- startCooldown(player, param.slotType, cfg.cooldown)
    
    -- ③ 应用效果
    -- 根据技能类型和参数应用不同效果
    -- 这部分是游戏逻辑核心，与技能系统框架解耦
    -- applySkillEffect(player, param)
    
    -- ④ 通知所有客户端播放动画
    -- game.ReplicatedStorage.Events.SkillAnimation:FireAllClients({
    --     playerId = player.UserId,
    --     skillId = param.skillId,
    --     targetPos = param.targetPosition,
    --     targetDir = param.targetDirection,
    -- })
    
    -- ⑤ 通知释放者技能释放完毕
    -- 延迟：技能动画时长后触发
    -- task.delay(cfg.castDuration or 0.5, function()
    --     game.ReplicatedStorage.Events.SkillCastFinished:FireClient(
    --         player, {slotType = param.slotType}
    --     )
    -- end)
end

return SE
```

---

## 服务端入口脚本

```lua
-- 文件: ServerScriptService/SkillSystem/SkillServerInit.server.lua
-- 连接 RemoteEvent 和校验+执行流程

local validator = require(script.Parent.SkillValidator).new()
local executor = require(script.Parent.SkillExecutor).new()

-- 技能释放 RemoteEvent
local skillEvent = Instance.new("RemoteEvent")
skillEvent.Name = "SkillEvent"
skillEvent.Parent = game.ReplicatedStorage.Events

skillEvent.OnServerEvent:Connect(function(player, param)
    -- 校验
    local ok, reason = validator:Validate(player, param)
    if not ok then
        warn(("[SkillValidator] %s failed: %s"):format(player.Name, reason))
        return
    end
    
    -- 执行
    executor:Execute(player, param)
end)

-- 普攻 RemoteEvent
local attackEvent = Instance.new("RemoteEvent")
attackEvent.Name = "AttackEvent"
attackEvent.Parent = game.ReplicatedStorage.Events

attackEvent.OnServerEvent:Connect(function(player, param)
    -- 普攻校验和执行（简化）
    executor:Execute(player, {
        slotType = 0,
        skillId = 0,
        rangeType = 0,
    })
end)
```

---

## 安全注意事项

| 风险 | 防范 | 说明 |
|---|---|---|
| 客户端伪造 skillId | 服务端查配置表校验 | 不存在的 skillId 直接拒绝 |
| CD 作弊 | 服务端独立维护 CD 计时器 | 不信任客户端的 CD 状态 |
| 蓝量作弊 | 服务端独立维护蓝量 | 不信任客户端的蓝量值 |
| 目标位置超距 | 距离校验 + 10% 容差 | 容差应对网络延迟 |
| 频率攻击 | 速率限制（每秒最多N次） | 防止刷技能 |
| 伪造目标ID | 查目标是否存活、非友方 | 防止选中无效目标 |

---

> **下一步**: `14_AntiMistouch/`
