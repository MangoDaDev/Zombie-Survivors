# Loading screen guidance

- This script runs from ReplicatedFirst before the normal client bootstrap has completed.
- Keep the loading screen deliberately simple and image-free: use Frames, text, and the existing progress bar rather than asset-backed ImageLabels or ImageButtons.
- Do not depend on Vide here. The loading screen uses direct Instance creation so it can appear before replicated application UI is ready.
- The flow waits for `PlayerGui.App`, then `CharacterController:WaitUntilReady()`, and finally requests a character because CharacterAutoLoads is disabled.
- If the UI root name, character startup API, or CharacterAutoLoads policy changes, update this script in the same change.
- Avoid scanning or preloading the entire DataModel. Load only assets that a future design explicitly requires.
- Disconnect or complete animations before destroying the ScreenGui, and do not leave loading tasks running after dismissal.
