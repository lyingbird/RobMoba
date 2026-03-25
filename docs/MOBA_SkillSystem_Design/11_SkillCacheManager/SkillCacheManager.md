# 11 — 缓冲区管理 SkillCacheManager

> **文件路径**: `StarterPlayerScripts/SkillSystem/SkillCacheManager.lua`  
> **重要性**: ★★★★★ 这是影响操作手感的核心模块

---

## 设计说明

缓冲区系统是MOBA连招手感的灵魂。它解决的核心问题是：**当前技能还在释放中，玩家按了下一个技能怎么办？**

答案：缓存起来，前序技能结束后自动释放。

### 四大子系统

| 子系统 | 功能 | 来源 |
|---|---|---|
| 技能缓冲队列 | 技能释放中按其他技能→入队 | `PushCacheSkillList()` 第333-382行 |
| 普攻缓冲标记 | 技能释放中按普攻→标记 | `SetCacheNormalAttackContext()` 第384-406行 |
| 连续普攻窗口 | 普攻CD中按普攻→窗口期内缓冲 | `SetCacheContinuAttackCacheInfo()` 第959-990行 |
| 受控保护 | 被控期间的缓存技能→解控后自动释放 | `OnBuffChange()` 第168-212行 |

### 入队逻辑（两种模式）

```
PushCacheSkillList(entry):

  窗口未生效 (cacheWindowBeginTime==0 or curTime < beginTime):
    → 覆盖模式: Clear() + Add(entry)  ← 只保留最新1个
    
  窗口已生效:
    → 追加模式: 
       if #cacheList < maxCount:
           Add(entry)              ← 追加到末尾
       else:
           丢弃                    ← 队列已满
```

**设计意图**：窗口未生效意味着还没进入技能动画的"可缓存阶段"，此时只保留最新操作（覆盖）。窗口生效后允许多个缓存（连招序列）。

### 出队逻辑（优先级）

```
UseSkillCache():

  ① 过期检查 → 清空
  ② 普攻缓存 (cacheCommonAttack) → 释放普攻
  ③ 技能缓存 (cacheList[1]) → 释放技能
  ④ 什么都没有 → 什么都不做
```

**优先级**：普攻 > 技能。这确保了玩家在连招间隙点普攻能立即出手。

---

## 完整伪代码

```lua
-- 文件: StarterPlayerScripts/SkillSystem/SkillCacheManager.lua

local GCfg = require(game.ReplicatedStorage.SkillSystem.Config.GlobalConfig)

local SCM = {}; SCM.__index = SCM

function SCM.new(deps)
    local self = setmetatable({}, SCM)
    
    -- ========== 依赖 ==========
    self._remoteEvent = deps.skillRemoteEvent   -- RemoteEvent 引用
    self._getSlot     = deps.getSlotFunc        -- 函数: (slotType) → SkillSlot
    self._onExecute   = deps.onExecuteCallback  -- 函数: (skillParam) 通知外部
    
    -- ========== 技能缓冲队列 ==========
    self._cacheList = {}                        -- {CacheEntry, ...}
    self._maxCount  = GCfg.SKILL_CACHE_MAX_COUNT  -- 默认 1
    
    -- ========== 普攻缓冲 ==========
    self._cacheCommonAttack = false             -- 是否缓冲了普攻
    self._cacheContinueCommonAttack = false     -- 连续普攻缓冲
    
    -- ========== 连续普攻窗口 ==========
    self._continueWindowBegin = 0               -- os.clock() 基准
    self._continueWindowEnd   = 0
    self._pursueWindowBegin   = 0
    
    -- ========== 缓存窗口 ==========
    -- 中由 AGE 动画轨道 缓存窗口机制 控制
    -- Roblox 简化为由技能释放事件触发
    self._cacheWindowActive = false
    self._cacheWindowBeginTime = 0
    
    -- ========== 过期 ==========
    self._lastCacheTick = 0                     -- 最后一次入队的时间戳
    
    -- ========== 受控保护 ==========
    self._controlProtectExpire = 0              -- 受控保护过期时间
    
    -- ========== 可释放标记 ==========
    self._canCast = true                        -- 外部设置：当前是否可释放技能
    
    return self
end
```

### TryExecuteOrBuffer — 主入口

```lua
-- 由 SkillController._Execute() 调用
-- 返回 true = 已释放，false = 已缓冲或忽略

function SCM:TryExecuteOrBuffer(param): boolean
    if self._canCast then
        -- 当前可释放 → 直接发送
        self:_FireSkill(param)
        return true
    else
        -- 当前不可释放 → 缓冲
        self:PushToCache({
            skillParam = param,
            timestamp = os.clock(),
            isCommonAttack = (param.slotType == 0),
        })
        return false
    end
end
```

### PushToCache — 入队

```lua
-- 来源: SkillCache::PushCacheSkillList() 第333-382行
--
-- 两种模式:
--   覆盖模式: 窗口未生效 → Clear + Add（只保留最新1个）
--   追加模式: 窗口已生效 → Add（满则丢弃）

function SCM:PushToCache(entry)
    -- 普攻走独立标记通道
    if entry.isCommonAttack then
        self._cacheCommonAttack = true
        -- : 普攻入队时清理技能缓存中的普攻
        -- (除非配置 noClearCommonAttackWhenSkillCache)
        -- Roblox 版简化: 普攻只用标记
        return
    end

    self._lastCacheTick = os.clock()

    -- 判断缓存窗口是否生效
    if not self._cacheWindowActive
        or os.clock() < self._cacheWindowBeginTime then
        
        -- ★ 覆盖模式: 清空后只保留最新1个
        -- 设计意图: 窗口未生效说明还没进入可缓存阶段
        -- 此时玩家的"最终意图"是最后一次按下的技能
        self._cacheList = {}
        table.insert(self._cacheList, entry)
    else
        -- ★ 追加模式: 队列未满则追加
        if #self._cacheList < self._maxCount then
            table.insert(self._cacheList, entry)
        end
        -- 满了就丢弃（不做任何提示）
    end
end
```

### TryUseCache — 出队

```lua
-- 来源: SkillCache::UseSkillCache() 第618-755行
-- 由 SkillController.OnSkillCastFinished() 在技能释放完毕后调用

function SCM:TryUseCache()
    -- ① 过期检查
    -- 来源: CheckSkillCacheExpried() 第843-858行
    if self:_IsExpired() then
        self:Clear()
        return
    end

    -- ② 普攻缓存优先
    -- 逻辑: cacheCommonAttack && !IgnoreCommonAttack
    --           && cacheComAtkIndexInSkillList <= currentIndex
    -- Roblox 简化: 普攻标记存在就优先
    if self._cacheCommonAttack then
        self._cacheCommonAttack = false
        self:_FireSkill({
            slotType  = 0,
            skillId   = 0,     -- 普攻不需要 skillId
            rangeType = 0,
        })
        return
    end

    -- ③ 技能缓存
    if #self._cacheList > 0 then
        local entry = table.remove(self._cacheList, 1)  -- FIFO 取队首
        -- 校验: 槽位是否仍然可用（可能已在冷却中等）
        local slot = self._getSlot(entry.skillParam.slotType)
        if slot and slot.isEnabled then
            self:_FireSkill(entry.skillParam)
        end
        -- 槽位不可用 → 静默丢弃这个缓存
        return
    end

    -- ④ 队列为空，什么都不做
end
```

### 连续普攻窗口

```lua
-- ================================================================
-- 连续普攻窗口
-- ================================================================
-- 来源: SkillCache::SetCacheContinuAttackCacheInfo() 第959-990行
-- 调用时机: 普攻 CD 开始时 (SkillCD.StartSkillCD 第448-453行)
--
-- 公式:
--   windowBegin = curTime + attackCD × BeginPercent / 100
--   windowEnd   = curTime + attackCD + frameDelta × 2
--   pursueBegin = curTime + attackCD × PursueBeginPercent / 100
--
-- 含义:
--   普攻打出后，CD进行到 70% 时开始接受"连续普攻"缓冲
--   直到 CD 结束后再多 2 帧
--   追击窗口从 50% 处开始（允许移动追击+普攻）

function SCM:SetContinueAttackWindow(attackCD: number)
    local now = os.clock()
    local beginPct  = GCfg.CONTINUE_ATTACK_WINDOW_BEGIN_PCT / 100  -- 0.7
    local pursuePct = GCfg.CONTINUE_PURSUE_WINDOW_BEGIN_PCT / 100  -- 0.5
    local frameDelta = 1/60 * 2  -- 约 0.033 秒（2帧裕度）
    
    self._continueWindowBegin = now + attackCD * beginPct
    self._continueWindowEnd   = now + attackCD + frameDelta
    self._pursueWindowBegin   = now + attackCD * pursuePct
end

-- 检查当前是否在连续普攻窗口内
function SCM:IsInContinueAttackWindow(): boolean
    local now = os.clock()
    return now >= self._continueWindowBegin and now < self._continueWindowEnd
end

-- 来源: SetCacheContinueNormalAttackContext() 第408-435行
-- 在窗口期内按下普攻 → 标记连续普攻缓冲
function SCM:SetContinueCommonAttackCache()
    if self:IsInContinueAttackWindow() then
        self._cacheContinueCommonAttack = true
    end
end
```

### 连续普攻窗口时序图

```
普攻打出                         CD结束
  │                                │
  ├───────────────────────────────┤
  │        attackCD               │
  │                               │
  │    50%        70%     100%   +2帧
  │     ↓          ↓       ↓      ↓
  │  pursueBegin  windowBegin   windowEnd
  │     │          │              │
  │     ├──────────┤              │
  │     │ 追击窗口  │              │
  │     │          ├──────────────┤
  │     │          │ 连续普攻窗口  │
  │     │          │              │
  
  在 70%~结束+2帧 之间按普攻 → 缓冲
  在 50%~70% 之间按普攻 → 可追击+缓冲
```

### 受控保护

```lua
-- ================================================================
-- 受控保护机制
-- ================================================================
-- 来源: SkillCache::OnBuffChange() 第168-212行
--
-- 场景: 玩家正在连招，突然被眩晕
-- 期望: 眩晕结束后，之前缓存的技能自动释放（如果在保护窗口内）
--
-- 流程:
--   硬控开始 → 如果缓存窗口激活 → 记录保护过期时间
--   硬控结束 → 
--     在保护时间内 → 自动 TryUseCache()
--     过了保护时间 → Clear()（太久了，缓存失效）

function SCM:OnControlStart()
    if self._cacheWindowActive then
        self._controlProtectExpire = os.clock() + GCfg.CONTROL_PROTECT_DURATION
    end
end

function SCM:OnControlEnd()
    if os.clock() <= self._controlProtectExpire then
        -- 在保护窗口内解控 → 自动释放缓存
        self:TryUseCache()
    else
        -- 过了保护时间 → 清空（缓存已经过时了）
        self:Clear()
    end
end
```

### Clear / IsExpired / 缓存窗口控制

```lua
-- 清空所有缓存
-- 触发场景: 死亡、切AutoAI、受控超时
function SCM:Clear()
    self._cacheList = {}
    self._cacheCommonAttack = false
    self._cacheContinueCommonAttack = false
end

-- 来源: CheckSkillCacheExpried() 第843-858行
-- 判断缓存是否过期: 距上次入队时间 > SKILL_CACHE_EXPIRED_TIME
function SCM:_IsExpired(): boolean
    if self._lastCacheTick == 0 then return false end
    return (os.clock() - self._lastCacheTick) > GCfg.SKILL_CACHE_EXPIRED_TIME
end

-- 缓存窗口控制
-- 中由 AGE 动画轨道 缓存窗口机制 的 Enter()/Leave() 触发
-- Roblox 中由技能释放动画事件触发

function SCM:EnableCacheWindow()
    self._cacheWindowActive = true
    self._cacheWindowBeginTime = os.clock()
end

function SCM:DisableCacheWindow()
    self._cacheWindowActive = false
end

-- 设置是否可释放（外部控制）
function SCM:SetCanCast(can: boolean)
    self._canCast = can
end
```

### 内部：发送技能请求

```lua
function SCM:_FireSkill(param)
    self._remoteEvent:FireServer(param)
    if self._onExecute then
        self._onExecute(param)
    end
end

return SCM
```

---

## 缓冲区常量速查

| 常量 | 值 | 枚举 | 含义 |
|---|---|---|---|
| `SKILL_CACHE_MAX_COUNT` | 1  `SKILL_CACHE_EXPIRED_TIME` | 2.0s  `CONTINUE_ATTACK_WINDOW_BEGIN_PCT` | 70%  `CONTINUE_PURSUE_WINDOW_BEGIN_PCT` | 50%  `CONTROL_PROTECT_DURATION` | 0.5s | 缓存窗口机制 | 受控保护窗口 |

---

## 清理场景汇总

| 场景 | 操作 |
|---|---|
| 死亡 | `Clear()` |
| 切 AutoAI | `Clear()` |
| 受控解除后过期 | `Clear()` |
| 新技能入队时 | `ClearCommonAttackCache()` |
| 缓存过期 | `Clear()` |

---

> **下一步**: `12_CommonAttackController/`
