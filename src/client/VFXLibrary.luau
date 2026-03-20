--[[
    VFXLibrary.luau
    特效模板库

    职责：
    - 根据 VFXTemplateTable 预加载特效模板
    - 优先返回手工预制体，其次生成程序化特效
    - 统一播放/停止/清理逻辑
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VFXProceduralBuilder = require(script.Parent:WaitForChild("VFXProceduralBuilder"))

local VFXLibrary = {}
VFXLibrary.__index = VFXLibrary

VFXLibrary._cachedTemplates = {}
VFXLibrary._cachedPrefabs = {}

function VFXLibrary:_countTable(t)
    local count = 0
    for _ in pairs(t) do
        count += 1
    end
    return count
end

function VFXLibrary:PreloadAllTemplates()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if not shared then
        return
    end

    local vfxTableModule = shared:FindFirstChild("VFXTemplateTable")
    if not vfxTableModule then
        return
    end

    local success, VFXTemplateTable = pcall(require, vfxTableModule)
    if not success or not VFXTemplateTable then
        return
    end

    local templates = nil
    if VFXTemplateTable.getAll then
        templates = VFXTemplateTable.getAll()
    end

    if not templates then
        return
    end

    for templateId, config in pairs(templates) do
        if type(config) == "table" and config.type then
            VFXLibrary._cachedTemplates[templateId] = config
        end
    end

    local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
    if assetsFolder then
        local vfxFolder = assetsFolder:FindFirstChild("VFX")
        if vfxFolder then
            for templateId in pairs(templates) do
                local prefab = vfxFolder:FindFirstChild(templateId)
                if prefab then
                    local cachedPrefab = prefab:Clone()
                    cachedPrefab.Parent = nil
                    VFXLibrary._cachedPrefabs[templateId] = cachedPrefab
                    print("[VFXLibrary] preloaded prefab: " .. templateId)
                end
            end
        end
    end

    print("[VFXLibrary] templates loaded: " .. tostring(VFXLibrary:_countTable(VFXLibrary._cachedTemplates)))
end

function VFXLibrary:GetTemplateConfig(templateId: string)
    return VFXLibrary._cachedTemplates[templateId]
end

function VFXLibrary:GetTemplate(templateId: string): Instance?
    if VFXLibrary._cachedPrefabs[templateId] then
        return VFXLibrary._cachedPrefabs[templateId]:Clone()
    end

    local config = VFXLibrary._cachedTemplates[templateId]
    if config then
        return VFXProceduralBuilder.Build(templateId, config)
    end

    return nil
end

function VFXLibrary:PlayVFX(vfxInstance: Instance)
    if vfxInstance:GetAttribute("GeneratedVFX") == true then
        VFXProceduralBuilder.Play(vfxInstance)
        return
    end

    for _, descendant in ipairs(vfxInstance:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            descendant.Enabled = true
        elseif descendant:IsA("Sound") then
            descendant:Play()
        elseif descendant:IsA("Light") then
            descendant.Enabled = true
        elseif descendant:IsA("Beam") then
            descendant.Enabled = true
        elseif descendant:IsA("Trail") then
            descendant.Enabled = true
        end
    end
end

function VFXLibrary:StopVFX(vfxInstance: Instance)
    if vfxInstance:GetAttribute("GeneratedVFX") == true then
        VFXProceduralBuilder.Stop(vfxInstance)
        return
    end

    for _, descendant in ipairs(vfxInstance:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            descendant.Enabled = false
        elseif descendant:IsA("Sound") then
            descendant:Stop()
        elseif descendant:IsA("Light") then
            descendant.Enabled = false
        elseif descendant:IsA("Beam") then
            descendant.Enabled = false
        elseif descendant:IsA("Trail") then
            descendant.Enabled = false
        end
    end
end

function VFXLibrary:CleanupVFX(vfxInstance: Instance, duration: number?)
    local cleanupTime = duration

    if not cleanupTime then
        cleanupTime = VFXLibrary:_getVFXDuration(vfxInstance)
        if cleanupTime <= 0 then
            cleanupTime = 5
        end
    end

    task.delay(cleanupTime, function()
        if vfxInstance and vfxInstance.Parent then
            vfxInstance:Destroy()
        end
    end)
end

function VFXLibrary:_getVFXDuration(vfxInstance: Instance): number
    local configuredDuration = vfxInstance:GetAttribute("ConfiguredDuration")
    if type(configuredDuration) == "number" and configuredDuration > 0 then
        return configuredDuration
    end

    local maxDuration = 0

    for _, descendant in ipairs(vfxInstance:GetDescendants()) do
        if descendant:IsA("ParticleEmitter") then
            local lifetime = descendant.Lifetime.Max
            if lifetime > maxDuration then
                maxDuration = lifetime
            end
        elseif descendant:IsA("Sound") then
            local soundDuration = descendant.TimeLength
            if soundDuration > maxDuration then
                maxDuration = soundDuration
            end
        end
    end

    return maxDuration + 0.5
end

return VFXLibrary
