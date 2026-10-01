# Zombie Survivors Agent Guide

## Scope and sources of truth

- These instructions apply repository-wide and contain only general workflow, architecture, and coding rules.
- Read `PROJECT_NOTES.md` before making changes. Keep project-specific decisions, corrections, invariants, and patterns concise and current there or beside their authoritative code.
- `default.project.json` defines the source-to-DataModel mapping. `Index.md` is the concise first-party code map.
- Update `Index.md` when a script or system responsibility is added, removed, renamed, moved, or materially changed.
- Do not put game mechanics, feature requirements, or balancing rules in this file. Put them in the relevant script/module or `PROJECT_NOTES.md`.
- Add a rule here only when it applies across the whole project. Put narrower guidance in the nearest scoped `AGENTS.md`.

## UI routing

- Before creating, modifying, restyling, reviewing, or fixing Roblox UI, read and follow `src/UI/AGENTSCREATINGUI.md` in full.
- `src/UI/AGENTSCREATINGUI.md` is the sole authoritative location for UI-specific development, responsiveness, Vide, asset, and visual-validation rules. Do not duplicate UI policy here.

## Working method and scope

- Inspect the repository and similar implementations before editing. Reuse existing utilities, patterns, and assets.
- Ask for clarification only when it is necessary to proceed safely or when a choice would materially change the result.
- Keep work scoped to the request. Do not change unrelated or adjacent systems unless the requested change cannot work without it; explain any necessary expansion.
- For potentially broad work, state the intended scope early so the user can correct it.
- Apply user corrections to the current work immediately instead of restarting from scratch.
- Treat repeated corrections as workflow feedback. Add or improve one concise preventive rule in the correctly scoped instruction file when appropriate.
- If the user explicitly prohibits behavior, leave a short comment beside the authoritative code so future work does not reintroduce it.
- Record user-specified standards, corrected mistakes, important implementation decisions, protected behavior, and recurring project patterns in the appropriate persistent location. Keep those notes organized and useful, and do not mix general guidance with game-specific facts.

## Repository and Studio workflow

- Do not create permanent scripts inside Roblox Studio. Source-controlled runtime code belongs in the mapped repository paths.
- Use Roblox Studio MCP for live DataModel inspection or Studio-owned assets. Do not use computer control, invent Instance paths, or run playtests unless the user asks.
- Do not use screen capture, screenshots, or similar capture-based inspection tools; they do not work for this project.
- If Studio is already in play mode, do not stop it unless the request requires that.
- Inspect `ReplicatedStorage.Assets` and use exact existing names instead of guessing asset paths.
- Before using `WaitForChild` in Studio tooling or validation code, verify the path and provide a timeout so a wrong path cannot stall the task. Runtime code may use `WaitForChild` normally where replication timing requires it.
- When reacting to a replicated parent, wait for required descendants or subscribe for them; replication does not guarantee that a hierarchy arrives atomically.
- If a required asset does not exist, create a blank Instance in the appropriate folder and tell the user.
- Do not repair the intentionally missing local Rojo/Rokit target.

## Code organization and style

- Keep code simple, modular, mostly event-driven, and consistent with nearby Luau.
- Use `camelCase` for locals and private functions, `UPPER_SNAKE_CASE` for constants, and `PascalCase` for public APIs, controllers, classes, and modules.
- Put client controllers in `src/controllers`, server controllers in `src/servercontrollers`, and shared modules in `src/modules`. Register controllers in the appropriate bootstrap.
- Keep bootstraps orchestration-only. Keep server-only logic and secrets out of replicated modules.
- Add detailed comments beside non-obvious logic to preserve its intended behavior, constraints, and balancing purpose.
- When implementing a user-requested invariant, leave a short comment beside its authoritative logic or configuration and update the comment if the requirement changes.
- Do not hide ordinary code errors with `pcall`, add unnecessary assertions, overengineer one-off behavior, or hardcode the same data in multiple places.
- Manage dependencies through `wally.toml`. Never edit generated packages, lockfiles, place files, or build output manually.

## Networking, authority, and persistence

- Use Networker for client/server communication, GoodSignal for in-process events, and DataService for player persistence.
- Do not create raw remotes for ordinary gameplay or duplicate the legacy `SharedClass` replication pattern.
- Keep currency, inventory, rewards, progression, purchases, and damage server-authoritative. Validate every client request and persist only JSON-compatible data.
- Use server authority where it prevents exploitation, but do not move harmless presentation or client-local behavior to the server unnecessarily.
- Never use Roblox Attributes. Store configuration and runtime metadata in Luau tables; do not substitute unnecessary ValueObjects.

## Runtime ownership and cleanup

- Clean up connections, tasks, temporary Instances, and cached state.
- Avoid polling, repeated hierarchy scans, duplicate systems, and per-object frame loops.
- Do not mutate shared Studio-owned asset templates. Clone templates that need runtime ownership, mutation, or cleanup.
- When debugging replicated interactions, identify which side writes each value every frame and remove competing writers before adding synchronization.

## Asset safety and references

- When a sound effect needs a new name, duplicate and rename the copy; never rename the original because existing references may depend on it.
- Before creating avatar-dependent thumbnails, icons, promotional art, or other visuals, inspect `references/` and use the relevant files as authoritative appearance references.
- Do not generate images unless the user explicitly asks.
- Before uploading generated or edited imagery to Roblox, inspect the final image for Roblox Community Standards and moderation risks, including sexual or suggestive material, graphic gore, hateful or extremist imagery, profanity, illegal drugs, accidental text or watermarks, real-person likenesses, third-party brands, and copyright-infringing material.
- Never generate or upload questionable imagery. Regenerate a clearly safe version or ask the user, and always require human review before upload.

## Model and VFX authoring

- When the user asks for a model, use a classic Roblox stud-building style: simple rectangular Parts, chunky proportions, strong silhouettes, visible studs on appropriate surfaces, simple colors, and purposeful structural layering.
- Approximate curves, slopes, and complex forms with layered, stepped, or rotated blocks. Do not use MeshParts, SpecialMeshes, Cylinders, Balls, Wedges, or CornerWedges.
- Author requested models in the appropriate folder rather than generating them at runtime. Use Plastic, not SmoothPlastic, and set every surface to studs.
- If the user asks you to create missing VFX, build satisfying client-animated runtime effects from studded Parts.

## Verification and handoff

- Keep verification proportional to risk. For simple configuration or balance changes, prefer targeted source checks and compilation over broad Studio/DataModel validation.
- Do not run automated playtests unless the user explicitly requests them.
- Before handing off source changes, search all mapped runtime files for unresolved merge markers. Never leave conflict markers in Luau because Studio parses them as syntax.
