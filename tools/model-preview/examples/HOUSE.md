# Willow Cottage

A detailed two-storey cottage authored for the local model-preview tool: **571 rectangular Plastic Parts**, all six surfaces Studs. Grouped into the house shell, roof/chimney, windows/shutters, porch, fittings, garden/fence, and basic ground-floor furnishings.

Features include real window and door openings, a hollow stepped gable roof, attic windows, a brick chimney, a covered porch with railings and steps, a panelled front door and lanterns, window flower boxes, a paved approach, garden beds, fencing, a block-built tree and a bench.

The complete garden footprint is **30 × 29 studs**; total bounds are **30 × 22.075 × 29 studs**. The model pivot is `[0, 0, 0]` on the lawn surface. Exterior inspection is the focus; the model does not include a complete playable interior or scripted door interactions.

From the repository root:

```powershell
# Render the editable JSON source.
.\tools\model-preview\preview.cmd render tools/model-preview/examples/house.json -Settings tools/model-preview/examples/house-settings.json -Out tools/model-preview/renders/house

# Inspect the generated files.
Invoke-Item tools/model-preview/renders/house/front-garden.png
Invoke-Item tools/model-preview/renders/house/contact-sheet.png
Invoke-Item tools/model-preview/renders/house/properties.html
```

`house.json` is ready to edit/paste into the tool. `build-house.py` is the deterministic local authoring recipe; running it rewrites `house.json` and `house-settings.json`. The generated `renders/house/construction.luau` builds that same data and returns an unparented Roblox Model. Nothing is generated at game runtime or inserted into Studio automatically.

Visual revisions: a stone threshold connects the porch deck to the doorway, the small attic apex gap is closed, and a brick curb with a stone collar finishes the chimney's junction with the stepped roof. The definition was rendered and inspected after these revisions.
