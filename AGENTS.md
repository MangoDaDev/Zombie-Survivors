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

## Recurring Mistakes To Avoid

- Do not guess Studio asset paths; inspect `ReplicatedStorage.Assets` and use exact existing names.
- Do not create raw remotes for normal gameplay or duplicate the legacy `SharedClass` replication pattern.
- Do not mutate shared Studio-owned asset templates; clone them when runtime ownership or cleanup is needed.
- Do not hide ordinary code errors with `pcall`, overengineer one-off behavior, or hardcode the same data in multiple places.
- Do not repair the intentionally missing local Rojo/Rokit target or run automated playtests without an explicit request.
- When a recurring mistake is discovered and fixed, add one short preventive rule here without expanding this file into documentation.
- When I tell you explicitly to Not do something, leave a not in the code for future agents to not do it too.
- DO NOT use screen capture or similar tools. They do not work.