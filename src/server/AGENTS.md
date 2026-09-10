# Server runtime guidance

- `init.server.lua` is the ServerScriptService bootstrap; keep it focused on DataService initialization and controller lifecycle dispatch.
- DataService is initialized before controllers using `Modules.Game.DataTemplate`.
- Preserve the separate `STUDIOTEST_` and `PLAYER_` profile prefixes unless intentionally planning a data migration.
- `Players.CharacterAutoLoads` is false. Do not remove or reorder the CharacterController without updating the loading and respawn flow.
- Add server controllers to `modules_to_init`; placing a ModuleScript in ServerStorage does not start it automatically.
- Registration order is initialization and lifecycle-dispatch order. `SetDataService(dataService)`, when present, runs before `Init()`.
- `OnPlayerAdded` runs only after `dataService:waitForData(player)` succeeds. Re-check that the player still belongs to Players after any yield.
- Player removal is dispatched through `dataService:addPlayerRemovingCallback` and guarded against duplicate dispatch.
- Keep gameplay and persistence authority here or in server-only controllers/modules. Never move sensitive logic into replicated shared modules.
