# LianPo First-Pass Roblox Mapping

## Status
LianPo is now the first active hero in the migration pipeline.
A first-pass Roblox procedural runtime is already wired into the project, so existing LianPo template ids can start rendering as generated effects instead of falling back to the generic emergency particle.

## Prefab families worth converting first
- `LianPo_attack_Spell02A_LOD1`: prep ring / cast area accent
- `LianPo_attack_Spell02D_LOD1`: main slam hit and crack burst
- `LianPo_attack_Spell03A_LOD1`: charge wave / heavy impact pulse
- `LianPo_buff01_LOD1`: charge state aura
- `LianPo_buff02_LOD1`: super armor aura

## What the analysis says
### Spell02D
- 8 particle systems
- 8 particle renderers
- 3 mesh renderers
- render mix: `Billboard`, `HorizontalBillboard`, `StretchBillboard`, `Mesh`
- interpretation: this is a layered slam effect with dust, explosion flash, crack mesh particles, and glow pulses

### Spell03A
- 5 particle systems
- 5 particle renderers
- 2 mesh renderers
- render mix: `Billboard`, `HorizontalBillboard`, `StretchBillboard`, `Mesh`
- interpretation: this is a cleaner ring/pulse effect with radial accents and one or two key mesh silhouettes

## Roblox implementation decisions
### Spell02D -> `lianpo_slam_explosion`
Use:
- 1 expanding ground ring pulse
- 1 short burst particle emitter for dust/debris
- 1 bright center flash pulse
- 1 optional outward streak or shockwave layer

Do not port literally:
- multiple separate glow billboards
- shader-driven edge distortion
- dense mesh particle duplication

### Spell03A -> `lianpo_charge_wave`
Use:
- 1 slash/charge pulse mesh-like strip
- 1 directional spark emitter
- 1 subtle debris or dust accent

Do not port literally:
- repeated ornamental glow stacks
- exact mesh particle inventory

### Buff01/Buff02 -> aura presets
Use:
- low-rate aura emitter attached to root
- one thin ring pulse for state readability
- short accent burst on state start

## Templates already wired on Roblox side
These ids now resolve through the procedural runtime if no hand-authored prefab exists:
- `lianpo_charge_wave`
- `lianpo_enhanced_punch`
- `lianpo_ring_outer`
- `lianpo_ring_mid`
- `lianpo_ring_inner`
- `lianpo_ground_crack`
- `lianpo_charge_aura`
- `lianpo_slam_explosion`
- `lianpo_charge_dust`
- `lianpo_shockwave`
- `lianpo_w_release`

## Mobile budget guidance
Per visible skill beat, aim roughly for:
- 1 to 3 emitters
- 0 to 2 pulse parts
- lifetime under 1.2s for burst layers
- avoid high constant `Rate` emitters for combat impacts

## Next Roblox-side code work
1. Add authored textures and optional real prefab assets for the most important LianPo beats.
2. Tune color, scale, and lifetime by testing on device.
3. After LianPo is stable, repeat the same pipeline for the next hero id you give.
