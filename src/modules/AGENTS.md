# Shared module guidance

- Modules here map to `ReplicatedStorage.Modules` and may be required by both client and server.
- Keep modules in one of the five established categories:
  - `Core`: game-agnostic instance, callback, identity, and framework utilities.
  - `Game`: shared gameplay helpers and the DataService template.
  - `Math`: deterministic calculation, formatting, sequence, color, random, and spatial math helpers.
  - `Platform`: Roblox account, identity, thumbnail, rank, and synchronized-platform helpers.
  - `UI`: presentation-only catalogs and reusable visual-effect helpers; actual Vide components belong under `src/UI`.
- Choose the narrowest category based on what the module does, not where its first caller happens to live. Do not create miscellaneous buckets or placeholder folders.
- Keep reusable modules independent of bootstrap order and avoid hidden initialization side effects.
- Guard environment-specific behavior with RunService when a shared module must support different client/server paths.
- Never place secrets, server authority, or server-only package requirements in this replicated tree.
- UI components belong under `src/UI`; do not put Vide-specific guidance or components in general shared modules.
- These modules were imported from unmapped Studio ModuleScripts. The filesystem versions are now the Rojo source of truth; make future edits here rather than editing the corresponding live Studio scripts.
- Two imported names were corrected for clarity: use `Math.Generate3DBezier` instead of Studio's misspelled `Generate3DBeizer`, and `Math.MultiplyUDim2` instead of `MultiplyUdim2`.
