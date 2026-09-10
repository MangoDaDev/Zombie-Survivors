# Client runtime guidance

- `init.client.lua` is the StarterPlayerScripts bootstrap; keep it focused on initialization and lifecycle dispatch.
- DataService client initialization currently runs first and yields until the server supplies player data.
- Add client controllers or UI roots to `modules_to_init`; placing a ModuleScript in the repository does not start it automatically.
- Registration order is initialization order. `SetDataService(dataService)`, when present, is called before `Init()`.
- Registered modules may implement `Init()` and `OnCharacterAdded(character)`. The bootstrap also accepts lowercase `init()` for compatibility, but new modules should use `Init()`.
- The CharacterController and UI origin are required by the loading flow. Update `src/loading/init.client.lua` if either startup contract changes.
- Keep input, camera, UI, and cosmetic behavior client-side, but never make the client authoritative for gameplay or saved data.
- Treat character references as temporary and clean character-scoped connections when characters respawn.
