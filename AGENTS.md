# Restoration Game Agent Guide

## Project

- Roblox restoration game built in Luau and synchronized with Rojo.
- Gameplay includes crate rewards, item cleaning, inventory, museum displays, visitors, upgrades, and guided progression.
- `default.project.json` defines the source-to-DataModel mapping; `Index.md` is the concise first-party code map.

## Requirements / Rules

- Inspect the repository and similar implementations before editing; reuse existing utilities, patterns, and assets.
- Use Roblox Studio MCP for live DataModel or Studio-owned assets. Do not use computer control, invent instance paths, or run playtests unless requested.
- Keep code simple, modular, mostly event-driven, and consistent with nearby Luau.
- Use `camelCase` for locals/private functions, `UPPER_SNAKE_CASE` for constants, and `PascalCase` for public APIs, controllers, classes, and modules.
- Put client controllers in `src/controllers`, server controllers in `src/servercontrollers`, shared modules in `src/modules`, and register controllers in the appropriate bootstrap.
- Keep bootstraps orchestration-only. Keep server-only logic and secrets out of replicated modules.
- Use Networker for client/server communication, GoodSignal for in-process events, and DataService for player persistence.
- Keep currency, inventory, rewards, progression, purchases, and damage server-authoritative. Validate every client request and store only JSON-compatible data.
- Never use Roblox Attributes. Keep configuration and runtime metadata in Luau tables; do not substitute unnecessary ValueObjects.
- Preserve existing UI hierarchy when working with pre-existing UI.
- Manage dependencies through `wally.toml`; never edit generated packages, lockfiles, place files, or build output manually.
- Clean up connections, tasks, temporary instances, and cached state. Avoid polling, repeated scans, duplicate systems, and per-object frame loops.
- Update `Index.md` when scripts or system responsibilities are added, removed, renamed, moved, or materially changed.
- Server authority is not needed for everything. Be reasonable with what you use server authority with. It should still be used to counter hackers though.

## Recurring Mistakes To Avoid

- Do not guess Studio asset paths; inspect `ReplicatedStorage.Assets` and use exact existing names.
- Use an item's `BoundingBox` frame for persistent part-relative transforms; template and runtime model pivots may differ.
- Before using `WaitForChild` in Studio tooling or validation code, verify the instance path and always provide a timeout so a wrong path cannot stall the task indefinitely. Try to avoid the function as everything is completely loaded in the MCP. However you can use it normally in runtime scripts.
- Do not overscope simple tasks. Choose the right scope for a task. Make sure to think about the scope and send it so that the user can see and stop if needed.
- Do not modify adjacent systems or existing behavior unless the user explicitly asks for it or the requested change cannot work without it; keep fixes correctly scoped. However if it is better to change it then do it.
- Treat discreet or background progression as non-blocking: do not add visible objectives, UI gates, or forced actions unless the user explicitly requests them.
- Keep verification proportional to the change; for simple configuration or balance edits, use targeted source checks and compilation rather than broad Studio or DataModel validation unless runtime data is directly involved.
- When reacting to a replicated parent, wait for required descendants or listen for them; replication does not guarantee the full hierarchy arrives atomically.
- Do not create raw remotes for normal gameplay or duplicate the legacy `SharedClass` replication pattern.
- Do not mutate shared Studio-owned asset templates; clone them when runtime ownership or cleanup is needed.
- Do not hide ordinary code errors with `pcall`, overengineer one-off behavior, or hardcode the same data in multiple places.
- Do not repair the intentionally missing local Rojo/Rokit target or run automated playtests without an explicit request.
- When a recurring mistake is discovered and fixed, add one short preventive rule here without expanding this file into documentation.
* If the user explicitly says **not** to do something, leave a clear code comment so future agents do not reintroduce it.
* When implementing a user-requested invariant, leave a short code comment beside its authoritative logic or configuration so future agents preserve it. Update the comment if the requirement changes.
* **DO NOT use screen capture, screenshots, or similar visual inspection tools. They do not work for this project.**
Do not change anything unrelated to the user's request.
When debugging replicated interactions, trace which side writes each value every frame and remove competing writers before adding synchronization.
Keep the main App `ScreenGui.IgnoreGuiInset` enabled; clear the Roblox topbar with explicit dynamic safe offsets.
Do not generate images unless EXPLICITLY asked to.
If I correct you, immediately apply the correction to the current task instead of restarting from scratch.
When an agent makes a recurring mistake and the user corrects it, add or improve a concise AGENTS.md rule so future agents avoid the same mistake.
- Treat repeated user corrections as feedback about the agent workflow. When appropriate, update AGENTS.md with a short general rule that prevents the same problem from happening again.
Ask for any clarifications before beginning only if nesscecary
* **DO NOT put game-specific logic, mechanics, behavior specifications, balancing rules, or feature requirements in `AGENTS.md`.** Put those requirements in the relevant scripts or modules instead. This `AGENTS.md` should only contain general development rules, coding standards, workflow instructions, architectural conventions, and best practices that apply across the project.
Dont do unnesscecary assert
If studio is in play mode, don't stop it unless it is needed to do the request.
ONLY IF IT APPLIES TO ALL SYSTEMS IN THE GAME write something in THIS Agents.md. 
Dont put stuff that is too niche in Agents.md. You can put it in/create an Agents.md or a script in the niche if needed but not in this one.
Put UI-specific development rules in `src/UI/AGENTSCREATINGUI.md`, not in this root `AGENTS.md`.
