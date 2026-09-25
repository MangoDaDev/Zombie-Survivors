AgentsCreatingUI.md
Purpose
This file defines how agents must create, modify, review, and polish Roblox UI in this project.
The project uses Vide for production UI and Pinevex Renderer for headless visual iteration. UI work is not complete when the code merely runs; agents must render, inspect, revise, and re-render the interface until the result is visually coherent and matches the project design system.
Core Rules
- Production UI must use Vide unless the surrounding system explicitly requires otherwise.
- Preserve existing gameplay logic, state, signals, callbacks, controllers, and data flow when changing UI.
- Do not replace working behavior just to simplify styling.
- Reuse existing UI components, style modules, animation helpers, image registries, and interaction modules where appropriate.
- Do not create a second visual system for one screen.
- Prefer clear, maintainable component boundaries over a single giant UI function.
- Do not duplicate the same styled control across multiple screens.
- Do not add large example blocks, mock systems, or unrelated demo UI to production files.
Visual Design System
All UI should belong to the same STUD design language.
The style should feel:
- chunky
- playful
- polished
- game-like
- readable at a glance
- visually layered without becoming noisy
The UI should not look like a generic flat web dashboard.
STUD Style Characteristics
Use these traits consistently where appropriate:
- layered depth rather than one flat rectangle
- subtle top-to-bottom or directional gradients
- dark backing layers or outlines that are slightly tinted toward the element theme color
- rounded corners
- visible but controlled strokes
- tiled stud texture on major filled surfaces
- restrained glow/highlight layers where they improve depth
- strong readable text
- clear separation between primary, secondary, and decorative elements
- theme colors that vary by feature while preserving the same structural language
Effects must support hierarchy, not compete with it.
Do not add glow, gradients, texture, strokes, shadows, and overlays to every object indiscriminately.
Layout Rules
Responsive Sizing
Use a deliberate mix of:
- Scale
- pixel offsets
Do not build an entire interface using only offsets.
Do not build an entire interface using only scale.
Layouts must remain usable across different viewport sizes.
When using UIAspectRatioConstraint, keep meaningful non-zero responsive size values on both axes unless a zero axis is intentionally required.
Avoid UITextSizeConstraint and UISizeConstraint unless they solve a real layout problem.
Use UIAspectRatioConstraint when preserving proportions materially improves the element.
Positioning
Prefer:
- logical container hierarchy
- padding
- list/grid layouts where suitable
- consistent anchor points
- predictable alignment
Avoid excessive hand-positioned children when a layout object would be clearer and more robust.
Do not use arbitrary positioning values merely to make one screenshot look correct if they make the component fragile.
Backgrounds
Not every UI element needs a filled background.
Use filled surfaces mainly for:
- buttons
- cards
- panels
- bars
- important interactive containers
- elements that need visual grouping
For simple labels or lightweight information, transparent backgrounds with text strokes or surrounding structure are often better.
Typography
Use TextScaled for rendered UI text unless there is a specific reason not to.
Typography must preserve hierarchy through:
- container size
- weight
- spacing
- contrast
- placement
Do not make every label equally prominent.
Primary titles, important values, action labels, secondary text, and helper text should visibly differ in importance.
Prevent:
- clipping
- cramped text
- overly wide lines
- weak contrast
- tiny text on mobile
- text touching strokes or panel edges
Use the project's existing font choices and text-stroke conventions unless the task explicitly requires a different treatment.
Color and Theme
Use strong theme colors, but keep supporting colors controlled.
Dark outline/backing colors should generally be slightly biased toward the element's theme color rather than defaulting to pure black or neutral gray.
Do not calculate those colors continuously at runtime. Use the final intended color directly.
Maintain sufficient contrast between:
- text and background
- icons and background
- selected and unselected states
- enabled and disabled states
- foreground and decorative texture
Different systems may have different theme colors, but they should still look like part of the same UI family.
Texture, Depth, and Surface Treatment
For major filled STUD surfaces, consider the project's existing stud texture.
Typical surface construction may include:
- darker outer/back layer
- lighter front/content layer
- subtle gradient
- tiled stud texture
- inner or outer stroke
- optional restrained glow
Do not blindly apply the full stack to every object.
Small controls should remain visually clean.
Decorative layers must not interfere with input or readability.
Reusable UI Components
Create reusable Vide components for visual structures that appear repeatedly.
Good candidates include:
- standard buttons
- icon buttons
- close buttons
- panels
- cards
- tabs
- progress bars
- currency/cost displays
- badges
- locked states
- selected states
- notification elements
- upgrade nodes
Reusable components should accept the data and state they need while keeping STUD styling internally consistent.
Do not create reusable abstractions for tiny one-off elements.
Before building a new control from scratch, inspect the existing UI codebase for an appropriate component to reuse or extend.
Interaction States
Interactive elements must clearly communicate their state.
Where relevant, support:
- hover
- pressed
- selected
- disabled
- locked
- notification/attention states
Reuse existing interaction, hover, click, tween, or animation helpers when available.
Do not duplicate animation systems unnecessarily.
Animations should feel responsive and intentional.
Avoid excessive motion that reduces readability or delays interaction.
Vide Requirements
Production UI must integrate cleanly with the project's existing Vide architecture.
Use the existing project import style and conventions.
Keep visual structure separate from unrelated gameplay logic when practical.
Do not destroy or bypass:
- reactive state
- cleanup logic
- controller subscriptions
- callbacks
- signals
- visibility conditions
- existing ownership rules
When modifying an existing component, preserve its external API unless a task explicitly requires changing it.
Avoid introducing duplicate live UI instances.
Do not use weak-key tables as the sole ownership registry for live Instance-backed UI. Keep explicit ownership, clean it up when the Instance is removed, and deduplicate against the actual hierarchy before creating another instance.
Pinevex Visual Workflow
Pinevex is the required headless visual feedback tool for substantial UI work.
The local Pinevex server is expected to run at:
http://127.0.0.1:8000
Project UI design files live in:
ui-designs/
Rendered previews live in:
.ui-previews/
The project renderer command is:
python tools/pinevex/render.py ui-designs/<Name>.json
When Pinevex Must Be Used
Use the Pinevex loop when:
- creating a new screen
- creating a new major component
- substantially restyling an existing component
- recreating UI from a screenshot/reference
- changing layout hierarchy
- changing spacing, proportions, or visual structure
- performing visual polish that cannot be validated from code alone
Minor text or logic-only changes do not require a full visual iteration cycle unless they affect layout.
Required Visual Iteration Loop
For substantial UI work, follow this loop:
1. Inspect the relevant existing UI code, shared components, style modules, and image registries.
2. Determine the intended hierarchy and interaction model.
3. Create or update the corresponding Pinevex design in ui-designs/.
4. Render it with the project Pinevex tool.
5. Inspect the generated PNG in .ui-previews/.
6. Identify the highest-impact visual problems.
7. Correct those problems.
8. Render again.
9. Repeat until another pass would not create a meaningful visual improvement.
10. Implement or update the production Vide UI to match the validated design.
11. Re-check that existing behavior and reactive logic still work.
Do not declare substantial UI work complete after only writing code.
Do not assume the first render is acceptable.
Visual Review Order
Review each render in this order:
1. overall composition
2. hierarchy
3. proportions
4. alignment
5. spacing and padding
6. control sizing
7. typography
8. contrast and color balance
9. strokes, corners, gradients, texture, and depth
10. small polish
Fix the largest structural issues before adjusting minor decorative details.
Do not waste iterations tuning tiny color differences while major layout problems remain.
Iteration Discipline
After each render, focus on the 1-3 highest-impact defects.
Avoid changing many unrelated visual decisions at once.
Each iteration should have a clear reason.
Good iteration behavior:
- identify a concrete problem
- make a targeted correction
- render again
- verify whether the correction actually improved the result
Bad iteration behavior:
- random restyling
- changing multiple unrelated areas without evidence
- endlessly tweaking insignificant values
- declaring success without inspecting the render
Stop when:
- hierarchy is clear
- spacing is consistent
- proportions are coherent
- text is readable
- states are understandable
- the UI matches the project style
- further changes would be marginal rather than meaningful
Reference Images
When a screenshot or visual reference is provided, treat it as a target rather than loose inspiration unless the task says otherwise.
Compare:
- overall silhouette
- hierarchy
- relative sizes
- spacing
- alignment
- major colors
- panel structure
- button treatment
- typography
- icon placement
- decorative density
Do not blindly copy defects from a reference.
Preserve the project's STUD visual language while matching the intended composition.
When the requested design conflicts with established project style, keep the requested structure while adapting the finish so it still belongs to the game.
Pinevex vs Production Vide
Pinevex is the visual design and validation layer.
Vide is the production implementation layer.
Do not maintain two independently designed versions of the same interface.
The Pinevex design should describe the intended visual result, and the Vide implementation should match it as closely as practical.
If Pinevex cannot represent a Roblox/Vide feature exactly:
- use Pinevex for the closest visual approximation
- implement the real feature correctly in Vide
- preserve the same layout and visual intent
Do not reduce production functionality merely to fit Pinevex limitations.
Responsive Validation
Major screens should be checked at more than one viewport when practical.
Pay particular attention to:
- desktop
- narrow/mobile layouts
- text wrapping
- panel overflow
- controls becoming too small
- excessive empty space
- aspect-ratio breakage
A UI that only looks correct at one exact resolution is not finished.
Existing Codebase First
Before creating new UI infrastructure, inspect:
- existing UI components
- shared style modules
- image/asset registries
- existing animation helpers
- current Vide patterns
- nearby screens with related functionality
Prefer extending what already exists over creating parallel systems.
Do not rewrite a working system unless the task specifically requires it.
Code Quality
UI code should be:
- readable
- modular
- consistently named
- easy to revise
- explicit about ownership and cleanup
Use clear internal names such as:
- Content
- StudTexture
- Glow
- Icon
- Label
- Cost
- Sensor
- Header
- Body
- Footer
Avoid meaningless autogenerated names.
Avoid giant components when meaningful visual sections can be separated cleanly.
Do not over-engineer simple UI.
Completion Criteria
UI work is complete only when all relevant items below are satisfied:
- production UI uses Vide correctly
- existing logic still works
- visual structure matches the requested design
- STUD styling is consistent with the rest of the project
- repeated controls reuse appropriate components
- layout is responsive enough for intended viewports
- text is readable and unclipped
- interaction states are clear
- Pinevex preview has been rendered and inspected for substantial visual work
- major visual defects found during inspection have been corrected
- no unnecessary duplicate UI systems or components were introduced
Code correctness alone is not sufficient for substantial UI work.

If no examples are provided in the prompt, use UI reference libary!
# UI Reference Library

Visual reference material is stored in `ui-references/`.

Before designing substantial UI, inspect relevant references from this directory.

Use references to understand:
- STUD surface construction
- button depth
- panel layering
- texture density
- stroke thickness
- corner radii
- typography
- spacing
- visual hierarchy
- theme treatment

Do not completely copy the references, make sure the UI is good for the use including the layout and colors. The references are only for guide.

Choose references relevant to the type of UI being created. For example, a new button should primarily reference existing buttons rather than copying the layout of an entire menu.

References define the project's visual language, not an exact layout that must always be copied.

When multiple references exist, extract their shared design principles rather than combining every decorative feature into one element.

Before implementation, visibly reproduce the references' dominant silhouette, border depth, title scale, and surface contrast; matching only their palette or stud texture is not sufficient.

Also inspect good existing production UI under `src/UI/` when it is relevant to the task.

Do not copy obsolete, unused, or visibly inconsistent UI merely because it exists in the codebase.

FOR STUD TEXTURE, THERE IS ONE IN UISTYLE! DO NOT CREATE STUD TEXTURE WITH CODE! THE IMAGE IS 4x4 STUDS.

The UI should match the style of the UI in the references or the libary
