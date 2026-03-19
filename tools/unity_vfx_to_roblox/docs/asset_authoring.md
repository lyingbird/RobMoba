# Asset Authoring Guide

## Goal
Replace the current pure-procedural first pass with better-looking LianPo assets while keeping the same template ids and runtime.

## Where to plug asset ids
Edit:
- `src/shared/VFXAssetTable.luau`

Each entry can provide optional Roblox asset ids for:
- particle textures
- shockwave/ring textures
- mesh-like pulse surfaces

The current runtime reads this table automatically.

## Recommended order for LianPo
1. `lianpo_slam_explosion`
2. `lianpo_charge_wave`
3. `lianpo_ground_crack`
4. `lianpo_charge_aura`
5. `super_armor_aura`

## First upload set already prepared
Prepared folder:
- `tools/unity_vfx_to_roblox/exports/lianpo_105_core_upload`

Prepared manifest:
- `tools/unity_vfx_to_roblox/analysis/lianpo_105_core_upload_manifest.json`

Use this set first instead of uploading every extracted texture.

## What to make first
### 1. Burst texture
Use for:
- `lianpo_slam_explosion`
- `lianpo_w_release`
- `lianpo_shockwave`

Visual direction:
- warm bronze / dusty gold
- soft edge radial burst
- no fine detail that disappears on phone

### 2. Ring / crack texture
Use for:
- `lianpo_ring_outer`
- `lianpo_ring_mid`
- `lianpo_ring_inner`
- `lianpo_ground_crack`

Visual direction:
- cracked stone ring
- readable from top-down camera
- outer edge brighter than center

### 3. Slash band texture
Use for:
- `lianpo_charge_wave`
- `lianpo_enhanced_punch`

Visual direction:
- broad angled energy strip
- not a thin line
- one strong silhouette is better than many details

### 4. Aura texture
Use for:
- `lianpo_charge_aura`
- `super_armor_aura`

Visual direction:
- subtle embers or heavy dust motes
- do not make it too noisy during combat

## Upload workflow
1. Start from `tools/unity_vfx_to_roblox/exports/lianpo_105_core_upload`.
2. Upload the selected images into Roblox Studio as image assets.
3. Copy the resulting asset ids.
4. Fill the corresponding fields in `src/shared/VFXAssetTable.luau`.
5. Test in Studio and on mobile.

## Current runtime hooks
- Particle systems read `emitterTextureAssetId` or `burstTextureAssetId`.
- Pulse parts can read `pulseTextureAssetId`, `ringTextureAssetId`, or `shockwaveTextureAssetId`.
- If an asset id is empty, the runtime falls back to the current procedural visuals.

## Practical note
You do not need to finish all assets before testing. Start with one burst texture and one crack/ring texture; those two will already improve most of LianPo's readability.
