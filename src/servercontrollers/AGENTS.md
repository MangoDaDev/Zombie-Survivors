# Server controller guidance

- Controllers here map to `ServerStorage.Controllers` and start only when listed in `src/server/init.server.lua` under `modules_to_init`.
- Keep each controller focused on one server-authoritative gameplay or player-data concern. Avoid substantial work at module scope.
- Optional bootstrap hooks are `SetDataService(dataService)`, `Init()`, `OnPlayerAdded(player)`, `OnCharacterAdded(player, character)`, and `OnPlayerRemoving(player)`.
- `SetDataService` and lifecycle hooks are called with `.`, so they must not expect `self`. `Init` is called with `:`.
- `OnPlayerAdded` receives players only after their DataService data is ready. Existing players and characters are also dispatched during bootstrap.
- Make setup and cleanup resilient to a player leaving during yielded work. Store per-player connections and temporary resources for removal.
- Validate every Networker-exposed client request, including type, range, permission, ownership, cooldown, and relevant world state.
- Track relevant instances through events instead of repeatedly scanning Workspace.
- Persist through DataService, avoid unnecessary writes, and prevent duplicate rewards or purchases.
