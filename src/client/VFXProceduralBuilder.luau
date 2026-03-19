local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local VFXAssetTable = require(shared:WaitForChild("VFXAssetTable"))

local VFXProceduralBuilder = {}

local DEFAULT_EMITTER_TEXTURE = ""

local function parseAssetId(value: string?): string?
    if type(value) ~= "string" or value == "" then
        return nil
    end

    if string.find(value, "rbxassetid://", 1, true) then
        return value
    end

    if string.match(value, "^%d+$") then
        return "rbxassetid://" .. value
    end

    return value
end

local function getAssetConfig(templateId: string)
    return VFXAssetTable.getTemplate(templateId)
end

local function pickTexture(templateId: string, fallbackField: string?): string
    local assetConfig = getAssetConfig(templateId)
    if assetConfig and fallbackField then
        local parsed = parseAssetId(assetConfig[fallbackField])
        if parsed then
            return parsed
        end
    end
    return DEFAULT_EMITTER_TEXTURE
end

local function makeRootModel(templateId: string): (Model, Part)
    local model = Instance.new("Model")
    model.Name = templateId

    local root = Instance.new("Part")
    root.Name = "Root"
    root.Size = Vector3.new(0.2, 0.2, 0.2)
    root.Anchored = true
    root.CanCollide = false
    root.CanQuery = false
    root.CanTouch = false
    root.Transparency = 1
    root.Parent = model

    model.PrimaryPart = root
    return model, root
end

local function asColorSequence(color: Color3, secondaryColor: Color3?): ColorSequence
    return ColorSequence.new(color, secondaryColor or color)
end

local function makeSizeSequence(startSize: number, endSize: number): NumberSequence
    return NumberSequence.new({
        NumberSequenceKeypoint.new(0, startSize),
        NumberSequenceKeypoint.new(1, endSize),
    })
end

local function createAttachment(parent: Instance, name: string, position: Vector3?): Attachment
    local attachment = Instance.new("Attachment")
    attachment.Name = name
    attachment.Position = position or Vector3.zero
    attachment.Parent = parent
    return attachment
end

local function configureBurstEmitter(emitter: ParticleEmitter, emitCount: number)
    emitter.Enabled = false
    emitter:SetAttribute("EmitCount", emitCount)
end

local function configureLoopEmitter(emitter: ParticleEmitter, autoDisableAfter: number?)
    emitter.Enabled = false
    emitter:SetAttribute("EnableOnPlay", true)
    if autoDisableAfter and autoDisableAfter > 0 then
        emitter:SetAttribute("AutoDisableAfter", autoDisableAfter)
    end
end

local function createEmitter(parent: Instance, options)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = options.name or "Emitter"
    emitter.Color = asColorSequence(options.color or Color3.new(1, 1, 1), options.secondaryColor)
    emitter.LightEmission = options.lightEmission or 0.7
    emitter.LightInfluence = options.lightInfluence or 0
    emitter.Lifetime = options.lifetime or NumberRange.new(0.3, 0.6)
    emitter.Speed = options.speed or NumberRange.new(0, 0)
    emitter.Rotation = options.rotation or NumberRange.new(0, 360)
    emitter.RotSpeed = options.rotSpeed or NumberRange.new(-120, 120)
    emitter.SpreadAngle = options.spreadAngle or Vector2.new(180, 180)
    emitter.Acceleration = options.acceleration or Vector3.zero
    emitter.Drag = options.drag or 2
    emitter.LockedToPart = options.lockedToPart == true
    emitter.Rate = options.rate or 0
    emitter.Size = options.size or makeSizeSequence(0.5, 0)
    emitter.Transparency = options.transparency or NumberSequence.new({
        NumberSequenceKeypoint.new(0, options.startTransparency or 0.1),
        NumberSequenceKeypoint.new(1, options.endTransparency or 1),
    })
    emitter.Texture = options.texture or DEFAULT_EMITTER_TEXTURE
    emitter.ZOffset = options.zOffset or 0
    emitter.Parent = parent

    if options.emitCount and options.emitCount > 0 then
        configureBurstEmitter(emitter, options.emitCount)
    else
        configureLoopEmitter(emitter, options.autoDisableAfter)
    end

    return emitter
end

local function markPulsePart(part: BasePart, expandMultiplier: number, fadeTime: number, endTransparency: number?)
    part:SetAttribute("PulsePart", true)
    part:SetAttribute("PulseExpandMultiplier", expandMultiplier)
    part:SetAttribute("PulseFadeTime", fadeTime)
    part:SetAttribute("PulseEndTransparency", endTransparency or 1)
end

local function applyPartVisuals(part: BasePart, textureAssetId: string?, shape: string?)
    if textureAssetId and textureAssetId ~= "" then
        local decal = Instance.new("Decal")
        decal.Texture = textureAssetId
        decal.Transparency = part.Transparency
        decal.Face = Enum.NormalId.Top
        decal.Parent = part

        if shape == "disk" then
            local bottomDecal = decal:Clone()
            bottomDecal.Face = Enum.NormalId.Bottom
            bottomDecal.Parent = part
        end
    end
end

local function createDiskPulse(templateId: string, root: BasePart, options)
    local part = Instance.new("Part")
    part.Name = options.name or "DiskPulse"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Shape = Enum.PartType.Cylinder
    part.Material = options.material or Enum.Material.Neon
    part.Color = options.color or Color3.new(1, 1, 1)
    part.Transparency = options.transparency or 0.35
    local radius = options.radius or 3
    local height = options.height or 0.16
    part.Size = Vector3.new(height, radius * 2, radius * 2)
    part.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
    part.Parent = root.Parent

    applyPartVisuals(part, options.texture or parseAssetId((getAssetConfig(templateId) or {}).pulseTextureAssetId), "disk")
    markPulsePart(part, options.expandMultiplier or 1.2, options.fadeTime or 0.35, options.endTransparency or 1)
    return part
end

local function createBoxPulse(templateId: string, root: BasePart, options)
    local part = Instance.new("Part")
    part.Name = options.name or "BoxPulse"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = options.material or Enum.Material.Neon
    part.Color = options.color or Color3.new(1, 1, 1)
    part.Transparency = options.transparency or 0.2
    part.Size = options.size or Vector3.new(0.4, 0.2, 4)
    part.CFrame = root.CFrame * (options.offset or CFrame.new())
    part.Parent = root.Parent

    applyPartVisuals(part, options.texture or parseAssetId((getAssetConfig(templateId) or {}).pulseTextureAssetId), "box")
    markPulsePart(part, options.expandMultiplier or 1.15, options.fadeTime or 0.3, options.endTransparency or 1)
    return part
end

local function createSpherePulse(root: BasePart, options)
    local part = Instance.new("Part")
    part.Name = options.name or "SpherePulse"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Shape = Enum.PartType.Ball
    part.Material = options.material or Enum.Material.Neon
    part.Color = options.color or Color3.new(1, 1, 1)
    part.Transparency = options.transparency or 0.15
    local radius = options.radius or 2
    part.Size = Vector3.new(radius, radius, radius)
    part.CFrame = root.CFrame
    part.Parent = root.Parent

    markPulsePart(part, options.expandMultiplier or 1.35, options.fadeTime or 0.2, options.endTransparency or 1)
    return part
end

local function createPointLight(parent: Instance, color: Color3, brightness: number, range: number)
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = brightness
    light.Range = range
    light.Enabled = false
    light.Parent = parent
    light:SetAttribute("EnableOnPlay", true)
    light:SetAttribute("AutoDisableAfter", 0.2)
    return light
end

local function createTrail(root: BasePart, width: number, color: Color3, secondaryColor: Color3?, fadeTime: number)
    local a0 = createAttachment(root, "TrailA0", Vector3.new(0, 0.05, -0.35))
    local a1 = createAttachment(root, "TrailA1", Vector3.new(0, 0.05, 0.35))

    local trail = Instance.new("Trail")
    trail.Name = "Trail"
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Color = asColorSequence(color, secondaryColor)
    trail.WidthScale = NumberSequence.new({
        NumberSequenceKeypoint.new(0, width),
        NumberSequenceKeypoint.new(1, 0),
    })
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.LightEmission = 1
    trail.Lifetime = fadeTime
    trail.Enabled = false
    trail.Parent = root
    trail:SetAttribute("EnableOnPlay", true)
    trail:SetAttribute("AutoDisableAfter", fadeTime)
    trail:SetAttribute("AutoClearAfter", fadeTime)
    return trail
end

local function createForwardBeam(model: Model, root: BasePart, length: number, width: number, color: Color3, secondaryColor: Color3?)
    local endPart = Instance.new("Part")
    endPart.Name = "BeamTarget"
    endPart.Size = Vector3.new(0.2, 0.2, 0.2)
    endPart.Anchored = true
    endPart.CanCollide = false
    endPart.CanQuery = false
    endPart.CanTouch = false
    endPart.Transparency = 1
    endPart.CFrame = root.CFrame * CFrame.new(0, 0, -length)
    endPart.Parent = model

    local a0 = createAttachment(root, "BeamA0")
    local a1 = createAttachment(endPart, "BeamA1")

    local beam = Instance.new("Beam")
    beam.Name = "Beam"
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Color = asColorSequence(color, secondaryColor)
    beam.Width0 = width
    beam.Width1 = width * 0.6
    beam.LightEmission = 1
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.85),
    })
    beam.FaceCamera = true
    beam.Enabled = false
    beam.Parent = root
    beam:SetAttribute("EnableOnPlay", true)
    beam:SetAttribute("AutoDisableAfter", 0.3)
    return beam
end

local function resolveLifetime(rangeOrNumber): number
    if typeof(rangeOrNumber) == "NumberRange" then
        return rangeOrNumber.Max
    end
    if type(rangeOrNumber) == "number" then
        return rangeOrNumber
    end
    return 0.6
end

local function buildProjectile(templateId: string, model: Model, root: BasePart, config)
    local lifetime = config.lifetime or NumberRange.new(0.2, 0.4)
    createTrail(root, config.trailWidth or 0.3, config.color, config.secondaryColor, resolveLifetime(lifetime))
    createEmitter(root, {
        name = "ProjectileGlow",
        color = config.color,
        secondaryColor = config.secondaryColor,
        size = config.particleSize or makeSizeSequence(0.35, 0),
        lifetime = lifetime,
        speed = NumberRange.new(0, 0),
        rate = config.particleRate or 24,
        lightEmission = config.glowIntensity or 1,
        autoDisableAfter = resolveLifetime(lifetime),
        lockedToPart = true,
        spreadAngle = Vector2.new(20, 20),
        texture = pickTexture(templateId, "emitterTextureAssetId"),
    })
    createPointLight(root, config.color, math.max(1, config.glowIntensity or 1), 8)
    model:SetAttribute("ConfiguredDuration", resolveLifetime(lifetime) + 0.2)
end

local function buildMeleeSlash(templateId: string, model: Model, root: BasePart, config)
    createBoxPulse(templateId, root, {
        name = "Slash",
        color = config.color,
        size = Vector3.new(config.thickness or 0.35, 0.18, config.scale or 4),
        offset = CFrame.new(0, 0.15, -(config.scale or 4) * 0.45),
        fadeTime = config.fadeTime or 0.35,
        expandMultiplier = 1.18,
        transparency = 0.18,
    })
    createEmitter(root, {
        name = "SlashSparks",
        color = config.secondaryColor or config.color,
        size = makeSizeSequence(0.35, 0),
        lifetime = NumberRange.new(0.15, 0.3),
        speed = NumberRange.new(6, 10),
        emitCount = 12,
        lightEmission = config.glowIntensity or 1.5,
        spreadAngle = Vector2.new(config.arcAngle or 60, config.arcAngle or 60),
        texture = pickTexture(templateId, "emitterTextureAssetId"),
    })
    model:SetAttribute("ConfiguredDuration", (config.fadeTime or 0.35) + 0.15)
end

local function buildImpact(templateId: string, model: Model, root: BasePart, config)
    createSpherePulse(root, {
        name = "ImpactFlash",
        color = config.color,
        radius = math.max(1.5, config.flashIntensity or 2),
        fadeTime = config.flashDuration or 0.15,
        expandMultiplier = 1.4,
        transparency = 0.12,
    })
    createEmitter(root, {
        name = "ImpactBurst",
        color = config.color,
        secondaryColor = config.secondaryColor,
        size = makeSizeSequence(config.debrisSize or 0.25, 0),
        lifetime = NumberRange.new(0.2, 0.45),
        speed = NumberRange.new(6, 12),
        emitCount = config.particleBurst or 12,
        lightEmission = config.flashIntensity or 2,
        spreadAngle = Vector2.new(180, 180),
        acceleration = Vector3.new(0, -10, 0),
        texture = pickTexture(templateId, "burstTextureAssetId"),
    })
    model:SetAttribute("ConfiguredDuration", math.max(config.flashDuration or 0.15, 0.45) + 0.2)
end

local function buildAOEField(templateId: string, model: Model, root: BasePart, config)
    createDiskPulse(templateId, root, {
        name = "AreaPulse",
        color = config.color,
        radius = config.radius or 3,
        height = config.height or 0.18,
        fadeTime = 0.35,
        expandMultiplier = 1.08,
        transparency = 0.4,
        endTransparency = 0.9,
    })
    createEmitter(root, {
        name = "AreaParticles",
        color = config.color,
        secondaryColor = config.secondaryColor,
        size = makeSizeSequence(0.3, 0),
        lifetime = NumberRange.new(0.3, 0.6),
        speed = NumberRange.new(0.5, 2),
        rate = config.particleRate or 20,
        lightEmission = config.glowIntensity or 1.2,
        autoDisableAfter = 0.75,
        spreadAngle = Vector2.new(180, 180),
        acceleration = Vector3.new(0, 2, 0),
        texture = pickTexture(templateId, "emitterTextureAssetId"),
    })
    model:SetAttribute("ConfiguredDuration", 0.9)
end

local function buildBuffAura(templateId: string, model: Model, root: BasePart, config)
    createEmitter(root, {
        name = "Aura",
        color = config.color,
        secondaryColor = config.secondaryColor,
        size = config.particleSize or makeSizeSequence(0.3, 0.05),
        lifetime = config.lifetime or NumberRange.new(0.5, 1),
        speed = NumberRange.new(0.5, 1.5),
        rate = config.particleRate or 12,
        lightEmission = config.glowIntensity or 2,
        autoDisableAfter = resolveLifetime(config.lifetime or NumberRange.new(0.5, 1)) + 0.3,
        spreadAngle = Vector2.new(50, 180),
        lockedToPart = false,
        acceleration = Vector3.new(0, 2, 0),
        texture = pickTexture(templateId, "emitterTextureAssetId"),
    })
    createDiskPulse(templateId, root, {
        name = "AuraRing",
        color = config.secondaryColor or config.color,
        radius = 1.8,
        height = 0.1,
        fadeTime = 0.45,
        expandMultiplier = 1.02,
        transparency = 0.55,
        endTransparency = 0.8,
        texture = parseAssetId((getAssetConfig(templateId) or {}).ringTextureAssetId),
    })
    createPointLight(root, config.color, math.max(1.5, config.glowIntensity or 2), 10)
    model:SetAttribute("ConfiguredDuration", resolveLifetime(config.lifetime or NumberRange.new(0.5, 1)) + 0.4)
end

local function buildChannelBeam(templateId: string, model: Model, root: BasePart, config)
    createForwardBeam(model, root, config.beamLength or 12, config.beamWidth or 2.5, config.color, config.innerGlow or config.secondaryColor)
    createEmitter(root, {
        name = "BeamOrigin",
        color = config.color,
        secondaryColor = config.innerGlow or config.secondaryColor,
        size = makeSizeSequence(0.5, 0),
        lifetime = NumberRange.new(0.2, 0.35),
        speed = NumberRange.new(0, 0),
        rate = config.particleRate or 60,
        lightEmission = config.glowIntensity or 3,
        autoDisableAfter = 0.4,
        lockedToPart = true,
        spreadAngle = Vector2.new(15, 15),
        texture = pickTexture(templateId, "emitterTextureAssetId"),
    })
    model:SetAttribute("ConfiguredDuration", 0.5)
end

local function buildExplosion(templateId: string, model: Model, root: BasePart, config)
    createDiskPulse(templateId, root, {
        name = "Shockwave",
        color = config.color,
        radius = config.radius or 4,
        height = 0.14,
        fadeTime = config.fadeTime or 0.5,
        expandMultiplier = 1.35,
        transparency = 0.2,
        texture = parseAssetId((getAssetConfig(templateId) or {}).shockwaveTextureAssetId),
    })
    createSpherePulse(root, {
        name = "ExplosionCore",
        color = config.secondaryColor or config.color,
        radius = math.max(2, (config.radius or 4) * 0.6),
        fadeTime = 0.2,
        expandMultiplier = 1.25,
        transparency = 0.12,
    })
    createEmitter(root, {
        name = "ExplosionBurst",
        color = config.color,
        secondaryColor = config.secondaryColor,
        size = makeSizeSequence(0.45, 0),
        lifetime = NumberRange.new(0.2, 0.5),
        speed = NumberRange.new(8, config.expandSpeed or 20),
        emitCount = config.particleBurst or 20,
        lightEmission = config.flashIntensity or 2.5,
        spreadAngle = Vector2.new(180, 180),
        acceleration = Vector3.new(0, -6, 0),
        texture = pickTexture(templateId, "burstTextureAssetId"),
    })
    model:SetAttribute("ConfiguredDuration", (config.fadeTime or 0.5) + 0.2)
end

local function buildTrail(templateId: string, model: Model, root: BasePart, config)
    createTrail(root, config.width or 1, config.color, config.secondaryColor, config.fadeTime or 0.5)
    createEmitter(root, {
        name = "TrailDust",
        color = config.color,
        secondaryColor = config.secondaryColor,
        size = makeSizeSequence(0.2, 0),
        lifetime = NumberRange.new(0.15, 0.3),
        speed = NumberRange.new(0, 1.5),
        rate = 18,
        lightEmission = 1,
        autoDisableAfter = config.fadeTime or 0.5,
        lockedToPart = true,
        spreadAngle = Vector2.new(25, 25),
        texture = pickTexture(templateId, "emitterTextureAssetId"),
    })
    model:SetAttribute("ConfiguredDuration", (config.fadeTime or 0.5) + 0.1)
end

function VFXProceduralBuilder.Build(templateId: string, config): Instance?
    if type(config) ~= "table" or type(config.type) ~= "string" then
        return nil
    end

    local model, root = makeRootModel(templateId)
    model:SetAttribute("GeneratedVFX", true)
    model:SetAttribute("TemplateType", config.type)

    if config.type == "Projectile" then
        buildProjectile(templateId, model, root, config)
    elseif config.type == "MeleeSlash" then
        buildMeleeSlash(templateId, model, root, config)
    elseif config.type == "Impact" then
        buildImpact(templateId, model, root, config)
    elseif config.type == "AOEField" then
        buildAOEField(templateId, model, root, config)
    elseif config.type == "BuffAura" then
        buildBuffAura(templateId, model, root, config)
    elseif config.type == "ChannelBeam" then
        buildChannelBeam(templateId, model, root, config)
    elseif config.type == "Explosion" then
        buildExplosion(templateId, model, root, config)
    elseif config.type == "Trail" then
        buildTrail(templateId, model, root, config)
    else
        model:Destroy()
        return nil
    end

    return model
end

local function playPulsePart(part: BasePart)
    local fadeTime = part:GetAttribute("PulseFadeTime")
    if type(fadeTime) ~= "number" or fadeTime <= 0 then
        return
    end

    local expandMultiplier = part:GetAttribute("PulseExpandMultiplier")
    if type(expandMultiplier) ~= "number" or expandMultiplier <= 0 then
        expandMultiplier = 1.15
    end

    local endTransparency = part:GetAttribute("PulseEndTransparency")
    if type(endTransparency) ~= "number" then
        endTransparency = 1
    end

    local endSize = part.Size * expandMultiplier
    local tween = TweenService:Create(part, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = endSize,
        Transparency = endTransparency,
    })
    tween:Play()
end

function VFXProceduralBuilder.Play(vfxInstance: Instance)
    for _, descendant in ipairs(vfxInstance:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            local emitCount = descendant:GetAttribute("EmitCount")
            if type(emitCount) == "number" and emitCount > 0 then
                descendant:Emit(emitCount)
            end

            if descendant:GetAttribute("EnableOnPlay") == true then
                descendant.Enabled = true
                local autoDisableAfter = descendant:GetAttribute("AutoDisableAfter")
                if type(autoDisableAfter) == "number" and autoDisableAfter > 0 then
                    task.delay(autoDisableAfter, function()
                        if descendant.Parent then
                            descendant.Enabled = false
                        end
                    end)
                end
            end
        elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
            if descendant:GetAttribute("EnableOnPlay") == true then
                descendant.Enabled = true
                local autoDisableAfter = descendant:GetAttribute("AutoDisableAfter")
                if type(autoDisableAfter) == "number" and autoDisableAfter > 0 then
                    task.delay(autoDisableAfter, function()
                        if descendant.Parent then
                            descendant.Enabled = false
                        end
                    end)
                end

                if descendant:IsA("Trail") and descendant:GetAttribute("AutoClearAfter") then
                    descendant:Clear()
                end
            end
        elseif descendant:IsA("PointLight") then
            if descendant:GetAttribute("EnableOnPlay") == true then
                descendant.Enabled = true
                local autoDisableAfter = descendant:GetAttribute("AutoDisableAfter")
                if type(autoDisableAfter) == "number" and autoDisableAfter > 0 then
                    task.delay(autoDisableAfter, function()
                        if descendant.Parent then
                            descendant.Enabled = false
                        end
                    end)
                end
            end
        elseif descendant:IsA("BasePart") and descendant:GetAttribute("PulsePart") == true then
            playPulsePart(descendant)
        end
    end
end

function VFXProceduralBuilder.Stop(vfxInstance: Instance)
    for _, descendant in ipairs(vfxInstance:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            descendant.Enabled = false
        elseif descendant:IsA("Trail") or descendant:IsA("Beam") then
            descendant.Enabled = false
        elseif descendant:IsA("PointLight") then
            descendant.Enabled = false
        end
    end
end

return VFXProceduralBuilder
