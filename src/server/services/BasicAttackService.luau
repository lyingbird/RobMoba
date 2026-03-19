local BasicAttackService = {}

local SkillEventTable = nil

function BasicAttackService.init(skillEventTableRef)
    SkillEventTable = skillEventTableRef
end

function BasicAttackService.resetPlayerState(player, attackCounts, attackCooldowns)
    attackCounts[player] = 0
    attackCooldowns[player] = 0
end

function BasicAttackService.clearPlayerState(player, attackCounts, attackCooldowns)
    attackCounts[player] = nil
    attackCooldowns[player] = nil
end

function BasicAttackService.resolveAttackRequest(player, character, heroId: string, requestData, attackCounts, attackCooldowns, deps)
    if not requestData or not SkillEventTable then
        return nil
    end

    if deps.eventScheduler.isCasting(character) then
        return nil
    end

    if deps.statusEffectManager.isControlled(character) then
        return nil
    end

    local now = tick()
    local lastAttack = attackCooldowns[player] or 0
    local attackSpeed = 1.0
    local asValue = character:FindFirstChild("AttackSpeed")
    if asValue and asValue:IsA("NumberValue") then
        attackSpeed = asValue.Value
    end

    local attackInterval = 1.0 / math.max(0.2, attackSpeed)
    if now - lastAttack < attackInterval then
        return nil
    end
    attackCooldowns[player] = now

    local basicAttackEvents = SkillEventTable.getBasicAttack(heroId)
    if not basicAttackEvents then
        return nil, "missing_basic_attack"
    end

    attackCounts[player] = (attackCounts[player] or 0) + 1
    local eventsToUse = basicAttackEvents

    if basicAttackEvents.enhancedAttackCount and basicAttackEvents.enhancedEvents then
        if attackCounts[player] >= basicAttackEvents.enhancedAttackCount then
            eventsToUse = {
                totalDuration = basicAttackEvents.totalDuration,
                isBasicAttack = true,
                events = basicAttackEvents.enhancedEvents,
            }
            attackCounts[player] = 0
        end
    end

    if heroId == "houyi" and basicAttackEvents.multiArrowEvents then
        local buffFolder = character:FindFirstChild("CurrentAttackBuff")
        if buffFolder then
            eventsToUse = {
                totalDuration = basicAttackEvents.totalDuration,
                isBasicAttack = true,
                events = basicAttackEvents.multiArrowEvents,
            }
        end
    end

    return {
        timeline = eventsToUse,
        targetPosition = requestData.targetPosition,
    }
end

return BasicAttackService
