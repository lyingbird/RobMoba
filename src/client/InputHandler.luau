--[[
    InputHandler.luau

    Client-side skill input handling:
    - listens for Q/W/E/R
    - manages indicator confirm/cancel flow
    - tracks local cooldown state for input gating
    - supports a short preinput window before cooldown ends
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputHandler = {}

local remotes = nil
local localPlayer = Players.LocalPlayer
local mouse = localPlayer:GetMouse()

local shared = ReplicatedStorage:WaitForChild("Shared")
local SkillTable = require(shared:WaitForChild("SkillTable"))
local HeroTable = require(shared:WaitForChild("HeroTable"))

local SkillIndicator = require(script.Parent:WaitForChild("SkillIndicator"))
local MovementController = require(script.Parent:WaitForChild("MovementController"))
local TouchInputGuard = require(script.Parent:WaitForChild("TouchInputGuard"))

local SKILL_KEYS = {
    [Enum.KeyCode.Q] = "Q",
    [Enum.KeyCode.W] = "W",
    [Enum.KeyCode.E] = "E",
    [Enum.KeyCode.R] = "R",
}

local PREINPUT_WINDOW = 0.2

local currentSkills = {}
local currentHeroId = nil
local isAlive = true
local pendingSkillKey = nil
local channelDirectionTask = nil
local cooldowns = {}
local bufferedCast = nil

local CHANNEL_DIRECTION_SKILLS = {
    angela_e = 3.0,
}

local function usesIndicator(castType: string?): boolean
    return castType == "Direction" or castType == "Position" or castType == "Channel"
end

function InputHandler.init(remotesRef)
    remotes = remotesRef

    SkillIndicator.init()

    ContextActionService:BindAction(
        "SkillKeys",
        function(_actionName, inputState, inputObj)
            if inputState ~= Enum.UserInputState.Begin then
                return Enum.ContextActionResult.Pass
            end

            local keyName = SKILL_KEYS[inputObj.KeyCode]
            if keyName and isAlive then
                InputHandler._handleSkillKey(keyName)
                return Enum.ContextActionResult.Sink
            end

            return Enum.ContextActionResult.Pass
        end,
        false,
        Enum.KeyCode.Q,
        Enum.KeyCode.W,
        Enum.KeyCode.E,
        Enum.KeyCode.R
    )

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not isAlive then
            return
        end

        if input.KeyCode == Enum.KeyCode.Escape then
            if pendingSkillKey or bufferedCast then
                InputHandler._clearPendingSkill()
                InputHandler._clearBufferedCast()
                return
            end
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if pendingSkillKey then
                InputHandler._confirmCast(pendingSkillKey)
                return
            end

            InputHandler._basicAttack()
        end
    end)

    UserInputService.TouchTap:Connect(function(_touchPositions, gameProcessed)
        if gameProcessed or TouchInputGuard.isConsumed() or not isAlive then
            return
        end

        if pendingSkillKey then
            MovementController.suppressTouchTap()
            InputHandler._confirmCast(pendingSkillKey)
        end
    end)

    if remotes.SkillBarUpdate then
        remotes.SkillBarUpdate.OnClientEvent:Connect(function(data)
            InputHandler._onSkillBarUpdate(data)
        end)
    end

    if remotes.CooldownUpdate then
        remotes.CooldownUpdate.OnClientEvent:Connect(function(data)
            InputHandler._onCooldownUpdate(data)
        end)
    end

    RunService.Heartbeat:Connect(function()
        InputHandler._flushBufferedCast()
    end)

    localPlayer.CharacterAdded:Connect(function(character)
        isAlive = true
        InputHandler._clearPendingSkill()
        InputHandler._clearBufferedCast()

        local humanoid = character:WaitForChild("Humanoid")
        humanoid.Died:Connect(function()
            isAlive = false
            InputHandler._clearPendingSkill()
            InputHandler._clearBufferedCast()
            InputHandler._stopChannelDirection()
        end)
    end)

    if localPlayer.Character then
        isAlive = true
        local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if humanoid.Health <= 0 then
                isAlive = false
            end

            humanoid.Died:Connect(function()
                isAlive = false
                InputHandler._clearPendingSkill()
                InputHandler._clearBufferedCast()
                InputHandler._stopChannelDirection()
            end)
        end
    end

    print("[InputHandler] initialized")
end

function InputHandler._handleSkillKey(keyName: string)
    local skillInfo = currentSkills[keyName]
    if not skillInfo then
        return
    end

    if skillInfo.castType == "Passive" then
        return
    end

    if bufferedCast and bufferedCast.keyName ~= keyName then
        InputHandler._clearBufferedCast()
    end

    if pendingSkillKey then
        if pendingSkillKey == keyName then
            InputHandler._confirmCast(keyName)
        else
            InputHandler._clearPendingSkill()
            InputHandler._handleSkillKey(keyName)
        end
        return
    end

    local remainingCooldown = InputHandler._getRemainingCooldown(skillInfo.id)
    if remainingCooldown > PREINPUT_WINDOW then
        return
    end

    if skillInfo.castType == "Instant" then
        InputHandler._castSkill(keyName)
        return
    end

    if usesIndicator(skillInfo.castType) then
        pendingSkillKey = keyName
        SkillIndicator.show(skillInfo.id, keyName)
        return
    end

    InputHandler._castSkill(keyName)
end

function InputHandler._confirmCast(keyName: string)
    InputHandler._clearPendingSkill()
    InputHandler._castSkill(keyName)
end

function InputHandler._castSkill(keyName: string)
    local skillInfo = currentSkills[keyName]
    if not skillInfo or skillInfo.castType == "Passive" then
        return
    end

    local remainingCooldown = InputHandler._getRemainingCooldown(skillInfo.id)
    if remainingCooldown > PREINPUT_WINDOW then
        return
    end

    local direction, targetPosition = InputHandler._getAimInfo(skillInfo.castType, skillInfo)

    if remainingCooldown > 0 then
        bufferedCast = {
            keyName = keyName,
            skillId = skillInfo.id,
            direction = direction,
            targetPosition = targetPosition,
        }
        return
    end

    InputHandler._sendSkillCast(skillInfo, direction, targetPosition)
end

function InputHandler._sendSkillCast(skillInfo, direction: Vector3, targetPosition: Vector3?)
    if not skillInfo then
        return
    end

    MovementController.stopMovement()

    if remotes and remotes.SkillCast then
        remotes.SkillCast:FireServer({
            skillId = skillInfo.id,
            direction = direction,
            targetPosition = targetPosition,
        })
    end

    InputHandler._checkChannelDirection(skillInfo)
end

function InputHandler._getAimInfo(castType: string, skillInfo)
    local character = localPlayer.Character
    if not character then
        return Vector3.new(0, 0, -1), nil
    end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        return Vector3.new(0, 0, -1), nil
    end

    local mouseRay = mouse.UnitRay
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { character }

    local rayResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
    local hitPosition = rayResult and rayResult.Position or (mouseRay.Origin + mouseRay.Direction * 200)

    local flatOffset = Vector3.new(
        hitPosition.X - rootPart.Position.X,
        0,
        hitPosition.Z - rootPart.Position.Z
    )

    local maxRange = nil
    if skillInfo and skillInfo.indicatorParams then
        maxRange = skillInfo.indicatorParams.range
    end

    if maxRange and flatOffset.Magnitude > maxRange then
        flatOffset = flatOffset.Unit * maxRange
    end

    local flatDirection
    if flatOffset.Magnitude > 0.01 then
        flatDirection = flatOffset.Unit
    else
        local lookVector = rootPart.CFrame.LookVector
        flatDirection = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
    end

    if castType == "Position" then
        local groundPos = Vector3.new(
            rootPart.Position.X + flatOffset.X,
            0,
            rootPart.Position.Z + flatOffset.Z
        )
        return flatDirection, groundPos
    end

    return flatDirection, nil
end

function InputHandler._onSkillBarUpdate(data)
    if not data then
        return
    end

    if data.action == "init" then
        currentHeroId = data.heroId
        currentSkills = {}
        if data.skills then
            for key, skillData in pairs(data.skills) do
                currentSkills[key] = skillData
            end
        end
        InputHandler._clearPendingSkill()
        InputHandler._clearBufferedCast()
        print("[InputHandler] skill bar updated for hero:", tostring(data.heroId))
        return
    end

    if data.action == "replace" then
        if data.key and data.newSkillId then
            local newSkill = SkillTable.getSkill(data.newSkillId)
            if newSkill then
                currentSkills[data.key] = newSkill
                InputHandler._syncTransientSkillState(data.key)
            end
        end
        return
    end

    if data.action == "revert" then
        if data.key and currentHeroId then
            local hero = HeroTable.getHero(currentHeroId)
            if hero and hero.skills[data.key] then
                local originalSkill = SkillTable.getSkill(hero.skills[data.key])
                if originalSkill then
                    currentSkills[data.key] = originalSkill
                    InputHandler._syncTransientSkillState(data.key)
                end
            end
        end
    end
end

function InputHandler._onCooldownUpdate(data)
    if not data or not data.skillId then
        return
    end

    local cooldownTime = math.max(0, data.cooldownTime or 0)
    if cooldownTime <= 0 then
        cooldowns[data.skillId] = nil
    else
        cooldowns[data.skillId] = {
            endTime = tick() + cooldownTime,
            totalTime = cooldownTime,
        }
    end

    InputHandler._refreshPendingSkill()
end

function InputHandler._getRemainingCooldown(skillId: string): number
    local cooldownState = cooldowns[skillId]
    if not cooldownState then
        return 0
    end

    local remaining = cooldownState.endTime - tick()
    if remaining <= 0 then
        cooldowns[skillId] = nil
        return 0
    end

    return remaining
end

function InputHandler._clearPendingSkill()
    if pendingSkillKey then
        SkillIndicator.hide()
        pendingSkillKey = nil
    end
end

function InputHandler._clearBufferedCast()
    bufferedCast = nil
end

function InputHandler._flushBufferedCast()
    if not bufferedCast or not isAlive then
        return
    end

    local skillInfo = currentSkills[bufferedCast.keyName]
    if not skillInfo or skillInfo.id ~= bufferedCast.skillId then
        InputHandler._clearBufferedCast()
        return
    end

    if InputHandler._getRemainingCooldown(bufferedCast.skillId) > 0 then
        return
    end

    local queuedCast = bufferedCast
    bufferedCast = nil
    InputHandler._sendSkillCast(skillInfo, queuedCast.direction, queuedCast.targetPosition)
end

function InputHandler._refreshPendingSkill()
    if not pendingSkillKey then
        return
    end

    local skillInfo = currentSkills[pendingSkillKey]
    if not skillInfo or not usesIndicator(skillInfo.castType) then
        InputHandler._clearPendingSkill()
        return
    end

    if InputHandler._getRemainingCooldown(skillInfo.id) > PREINPUT_WINDOW then
        InputHandler._clearPendingSkill()
        return
    end

    SkillIndicator.show(skillInfo.id, pendingSkillKey)
end

function InputHandler._syncTransientSkillState(keyName: string)
    if bufferedCast and bufferedCast.keyName == keyName then
        local currentSkill = currentSkills[keyName]
        if not currentSkill or currentSkill.id ~= bufferedCast.skillId then
            InputHandler._clearBufferedCast()
        end
    end

    if pendingSkillKey == keyName then
        InputHandler._refreshPendingSkill()
    end
end

function InputHandler._basicAttack()
    if not isAlive or not currentHeroId then
        return
    end

    local direction, targetPosition = InputHandler._getAimInfo("Direction")
    if remotes and remotes.BasicAttack then
        remotes.BasicAttack:FireServer({
            direction = direction,
            targetPosition = targetPosition,
        })
    end
end

function InputHandler._checkChannelDirection(skillInfo)
    if not skillInfo then
        return
    end

    local duration = CHANNEL_DIRECTION_SKILLS[skillInfo.id]
    if not duration then
        return
    end

    InputHandler._stopChannelDirection()

    channelDirectionTask = task.spawn(function()
        local elapsed = 0
        while elapsed < duration + 0.5 do
            local direction = InputHandler._getAimInfo("Direction")
            if remotes and remotes.ChannelDirection then
                remotes.ChannelDirection:FireServer({
                    direction = direction,
                })
            end

            local waitTime = task.wait(0.05)
            elapsed += waitTime

            if not isAlive then
                break
            end
        end

        channelDirectionTask = nil
    end)
end

function InputHandler._stopChannelDirection()
    if channelDirectionTask then
        task.cancel(channelDirectionTask)
        channelDirectionTask = nil
    end
end

function InputHandler.getCurrentSkills()
    return currentSkills
end

function InputHandler.getCurrentHeroId()
    return currentHeroId
end

function InputHandler.triggerSkillKey(keyName: string)
    if not isAlive then
        return
    end

    InputHandler._handleSkillKey(keyName)
end

return InputHandler
