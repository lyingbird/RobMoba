# Figma Workflow

## Goal
- For feature work that changes UX, Codex should produce an interaction draft before implementation.
- The draft should then go through one reflection pass and one iteration pass before code is finalized.

## Default Flow
1. Clarify the user story, entry point, target device, and success criteria.
2. Produce an interaction draft.
3. Review the draft against task goals, edge cases, and consistency with the existing product.
4. Iterate the draft at least once when the change is non-trivial.
5. Only then move into implementation, unless the user explicitly wants code-first work.

## Deliverables
- Screen list
- Main interaction path
- Empty / error / loading states
- Key component states
- Short design reflection
- Updated implementation notes

## Figma Integration
- If Figma is connected, Codex should use it to create and revise the interaction draft.
- If Figma is not connected, Codex should still create a structured draft in repo notes and mark it as pending Figma sync.
- Figma files are design artifacts; repository code remains the source of truth for shipped behavior.

## Reflection Checklist
- Is the primary path obvious on first use?
- Are mobile and desktop differences explicitly handled?
- Are destructive or high-risk actions clearly gated?
- Are loading, failure, and retry states visible?
- Does the flow fit the current game loop and UI language?

## Handoff Rule
- When implementation begins, the latest accepted draft and reflection summary should be written into `.codex-team/` memory, plan, or task notes.
