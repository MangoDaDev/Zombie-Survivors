# Client controller guidance

- Controllers here map to `ReplicatedStorage.Controllers` and start only when listed in `src/client/init.client.lua` under `modules_to_init`.
- Keep each controller focused on one client concern. Avoid substantial work at module scope.
- Optional bootstrap hooks are `SetDataService(dataService)`, `Init()`, and `OnCharacterAdded(character)`.
- `SetDataService` and `OnCharacterAdded` are called with `.`, so they must not expect `self`. `Init` is called with `:`.
- Initialization completes before the bootstrap dispatches an existing or future character.
- The bootstrap has no controller destroy hook. Controllers must own and replace/disconnect character-scoped state on respawn.
- Use Networker to request server actions. A request describes player intent; the server validates and decides the result.
- Do not access ServerStorage or ServerScriptService from client controllers.
- Reuse shared modules and Vide components instead of duplicating utility or presentation code inside a controller.
