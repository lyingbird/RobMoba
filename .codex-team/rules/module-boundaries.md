# Module Boundaries

## Goal
- Keep large files as orchestration layers.
- Push stable responsibilities into focused modules before the project scales further.

## Current Rule
- Files over roughly `300-400` lines should default to composition, not absorb more domain detail.
- Content-heavy data tables are allowed to grow if they remain declarative.
- Logic-heavy files should be split by capability, not by arbitrary naming.

## Server Direction
- `SkillSystem` should orchestrate:
  - request intake
  - validation routing
  - timeline dispatch
  - passive/combat side effects that still need consolidation
- Extract capability modules under `src/server/services/` when new logic would otherwise grow `SkillSystem`.

## Initial Seams
- `SkillLoadoutService`: player hero + replacement state
- `BasicAttackService`: basic attack request resolution and timeline selection
- `SkillTargeting`: request normalization for direction and target position

## Next Seams
- Split `EventHandlers` by event family instead of keeping one central implementation file.
- Split large UI controllers into controller/view/component boundaries before adding more UX states.
