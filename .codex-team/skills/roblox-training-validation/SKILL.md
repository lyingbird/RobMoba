---
name: roblox-training-validation
description: Validate the live Roblox training flow for this project when the user asks to test training mode, hero selection, lobby-to-training transitions, skill release, dummy damage, or end-to-end gameplay verification in Studio. Use this for repeatable regression checks against the currently running Studio system.
---

# Roblox Training Validation

Use this skill when the task is to verify the current playable training flow in Roblox Studio.

## What This Skill Covers

- Lobby loads without combat HUD leaking into the hall
- Entering training mode from the lobby
- Hero confirmation for training mode
- Training panel visibility
- Skill button visibility timing
- Basic attack and skill release against training dummies
- Capturing known deviations between repo truth and live Studio behavior

## Current Project Reality

- Repository code is the long-term truth source.
- Live Studio currently runs the lobby/training system, not the old repo `GameManager` gameplay loop.
- Training validation should therefore verify the live Studio path first, then record any repo-vs-Studio divergence.

## Standard Validation Flow

1. Confirm the active Studio instance is the intended one.
2. Start play mode.
3. Verify the lobby appears and combat skill buttons are not visible in the hall.
4. Enter training mode from the lobby UI.
5. Confirm hero selection appears.
6. Confirm a hero for training mode.
7. Verify the training panel appears and skill buttons appear only after entering gameplay.
8. Move near a dummy.
9. Trigger basic attack and at least one skill.
10. Confirm dummy HP decreases or other combat evidence appears.
11. Stop play mode.
12. Record results, blockers, and deviations in `.codex-team`.

## Preferred Execution Strategy

- Prefer real UI interaction for lobby entry and obvious buttons.
- If GUI hit-testing is unstable in MCP, use the project's own testing bridge only for the unstable step, not for the whole flow.
- For this project, `GM_ForceHeroConfirm` is acceptable when hero-select GUI interaction is flaky under MCP.
- If mobile skill-button `InputBegan/InputEnded` is unstable under MCP, use the same RemoteEvents the client actually uses to complete combat validation.

## Evidence To Capture

- Console lines showing training-mode entry or hero confirmation
- Presence or absence of key UI objects
- Dummy HP before and after attack
- Any warnings that indicate incomplete client/server sync

## Known Project-Specific Deviations

- Live Studio logs may show `GameManager` disabled while lobby/training systems are active.
- Training validation currently runs against the live Studio lobby/training stack.
- `SyncEnergyEvent` warnings indicate an unfinished client consumption path and should be noted if seen.

## Success Criteria

- Lobby loads cleanly
- No combat buttons in lobby
- Training mode can be entered
- Hero can be confirmed
- Training panel appears
- `Q/W/R/Attack` appear only after gameplay starts
- Dummy takes damage

## Report Format

- Result: pass or fail
- Verified path: lobby -> training -> hero confirm -> combat
- Evidence: key UI objects, console lines, HP delta
- Deviations: repo-vs-Studio or MCP interaction limitations
- Next fix: the highest-value follow-up
