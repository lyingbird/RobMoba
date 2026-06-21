# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RobMoba is a lightweight MOBA demo for Roblox Studio. It implements a full client-server
MOBA loop: champion select, lobby + 1v1 matchmaking, arena duels with kill-to-win scoring,
a data-driven skill system, stats/leveling, items/runes, energy, buffs, passives, enemy AI,
a training mode, and both PC (keyboard/mouse) and mobile (joystick/buttons) controls.

## Tech Stack & Tooling

- **Language:** Luau (Roblox dialect)
- **Sync:** Rojo (filesystem ↔ Studio). Toolchain pinned via Aftman (`aftman.toml` → `rojo 7.7.0-rc.1`).
- **Place file:** `build.rbxl` (gitignored; the bound Studio place).

There is **no CLI build, lint, or automated test suite**. The dev loop runs entirely inside Studio:

```bash
aftman install      # install pinned Rojo
rojo serve          # start sync server (Studio Rojo plugin → Connect to localhost)
```

Then in Studio:
- **Single-player** (UI, skills, training dummy): `TEST → Play Solo` (F5).
- **Multiplayer** (matchmaking, duels, teams, scoring): `TEST → Players: 2 → Start` — use **Start**, not Play Solo; ≥2 players are required to trigger a match.

"Testing" = manual verification in Studio + reading the Server window Output log. See README.md
for the expected server log chain (`[LobbyManager] … [DuelManager] … [MatchSystem] …`).

## Architecture: the big picture

Reading these wiring patterns first will save you from misreading the codebase.

### Cross-system coupling via `shared`

Top-level `*.server.lua` scripts in `ServerScriptService/` are independent entry points that
self-register into the global `shared` table. They find each other through it — there is no
central DI. The registered managers are:

`shared.LobbyManager`, `shared.DuelManager`, `shared.MatchSystem`, `shared.TrainingManager`,
`shared.PlayerSkillManager`, `shared.GameManager`.

Code that depends on another system **must** guard the lookup (`if shared.X then … end`) because
load order is not guaranteed. Example: `PlayerSkillManager` reads player state via
`shared.LobbyManager.GetPlayerState(player)` and active-battle status via `shared.DuelManager`.

`Server.server.lua` is **not** the only entry point — it only initializes `InventoryManager`
and `StatsManager`. The lobby/duel/match/training/skill managers each boot themselves.

### Data-driven skill pipeline (the core system)

Skills are pure data + reusable behavior classes. Adding content rarely needs new framework code.

```
Heroes/<Name>.lua  ─┐                         (per-hero data: HeroID, Role, Skills{Q,W,R}=ids,
                    ├─► HeroRegistry  ◄──────── EnergyType, Poses, CastDurations, MoveLock…)
Skills/<Name>_Skills.lua ─► SkillRegistry      (per-skill data: ArchetypeType, CD, Range,
                    │                            EnergyCost, OnHitEffects/OnHitCC/TickEffects → effect ids)
                    ▼
ServerModules/Skills/Skill_XXXX.lua            (behavior: inherits an Archetype, may override OnCast)
   └─ Archetypes/{Projectile,Beam,Area,Dash,Instant}Skill.lua  (extends BaseSkill via Template Method)
        └─ SkillHelper.ApplyEffects → BuffSystem → EffectExecutor → EffectConfig[id]
```

- **`HeroRegistry` / `SkillRegistry`** auto-discover every ModuleScript in `Heroes/` and `Skills/`
  at require time. They are the successors to the old flat `HeroConfig`/`SkillConfig` and keep the
  same access shape (`HeroRegistry["Angela"].Skills.Q == 1006`, `SkillRegistry[1006].Name`).
- **Archetypes** (`ServerModules/Archetypes/`) hold the generic behavior (projectile flight,
  beam channel, AoE, dash, instant). A `Skill_XXXX` module subclasses one and supplies parameters
  via the registry; it overrides `OnCast` only for special behavior (e.g. `Skill_1006` AngelaQ
  fans 5 projectiles). All concrete skills ultimately extend `BaseSkill` (cooldown, runes, recast).
- **Effects are decoupled from skills.** A skill references numeric effect ids; `EffectConfig.lua`
  defines them (6 types: `Damage`, `CC`, `Shield`, `StatMod`, `DoT`, `HoT`). `SkillHelper` →
  `BuffSystem` apply them; `EffectExecutor` is the only place that mutates target Humanoids
  (damage-after-shield, CC via anchor/MovementState locks, stacked stat modifiers, shields).
  Effect-id ranges are namespaced per hero — see the header comment in `EffectConfig.lua`
  (LianPo uses real Honor-of-Kings ids like `105xxx`; others use temporary ids).

### Skill cast flow (server authority)

`CastSkillEvent` (client) → `PlayerSkillManager`:
1. `canPlayerCast` — gate on player state (`DUELING`/`TRAINING` only), live character, `CanCastSkill`
   attribute (set false by CC), and that the equipped skill id matches the hero's Q/W/R.
2. Resolve aim (direction vs. position, clamped to range) and check `EnergySystem` cost.
3. `skillInstance:OnCast` → archetype logic → effects. Then start cooldown and `SyncCooldownEvent`
   back to the client. Recastable skills defer cooldown until the recast detonation.

`TrainingManager` no-CD / no-cost mode is honored in `BaseSkill:CanCast`/`StartCooldown` and the
cast handler — keep new skills compatible by going through `BaseSkill`, not by hardcoding cooldowns.

### Client (StarterPlayerScripts)

`Client.client.lua` boots `UIManager` and the `Modules/`. Input is split: `InputManager`
(PC QWER + mouse aim + right-click move) and `MobileInputManager` + `UI_VirtualJoystick` /
`UI_SkillButtons` / `UI_MobileHUD` (touch). `CameraManager` is the MOBA top-down camera;
`CinematicManager` does ultimate close-ups. UI is code-built (no .rbxmx), Chinese player-facing strings.

### RemoteEvents

Declared statically in `default.project.json` under ReplicatedStorage, **and** defensively
re-ensured at runtime (`RemoteEventInit.server.lua`, plus `ensureRemoteEvent` in
`PlayerSkillManager`). When adding a remote, add it in both places.

## Project Structure

```
src/
  ReplicatedStorage/        Shared data + registries
    HeroRegistry / SkillRegistry   Auto-discovery aggregators
    Heroes/<Name>.lua              Per-hero data (Angela, HouYi, LianPo, Lux, Test)
    Skills/<Name>_Skills.lua       Per-hero skill data tables
    EffectConfig / EnergyConfig / PassiveConfig / RuneConfig / ItemConfig / LevelConfig
  ServerScriptService/      Server logic (top-level *.server.lua = self-booting managers)
    LobbyManager / DuelManager / MatchSystem / PlayerSkillManager / TrainingManager / Server
    ServerModules/
      BaseSkill / CombatUtils / StatsManager / InventoryManager
      BuffSystem / EffectExecutor / EnergySystem / PassiveSystem / SkillHelper / SkillPresenter
      MovementState                 Stacked movement/anchor lock tokens (used by CC)
      Archetypes/                   Projectile/Beam/Area/Dash/Instant base behaviors
      Skills/Skill_XXXX.lua         Concrete skill implementations
  StarterPlayer/StarterPlayerScripts/
    Client / UIManager + Modules/ (input, camera, cooldown, cinematic, animator, mobile)
    UIComponents/ (HUD, HeroSelect, Backpack, DragDrop, MatchButton, Minimap, Mobile*, Training)
  ServerStorage/SkillEditorPlugin.server.lua   Studio plugin for authoring skills
```

## Champion roster & skill ids

| Hero | Role | Q / W / R skill ids |
|------|------|---------------------|
| Lux | Mage | 1002 / 1003 / 1005 |
| Angela | Mage | 1006 / 1007 / 1008 |
| HouYi | Marksman | 1009 / 1010 / 1011 |
| LianPo | Tank | 10510 / 10520 / 10530 (real HoK ids) |
| Test | — | dev/sandbox hero |

(Confirm ids against `Heroes/<Name>.lua` `Skills` tables; skill ids are **not** a contiguous
1001–1015 range despite the file naming.)

## Coding Conventions

- Server scripts use `.server.lua`; client scripts use `.client.lua`; ModuleScripts use `.lua`.
- Shared data lives in ReplicatedStorage; server-only logic in `ServerScriptService/ServerModules`.
- Config tables key on numeric ids (`[1006]`, `[3020]`); player-facing `UIName`/`DisplayName` are Chinese.
- New skill: add data to a `Skills/<Hero>_Skills.lua` entry (+ effect ids in `EffectConfig.lua`) and a
  `ServerModules/Skills/Skill_XXXX.lua` that extends the matching Archetype. Registries auto-pick it up.
- New hero: add `Heroes/<Name>.lua` with a `HeroID`; HeroRegistry discovers it automatically.
- Mutate target health/stats only through `EffectExecutor`/effect ids, not ad-hoc `TakeDamage`,
  so shields, damage reduction, CC immunity, energy gain, and passives stay consistent.

## AI Agent development pipeline (`.codebuddy/`)

The repo ships a CodeBuddy-driven 8-role game-dev workflow (制作人/PM/策划/主程/程序/美术/QA/UX)
under `.codebuddy/rules/`, driven by `/gd:` commands (`/gd:new`, `/gd:feature`, `/gd:bugfix`,
`/gd:status`, `/gd:resume`, …). Requirements and design docs live in `.GameDev/`
(`_ProjectManagement/需求池.md`, `进度看板.md`, per-REQ folders). This is a separate process layer
from the game code; consult it for product/requirement context, not runtime behavior.

## AI Team Configuration (autogenerated by team-configurator, 2026-03-13)

**Important: YOU MUST USE subagents when available for the task.**

| Task | Agent |
|------|-------|
| Codebase exploration & onboarding | `code-archaeologist` |
| Code review & PR checks (before every merge) | `code-reviewer` |
| Performance profiling (frame budget, network, GC) | `performance-optimizer` |
| Documentation & README updates | `documentation-specialist` |
| Project analysis & stack detection | `project-analyst` |
| Multi-step feature planning (new champion, map, matchmaking) | `tech-lead-orchestrator` |
| Open-ended investigation / structured implementation | `Explore` / `Plan` |

No framework-specific agents apply (Luau/Roblox game, not a web stack); the language-agnostic
core and orchestrator agents are assigned instead.

---
*Architecture sections last updated: 2026-06-13*
```
