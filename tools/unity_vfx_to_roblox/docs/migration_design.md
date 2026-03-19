# Migration Design

## Why not direct import
Roblox cannot natively execute Unity `ParticleSystem`, custom shader graphs, or a game-specific rendering pipeline. For your source project, the custom Wangzhe rendering stack is the hard blocker. Even if meshes and textures can be extracted, the authored look depends on Unity-only shader behavior.

So the correct approach is not literal import. It is:
1. batch inspect Unity prefabs,
2. identify reusable source assets,
3. reduce each effect into a Roblox-friendly visual recipe,
4. generate or hand-author Roblox templates from that recipe.

## Practical target model in Roblox
For mobile-first 1v1 combat, prefer these Roblox building blocks:
- `ParticleEmitter` for sparks, dust, aura, burst, embers
- `Trail` for movement streaks
- `Beam` for slash arcs and energy bands
- flat mesh or cylinder parts for ground rings and impact decals
- short tweened mesh flashes for explosions and circles
- optional flipbook textures when a sprite sheet can replace shader animation

## Mapping rules
- Unity billboard particles -> Roblox `ParticleEmitter`
- Unity stretch billboard -> Roblox `ParticleEmitter` with speed/lifetime plus optional `Trail`
- Unity mesh particles -> either mesh parts with tweening, or simplified emitter if mesh shape is not critical
- Unity additive glow stack -> 1 emitter + 1 mesh ring, not multiple layered emitters
- Unity distortion/refraction/custom shader -> redesign to readable timing, scale, color pulse, and alpha fade
- Unity complex ground decals -> cylinder/plane mesh with animated transparency and size

## Performance rules for your game
- Mobile first, so do not chase the original layer count.
- Prefer 1-3 visible effect layers per skill beat.
- Prefer bursts over sustained high-rate emitters.
- Keep important combat information readable at a distance.
- Treat LOD1 as the semantic source, not the final particle count budget.

## Recommended pipeline
1. Analyze prefab families and ignore duplicate LOD variants.
2. Pick one source prefab per effect family, usually `LOD1`.
3. Export structure report.
4. Classify the effect into one Roblox archetype.
5. Generate an intermediate JSON spec.
6. Map that spec into Roblox template data and authored prefab assets.
7. Playtest on phone and trim layers aggressively.

## Initial archetypes for LianPo
- `Spell02A`: concentric prep/area ring
- `Spell02D`: slam impact / explosion / crack
- `Spell03A/B/C`: charge wave / ring pulses
- `Spell03D`: ground crack / end hit
- `buff01/buff02`: self aura / super armor state

## What MCP would help with
A Unity MCP or editor automation would help with deeper structured extraction of:
- particle curves
- gradients
- material names and textures
- mesh references
- prefab dependency graphs

But it is not required for the first milestone. I already set this up so we can start from text-prefab analysis and optional Unity editor export.
