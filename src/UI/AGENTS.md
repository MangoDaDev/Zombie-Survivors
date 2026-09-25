# UI guidance

- This replicated tree is the client UI implementation and uses Vide from `ReplicatedStorage.Packages.vide`.
- `UIOrigin.lua` is the single application mount boundary. It mounts `App.lua` into LocalPlayer.PlayerGui once.
- `App.lua` is the neutral ScreenGui composition root. Compose screens and HUD components there without moving gameplay authority into UI code.
- Components return their UI hierarchy; they should not find PlayerGui, parent themselves, or call `mount` independently.
- Put generic reusable controls in `Classes`. Introduce folders such as HUD, Menus, Frames, Theme, Effects, or Utility only when real components need them.
- Name positional component groups clearly, such as `BottomRight`, rather than using vague container names.
- Prefer Vide's `create`, `source`, `derive`, `read`, `spring`, `effect`, `cleanup`, `action`, `context`, `batch`, `changed`, and `mount` APIs over manual UI synchronization.
- Pass reactive values directly to properties. Use `effect` only for real side effects, not merely to assign an Instance property.
- Use `cleanup` for RBXScriptConnections, callbacks, threads, and resources created manually inside a Vide scope.
- Keep components small and composable. Prefer typed props and reactive state over OOP-style `new`, `Enable`, `Disable`, and `Destroy` APIs.
- Keep pressed interaction higher priority than hover state, and ensure interaction state cannot remain stuck after input ends, the pointer leaves, or a control becomes disabled.
- For controls animated with `UIScale` inside layouts, keep an unscaled layout slot and center the scaled visual child with `AnchorPoint` and `Position` at `(0.5, 0.5)`.
- Keep undiscovered collection entries visually anonymous and non-interactive; do not leak their authored name or icon before discovery.
- Put frequent item actions directly on collection cards when space permits so they do not require opening a secondary detail view.
- Keep persistent HUD control rows in their own stable frame; presentation overlays must not move or own them.
- For reel or carousel focus effects, derive every entry's scale from its live distance to the focus point so neighboring entries cannot retain stale emphasis.
- Reuse `Classes/Button.lua` before introducing another general-purpose button.
- Reuse suitable Studio-owned assets when they exist instead of duplicating them, but do not make the reusable UI root depend on optional asset folders.
- UI image assets may be searched through the Roblox Studio MCP in the Creator Store, user inventory, group inventory, or universe inventory. Search only the `Image` or `Decal` asset types; never use Creator Store models, meshes, packages, or other non-image assets for this workflow.
- Visually inspect a candidate's returned thumbnail or source image before inserting or using it. Confirm that it looks polished, fits the requested UI, and does not contain suspicious, inappropriate, misleading, or moderation-risk content; do not use an asset merely because its name or metadata appears suitable.
- Image-asset sourcing must never introduce scripts. Reject any result or inserted hierarchy containing a `Script`, `LocalScript`, or `ModuleScript` rather than preserving or executing it.
- Upload images to Roblox only after verifying that the account currently active in Studio is exactly `Varie3n` and reviewing the image itself for anything Roblox moderation could reasonably flag as suspicious or inappropriate. If the account cannot be verified or the image is questionable, do not upload it and ask the user.
- Clone sounds before playback and parent runtime copies appropriately so concurrent UI interactions do not fight over one shared Sound instance. Clean up each clone after playback.
IF YOU ARE GOING TO BE CREATING/MODIFYING UI, READ AGENTSCREATINGUI.md
