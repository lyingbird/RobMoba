# Asset Table Notes

## Why one image can appear in multiple places
That is not automatically wrong.

In Roblox VFX work, one uploaded image is often reused across:
- multiple skills of the same hero
- both a burst and a directional flash
- several variants of the same effect beat

This is normal because Roblox effects are usually built from a small reusable texture vocabulary, not one unique image per sub-layer.

## What was actually wrong in your earlier table
The wrong part was not image reuse itself.
The wrong part was putting an image asset id into mesh fields such as:
- `pulseMeshAssetId`
- `ringMeshAssetId`
- `shockwaveMeshAssetId`
- `coreMeshAssetId`

Those fields are reserved for future mesh assets and should stay empty unless you upload a real mesh asset.

## Correct field meaning
- `emitterTextureAssetId`: image used by `ParticleEmitter.Texture`
- `burstTextureAssetId`: image used by burst-style particle emitters
- `pulseTextureAssetId`: image projected onto procedural pulse parts
- `ringTextureAssetId`: image projected onto aura ring pulse parts
- `shockwaveTextureAssetId`: image projected onto explosion shockwave pulse parts

## Current fix applied
I cleaned the table so that:
- image ids remain only in texture fields
- mesh fields are blank again
- notes now explain intentional reuse

## Reuse policy going forward
Use the same image across multiple entries when:
- the silhouette language is the same
- the color family is the same
- the effect is only a variation in timing/scale/intensity

Prefer separate images when:
- one is a ring/decal and one is a soft glow sprite
- one is a trail streak and one is a radial burst
- the gameplay readability would improve with a distinct silhouette
