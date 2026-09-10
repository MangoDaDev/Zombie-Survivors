# Math module guidance

- Math contains reusable calculations, formatting, color/sequence conversion, random selection, and spatial math with no game-specific state.
- Keep functions deterministic when practical. Random helpers should accept an optional Random instance so callers can supply reproducible randomness.
- Do not read Workspace, players, assets, or saved data from math modules.
- Use assertions only for genuine mathematical preconditions that would otherwise make the result meaningless, such as an empty Bézier input or zero rounding interval.
- Preserve units and return shapes clearly. Do not silently convert between percentages and ratios, seconds and milliseconds, or local and world space.
