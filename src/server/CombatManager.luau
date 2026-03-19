--[[
    CombatManager.luau
    战斗管理模块
    处理伤害计算、护盾、死亡判定
]]

local CombatManager = {}

local remotes = nil
local statusEffectManager = nil
local skillSystem = nil  -- 延迟设置，避免循环依赖

--============================================================
-- 初始化
--============================================================

function CombatManager.init(remotesRef, statusEffectManagerRef)
    remotes = remotesRef
    statusEffectManager = statusEffectManagerRef
end

-- 延迟注入 SkillSystem 引用（由 init.server.luau 在所有模块初始化后调用）
function CombatManager.setSkillSystem(skillSystemRef)
    skillSystem = skillSystemRef
end

--============================================================
-- 伤害计算
--============================================================

--[[
    dealDamage(params)
    params = {
        attacker: Model,        -- 攻击者模型
        target: Model,          -- 目标模型
        damage: number,         -- 基础伤害值
        damageType: string,     -- "Physical" | "Magic" | "True"
        position: Vector3?,     -- 伤害发生位置（用于显示伤害数字）
    }
]]
function CombatManager.dealDamage(params)
    local attacker = params.attacker
    local target = params.target
    local baseDamage = params.damage or 0
    local damageType = params.damageType or "Physical"

    if not target or not target.Parent then return end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- 伤害减免计算
    local finalDamage = baseDamage
    
    if damageType == "Physical" then
        -- 物理伤害受护甲减免
        local armor = 0
        local armorValue = target:FindFirstChild("Armor")
        if armorValue and armorValue:IsA("NumberValue") then
            armor = armorValue.Value
        end
        -- 减免公式: 伤害 * (1 - 护甲/(护甲+100))
        if armor > 0 then
            finalDamage = baseDamage * (1 - armor / (armor + 100))
        end
    elseif damageType == "Magic" then
        -- 法术伤害受魔抗减免
        local magicResist = 0
        local mrValue = target:FindFirstChild("MagicResist")
        if mrValue and mrValue:IsA("NumberValue") then
            magicResist = mrValue.Value
        end
        if magicResist > 0 then
            finalDamage = baseDamage * (1 - magicResist / (magicResist + 100))
        end
    end
    -- True 伤害不减免

    -- 廉颇战意减伤（在护甲/魔抗之后叠乘）
    if skillSystem and damageType ~= "True" then
        local zhanYiReduction = skillSystem.getZhanYiDamageReduction(target)
        if zhanYiReduction > 0 then
            finalDamage = finalDamage * (1 - zhanYiReduction)
        end
    end

    finalDamage = math.floor(math.max(1, finalDamage))

    -- 优先扣除护盾
    if statusEffectManager then
        local shieldAbsorbed = 0
        
        -- 通用护盾（吸收所有伤害类型）
        shieldAbsorbed = statusEffectManager.absorbDamage(target, "Shield", finalDamage)
        
        -- 法术护盾（仅对法术伤害额外生效）
        if damageType == "Magic" then
            shieldAbsorbed = shieldAbsorbed + statusEffectManager.absorbDamage(target, "MagicShield", finalDamage - shieldAbsorbed)
        end
        
        finalDamage = math.max(0, finalDamage - shieldAbsorbed)
    end

    -- 扣血
    if finalDamage > 0 then
        -- 记录最后攻击者到目标角色上（供击杀判定读取）
        local lastAttacker = target:FindFirstChild("LastAttacker")
        if not lastAttacker then
            lastAttacker = Instance.new("ObjectValue")
            lastAttacker.Name = "LastAttacker"
            lastAttacker.Parent = target
        end
        lastAttacker.Value = attacker
        
        humanoid:TakeDamage(finalDamage)
    end

    -- 计算伤害位置
    local damagePos = params.position
    if not damagePos then
        local rootPart = target:FindFirstChild("HumanoidRootPart")
        if rootPart then
            damagePos = rootPart.Position + Vector3.new(
                math.random(-10, 10) / 10,
                math.random(10, 20) / 10,
                math.random(-10, 10) / 10
            )
        end
    end

    -- 通知客户端显示伤害数字
    if remotes and remotes.DamageDealt and damagePos then
        remotes.DamageDealt:FireAllClients({
            targetModel = target,
            amount = finalDamage,
            damageType = damageType,
            position = damagePos,
        })
    end

    -- 标记攻击者和目标进入战斗（廉颇战意系统）
    if skillSystem then
        if attacker then
            skillSystem.markInCombat(attacker)
        end
        skillSystem.markInCombat(target)
    end

    return finalDamage
end

--============================================================
-- 治疗
--============================================================

function CombatManager.heal(target: Model, amount: number)
    if not target or not target.Parent then return end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
end

--============================================================
-- 判断目标是否可被攻击
--============================================================

function CombatManager.isValidTarget(target: Model): boolean
    if not target or not target.Parent then return false end
    local humanoid = target:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return true
end

-- 判断是否是假人
function CombatManager.isDummy(target: Model): boolean
    local tag = target:FindFirstChild("IsDummy")
    return tag ~= nil and tag:IsA("BoolValue") and tag.Value == true
end

-- 判断是否是玩家角色
function CombatManager.isPlayerCharacter(target: Model): boolean
    local Players = game:GetService("Players")
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character == target then
            return true
        end
    end
    return false
end

-- 获取目标所属玩家
function CombatManager.getPlayerFromCharacter(character: Model)
    local Players = game:GetService("Players")
    return Players:GetPlayerFromCharacter(character)
end

return CombatManager
