---
name: roblox-training-validation
description: Validate the live Roblox training flow for this project when the user asks to test training mode, hero selection, lobby-to-training transitions, skill release, dummy damage, or end-to-end gameplay verification in Studio. Use this for repeatable regression checks against the currently running Studio system.
---

# Roblox Training Validation

Use this skill when the task is to verify the current playable training flow in Roblox Studio.

## Standard Validation Flow

1. Confirm the active Studio instance is correct.
2. Start play mode.
3. Verify lobby loads and combat buttons are absent in the hall.
4. Enter training mode from the lobby.
5. Confirm hero selection.
6. Confirm a hero for training mode.
7. Verify the training panel appears and combat buttons appear only after gameplay starts.
8. Move near a dummy.
9. Trigger basic attack and at least one skill.
10. Confirm dummy HP decreases.
11. Stop play mode.
12. Write results into `.codex-team`.

## Project Notes

- Repository is the long-term truth source, but live Studio currently runs the lobby/training stack.
- Prefer real UI interaction first.
- If MCP GUI hit-testing is unstable, use project-native test bridges only for the unstable step.
- `GM_ForceHeroConfirm` is acceptable for flaky hero-select interaction.
- Combat validation may fall back to the same RemoteEvents the live client uses.

## Success Criteria

- No combat buttons in lobby
- Training mode entry works
- Hero confirmation works
- Training panel appears
- `Q/W/R/Attack` appear only after gameplay starts
- Dummy HP drops after attack
