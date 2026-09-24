# Shared UI utility guidance

- This category contains presentation-only data and effects that can be used by client UI or other visual systems. Vide components still belong under `src/UI`.
- `PlayVFX.lua` clones effect templates, starts supported particles, beams, trails, and sounds, and schedules cleanup. Pass a Studio-owned template rather than mutating the source asset.
- Studio-owned assets are optional and are not mapped by Rojo. Inspect the live hierarchy through Studio MCP before adding a reference, and keep reusable modules safe when an optional asset folder is absent.
