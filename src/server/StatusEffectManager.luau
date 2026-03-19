--[[
    StatusEffectManager.luau
    状态效果统一管理器
    管理所有 Buff/Debuff 的施加、刷新、移除和免疫判定
    支持印记系统
]]

local TweenService = game:GetService("TweenService")

local DataManager = nil -- 延迟初始化避免循环依赖
local SkillEffectTable = nil
local eventSchedulerRef = nil -- 延迟注入，用于控制打断技能

local StatusEffectManager = {}

local remotes = nil

-- 每个目标的活跃效果: { [Model] = { [effectType] = effectData } }
local activeEffects = {}

-- 印记系统: { [Model] = { [markId] = { stacks = number, lastApplyTime = number, removeTask = thread? } } }
local activeMarks = {}

-- 护盾值: { [Model] = { [shieldType] = number } }
local shieldValues = {}

--============================================================
-- 初始化
--============================================================

function StatusEffectManager.init(remotesRef)
    remotes = remotesRef
    -- 延迟 require 避免循环依赖
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local shared = ReplicatedStorage:WaitForChild("Shared")
    SkillEffectTable = require(shared:WaitForChild("SkillEffectTable"))
end

-- 延迟注入 EventScheduler（由 init.server.luau 在所有模块初始化后调用）
function StatusEffectManager.setEventScheduler(esRef)
    eventSchedulerRef = esRef
end

--============================================================
-- 核心接口
--============================================================

--[[
    applyEffect(params)
    params = {
        target: Model,
        buffType: string,       -- "Slow"|"Stun"|"Knockback"|"Airborne"|"Burn"|"Shield"|"SpeedUp"|"SuperArmor"|"AttackBuff"
        duration: number,
        value: number?,         -- 效果数值
        source: Model?,         -- 施法者
        toSelf: boolean?,       -- 是否施加给施法者自身
        subType: string?,       -- 子类型（如 AttackBuff 的 "MultiArrow"）
    }
]]
function StatusEffectManager.applyEffect(params)
    local target = params.target
    local buffType = params.buffType
    local duration = params.duration or 0
    local value = params.value or 0
    local source = params.source

    if not target or not target.Parent then return false end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    -- 免疫判定：目标有霸体时，控制类 Debuff 被免疫
    if SkillEffectTable and SkillEffectTable.ControlDebuffs[buffType] then
        if StatusEffectManager.hasEffect(target, "SuperArmor") then
            -- 通知客户端显示"免疫"
            if remotes and remotes.StatusEffectUpdate then
                remotes.StatusEffectUpdate:FireAllClients({
                    targetModel = target,
                    effectType = buffType,
                    action = "immune",
                })
            end
            return false
        end
    end

    -- 初始化目标效果表
    if not activeEffects[target] then
        activeEffects[target] = {}
    end

    -- 如果已有同类效果，刷新持续时间
    local existing = activeEffects[target][buffType]
    if existing and existing.removeTask then
        task.cancel(existing.removeTask)
    end

    -- 施加效果
    local effectData = {
        buffType = buffType,
        duration = duration,
        value = value,
        source = source,
        startTime = tick(),
        subType = params.subType,
    }

    -- 根据效果类型执行具体逻辑
    StatusEffectManager._applyEffectLogic(target, humanoid, effectData)

    -- 设定自动移除
    if duration > 0 then
        effectData.removeTask = task.delay(duration, function()
            StatusEffectManager.removeEffect(target, buffType)
        end)
    end

    activeEffects[target][buffType] = effectData

    -- 通知客户端
    if remotes and remotes.StatusEffectUpdate then
        remotes.StatusEffectUpdate:FireAllClients({
            targetModel = target,
            effectType = buffType,
            action = "apply",
            duration = duration,
            value = value,
        })
    end

    return true
end

--============================================================
-- 效果逻辑实现
--============================================================

function StatusEffectManager._applyEffectLogic(target, humanoid, effectData)
    local buffType = effectData.buffType
    local value = effectData.value

    if buffType == "Slow" then
        -- 减速：降低移动速度（使用 _baseWalkSpeed 避免重复减速时叠加）
        if not effectData._originalWalkSpeed then
            -- 获取基础移速：若已有 Slow 生效，读取旧 effectData 记录的原始速度
            local existing = activeEffects[target] and activeEffects[target]["Slow"]
            if existing and existing._originalWalkSpeed then
                effectData._originalWalkSpeed = existing._originalWalkSpeed
            else
                effectData._originalWalkSpeed = humanoid.WalkSpeed
            end
        end
        humanoid.WalkSpeed = effectData._originalWalkSpeed * (1 - value)

    elseif buffType == "Stun" then
        -- 眩晕：禁止移动和施法
        local rootPart = target:FindFirstChild("HumanoidRootPart")
        if rootPart then
            effectData._originalWalkSpeed = humanoid.WalkSpeed
            effectData._originalJumpPower = humanoid.JumpPower
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
        end
        -- 控制打断当前技能（霸体免疫已在 applyEffect 入口处判定）
        if eventSchedulerRef then
            eventSchedulerRef.interruptByControl(target, StatusEffectManager)
        end

    elseif buffType == "Knockback" then
        -- 击退
        local rootPart = target:FindFirstChild("HumanoidRootPart")
        local source = effectData.source
        if rootPart and source then
            local sourceRoot = source:FindFirstChild("HumanoidRootPart")
            if sourceRoot then
                local direction = (rootPart.Position - sourceRoot.Position).Unit
                direction = Vector3.new(direction.X, 0, direction.Z).Unit
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Velocity = direction * (value or 30) + Vector3.new(0, 10, 0)
                bv.Parent = rootPart
                game:GetService("Debris"):AddItem(bv, 0.3)
            end
        end

    elseif buffType == "Airborne" then
        -- 击飞
        local rootPart = target:FindFirstChild("HumanoidRootPart")
        if rootPart then
            effectData._originalWalkSpeed = humanoid.WalkSpeed
            effectData._originalJumpPower = humanoid.JumpPower
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = Vector3.new(0, 40, 0)
            bv.Parent = rootPart
            game:GetService("Debris"):AddItem(bv, 0.2)
        end
        -- 控制打断当前技能
        if eventSchedulerRef then
            eventSchedulerRef.interruptByControl(target, StatusEffectManager)
        end

    elseif buffType == "Burn" then
        -- 灼烧 DoT
        effectData._burnTask = task.spawn(function()
            local duration = effectData.duration
            local elapsed = 0
            while elapsed < duration do
                task.wait(1)
                elapsed += 1
                if target and target.Parent and humanoid.Health > 0 then
                    humanoid:TakeDamage(value)
                    -- 通知客户端显示灼烧伤害数字
                    if remotes and remotes.DamageDealt then
                        local rootPart = target:FindFirstChild("HumanoidRootPart")
                        if rootPart then
                            remotes.DamageDealt:FireAllClients({
                                targetModel = target,
                                amount = value,
                                damageType = "Magic",
                                position = rootPart.Position + Vector3.new(0, 3, 0),
                            })
                        end
                    end
                else
                    break
                end
            end
        end)

    elseif buffType == "Shield" then
        -- 护盾
        if not shieldValues[target] then
            shieldValues[target] = {}
        end
        shieldValues[target]["Shield"] = value

    elseif buffType == "MagicShield" then
        -- 法术护盾
        if not shieldValues[target] then
            shieldValues[target] = {}
        end
        shieldValues[target]["MagicShield"] = value

    elseif buffType == "SuperArmor" then
        -- 霸体：标记即可，免疫判定在 applyEffect 中处理

    elseif buffType == "SpeedUp" then
        -- 加速（使用基础速度避免叠加错误）
        local existing = activeEffects[target] and activeEffects[target]["SpeedUp"]
        if existing and existing._originalWalkSpeed then
            effectData._originalWalkSpeed = existing._originalWalkSpeed
        else
            effectData._originalWalkSpeed = humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = effectData._originalWalkSpeed * (1 + value)

    elseif buffType == "AttackBuff" then
        -- 攻击强化（标记即可，由攻击系统读取）
    end
end

--============================================================
-- 移除效果
--============================================================

function StatusEffectManager.removeEffect(target, buffType: string)
    if not activeEffects[target] then return end
    local effectData = activeEffects[target][buffType]
    if not effectData then return end

    local humanoid = target:FindFirstChildOfClass("Humanoid")

    -- 恢复逻辑
    if buffType == "Slow" then
        if humanoid and effectData._originalWalkSpeed then
            humanoid.WalkSpeed = effectData._originalWalkSpeed
        end

    elseif buffType == "Stun" then
        if humanoid then
            if effectData._originalWalkSpeed then
                humanoid.WalkSpeed = effectData._originalWalkSpeed
            end
            if effectData._originalJumpPower then
                humanoid.JumpPower = effectData._originalJumpPower
            end
        end

    elseif buffType == "Airborne" then
        if humanoid then
            if effectData._originalWalkSpeed then
                humanoid.WalkSpeed = effectData._originalWalkSpeed
            end
            if effectData._originalJumpPower then
                humanoid.JumpPower = effectData._originalJumpPower
            end
        end

    elseif buffType == "Burn" then
        if effectData._burnTask then
            task.cancel(effectData._burnTask)
        end

    elseif buffType == "Shield" then
        if shieldValues[target] then
            shieldValues[target]["Shield"] = nil
        end

    elseif buffType == "MagicShield" then
        if shieldValues[target] then
            shieldValues[target]["MagicShield"] = nil
        end

    elseif buffType == "SpeedUp" then
        if humanoid and effectData._originalWalkSpeed then
            humanoid.WalkSpeed = effectData._originalWalkSpeed
        end
    end

    -- 取消自动移除任务
    if effectData.removeTask then
        task.cancel(effectData.removeTask)
    end

    activeEffects[target][buffType] = nil

    -- 通知客户端
    if remotes and remotes.StatusEffectUpdate then
        remotes.StatusEffectUpdate:FireAllClients({
            targetModel = target,
            effectType = buffType,
            action = "remove",
        })
    end
end

--============================================================
-- 查询接口
--============================================================

function StatusEffectManager.hasEffect(target, buffType: string): boolean
    return activeEffects[target] ~= nil and activeEffects[target][buffType] ~= nil
end

function StatusEffectManager.getEffect(target, buffType: string)
    if activeEffects[target] then
        return activeEffects[target][buffType]
    end
    return nil
end

function StatusEffectManager.getAllEffects(target): { any }
    return activeEffects[target] or {}
end

-- 是否被控制中（Stun / Airborne）
function StatusEffectManager.isControlled(target): boolean
    return StatusEffectManager.hasEffect(target, "Stun")
        or StatusEffectManager.hasEffect(target, "Airborne")
end

--============================================================
-- 护盾吸收伤害
--============================================================

function StatusEffectManager.absorbDamage(target, shieldType: string, damage: number): number
    if not shieldValues[target] then return 0 end
    local shield = shieldValues[target][shieldType]
    if not shield or shield <= 0 then return 0 end

    local absorbed = math.min(shield, damage)
    shieldValues[target][shieldType] = shield - absorbed

    -- 护盾耗尽时移除效果
    if shieldValues[target][shieldType] <= 0 then
        StatusEffectManager.removeEffect(target, shieldType)
    end

    return absorbed
end

--============================================================
-- 印记系统
--============================================================

function StatusEffectManager.addMark(params)
    local target = params.target
    local markId = params.markId
    local amount = params.amount or 1
    local duration = params.duration or 3
    local maxStack = params.maxStack or 10

    if not target or not target.Parent then return 0 end

    if not activeMarks[target] then
        activeMarks[target] = {}
    end
    if not activeMarks[target][markId] then
        activeMarks[target][markId] = { stacks = 0, removeTask = nil }
    end

    local markData = activeMarks[target][markId]
    markData.stacks = math.min(maxStack, markData.stacks + amount)
    markData.lastApplyTime = tick()

    -- 刷新移除计时器
    if markData.removeTask then
        task.cancel(markData.removeTask)
    end
    markData.removeTask = task.delay(duration, function()
        -- 逐层消失
        if activeMarks[target] and activeMarks[target][markId] then
            activeMarks[target][markId].stacks = math.max(0, activeMarks[target][markId].stacks - 1)
            if activeMarks[target][markId].stacks <= 0 then
                activeMarks[target][markId] = nil
            end
            -- 通知客户端
            if remotes and remotes.MarkUpdate then
                remotes.MarkUpdate:FireAllClients({
                    targetModel = target,
                    markId = markId,
                    stacks = activeMarks[target] and activeMarks[target][markId] and activeMarks[target][markId].stacks or 0,
                    maxStacks = maxStack,
                })
            end
        end
    end)

    -- 通知客户端
    if remotes and remotes.MarkUpdate then
        remotes.MarkUpdate:FireAllClients({
            targetModel = target,
            markId = markId,
            stacks = markData.stacks,
            maxStacks = maxStack,
        })
    end

    return markData.stacks
end

function StatusEffectManager.getMarkStacks(target, markId: string): number
    if activeMarks[target] and activeMarks[target][markId] then
        return activeMarks[target][markId].stacks
    end
    return 0
end

function StatusEffectManager.clearMarks(target, markId: string)
    if activeMarks[target] and activeMarks[target][markId] then
        if activeMarks[target][markId].removeTask then
            task.cancel(activeMarks[target][markId].removeTask)
        end
        activeMarks[target][markId] = nil
        -- 通知客户端
        if remotes and remotes.MarkUpdate then
            remotes.MarkUpdate:FireAllClients({
                targetModel = target,
                markId = markId,
                stacks = 0,
                maxStacks = 0,
            })
        end
    end
end

-- 减少印记层数（逐层消失，安琪拉被动用）
function StatusEffectManager.reduceMarkStacks(target, markId: string, amount: number)
    if not activeMarks[target] or not activeMarks[target][markId] then return end
    
    local markData = activeMarks[target][markId]
    markData.stacks = math.max(0, markData.stacks - (amount or 1))
    
    -- 层数归零时清理
    if markData.stacks <= 0 then
        if markData.removeTask then
            task.cancel(markData.removeTask)
        end
        activeMarks[target][markId] = nil
    end
end

-- 取消印记的自动移除计时器（让外部系统接管印记生命周期）
function StatusEffectManager.cancelMarkRemoveTask(target, markId: string)
    if not activeMarks[target] or not activeMarks[target][markId] then return end
    local markData = activeMarks[target][markId]
    if markData.removeTask then
        task.cancel(markData.removeTask)
        markData.removeTask = nil
    end
end

--============================================================
-- 清理（角色移除时调用）
--============================================================

function StatusEffectManager.cleanup(target)
    -- 移除所有效果（先收集再移除，避免遍历中修改表）
    if activeEffects[target] then
        local buffTypes = {}
        for buffType, _ in pairs(activeEffects[target]) do
            table.insert(buffTypes, buffType)
        end
        for _, buffType in ipairs(buffTypes) do
            StatusEffectManager.removeEffect(target, buffType)
        end
        activeEffects[target] = nil
    end
    -- 清理印记
    if activeMarks[target] then
        for markId, data in pairs(activeMarks[target]) do
            if data.removeTask then
                task.cancel(data.removeTask)
            end
        end
        activeMarks[target] = nil
    end
    -- 清理护盾
    shieldValues[target] = nil
end

return StatusEffectManager
