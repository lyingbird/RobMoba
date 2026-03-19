--[[
    SkillSystem.luau
    技能系统入口
    
    职责：
    - 监听客户端 SkillCast 请求
    - 监听客户端 BasicAttack 请求（普攻）
    - 校验合法性（CD、蓝量、状态）
    - 从 SkillEventTable 读取事件时间轴
    - 交给 EventScheduler 执行
    - 被动技能触发（攻速叠加、灼烧印记等）
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillSystem = {}

local remotes = nil
local eventScheduler = nil
local statusEffectManager = nil
local DataManager = nil
local SkillEventTable = nil
local EventHandlers = nil  -- 缓存，init 时加载
local BasicAttackService = require(script.Parent.services.BasicAttackService)
local SkillLoadoutService = require(script.Parent.services.SkillLoadoutService)
local SkillTargeting = require(script.Parent.services.SkillTargeting)

-- 普攻计数（廉颇第3下强化）: { [Player] = number }
local attackCounts = {}

-- 普攻冷却: { [Player] = number (tick) }
local attackCooldowns = {}

--============================================================
-- 廉颇战意系统
--============================================================

-- 战意值: { [character] = number (0~100) }
local zhanYiValues = {}

-- 战斗状态: { [character] = { inCombat = bool, lastCombatTime = number, updateTask = thread? } }
local combatStates = {}

-- 战意满额攻速加成已激活: { [character] = bool }
local zhanYiFullBonusActive = {}

-- 基础攻速备份（用于战意攻速加成恢复）: { [character] = number }
local zhanYiBaseAttackSpeeds = {}

-- 脱战判定时间（秒）
local OUT_OF_COMBAT_DELAY = 5

--============================================================
-- 初始化
--============================================================

function SkillSystem.init(remotesRef, eventSchedulerRef, statusEffectManagerRef)
    remotes = remotesRef
    eventScheduler = eventSchedulerRef
    statusEffectManager = statusEffectManagerRef
    
    local shared = ReplicatedStorage:WaitForChild("Shared")
    DataManager = require(shared:WaitForChild("DataManager"))
    SkillEventTable = require(shared:WaitForChild("SkillEventTable"))
    BasicAttackService.init(SkillEventTable)
    SkillLoadoutService.init(DataManager)
    
    -- 缓存 EventHandlers（避免每次被动触发都 require）
    EventHandlers = require(script.Parent:WaitForChild("EventHandlers"))
    
    -- 监听技能释放请求
    if remotes.SkillCast then
        remotes.SkillCast.OnServerEvent:Connect(function(player, data)
            SkillSystem._onSkillCast(player, data)
        end)
    end
    
    -- 监听普攻请求
    if remotes.BasicAttack then
        remotes.BasicAttack.OnServerEvent:Connect(function(player, data)
            SkillSystem._onBasicAttack(player, data)
        end)
    end
    
    -- 注意：HeroSelect 由 HeroManager/GameManager 统一处理
    -- SkillSystem 通过 syncPlayerHero 接收英雄选择数据，避免重复监听
    
    -- 监听持续施法取消
    if remotes.ChannelCancel then
        remotes.ChannelCancel.OnServerEvent:Connect(function(player, data)
            SkillSystem._onChannelCancel(player, data)
        end)
    end
    
    -- 玩家离开时清理
    Players.PlayerRemoving:Connect(function(player)
        local character = player.Character
        if character then
            SkillSystem._cleanupZhanYi(character)
        end
        SkillLoadoutService.clearPlayer(player)
        BasicAttackService.clearPlayerState(player, attackCounts, attackCooldowns)
    end)
    
    print("[SkillSystem] 初始化完成")
end

--============================================================
-- 英雄选择同步（由 HeroManager/GameManager 调用）
-- 注：属性设置、技能栏通知等均由 HeroManager 统一处理
--============================================================

function SkillSystem.syncPlayerHero(player, heroId: string)
    local ok = SkillLoadoutService.syncPlayerHero(player, heroId)
    if not ok then return end

    BasicAttackService.resetPlayerState(player, attackCounts, attackCooldowns)

    local heroData = DataManager.getHero(heroId)
    print("[SkillSystem] 同步英雄选择: " .. player.Name .. " -> " .. heroData.name)
end

--============================================================
-- 普攻系统
--============================================================

function SkillSystem._onBasicAttack(player, data)
    if not data then return end
    
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    local heroId = SkillLoadoutService.getPlayerHero(player)
    if not heroId then return end
    
    local attackRequest, err = BasicAttackService.resolveAttackRequest(
        player,
        character,
        heroId,
        data,
        attackCounts,
        attackCooldowns,
        {
            eventScheduler = eventScheduler,
            statusEffectManager = statusEffectManager,
        }
    )
    if not attackRequest then
        if err == "missing_basic_attack" then
            warn("[SkillSystem] 英雄无普攻配置: " .. heroId)
        end
        return
    end

    local direction = SkillTargeting.normalizeDirection(data.direction)
    
    -- 执行普攻时间轴
    eventScheduler.executeTimeline({
        caster = character,
        direction = direction,
        targetPosition = attackRequest.targetPosition,
        skillId = "basic_attack_" .. heroId,
        timeline = attackRequest.timeline,
    })
    
    -- 触发被动（普攻命中后的被动效果）
    -- 后羿被动：普攻命中叠加攻速印记
    SkillSystem._triggerPassive(player, heroId, "onBasicAttackHit")
    
    -- 标记进入战斗（廉颇战意系统）
    SkillSystem.markInCombat(character)
end

--============================================================
-- 被动触发
--============================================================

-- 后羿攻速基础值: { [character] = baseAttackSpeed }
local baseAttackSpeeds = {}

function SkillSystem._triggerPassive(player, heroId: string, triggerType: string)
    local passive = SkillEventTable.getPassive(heroId)
    if not passive then return end
    if passive.passiveType ~= triggerType then return end
    
    local character = player.Character
    if not character then return end
    
    if passive.onTrigger then
        for _, subEvent in ipairs(passive.onTrigger) do
            local context = {
                caster = character,
                direction = Vector3.new(0, 0, -1),
                skillId = heroId .. "_passive",
                bullets = {},
                hitTarget = character, -- 被动效果作用于自身
                cancelled = false,
            }
            -- AddMark 对自身（后羿攻速印记叠加在自身）
            EventHandlers.executeEvent(context, subEvent)
        end
    end
    
    -- === 后羿被动：攻速叠加（每层 +4% 攻速，实际修改 AttackSpeed 属性）===
    if heroId == "houyi" then
        SkillSystem._applyAttackSpeedStack(character)
    end
    
    -- 检查是否满层触发特殊效果
    if passive.onMaxStack then
        local markId = nil
        -- 从 onTrigger 中找到 AddMark 获取 markId
        if passive.onTrigger then
            for _, ev in ipairs(passive.onTrigger) do
                if ev.params and ev.params.markId then
                    markId = ev.params.markId
                    break
                end
            end
        end
        if markId then
            local stacks = statusEffectManager.getMarkStacks(character, markId)
            local maxStack = 3 -- 默认
            if passive.onTrigger then
                for _, ev in ipairs(passive.onTrigger) do
                    if ev.params and ev.params.maxStack then
                        maxStack = ev.params.maxStack
                        break
                    end
                end
            end
            if stacks >= maxStack then
                for _, subEvent in ipairs(passive.onMaxStack) do
                    local context = {
                        caster = character,
                        direction = Vector3.new(0, 0, -1),
                        skillId = heroId .. "_passive",
                        bullets = {},
                        hitTarget = character,
                        cancelled = false,
                    }
                    EventHandlers.executeEvent(context, subEvent)
                end
                -- 满层后重置印记 → 恢复基础攻速
                statusEffectManager.clearMarks(character, markId)
                SkillSystem._resetAttackSpeed(character)
            end
        end
    end
end

--============================================================
-- 后羿被动：攻速叠加（每层 +4% 攻速）
--============================================================

function SkillSystem._applyAttackSpeedStack(character)
    local asValue = character:FindFirstChild("AttackSpeed")
    if not asValue or not asValue:IsA("NumberValue") then return end
    
    -- 记录基础攻速（首次调用时）
    if not baseAttackSpeeds[character] then
        baseAttackSpeeds[character] = asValue.Value
        -- 角色移除时清理
        character.AncestryChanged:Connect(function(_, parent)
            if not parent then
                baseAttackSpeeds[character] = nil
            end
        end)
    end
    
    local baseAS = baseAttackSpeeds[character]
    local stacks = statusEffectManager.getMarkStacks(character, "houyi_passive")
    
    -- 每层 +4% 攻速
    local speedBonus = 1 + stacks * 0.04
    asValue.Value = baseAS * speedBonus
end

function SkillSystem._resetAttackSpeed(character)
    local asValue = character:FindFirstChild("AttackSpeed")
    if not asValue or not asValue:IsA("NumberValue") then return end
    
    if baseAttackSpeeds[character] then
        asValue.Value = baseAttackSpeeds[character]
    end
end

-- 技能命中后触发被动（安琪拉咒术火焰：叠层 + 灼烧DoT + 移速加成）
function SkillSystem.triggerSkillHitPassive(caster, target, heroId: string)
    local passive = SkillEventTable.getPassive(heroId)
    if not passive then return end
    if passive.passiveType ~= "onSkillHit" then return end
    
    if passive.onTrigger then
        for _, subEvent in ipairs(passive.onTrigger) do
            local context = {
                caster = caster,
                direction = Vector3.new(0, 0, -1),
                skillId = heroId .. "_passive",
                bullets = {},
                hitTarget = target,
                cancelled = false,
            }
            EventHandlers.executeEvent(context, subEvent)
        end
    end
    
    -- === 安琪拉被动：灼烧DoT + 移速加成 + 逐层消失 ===
    if heroId == "angela" and passive.burnParams then
        local burnParams = passive.burnParams
        local markId = "angela_burn"
        local stacks = statusEffectManager.getMarkStacks(target, markId)
        
        if stacks > 0 then
            -- 启动/刷新灼烧 DoT（逐层衰减模式）
            SkillSystem._startBurnDoT(caster, target, stacks, burnParams)
            
            -- 施法者每层 +2% 移速（刷新）
            SkillSystem._applyPassiveSpeedBuff(caster, stacks)
        end
    end
end

--============================================================
-- 安琪拉被动：灼烧 DoT 系统（逐层衰减模式）
-- ✅ 王者荣耀官方机制：
-- - 技能命中叠层，刷新3秒持续时间
-- - 3秒持续时间结束后开始逐层消失（每秒减1层）
-- - 每层提供灼烧伤害: stacks × damagePerStack + stacks × apRatioPerStack × AP
-- - 每层提供移速: 施法者 +2% 移速
-- - 层数减少期间仍有灼烧伤害（按当前层数计算）
--============================================================

-- 活跃灼烧: { [target] = { task = thread, caster = Model, burnParams = table } }
local activeBurns = {}

function SkillSystem._startBurnDoT(caster, target, stacks: number, burnParams)
    -- 如果已有灼烧，先取消旧的（刷新）
    if activeBurns[target] then
        if activeBurns[target].task then
            task.cancel(activeBurns[target].task)
        end
    end
    
    local damagePerStack = burnParams.damagePerStack or 8
    local apRatioPerStack = burnParams.apRatioPerStack or 0.02
    local tickInterval = burnParams.tickInterval or 1.0
    local decayInterval = burnParams.decayInterval or 1.0
    local markDuration = 3  -- 印记持续3秒后开始逐层消失
    
    activeBurns[target] = {
        caster = caster,
        burnParams = burnParams,
        task = task.spawn(function()
            -- 接管印记生命周期：取消 addMark 设置的自动移除计时器
            statusEffectManager.cancelMarkRemoveTask(target, "angela_burn")
            
            -- === 阶段1：稳定期（3秒内层数不变，每秒造成灼烧伤害）===
            local stableTicks = math.floor(markDuration / tickInterval)
            for i = 1, stableTicks do
                task.wait(tickInterval)
                
                -- 目标/施法者存活检查
                if not target or not target.Parent then break end
                local humanoid = target:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Health <= 0 then break end
                if not caster or not caster.Parent then break end
                
                -- 重新获取当前层数（可能被新命中刷新）
                local currentStacks = statusEffectManager.getMarkStacks(target, "angela_burn")
                if currentStacks <= 0 then break end
                
                -- 造成灼烧伤害
                SkillSystem._dealBurnDamage(caster, target, currentStacks, damagePerStack, apRatioPerStack)
            end
            
            -- === 阶段2：逐层消失期（每秒减1层，同时每层仍造成灼烧伤害）===
            while true do
                -- 检查当前层数
                local currentStacks = statusEffectManager.getMarkStacks(target, "angela_burn")
                if currentStacks <= 0 then break end
                
                -- 减少1层印记
                statusEffectManager.reduceMarkStacks(target, "angela_burn", 1)
                local newStacks = statusEffectManager.getMarkStacks(target, "angela_burn")
                
                -- 更新施法者移速（层数减少了）
                if newStacks > 0 then
                    SkillSystem._applyPassiveSpeedBuff(caster, newStacks)
                end
                
                -- 通知客户端印记更新
                if remotes and remotes.MarkUpdate then
                    remotes.MarkUpdate:FireAllClients({
                        targetModel = target,
                        markId = "angela_burn",
                        stacks = newStacks,
                        maxStacks = 10,
                    })
                end
                
                if newStacks <= 0 then break end
                
                task.wait(decayInterval)
                
                -- 存活检查
                if not target or not target.Parent then break end
                local humanoid = target:FindFirstChildOfClass("Humanoid")
                if not humanoid or humanoid.Health <= 0 then break end
                if not caster or not caster.Parent then break end
                
                -- 重新获取（可能被新命中刷新了）
                local refreshedStacks = statusEffectManager.getMarkStacks(target, "angela_burn")
                if refreshedStacks <= 0 then break end
                
                -- 逐层消失期间仍造成灼烧伤害
                SkillSystem._dealBurnDamage(caster, target, refreshedStacks, damagePerStack, apRatioPerStack)
            end
            
            -- 灼烧结束，清理
            if activeBurns[target] then
                activeBurns[target] = nil
            end
        end),
    }
end

-- 灼烧伤害计算+造成+通知
function SkillSystem._dealBurnDamage(caster, target, stacks: number, damagePerStack: number, apRatioPerStack: number)
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    -- 计算灼烧伤害: stacks × base + stacks × apRatio × AP
    local baseBurnDmg = stacks * damagePerStack
    local apBonus = 0
    local apValue = caster:FindFirstChild("MagicPower")
    if apValue and apValue:IsA("NumberValue") then
        apBonus = stacks * apRatioPerStack * apValue.Value
    end
    local totalBurnDmg = math.floor(baseBurnDmg + apBonus)
    
    if totalBurnDmg <= 0 then return end
    
    -- 造成灼烧伤害
    humanoid:TakeDamage(totalBurnDmg)
    
    -- 通知客户端显示灼烧伤害数字
    if remotes and remotes.DamageDealt then
        local rootPart = target:FindFirstChild("HumanoidRootPart")
        if rootPart then
            remotes.DamageDealt:FireAllClients({
                targetModel = target,
                amount = totalBurnDmg,
                damageType = "Magic",
                position = rootPart.Position + Vector3.new(0, 3, 0),
                isBurn = true,
            })
        end
    end
end

--============================================================
-- 安琪拉被动：每层 +2% 移速
--============================================================

-- 活跃移速加成: { [caster] = { task = thread, originalSpeed = number } }
local activeSpeedBuffs = {}

function SkillSystem._applyPassiveSpeedBuff(caster, stacks: number)
    local humanoid = caster:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- 获取基础移速（从 HeroData 或存储值）
    local baseSpeed = 16 -- 默认
    if not activeSpeedBuffs[caster] then
        baseSpeed = humanoid.WalkSpeed
        activeSpeedBuffs[caster] = { originalSpeed = baseSpeed }
    else
        baseSpeed = activeSpeedBuffs[caster].originalSpeed
    end
    
    -- 取消旧的恢复任务
    if activeSpeedBuffs[caster].task then
        task.cancel(activeSpeedBuffs[caster].task)
    end
    
    -- 每层 +2% 移速
    local speedBonus = 1 + stacks * 0.02
    humanoid.WalkSpeed = baseSpeed * speedBonus
    
    -- 移速buff在灼烧DoT逐层消失时由 _startBurnDoT 更新
    -- 这里设置一个安全超时（所有层消失后+1秒）
    local safeTimeout = 3 + stacks + 1
    activeSpeedBuffs[caster].task = task.delay(safeTimeout, function()
        if caster and caster.Parent and humanoid and humanoid.Parent then
            humanoid.WalkSpeed = baseSpeed
        end
        if activeSpeedBuffs[caster] then
            activeSpeedBuffs[caster] = nil
        end
    end)
end

--============================================================
-- 技能释放
--============================================================

function SkillSystem._onSkillCast(player, data)
    if not data or not data.skillId then return end
    
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    local heroId = SkillLoadoutService.getPlayerHero(player)
    if not heroId then
        warn("[SkillSystem] 玩家 " .. player.Name .. " 未选择英雄")
        return
    end
    
    -- 检查技能替换
    local skillId = data.skillId
    local replacements = SkillLoadoutService.getSkillReplacements(player)
    if replacements then
        for key, replacedId in pairs(replacements) do
            if replacedId == skillId then
                -- 使用替换后的技能
                break
            end
        end
    end
    
    -- 获取技能配置
    local skillData = DataManager.getSkill(skillId)
    if not skillData then
        warn("[SkillSystem] 无效的技能ID: " .. tostring(skillId))
        return
    end
    
    -- 被动技能不能主动释放
    if skillData.castType == "Passive" then return end
    
    -- 取消技能特殊处理
    local skillEvents = DataManager.getSkillEvents(skillId)
    if skillEvents and skillEvents.isCancelSkill then
        eventScheduler.cancelSkill(character)
        return
    end
    
    -- === 合法性校验 ===
    
    -- 1. 是否正在施法
    if eventScheduler.isCasting(character) then
        -- 持续施法中不能释放其他技能
        return
    end
    
    -- 2. 是否被控制
    if statusEffectManager.isControlled(character) then
        return
    end
    
    -- 3. CD 校验
    local cdFolder = character:FindFirstChild("Cooldowns")
    if cdFolder then
        local cdValue = cdFolder:FindFirstChild(skillId)
        if cdValue and cdValue:IsA("NumberValue") and cdValue.Value > tick() then
            return -- 技能冷却中
        end
    end
    
    -- 4. 蓝量校验
    local mpValue = character:FindFirstChild("MP")
    if mpValue and skillData.manaCost > 0 then
        if mpValue.Value < skillData.manaCost then
            return -- 蓝量不足
        end
        -- 扣蓝
        mpValue.Value = mpValue.Value - skillData.manaCost
    end
    
    -- === 获取事件时间轴 ===
    
    if not skillEvents then
        warn("[SkillSystem] 技能无事件时间轴: " .. skillId)
        return
    end
    
    -- === 解析方向和目标位置 ===
    local direction = SkillTargeting.normalizeDirection(data.direction)
    local targetPosition = SkillTargeting.normalizeTargetPosition(data.targetPosition)
    
    -- === 执行技能 ===
    eventScheduler.executeTimeline({
        caster = character,
        direction = direction,
        targetPosition = targetPosition,
        skillId = skillId,
        timeline = skillEvents,
    })
    
    -- 标记进入战斗（廉颇战意系统）
    SkillSystem.markInCombat(character)
end

--============================================================
-- 持续施法取消
--============================================================

function SkillSystem._onChannelCancel(player, data)
    local character = player.Character
    if not character then return end
    eventScheduler.cancelSkill(character)
end

--============================================================
-- 查询接口
--============================================================

function SkillSystem.getPlayerHero(player): string?
    return SkillLoadoutService.getPlayerHero(player)
end

function SkillSystem.setSkillReplacement(player, key: string, newSkillId: string)
    SkillLoadoutService.setSkillReplacement(player, key, newSkillId)
end

function SkillSystem.revertSkillReplacement(player, key: string)
    SkillLoadoutService.revertSkillReplacement(player, key)
end

--============================================================
-- 廉颇战意系统 — 核心逻辑
--============================================================

--[[
    战意机制（勇士之魂被动）：
    - 进入战斗后每秒获得 10 战意（上限 100）
    - 脱战 5 秒后每秒失去 20 战意
    - 战意提供减伤（线性，满 100 时减伤 20%）
    - 满战意额外获得 30% 攻速加成
    - 战意不满时取消攻速加成
    
    "进入战斗"定义：释放技能、普攻、受到伤害
]]

-- 获取廉颇战意参数（从 SkillEventTable.lianpo_r.combatParams）
local function getZhanYiParams()
    local passive = SkillEventTable.getPassive("lianpo")
    if passive and passive.combatParams then
        return passive.combatParams
    end
    -- 兜底默认值
    return {
        maxZhanYi = 100,
        gainPerSecond = 10,
        losePerSecond = 20,
        maxDamageReduction = 0.20,
        attackSpeedBonus = 0.30,
    }
end

-- 标记角色进入战斗（技能/普攻/受伤时调用）
function SkillSystem.markInCombat(character)
    if not character or not character.Parent then return end
    
    -- 只有廉颇有战意系统
    local heroIdTag = character:FindFirstChild("HeroId")
    if not heroIdTag or heroIdTag.Value ~= "lianpo" then return end
    
    local now = tick()
    
    if not combatStates[character] then
        combatStates[character] = { inCombat = false, lastCombatTime = now }
        -- 首次进入战斗，初始化战意值
        if zhanYiValues[character] == nil then
            zhanYiValues[character] = 0
        end
    end
    
    combatStates[character].lastCombatTime = now
    
    -- 如果之前不在战斗状态，启动战意更新循环
    if not combatStates[character].inCombat then
        combatStates[character].inCombat = true
        SkillSystem._startZhanYiLoop(character)
    end
end

-- 启动战意更新循环（进战时启动，完全脱战且战意归零后停止）
function SkillSystem._startZhanYiLoop(character)
    -- 如果已有循环在运行，不重复启动
    if combatStates[character] and combatStates[character].updateTask then return end
    
    local params = getZhanYiParams()
    
    local loopTask = task.spawn(function()
        while character and character.Parent do
            task.wait(0.5) -- 每 0.5 秒更新一次（更平滑）
            
            if not character or not character.Parent then break end
            if not combatStates[character] then break end
            
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then break end
            
            local now = tick()
            local state = combatStates[character]
            local timeSinceCombat = now - state.lastCombatTime
            local currentZhanYi = zhanYiValues[character] or 0
            
            if timeSinceCombat < OUT_OF_COMBAT_DELAY then
                -- 战斗中：增加战意
                state.inCombat = true
                currentZhanYi = math.min(params.maxZhanYi, currentZhanYi + params.gainPerSecond * 0.5)
            else
                -- 脱战：减少战意 + 战意转化为回血
                state.inCombat = false
                local zhanYiLoss = math.min(currentZhanYi, params.losePerSecond * 0.5)
                currentZhanYi = math.max(0, currentZhanYi - zhanYiLoss)
                
                -- 战意转化回血：每点战意损失回复 0.5% 最大生命值
                -- 即满战意(100)脱战5秒清零 → 总共回复 50% 最大生命
                if zhanYiLoss > 0 and humanoid.Health < humanoid.MaxHealth then
                    local healPerZhanYi = humanoid.MaxHealth * (params.healPerZhanYi or 0.005)
                    local healAmount = zhanYiLoss * healPerZhanYi
                    humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
                end
            end
            
            zhanYiValues[character] = currentZhanYi
            
            -- 满战意攻速加成检查
            SkillSystem._checkZhanYiAttackSpeedBonus(character, currentZhanYi, params)
            
            -- 同步到客户端
            SkillSystem._syncZhanYiToClient(character, currentZhanYi, params)
            
            -- 战意归零且已脱战 → 停止循环
            if currentZhanYi <= 0 and not state.inCombat then
                break
            end
        end
        
        -- 循环结束，清理
        if combatStates[character] then
            combatStates[character].updateTask = nil
        end
    end)
    
    if combatStates[character] then
        combatStates[character].updateTask = loopTask
    end
end

-- 满战意攻速加成检查
function SkillSystem._checkZhanYiAttackSpeedBonus(character, currentZhanYi, params)
    local asValue = character:FindFirstChild("AttackSpeed")
    if not asValue or not asValue:IsA("NumberValue") then return end
    
    local isFull = currentZhanYi >= params.maxZhanYi
    local wasActive = zhanYiFullBonusActive[character] or false
    
    if isFull and not wasActive then
        -- 激活满战意攻速加成
        if not zhanYiBaseAttackSpeeds[character] then
            zhanYiBaseAttackSpeeds[character] = asValue.Value
        end
        asValue.Value = zhanYiBaseAttackSpeeds[character] * (1 + params.attackSpeedBonus)
        zhanYiFullBonusActive[character] = true
        
    elseif not isFull and wasActive then
        -- 取消满战意攻速加成
        if zhanYiBaseAttackSpeeds[character] then
            asValue.Value = zhanYiBaseAttackSpeeds[character]
        end
        zhanYiFullBonusActive[character] = false
    end
end

-- 同步战意值到客户端
function SkillSystem._syncZhanYiToClient(character, currentZhanYi, params)
    if not remotes or not remotes.ZhanYiUpdate then return end
    
    remotes.ZhanYiUpdate:FireAllClients({
        playerModel = character,
        value = currentZhanYi,
        maxValue = params.maxZhanYi,
        hasFullBonus = zhanYiFullBonusActive[character] or false,
    })
end

-- 获取角色当前战意减伤比例（CombatManager 调用）
function SkillSystem.getZhanYiDamageReduction(character): number
    if not character then return 0 end
    local heroIdTag = character:FindFirstChild("HeroId")
    if not heroIdTag or heroIdTag.Value ~= "lianpo" then return 0 end
    
    local currentZhanYi = zhanYiValues[character] or 0
    if currentZhanYi <= 0 then return 0 end
    
    local params = getZhanYiParams()
    -- 线性减伤：战意/满战意 × 最大减伤率
    return (currentZhanYi / params.maxZhanYi) * params.maxDamageReduction
end

-- 获取角色当前战意值（供外部查询）
function SkillSystem.getZhanYiValue(character): number
    return zhanYiValues[character] or 0
end

-- 清理角色战意数据（死亡/离开时）
function SkillSystem._cleanupZhanYi(character)
    if combatStates[character] then
        if combatStates[character].updateTask then
            task.cancel(combatStates[character].updateTask)
        end
        combatStates[character] = nil
    end
    zhanYiValues[character] = nil
    zhanYiFullBonusActive[character] = nil
    zhanYiBaseAttackSpeeds[character] = nil
end

-- 重置战意（角色重生时由 HeroManager 调用）
function SkillSystem.resetZhanYi(character)
    SkillSystem._cleanupZhanYi(character)
end

return SkillSystem
