# Studio Cleanliness Contract

This project treats the repository as the only source of truth.
Roblox Studio is a runtime and validation surface, not a second system of record.

## Allowed Runtime Entry Points

Only these Rojo-mapped roots may contain gameplay logic:

- `ReplicatedStorage.Shared`
- `ServerScriptService.Server`
- `StarterPlayer.StarterPlayerScripts.Client`

## Studio Rules

- Do not add business scripts, ModuleScripts, config tables, or RemoteEvents directly in Studio.
- `ReplicatedStorage.Remotes` must only be created by `src/shared/Remotes.luau`.
- Any gameplay object that needs to exist in Studio must first be added to the repo and synced through Rojo.
- Non-logic scene assets under services like `Workspace`, `Lighting`, and `SoundService` may remain in Studio when they are part of the place itself.

## Dirty State Definition

Studio is considered dirty if any of the following appear outside the Rojo-mapped roots:

- gameplay `Script`, `LocalScript`, or `ModuleScript`
- config registries or hero/skill data folders
- standalone gameplay `RemoteEvent` or `RemoteFunction`
- hand-authored client UI/controller trees that are not sourced from `src/client`

## Cleanup Expectation

If Studio drifts from this contract, clean the Studio objects instead of adapting repo code around them.
If runtime validation reveals a missing object, add it to the repo and resync through Rojo.
