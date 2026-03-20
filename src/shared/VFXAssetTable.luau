--[[
    VFXAssetTable.luau

    Field semantics:
    - `emitterTextureAssetId`: image asset for ParticleEmitter.Texture
    - `burstTextureAssetId`: image asset for burst-style ParticleEmitter.Texture
    - `pulseTextureAssetId`: image asset applied to procedural pulse parts
    - `ringTextureAssetId`: image asset applied to aura ring pulse parts
    - `shockwaveTextureAssetId`: image asset applied to explosion shockwave pulse parts

    Reserved for future mesh-backed versions, leave empty unless you actually upload mesh assets:
    - `pulseMeshAssetId`
    - `ringMeshAssetId`
    - `shockwaveMeshAssetId`
    - `coreMeshAssetId`

    Notes:
    - Reusing one image across several VFX is normal and often desirable.
    - Reusing an image asset id inside both emitter and pulse fields is only correct if the same silhouette works in both places.
    - Mesh fields must not be filled with image asset ids.
]]

local VFXAssetTable = {
    lianpo_charge_wave = {
        unitySource = "LianPo_attack_Spell03A_LOD1",
        emitterTextureAssetId = "rbxassetid://116661024165266",
        pulseMeshAssetId = "",
        pulseTextureAssetId = "",
        notes = "Main charge wave. Current setup uses one shared glow texture for the emitter layer only.",
    },

    lianpo_ring_outer = {
        unitySource = "LianPo_attack_Spell02A_LOD1",
        emitterTextureAssetId = "",
        pulseMeshAssetId = "",
        pulseTextureAssetId = "",
        notes = "Outer prep ring. Fill pulseTextureAssetId with a ring image when ready.",
    },

    lianpo_ring_mid = {
        unitySource = "LianPo_attack_Spell03B_LOD1",
        emitterTextureAssetId = "",
        pulseMeshAssetId = "",
        pulseTextureAssetId = "",
        notes = "Mid ring accent layer. Fill pulseTextureAssetId with a ring image when ready.",
    },

    lianpo_ring_inner = {
        unitySource = "LianPo_attack_Spell03C_LOD1",
        emitterTextureAssetId = "",
        pulseMeshAssetId = "",
        pulseTextureAssetId = "rbxassetid://118251119008102",
        notes = "Inner bright ring. The uploaded image is used as a pulse surface, not as a mesh.",
    },

    lianpo_ground_crack = {
        unitySource = "LianPo_attack_Spell03D_LOD1",
        emitterTextureAssetId = "",
        pulseMeshAssetId = "",
        pulseTextureAssetId = "rbxassetid://98303694622348",
        notes = "Ground crack decal. This should be a pulse texture only.",
    },

    lianpo_charge_aura = {
        unitySource = "LianPo_buff01_LOD1",
        emitterTextureAssetId = "rbxassetid://124532261421231",
        ringMeshAssetId = "",
        ringTextureAssetId = "",
        notes = "Charge aura. The current image is only assigned to the emitter layer.",
    },

    super_armor_aura = {
        unitySource = "LianPo_buff02_LOD1",
        emitterTextureAssetId = "rbxassetid://124532261421231",
        ringMeshAssetId = "",
        ringTextureAssetId = "",
        notes = "Super armor aura. It currently reuses the same aura emitter image as charge aura.",
    },

    lianpo_slam_explosion = {
        unitySource = "LianPo_attack_Spell02D_LOD1",
        burstTextureAssetId = "rbxassetid://116661024165266",
        shockwaveMeshAssetId = "",
        shockwaveTextureAssetId = "",
        coreMeshAssetId = "",
        coreTextureAssetId = "",
        notes = "Main slam burst. Reusing the same glow image here is acceptable for a first pass.",
    },

    lianpo_shockwave = {
        unitySource = "LianPo_attack_Spell02D_E_LOD1",
        burstTextureAssetId = "",
        shockwaveMeshAssetId = "",
        shockwaveTextureAssetId = "",
        notes = "Secondary shockwave pass.",
    },

    lianpo_w_release = {
        unitySource = "LianPo_attack_Spell02D_LOD1",
        burstTextureAssetId = "rbxassetid://91211911967765",
        shockwaveMeshAssetId = "",
        shockwaveTextureAssetId = "",
        coreMeshAssetId = "",
        coreTextureAssetId = "",
        notes = "W release burst. Usually can share assets with slam explosion.",
    },
}

function VFXAssetTable.getTemplate(templateId: string)
    return VFXAssetTable[templateId]
end

return VFXAssetTable
