# Mobile Combat UI Spec

> Last updated: 2026-03-20
> Scope: mobile battle HUD and skill interaction contract for this project
> Status: design contract, not yet fully implemented

---

## 1. Goal

This document defines the mobile combat HUD and skill interaction model for the current Roblox MOBA project.

The target experience is:

1. Players enter the game into the lobby first.
2. Players choose `PVP Match` or `Solo Training`.
3. After hero lock-in and actual gameplay entry, the mobile battle HUD appears.
4. Mobile battle interaction must follow the "left joystick + right combat cluster" pattern instead of a keyboard-like `QWER` layout.

This spec is the project-specific adaptation of the shared mobile MOBA skill interaction framework.

---

## 2. Product Decisions Locked In

The following decisions are already confirmed and must be treated as hard constraints:

1. Mobile movement uses a virtual joystick on the left side.
2. Mobile HUD must not present skills as `QWER` keys.
3. The attack area keeps only one main basic-attack button.
4. The battle HUD keeps exactly one summoner-skill slot.
5. The full battle HUD appears only after actual combat entry, never in lobby mode.

---

## 3. HUD States

### 3.1 Lobby State

Visible:

- Lobby mode selection UI
- Minimal top-level system UI if needed

Hidden:

- Skill buttons
- Basic attack button
- Summoner skill button
- Health/mana combat HUD
- Combat cast indicators

### 3.2 Hero Select State

Visible:

- Hero selection and lock-in UI

Hidden:

- Full combat HUD

### 3.3 Combat State

Visible:

- Left-side joystick area
- Right-side combat cluster
- Health/mana HUD
- Optional top map / score / quick-message entry

This is the only state where the mobile battle HUD is enabled.

### 3.4 Death State

Visible:

- Respawn overlay
- Optional grayed-out battle HUD underneath

Input restrictions:

- Skill and attack input disabled
- Movement disabled

---

## 4. Mobile HUD Layout

### 4.1 Left Side

The left side is reserved for movement.

- A dynamic joystick occupies the lower-left interaction zone.
- The player should not be forced to start exactly on a tiny static knob.
- The active movement area should behave like a broad lower-left thumb zone.

### 4.2 Right Side

The right side is reserved for combat.

The combat cluster contains:

1. One main basic-attack button
2. Three hero skill buttons by default
3. One ultimate button when the hero kit includes it
4. One summoner-skill slot
5. One recall button
6. One cancel-cast zone shown only while aiming / charging

### 4.3 Center Lower Area

The lower center should contain combat status rather than action buttons.

- HP bar
- MP / energy bar
- Optional charge bar when using charge skills

### 4.4 Top Area

The top area is reserved for macro information.

- Mini-map
- Team score / timer
- Quick-message entry
- Settings / menu

These elements must not overlap the thumb-heavy bottom interaction zones.

---

## 5. Combat Cluster Rules

### 5.1 Main Basic Attack

The basic-attack interaction keeps only one main attack button.

Rules:

- No minion-attack sub-button in v1
- No tower-attack sub-button in v1
- No dual-target attack mode in v1
- Tap triggers basic attack using the project targeting rules

Reason:

- The first goal is to restore a clean, readable mobile MOBA interaction model.
- Extra attack disambiguation buttons can be added later after core touch combat feels stable.

### 5.2 Skill Buttons

Skill buttons are icon-based and mobile-native.

Visible data on each skill button:

- Skill icon
- Cooldown number
- Disabled / usable state
- Upgrade cue if applicable

Forbidden on mobile:

- `Q`
- `W`
- `E`
- `R`
- keyboard labels used as the primary visual identity

Desktop may keep keyboard hints separately, but mobile must not.

### 5.3 Summoner Skill Slot

The mobile battle HUD keeps one summoner-skill slot.

Examples:

- Flash-like displacement
- Heal
- Sprint

The summoner slot is smaller than the main skill buttons and must not visually compete with the main attack button.

### 5.4 Recall

Recall remains a utility action, not a core battle action.

- It should sit outside the main thumb conflict area
- It should be visually smaller than combat skills

---

## 6. Skill Interaction Framework

All mobile skills use one shared interaction grammar:

`Press -> Hold/Drag -> Release`

The project must not implement a separate ad-hoc touch model per skill.

### 6.1 State Machine

The shared interaction states are:

- `IDLE`
- `AIMING`
- `CHARGING`
- `CANCEL_PENDING`
- `RELEASING`
- `COOLDOWN`

These match the core design framework and should remain the single source of truth for touch skill flow.

### 6.2 Tap Behavior

Quick tap means:

- no meaningful drag distance
- use the skill's default aim strategy
- release immediately

This is required for mobile usability. Players must not be forced to drag every cast.

### 6.3 Hold / Drag Behavior

Hold and drag means:

- show the indicator
- update aim in real time
- allow cancel by dragging into the cancel zone
- release on finger lift

### 6.4 Cancel Behavior

Non-charge skills:

- cancel means no cast
- no cooldown cost

Charge skills:

- cancel follows the skill's `cooldownOnCancel` and `cancelCooldownRatio`
- already-triggered charge-period effects are not retroactively undone

---

## 7. Supported Skill Types

The underlying framework supports these indicator / drag families:

- `LINE`
- `SECTOR`
- `CIRCLE_DROP`
- `CIRCLE_SELF`
- `TARGET_LOCK`

### 7.1 V1 Implementation Scope

For the current project phase, the recommended implementation order is:

1. `LINE`
2. `SECTOR`
3. `CIRCLE_DROP`
4. `CIRCLE_SELF`

`TARGET_LOCK` stays in the framework contract, but can be postponed until the base mobile combat feel is stable.

Reason:

- It is the most expensive type to ship well.
- It introduces extra UI around enemy portraits, target invalidation, and retarget rules.

---

## 8. Default Aim Strategy Rules

Every active skill must declare one default aim strategy.

Allowed strategies:

- `NEAREST_ENEMY_DIRECTION`
- `NEAREST_ENEMY_POSITION`
- `NEAREST_ENEMY_TARGET`
- `LAST_MOVE_DIRECTION`
- `SELF`

Project guidance:

- Directional skillshots usually use `NEAREST_ENEMY_DIRECTION`
- Ground-targeted AOE usually uses `NEAREST_ENEMY_POSITION`
- Self-centered buffs / bursts use `SELF`

The default aim must produce useful tap-cast behavior, not just a placeholder direction.

---

## 9. Indicator Rendering Rules

### 9.1 Shared Visual Rules

Indicators must visibly communicate three situations:

1. Default aiming
2. Manual adjustment
3. Cancel pending

Recommended visual language:

- normal: blue / cyan / green
- cancel pending: gray or red
- charge tier increase: stronger brightness / color change / width change

### 9.2 Cancel Zone

The cancel zone is not permanently visible.

It appears only while:

- `AIMING`
- `CHARGING`
- `CANCEL_PENDING`

Rules:

- It should sit toward the screen center relative to the pressed skill cluster
- It should be easy to hit intentionally, but hard to hit by accident
- Dragging into it changes the active indicator to cancel styling

### 9.3 Circle Drop Clamp

For `CIRCLE_DROP`:

- the effect circle must be clamped to cast range
- drag input outside the valid radius maps to the nearest point on the cast-range boundary

---

## 10. Charge Skill Rules

Charge skills are supported by the framework but are not required for every hero.

When a skill has `chargeConfig`:

- pressing immediately starts charge logic
- charge-period effects apply on press
- tier feedback must be visible
- release uses current tier

Project rules:

1. A charge bar appears above the relevant skill during charging
2. Tier changes should use haptics and visible indicator change where possible
3. Resource drain, movement lock, and full-charge behavior must come from config rather than hardcoded hero-specific logic

---

## 11. Current Project-Specific HUD Mapping

This section defines the intended mobile combat mapping for the current project.

### 11.1 Left Thumb Zone

- Dynamic virtual joystick

### 11.2 Right Thumb Zone

- Main basic attack button at the lower-right anchor
- Skill 1, Skill 2, Skill 3 arranged around the attack button in an arc / cluster
- Ultimate occupies the most prominent upper position in the cluster when present
- One summoner-skill slot placed beside the core skill cluster as a secondary action
- Recall placed outside the highest-frequency combat buttons

### 11.3 Button Priority

From highest to lowest visual priority:

1. Basic attack
2. Hero skills
3. Ultimate
4. Summoner skill
5. Recall

This priority order should influence size, contrast, and reachable placement.

---

## 12. Safe Area and Thumb Comfort Rules

The mobile HUD must respect safe areas.

Rules:

1. No core combat button may be clipped by rounded corners, notches, or emulator safe-area padding
2. The joystick and combat cluster must not overlap each other
3. Bottom-center status UI must not push into the joystick or attack-button thumb paths
4. The right combat cluster must be operable with one thumb without requiring extreme stretch to the top-right corner

---

## 13. What Must Change From the Current Prototype

The following current behaviors are explicitly incompatible with this spec:

1. Mobile skills presented as a horizontal `QWER` strip
2. Keyboard letters shown as the primary mobile skill label
3. A desktop-hotkey visual hierarchy reused unchanged on touch devices
4. A battle HUD shown before actual combat entry

These are not cosmetic issues. They are interaction-model violations.

---

## 14. Recommended Implementation Order

To reduce rework, implementation should follow this sequence:

1. Separate mobile HUD layout from desktop HUD layout
2. Remove `QWER` labels from the mobile battle HUD
3. Build the combat cluster around one main attack button
4. Add one summoner-skill slot
5. Implement the shared touch skill state machine
6. Connect indicator rendering for `LINE`, `SECTOR`, `CIRCLE_DROP`, `CIRCLE_SELF`
7. Add charge-skill support where needed
8. Add `TARGET_LOCK` later if a hero kit truly requires it

---

## 15. Acceptance Checklist

The mobile battle HUD should be considered correct only if all of these are true:

1. On mobile, players see a left joystick and right combat cluster, not a keyboard row
2. On mobile, no skill button depends on visible `QWER` labels
3. There is exactly one main basic-attack button
4. There is exactly one summoner-skill slot
5. Tap-cast works through default aim strategies
6. Hold-drag-release works with live indicators
7. Cancel works through a visible cancel zone
8. The HUD appears only in combat state
9. Safe-area overlap does not break touch interaction

