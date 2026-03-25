# 12 — 普攻控制器 CommonAttackController

> **文件路径**: `StarterPlayerScripts/SkillSystem/CommonAttackController.lua`  
> **HOK 来源**: 普攻相关逻辑分散在 `SkillCache.cpp`、`ActorControler.cpp` 中  
> **精简策略**: 只保留基础索敌（最近目标），去掉 HOK 的4种精准索敌策略

---

## 设计说明

HOK 的普攻系统相当复杂，包含：
- 4种索敌策略（最近/朝向偏好/血量最低/最近攻击过的）
- 普攻移动追击
- 连续普攻窗口期
- 普攻拖动选择目标

Roblox 版精简为最基础的"按下即攻击最近目标"。

## 完整伪代码

```lua
-- 文件: StarterPlayerScripts/SkillSystem/CommonAttackController.lua
-- 精简为1种基础策略（最近目标）

local CAC = {}; CAC.__index = CAC

function CAC.new(deps)
    local self = setmetatable({}, CAC)
    self._cache = deps.skillCacheManager         -- SkillCacheManager 引用
    self._remoteEvent = deps.attackRemoteEvent   -- 普攻 RemoteEvent
    self._isAttacking = false                    -- 是否正在攻击中
    return self
end

-- 按下普攻按钮
-- 如果当前有技能释放中 → 缓冲
-- 否则 → 直接攻击
function CAC:OnButtonDown()
    if not self._cache._canCast then
        -- 当前不可释放（技能释放中）→ 标记普攻缓冲
        self._cache._cacheCommonAttack = true
        return
    end
    self:_DoAttack()
end

-- 普攻拖动
-- 本版本不实现精准目标选择
-- 高级版可添加: 拖动锁定特定目标
function CAC:OnButtonDrag(pos)
    -- 预留接口
end

-- 普攻抬起
function CAC:OnButtonUp()
    -- 预留接口
end

-- 执行普攻
function CAC:_DoAttack()
    self._remoteEvent:FireServer({slotType = 0})
end

return CAC
```

---

## 与 SkillCacheManager 的交互

```
玩家按普攻:
  ├── canCast == true → _DoAttack() → FireServer
  └── canCast == false → cacheCommonAttack = true
                           ↓
                  技能释放完毕后
                  SkillCacheManager:TryUseCache()
                  ② 检查 cacheCommonAttack
                     → true → 释放普攻

连续普攻:
  普攻CD开始 → SetContinueAttackWindow(attackCD)
  普攻CD 70%处 → 窗口开启
  玩家再次按普攻 → SetContinueCommonAttackCache()
  普攻CD结束 → 自动释放缓冲的普攻
```

---

## 扩展建议

如果需要更接近 HOK 的普攻体验，可以扩展以下功能：

### 1. 索敌策略

```lua
-- HOK 有4种策略，可按需实现
function CAC:_FindTarget(strategy)
    if strategy == "nearest" then
        -- 最近目标（当前实现）
    elseif strategy == "facing" then
        -- 角色朝向偏好（±30°内优先）
    elseif strategy == "lowestHP" then
        -- 血量最低
    elseif strategy == "lastAttacked" then
        -- 最近攻击过的目标（仇恨列表）
    end
end
```

### 2. 普攻拖动选择

```lua
-- HOK: 长按普攻按钮并拖动可精确选择目标
function CAC:OnButtonDrag(pos)
    -- 计算拖动方向
    -- 在扇形范围内搜索敌方
    -- 高亮显示锁定的目标
end
```

### 3. 移动追击

```lua
-- HOK: 普攻目标超出攻击范围时自动走过去
function CAC:_MoveAndAttack(targetId)
    -- 移动到目标身边
    -- 到达后自动攻击
end
```

---

> **下一步**: `13_Server/`
