# Unity VFX -> Roblox VFX

## Goal
Build a practical pipeline for converting Unity particle-based VFX into Roblox-friendly effects.

## Current status
- The tooling directory is in place.
- LianPo (hero `105`) is the first conversion target.
- Roblox now has a first-pass procedural VFX runtime that can build effects from `VFXTemplateTable` without requiring manually authored prefabs first.

## Scope
- Source: Unity 2022.3.5f1 project at `E:\trunk\Project`
- Sample hero: LianPo `Assets\CustomResources\Shared\Prefab_Skill_Effects\Hero_Skill_Effects\105_LianPo`
- Target: Roblox mobile-first gameplay VFX
- Quality bar: preserve gameplay readability and hero fantasy, not pixel-perfect parity

## Strategy
- Treat Unity prefabs as source descriptors, not assets to directly replay in Roblox.
- Extract prefab structure, particle systems, renderer modes, meshes, and referenced materials/textures.
- Normalize each Unity effect into a Roblox-oriented intermediate JSON spec.
- Map the spec to Roblox implementation primitives:
  - `ParticleEmitter`
  - `Beam`
  - `Trail`
  - mesh-like pulse parts with tweened scale/transparency
  - authored fallback presets for mobile performance
- Keep the workflow semi-automatic: batch analysis plus curated template mapping.

## Folder layout
- `scripts/`: local analysis/export scripts
- `configs/`: hero/effect mapping rules
- `analysis/`: generated reports and extracted JSON
- `unity_editor/`: optional Unity editor scripts for deeper export
- `docs/`: migration docs and decisions

## Roblox runtime work already added
- `src/client/VFXProceduralBuilder.luau`
- `src/client/VFXLibrary.luau` now generates procedural effects from config when no prefab exists
- `src/client/VFXController.luau` now handles generated durations and instance-follow behavior more reliably
