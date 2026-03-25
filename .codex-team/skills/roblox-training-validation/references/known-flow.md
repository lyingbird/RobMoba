# Known Flow

## Repo Mainline Flow

1. Player joins and spawns in the lobby.
2. Lobby UI shows two entry points:
   `PVP匹配`
   `单人训练`
3. Choosing `单人训练` opens hero select.
4. Player selects and locks a hero.
5. Client enters training mode with that hero.
6. Combat HUD appears only after training gameplay starts.
7. Mobile movement uses Roblox virtual joystick.
8. Player can move to a dummy and attack.

## Current Repo Protocol

- Mode entry uses `ReplicatedStorage.Remotes.ModeSelect`.
- Hero confirmation uses `ReplicatedStorage.Remotes.HeroSelect`.
- State updates use `ReplicatedStorage.Remotes.GameStateChanged`.
- Combat uses the repo `ReplicatedStorage.Remotes` contract rather than legacy standalone remotes.

## Validation Signals

- Lobby visible and combat HUD hidden on first spawn.
- Training entry:
  - `LobbyUI.Enabled = true` before mode select
  - `HeroSelectUI.Enabled = true` after selecting training
- Training confirmation:
  - `[HeroManager] <player> 选择了 <hero>`
  - player respawns into training area
- Combat start:
  - `SkillBarUI.Enabled = true`
  - `HealthBarUI.Enabled = true`
  - `CombatUI.Enabled = true`

## Known Risks

- PVP matching is currently a lightweight repo implementation, not the old live Studio stack.
- MCP GUI clicking can still be flaky for layered mobile-style controls.
- If lobby and HUD are both visible at once, treat it as a regression.
