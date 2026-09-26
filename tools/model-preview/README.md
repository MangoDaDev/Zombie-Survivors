# Model preview

Local Windows CLI for building PNG previews directly from the same validated JSON used by the exported Luau constructor. It does not open Studio, capture a screen, start a server, create scripts in Studio, or modify game assets. Requires **Blender 4.5 LTS** and Windows PowerShell 5.1 (including System.Drawing). No pip/npm/Wally dependencies are added. Tested with Blender **4.5.4**, CPU rendering.

From the repository root:

```powershell
# The .cmd launcher applies execution policy only to its own PowerShell process.
.\tools\model-preview\preview.cmd render tools/model-preview/examples/gantry.json
Invoke-Item tools/model-preview/renders/preview/contact-sheet.png
Invoke-Item tools/model-preview/renders/preview/properties.html
```

Default Blender path: `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe`. Override with `-Blender "C:\path\blender.exe"` or `MODEL_PREVIEW_BLENDER`. Keep the same Blender build for reproducible files. Output is isolated under the tool's gitignored `renders/` directory unless `-Out` is provided.

## Paste → render → inspect → revise

```powershell
# Read directly from the clipboard. JSON is data, never executable source.
.\tools\model-preview\preview.cmd render -Clipboard -Out tools/model-preview/renders/pasted

# Or type/paste into stdin, then Ctrl+Z followed by Enter to finish.
.\tools\model-preview\preview.cmd render -Paste

# Or pipe a multiline string:
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
@'
{"version":1,"root":{"class":"Part","name":"Block","properties":{"Size":[4,2,3],"TopSurface":"Studs","FrontSurface":"Studs"}}}
'@ | .\tools\model-preview\preview.cmd render -Paste -Views front,perspective

# Validate without rendering; errors identify the source field and rejected value.
.\tools\model-preview\preview.cmd validate tools/model-preview/examples/gantry.json

# Fast iteration: open the source in your editor, revise it, run this again.
.\tools\model-preview\preview.cmd render tools/model-preview/examples/gantry.json -Views front,perspective -Resolution 480x480 -Samples 16 -Out tools/model-preview/renders/working

# Seven standard angles plus an example custom angle, adjustable lighting.
.\tools\model-preview\preview.cmd render tools/model-preview/examples/gantry.json -Settings tools/model-preview/examples/studio-lighting.json

# Transparent portrait perspective render.
.\tools\model-preview\preview.cmd render tools/model-preview/examples/gantry.json -Views front -Projection perspective -Resolution 480x720 -Transparent

# Export the exact construction adapter without rendering.
.\tools\model-preview\preview.cmd export tools/model-preview/examples/gantry.json -Out tools/model-preview/renders/export
.\tools\model-preview\preview.cmd render tools/model-preview/renders/export/construction.luau

# Focused parser/transform/hierarchy/camera/backend tests (~seconds).
.\tools\model-preview\preview.cmd test
# Also render twice and compare every output byte, including the contact sheet.
.\tools\model-preview\preview.cmd test -RenderTests
```

The clipboard and stdin are read only when requested. `-Clipboard` preserves Unicode names automatically; for native PowerShell pipelines, set UTF-8 `$OutputEncoding` as above. A render saves `definition.json`, so pasted data can be edited and rendered again. File input is not overwritten by rendering to the default output directory. The previous successful render survives validation/render failure. Existing unrelated files in a chosen output directory are retained; `manifest.json` lists the current run's artifacts (old angle PNGs can remain when the angle list is reduced).

## JSON construction schema, version 1

```json
{
  "version": 1,
  "root": {
    "class": "Model",
    "name": "Assembly",
    "properties": {"PrimaryPart": "base"},
    "children": [{
      "class": "Part",
      "name": "Base",
      "id": "base",
      "properties": {
        "CFrame": {"position": [0, 1, 0], "rotationDegrees": [0, 30, 0]},
        "PivotOffset": {"position": [0, -1, 0]},
        "Size": [6, 2, 4],
        "Color": [0.2, 0.5, 0.8],
        "Material": "Plastic",
        "Transparency": 0,
        "Reflectance": 0,
        "Anchored": true,
        "CanCollide": true,
        "TopSurface": "Studs",
        "BottomSurface": "Studs",
        "FrontSurface": "Studs",
        "BackSurface": "Studs",
        "LeftSurface": "Studs",
        "RightSurface": "Studs"
      },
      "children": []
    }]
  }
}
```

Nodes have required `class` and `name`; optional `id`, `properties`, and ordered `children`. Duplicate names are allowed; IDs must be unique. `PrimaryPart` references a descendant Part's ID, never an ambiguous name/path. Root may be a Part or Model; at least one Part is required. Hierarchy order is preserved. Unknown fields/classes/properties/enum values fail with a nonzero exit code, never a silent approximation or dropped instance. Limits: 8 MiB definition, 5,000 instances, 64 hierarchy levels, 64–4096 pixels per output dimension.

**Coordinates:** Roblox X right, Y up, front −Z, one unit per stud. All Part `CFrame`s are **world-space**, even under nested Models/Parts. Model `WorldPivot` is pivot metadata and does **not** move descendants. There is no hidden parent transform or model scale multiplier. Bake construction transforms into the exact CFrames/sizes you will assign in Roblox.

CFrames accept either the object form above (both members optional, default identity) or twelve numbers `[x,y,z,R00,R01,R02,R10,R11,R12,R20,R21,R22]`, matching `CFrame:GetComponents()`. Rotation degrees use `CFrame.Angles` **XYZ**, not `BasePart.Orientation`'s YXZ order. Matrices must be finite, orthonormal and have determinant +1; scale/shear/reflection is rejected. `PivotOffset` is local to its Part. Effective model pivot comes from PrimaryPart × PivotOffset, explicit WorldPivot, or descendant world bounding-box center, in that order.

| Class | Supported properties and defaults |
| --- | --- |
| Part | `CFrame` identity; `Size` `[4,1,2]` (each .001–2048); `Color` `[.6392156863,.6392156863,.6392156863]` (sRGB channels 0–1); `Material` `Plastic`; `Transparency` and `Reflectance` 0 (0–1); `Shape` `Block`; `PivotOffset` identity. |
| Part surfaces | All six `*Surface` properties default `Smooth`. Supports `Studs`, `Inlet`, `Smooth`, `SmoothNoOutlines`. Set all six explicitly to Studs for this project's construction style. |
| Part physics/state | `Anchored`, `CanCollide`, `CanTouch`, `CanQuery`, `CastShadow`, `Archivable` true; `Massless`, `Locked` false; `CollisionGroup` `Default`; `CustomPhysicalProperties` null. These are exported and fully reported. `CastShadow` also controls offline shadow rays. |
| Model | `PrimaryPart` null; `Archivable` true; optional `WorldPivot`. Effective pivot is separately reported, including when inferred. |

`CustomPhysicalProperties`, when non-null, requires `Density` (.01–100), `Friction` (0–2), `Elasticity` (0–1), `FrictionWeight` (0–100), and `ElasticityWeight` (0–100). These metadata do not run physics in a still render. Non-default `CollisionGroup` names must already be registered in the destination Studio place; the local tool validates the string but cannot validate another place's group registry. Defaults belong to this versioned schema, **not** to Roblox's changing creation defaults; the exporter explicitly writes them.

Supported materials: `Plastic`, `SmoothPlastic`, `Metal`. Other materials, shapes, meshes, unions, textures, decals, joints, constraints, lights as model children, Attributes, `MaterialVariant`, property aliases such as `Position`/`Orientation`/`BrickColor`, streaming settings, and model Scale are rejected. They are not silently discarded. Extend the schema, exporter and backend together to add a class/property.

## Render settings

Use `-Settings path.json`; every unknown settings key is rejected. CLI flags override that file. All fields are optional; defaults live in `settings.py`.

| Setting | Meaning |
| --- | --- |
| `views` | Ordered subset of front, back, left, right, top, bottom, perspective. Default all seven. Front looks from −Z; top has +Z toward image top. |
| `projection` | `orthographic` default, or `perspective`. The named `perspective` preset always uses perspective; custom cameras may override projection. |
| `resolution`, `fov`, `margin` | `[width,height]`, vertical FOV in degrees (default 40), framing margin (default 1.18). Every rotated Part corner is included in framing. |
| `transparent`, `background` | PNG alpha or a solid sRGB background (default `[.12,.15,.19]`). Background color is independent of ambient illumination. Contact sheet has a dark background for readability. |
| `lighting` | `direction` from model toward sun, `energy`, `ambient`, sun `angle` in degrees, and sRGB `color`. Defaults are preview lighting, not an exact reproduction of Studio Lighting. |
| `ground`, `groundColor` | Optional opaque preview floor just below world bounds, default off. Turn off to inspect bottom surfaces or get an isolated transparent model. Ground is not exported. |
| `samples`, `seed` | Fixed Cycles CPU sample count (default 32) and seed (default 0). Increase samples to reduce shadow/transparency noise. |
| `customCameras` | Up to 16 objects with unique safe filename `name`, nonzero `direction`, optional world `target`, `up`, `projection`, `fov`. Automatically fits the model around that target. |

Each run outputs clean angle PNGs, an annotated `contact-sheet.png` with world AABB/dimensions, oriented pivot axes and a calibrated scale bar, collapsible `properties.html`, complete machine-readable `properties.json`, normalized `definition.json`, `construction.luau`, and `manifest.json` with settings/build/source/artifact hashes. The scale bar measures distance at the look-at plane; perspective scale changes with depth. Properties stay out of the render image.

## Luau and fidelity boundaries

The inspected repository's helpers use ordinary `Instance.new`, `CFrame`, `Vector3`, `Color3` and enum assignments; there is no existing reusable model-generation DSL. The exporter follows that convention with a JSON payload and small constructor. `construction.luau` returns an **unparented** model; the caller controls parenting/cleanup. It is a local artifact, never installed as a Studio script by this tool. The importer accepts that adapter and permits edits to its embedded JSON, but rejects edits to the adapter body. It does **not** execute arbitrary Luau or pretend to interpret loops/functions/asset lookups. For an existing procedural generator, make its final construction records the JSON source of truth, or export its evaluated data first.

Geometry, CFrame order, sizes, hierarchy, face assignment, UV stud scale, camera projections and box intersections are directly derived from input. Offline **shading is an approximation**, not Roblox engine pixel parity: procedural square stud/inlet normal relief at one-stud spacing, Plastic/Metal BRDF, coat-based reflectance, lighting and alpha compositing use Cycles. Studs do not add geometry or alter silhouettes/bounds/collisions. Smooth and SmoothNoOutlines share the same smooth shader (no legacy outline pass). No Roblox proprietary material/normal maps are bundled. Coplanar duplicate faces remain ambiguous; revise the construction rather than relying on render order. This tool is useful for construction inspection, but cannot certify exact Studio appearance without an engine render reference.

Determinism uses a fixed CPU, one thread, seed, sample count, no adaptive sampling, denoising, dither, timestamps, network assets or stochastic construction. Same input/settings/tool/Blender build on the same platform should produce identical bytes; `test -RenderTests` verifies this, including PNGs and reports. Do not assume byte identity across Blender versions/CPUs/OS font libraries.

Architecture: `schema.py` validates and resolves hierarchy/pivots; `transforms.py` owns pure geometry/camera math; `settings.py` validates render settings; `luau.py` owns construction interchange; `backend.py` implements geometry/material rendering; `reports.py` and `compose-sheet.ps1` make reports/contact sheets; `cli.py` orchestrates output. The tool is outside `default.project.json` and has no runtime game responsibility.

API references used: [Roblox CFrame components](https://create.roblox.com/docs/reference/engine/datatypes/CFrame), [Model pivot semantics](https://create.roblox.com/docs/reference/engine/classes/Model), [SurfaceType](https://create.roblox.com/docs/reference/engine/enums/SurfaceType), [Blender Principled BSDF](https://docs.blender.org/api/4.5/bpy.types.ShaderNodeBsdfPrincipled.html).
