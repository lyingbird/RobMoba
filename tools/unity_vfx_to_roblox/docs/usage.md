# Usage

## 1. Group prefab families
```powershell
python tools/unity_vfx_to_roblox/scripts/group_prefab_lods.py `
  E:\trunk\Project\Assets\CustomResources\Shared\Prefab_Skill_Effects\Hero_Skill_Effects\105_LianPo `
  --out tools/unity_vfx_to_roblox/analysis/lianpo_families.json
```

## 2. Analyze one source prefab
```powershell
python tools/unity_vfx_to_roblox/scripts/analyze_unity_prefab.py `
  E:\trunk\Project\Assets\CustomResources\Shared\Prefab_Skill_Effects\Hero_Skill_Effects\105_LianPo\LianPo_attack_Spell02D_LOD1.prefab `
  --out tools/unity_vfx_to_roblox/analysis/lianpo_spell02d_lod1.json
```

## 3. Optional deeper export from Unity Editor
- Open Unity `2022.3.5f1`.
- Copy `tools/unity_vfx_to_roblox/unity_editor/ExportVfxPrefabSummary.cs` into an Editor folder in the Unity project, for example:
  - `E:\trunk\Project\Assets\Editor\ExportVfxPrefabSummary.cs`
- Let Unity recompile.
- In Project view, select a prefab.
- Click `Tools -> VFX -> Export Selected Prefab Summary`.
- Read the exported JSON from `E:\trunk\Project\Temp\VfxExports`.

## 4. Roblox implementation path
- Convert the report into a Roblox archetype.
- Put authored Roblox assets under a future `ReplicatedStorage/Assets/VFX` folder.
- Reference those assets through `src/shared/VFXTemplateTable.luau` and `src/client/VFXLibrary.luau`.

## 5. Decision rule
If a Unity effect depends mainly on particle count and shader glow, simplify.
If it depends on a unique mesh silhouette that communicates gameplay, preserve the mesh silhouette.

## First milestone
Reach one end-to-end conversion for LianPo:
- `Spell02D` slam impact
- `Spell03A` charge wave
- `buff01` aura

Once those three work in Roblox on mobile, scale the pipeline to other heroes.
