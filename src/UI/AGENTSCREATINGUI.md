AgentsCreatingUI.md
Purpose
This file defines how agents must create, modify, review, and polish Roblox UI in this project.
The project uses Vide for production UI and Pinevex Renderer for headless visual iteration. UI work is not complete when the code merely runs; agents must render, inspect, revise, and re-render substantial interfaces until the result is visually coherent and matches the requested direction.
Core Rules
- Production UI must use Vide unless the surrounding system explicitly requires otherwise.
- Preserve existing gameplay logic, state, signals, callbacks, controllers, and data flow when changing UI.
- Do not replace working behavior just to simplify styling.
- Reuse existing UI components, style modules, animation helpers, image registries, and interaction modules where appropriate.
- Follow the visual direction requested for the specific screen; do not impose an unrelated existing style on it.
- Prefer clear, maintainable component boundaries over a single giant UI function.
- Do not duplicate the same styled control across multiple screens.
- Do not add large example blocks, mock systems, or unrelated demo UI to production files.
Visual Direction
There is no mandatory project-wide visual aesthetic. Follow the user's brief, supplied reference, or screen-specific direction.
Do not assume that new UI needs rounded corners, stud textures, gradients, glow, layered depth, thick strokes, a particular palette, or any other existing treatment.
Existing style modules and visual components are optional resources. Reuse them only when they fit the requested result; functional interaction helpers may still be reused independently of their presentation.
Keep each screen internally coherent, readable, and appropriately polished without forcing it to match unrelated existing interfaces.
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
Choose typography deliberately for the requested design. Existing fonts and text-stroke conventions are optional, not defaults that override the brief.
Color and Theme
Use a controlled palette appropriate to the requested design.
Maintain sufficient contrast between:
- text and background
- icons and background
- selected and unselected states
- enabled and disabled states
- foreground and decorative elements
Surface Treatment
Use corners, textures, gradients, strokes, shadows, glow, and depth only when the requested design benefits from them.
No surface treatment is required by default.
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
Reusable components should accept the data and state they need without forcing one presentation onto every consumer.
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
- the UI matches the requested visual direction
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
The user's requested design takes precedence over existing project styling. Do not adapt it back toward an established aesthetic unless asked.
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
- visual styling matches the requested direction
- repeated controls reuse appropriate components
- layout is responsive enough for intended viewports
- text is readable and unclipped
- interaction states are clear
- Pinevex preview has been rendered and inspected for substantial visual work
- major visual defects found during inspection have been corrected
- no unnecessary duplicate UI systems or components were introduced
Code correctness alone is not sufficient for substantial UI work.

# UI Reference Library

Optional historical visual references are stored in `ui-references/`.

Consult them only when the user requests that style or when a specific reference is relevant to the task. They do not define a mandatory project-wide visual language.

When using a reference, extract only the traits that support the requested result. Do not automatically copy its corner treatment, depth, texture, strokes, palette, decoration, or layout.

Verify typography against the production component path: explicitly set required font weights and check shared-component text-size constraints instead of assuming the preview renderer will match Studio.

Also inspect good existing production UI under `src/UI/` when it is relevant to the task.

Do not copy obsolete, unused, or visibly inconsistent UI merely because it exists in the codebase.
Make sure to avoid unnesscecary rendering. If you arent greatly altering the visuals of something, do not render.