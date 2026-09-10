# Shared UI utility guidance

- This category contains presentation-only data and effects that can be used by client UI or other visual systems. Vide components still belong under `src/UI`.
- `Images.lua` is the imported image asset-ID catalog. Reuse its named entries instead of scattering duplicate IDs through components.
- `PlayVFX.lua` clones effect templates, starts supported particles, beams, trails, and sounds, and schedules cleanup. Pass a Studio-owned template rather than mutating the source asset.
- Assets under `ReplicatedStorage.Assets` are reusable by default, including every sound in `Assets.Sounds`, unless an asset name, attribute, containing-folder instruction, or `AGENTS` value says otherwise.
- Inspect the live asset hierarchy through Studio MCP before adding a new reference because Assets is Studio-owned and not mapped by Rojo.
