--[[
    VFXController.luau
    客户端特效调度器

    职责：
    - 接收服务端 PlayVFX 事件
    - 调度 VFXLibrary 播放/停止特效
    - 管理活跃特效实例池
    - 处理特效跟随目标
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VFXLibrary = require(script.Parent:WaitForChild("VFXLibrary"))

local VFXController = {}

local remotes = nil
local localPlayer = Players.LocalPlayer
local activeVFX = {}

local function ensureVFXFolder(): Folder
    local vfxFolder = workspace:FindFirstChild("VFX")
    if not vfxFolder then
        vfxFolder = Instance.new("Folder")
        vfxFolder.Name = "VFX"
        vfxFolder.Parent = workspace
    end
    return vfxFolder
end

local function resolveDuration(data, params, vfxInstance)
    local explicitDuration = params.duration or data.duration
    if explicitDuration then
        return explicitDuration
    end

    local configuredDuration = vfxInstance and vfxInstance:GetAttribute("ConfiguredDuration")
    if type(configuredDuration) == "number" and configuredDuration > 0 then
        return configuredDuration
    end

    return 5
end

local function extractFollowTarget(data, params)
    if params.followTarget then
        return params.followTarget
    end

    if data.attachToBullet and data.bulletRef then
        return data.bulletRef
    end

    if data.attachToSelf and data.casterModel then
        return data.casterModel
    end

    return nil
end

function VFXController.init(remotesRef)
    remotes = remotesRef

    pcall(function()
        VFXLibrary:PreloadAllTemplates()
    end)

    if remotes.PlayVFX then
        remotes.PlayVFX.OnClientEvent:Connect(function(data)
            task.spawn(function()
                VFXController._handlePlayVFX(data)
            end)
        end)
    end

    if remotes.PlayAnim then
        remotes.PlayAnim.OnClientEvent:Connect(function(data)
            task.spawn(function()
                VFXController._handlePlayAnim(data)
            end)
        end)
    end

    if remotes.StopAnim then
        remotes.StopAnim.OnClientEvent:Connect(function(data)
            task.spawn(function()
                VFXController._handleStopAnim(data)
            end)
        end)
    end

    print("[VFXController] initialized")
end

function VFXController._handlePlayVFX(data)
    if not data or not data.templateId then
        return
    end

    local templateId = data.templateId
    local position = data.position
    local direction = data.direction
    local params = data.params or {}
    local followTarget = extractFollowTarget(data, params)

    local vfxInstance = nil
    local success = pcall(function()
        vfxInstance = VFXLibrary:GetTemplate(templateId)
    end)

    if not success or not vfxInstance then
        local fallbackDuration = params.duration or data.duration
        vfxInstance = VFXController._createFallbackVFX(templateId, position, fallbackDuration)
        if not vfxInstance then
            return
        end

        if not activeVFX[templateId] then
            activeVFX[templateId] = {}
        end
        table.insert(activeVFX[templateId], vfxInstance)

        local cleanupFallbackDuration = fallbackDuration or 3
        task.delay(cleanupFallbackDuration + 0.5, function()
            if activeVFX[templateId] then
                local index = table.find(activeVFX[templateId], vfxInstance)
                if index then
                    table.remove(activeVFX[templateId], index)
                end
            end
        end)
        return
    end

    local cframe = CFrame.new(position or Vector3.zero)
    if direction and (position or Vector3.zero) ~= ((position or Vector3.zero) + direction) then
        cframe = CFrame.lookAt(position or Vector3.zero, (position or Vector3.zero) + direction)
    end

    vfxInstance:PivotTo(cframe)

    local scale = params.scale or data.scale
    if type(scale) == "number" and scale ~= 1 then
        pcall(function()
            vfxInstance:ScaleTo(scale)
        end)
    end

    vfxInstance.Parent = ensureVFXFolder()
    VFXLibrary:PlayVFX(vfxInstance)

    if followTarget then
        VFXController._followTarget(vfxInstance, followTarget, resolveDuration(data, params, vfxInstance))
    end

    if not activeVFX[templateId] then
        activeVFX[templateId] = {}
    end
    table.insert(activeVFX[templateId], vfxInstance)

    local cleanupTime = resolveDuration(data, params, vfxInstance)
    task.delay(cleanupTime, function()
        if vfxInstance and vfxInstance.Parent then
            pcall(function()
                VFXLibrary:StopVFX(vfxInstance)
            end)
            vfxInstance:Destroy()
        end

        if activeVFX[templateId] then
            local index = table.find(activeVFX[templateId], vfxInstance)
            if index then
                table.remove(activeVFX[templateId], index)
            end
        end
    end)
end

function VFXController._createFallbackVFX(templateId: string, position: Vector3?, duration: number?): Instance?
    if not position then
        return nil
    end

    local part = Instance.new("Part")
    part.Name = "VFX_" .. templateId
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 30
    emitter.Speed = NumberRange.new(2, 5)
    emitter.Lifetime = NumberRange.new(0.5, 1.0)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1),
    })

    if string.find(templateId, "houyi") or string.find(templateId, "arrow") or string.find(templateId, "sunfall") or string.find(templateId, "multi_arrow") then
        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 120, 0))
    elseif string.find(templateId, "lianpo") or string.find(templateId, "charge") or string.find(templateId, "slam") or string.find(templateId, "ground_crack") or string.find(templateId, "super_armor") or string.find(templateId, "shockwave") then
        emitter.Color = ColorSequence.new(Color3.fromRGB(210, 170, 80), Color3.fromRGB(140, 100, 40))
    elseif string.find(templateId, "angela") or string.find(templateId, "purple") or string.find(templateId, "fireball") or string.find(templateId, "vortex") or string.find(templateId, "radiance") or string.find(templateId, "seed") then
        emitter.Color = ColorSequence.new(Color3.fromRGB(180, 60, 220), Color3.fromRGB(100, 20, 160))
    elseif string.find(templateId, "fire") or string.find(templateId, "flame") then
        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 150, 50), Color3.fromRGB(255, 50, 0))
    elseif string.find(templateId, "impact") then
        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100), Color3.fromRGB(255, 150, 50))
    elseif string.find(templateId, "ice") or string.find(templateId, "frost") then
        emitter.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255), Color3.fromRGB(200, 230, 255))
    elseif string.find(templateId, "heal") then
        emitter.Color = ColorSequence.new(Color3.fromRGB(100, 255, 100), Color3.fromRGB(200, 255, 200))
    else
        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200), Color3.fromRGB(200, 200, 255))
    end

    emitter.Parent = part

    task.delay((duration or 2) * 0.7, function()
        emitter.Enabled = false
    end)

    task.delay(duration or 3, function()
        if part and part.Parent then
            part:Destroy()
        end
    end)

    return part
end

function VFXController._followTarget(vfxInstance: Instance, targetRef: any, duration: number?)
    local startTime = os.clock()
    local maxDuration = duration or 10

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if os.clock() - startTime > maxDuration then
            if connection then
                connection:Disconnect()
            end
            return
        end

        if not vfxInstance or not vfxInstance.Parent then
            if connection then
                connection:Disconnect()
            end
            return
        end

        local target = nil
        if targetRef == "LocalPlayer" then
            target = localPlayer.Character
        elseif typeof(targetRef) == "Instance" then
            target = targetRef
        elseif type(targetRef) == "string" then
            target = workspace:FindFirstChild(targetRef)
        end

        if target then
            local rootPart = target:FindFirstChild("HumanoidRootPart")
            if rootPart then
                vfxInstance:PivotTo(rootPart.CFrame)
            end
        end
    end)
end

function VFXController._handlePlayAnim(data)
    if not data or not data.targetModel or not data.animId then
        return
    end

    local targetModel = data.targetModel
    if not targetModel or not targetModel.Parent then
        return
    end

    local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local animInstance = Instance.new("Animation")
    animInstance.AnimationId = "rbxassetid://" .. tostring(data.animId)

    local success, animTrack = pcall(function()
        return animator:LoadAnimation(animInstance)
    end)

    if success and animTrack then
        if data.speed then
            animTrack:AdjustSpeed(data.speed)
        end

        local loopCount = data.loopCount or 1
        animTrack.Looped = loopCount > 1
        animTrack:Play()

        if data.duration then
            task.delay(data.duration, function()
                animTrack:Stop()
            end)
        end
    end

    animInstance:Destroy()
end

function VFXController._handleStopAnim(data)
    if not data or not data.targetModel then
        return
    end

    local targetModel = data.targetModel
    if not targetModel or not targetModel.Parent then
        return
    end

    local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        return
    end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if data.animId then
            if string.find(track.Animation.AnimationId, tostring(data.animId)) then
                track:Stop()
            end
        else
            track:Stop()
        end
    end
end

function VFXController.playManual(templateId: string, position: Vector3?, direction: Vector3?, duration: number?)
    VFXController._handlePlayVFX({
        templateId = templateId,
        position = position,
        direction = direction,
        duration = duration,
        params = { duration = duration },
    })
end

function VFXController.stopAll()
    for templateId, instances in pairs(activeVFX) do
        for _, inst in ipairs(instances) do
            if inst and inst.Parent then
                pcall(function()
                    VFXLibrary:StopVFX(inst)
                end)
                inst:Destroy()
            end
        end
        activeVFX[templateId] = nil
    end
end

function VFXController.stopByType(templateId: string)
    if activeVFX[templateId] then
        for _, inst in ipairs(activeVFX[templateId]) do
            if inst and inst.Parent then
                pcall(function()
                    VFXLibrary:StopVFX(inst)
                end)
                inst:Destroy()
            end
        end
        activeVFX[templateId] = nil
    end
end

return VFXController

