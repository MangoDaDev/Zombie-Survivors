# Game module guidance

- This folder contains shared definitions and rules specific to the game built from this template.
- `DataTemplate.lua` contains the established JSON-compatible player-data defaults. Add new persisted fields deliberately and preserve existing keys.
- DataService reconciles new template keys into existing profiles, so choose defaults deliberately and do not casually rename or remove persisted keys.
- Keep this folder declarative where possible. Sensitive decisions and all persistence mutations remain server-authoritative.
- Put broadly reusable, game-agnostic infrastructure in `Core` instead.
- `TeleportPlayer` supports a Player or character Model and should normally be called by authoritative server code. `TeleportLocalPlayer`, `FreezePlayer`, and `UnfreezePlayer` are client-only presentation/control helpers and must not be treated as server authority.
