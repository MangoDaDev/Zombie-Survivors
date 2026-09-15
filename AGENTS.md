# Project guidance

## Authority and workflow

- The user's current request overrides repository defaults when they conflict.
- Ask for clarification only when missing information would materially change the result or make a destructive change unsafe.
- Inspect the actual repository before changing it. Never invent paths, instances, remotes, modules, assets, or package APIs.
- Use Roblox Studio MCP when a task needs the live DataModel or Studio state. File-only Rojo work does not require Studio. If possible, Infer from current code where the Items are instead of viewing the Studio MCP
- Do not use Computer Control - It is not needed
- If a task does require Studio and MCP is unavailable, report that and stop before making Roblox project changes.
- Do not attempt to repair the local Rojo/Rokit setup. The missing Rojo target is intentional.
- Do not run automated playtests unless the user asks. Run formatting, static checks, or a non-destructive build only when the required tool is already available and the check is proportionate.
- When told not to do something or to do something leave a note to do it that way in the script for the agent. And update it as well.

Code should be mostly Event based.

Example code: Follow this style:

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.networker)
local Signal = require(ReplicatedStorage.Packages.signal)

local LocalPlayer = Players.LocalPlayer

local ReadySignal = Signal.new()
local DeathConnection: RBXScriptConnection?
local CharacterNetwork: Networker.Client?
local IsReady = false

local CharacterController = {}

local function DisconnectDeathConnection()
	if not DeathConnection then
		return
	end

	DeathConnection:Disconnect()
	DeathConnection = nil
end

function CharacterController.Init()
	CharacterNetwork = Networker.client.new("CharacterController", CharacterController)

	IsReady = true
	ReadySignal:Fire()
end

function CharacterController.WaitUntilReady()
	if IsReady then
		return
	end

	ReadySignal:Wait()
end

function CharacterController.RequestCharacter(): boolean
	CharacterController.WaitUntilReady()

	return (CharacterNetwork :: Networker.Client):fetch("RequestCharacter") == true
end

function CharacterController.OnCharacterAdded(Character: Model)
	DisconnectDeathConnection()

	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Camera = Workspace.CurrentCamera

	if Camera.CameraType == Enum.CameraType.Custom then
		Camera.CameraSubject = Humanoid
	end

	DeathConnection = Humanoid.Died:Connect(function()
		task.delay(Players.RespawnTime, function()
			if LocalPlayer.Character == Character or LocalPlayer.Character == nil then
				CharacterController.RequestCharacter()
			end
		end)
	end)
end

return CharacterController


## Template architecture

- This is a reusable Luau Roblox template managed with Rojo. `default.project.json` is the source-to-DataModel map.
- `src/client/init.client.lua` and `src/server/init.server.lua` are orchestration-only bootstraps. Controllers must be explicitly registered in their `modules_to_init` lists.
- Client controllers live in `src/controllers`; server controllers live in `src/servercontrollers`.
- Shared modules live in `src/modules` under the five categories `Core`, `Game`, `Math`, `Platform`, and `UI`; keep server-only logic and secrets out of this replicated tree.
- `src/UI/UIOrigin.lua` owns the Vide mount and `src/UI/App.lua` is the neutral UI composition root.
- `src/loading/init.client.lua` runs from ReplicatedFirst. It waits for the UI root and character controller, so startup changes must keep those systems compatible.
- `Players.CharacterAutoLoads` is disabled. The retained client and server CharacterControllers own initial spawning and respawning.
- `src/modules/Game/DataTemplate.lua` is intentionally empty and should be extended with JSON-compatible defaults when a game needs saved player data.
- `src/modules/Core/SharedClass.lua` is retained framework code for cross-boundary shared classes. Reuse it only when that model fits; do not create a competing class-replication layer.

## Studio-owned assets

- `ReplicatedStorage.Assets` is an existing Studio-owned asset library and is not mapped by Rojo. Inspect it through Studio MCP before referencing an asset; do not invent asset paths or assume it will exist in a place built only from this repository.
- Existing assets may be reused by default when they fit the requested feature. This includes Animations, Tools, Sounds, Models, VFX, and Music.
- Every sound currently under `ReplicatedStorage.Assets.Sounds` is a complete working sound approved for reuse.
- An asset's own name, attributes, containing folder name, or a nearby `AGENTS` StringValue can override the default permission. For example, anything named `Example... - Do not use in code` must not be used in runtime code.
- Treat asset names and hierarchy as contracts. Reinspect Studio when choosing an asset, use the exact existing path, and avoid renaming or moving Studio-owned assets unless the user requests it.
- Prefer an appropriate existing asset over importing or generating a duplicate. Clone reusable templates when runtime ownership or cleanup requires it; do not mutate shared source assets.

## Dependencies

- Dependencies are managed by Wally and tools by Rokit. Never manually edit `Packages/`, `ServerPackages/`, either `_Index/`, `wally.lock`, or generated place/build files.
- Change dependencies in `wally.toml`, then run Wally install to reconcile generated packages and the lockfile.
- Use the lowercase project aliases exactly as mapped by Wally:
  - `dataservice` (`leifstout/dataservice@1.0.0`)
  - `networker` (`leifstout/networker@0.3.1`)
  - `promise` (`evaera/promise@4.0.0`)
  - `signal` / GoodSignal (`stravant/goodsignal@0.3.1`)
  - `vide` (`centau/vide@0.4.1`)
  - `profileservice` (`firebird702/profileservice@1.1.0`, server only)
- Prefer DataService for player persistence. Do not manage the same player record independently through ProfileService.
- Use `DataService.server:init(options)` on the server and `DataService.client:init()` on the client. Client initialization yields until initial data arrives.
- Common DataService operations are `get`, `set`, `update`, `arrayInsert`, `arrayRemove`, `waitForData`, and the path-specific signal getters. Inspect the installed source before relying on less common methods.
- Use Networker for client/server requests and replication. Do not create raw RemoteEvents or RemoteFunctions for normal gameplay systems.
- `SharedClass` internally owns raw remotes as a legacy framework exception. Do not copy that implementation pattern into new systems.
- Use GoodSignal for custom in-process events when another system genuinely needs to subscribe.

## Coding conventions

- Use `camelCase` for local variables and private functions.
- Use `UPPER_SNAKE_CASE` for constants, except declarative information/data modules where ordinary keys may be clearer.
- Use `PascalCase` for public methods, exposed members, controller lifecycle methods, and module/class names.
- Treat controller tables as namespaces: use dot functions, keep mutable state in focused module-scope variables, and never use `self` to reference a controller.
- Networker callbacks that receive the controller table should accept it as an unused first parameter (`_`) instead of treating it as controller state.
- Follow the surrounding file's established style when making a small targeted edit; do not rename unrelated code solely for style consistency.
- Prefer simple, direct Roblox code that an intermediate Luau developer can comfortably modify.
- Search existing controllers, modules, UI components, utilities, and packages before adding a new system.
- Extract genuinely reusable behavior into a focused module, but do not create abstractions for one-off logic.
- Keep bootstrap files small, avoid hidden module-scope side effects, and avoid circular dependencies.
- Prefer events over polling. Avoid unnecessary loops, Workspace scans, repeated instance creation, and per-object frame connections.
- Clean up connections, tasks, temporary instances, networkers, and cached player/character state.
- Use `pcall` only where failure is expected from an external Roblox operation, not to hide ordinary coding errors.
- Keep tunable values such as speeds, cooldowns, limits, and probabilities in a focused configuration table when they are genuinely likely to change.
- Separate logical sections with a blank line and prefer one statement per line. Keep code comfortably spaced without fragmenting closely related operations.
## Coding Rules

* **Do not use Roblox Attributes anywhere.** Never use `SetAttribute`, `GetAttribute`, `GetAttributes`, or Attribute changed signals.
* Store configuration, metadata, and runtime state in **Luau tables**, preferably organized inside appropriate ModuleScripts.
* Do not replace Attributes with unnecessary `ValueObject`s. Keep data in code unless an Instance is genuinely required.
* Keep the code clean, modular, readable, and maintainable.
* Avoid spaghetti code, giant functions, excessive nesting, duplicated logic, and random patches added to unrelated scripts.
* Use reusable functions/modules for shared behaviour and configuration tables for differences between items/tools.
* Keep each system focused on its own responsibility.
* Maintain a **single source of truth** for important data instead of hardcoding the same values across multiple scripts.
* Follow good modern Luau practices and integrate changes into the existing architecture rather than creating duplicate systems.
* Do not overengineer. Use sensible abstractions only where they improve the code.

## Codebase index

- When work on a script is finished, check `Index.markdown` and update it if a script was added, removed, renamed, or moved; its responsibility changed; a new system or module was introduced; or its existing description is no longer accurate.
- Keep `Index.markdown` concise and structural. It is a quick codebase map, not detailed technical documentation.

## Security and persistence

- Keep currency, inventory, progression, rewards, purchases, damage, and persistent state server-authoritative.
- Validate all client-originated types, values, permissions, ownership claims, cooldowns, distances, and relevant world state.
- Persist player-specific data through DataService and keep every stored value JSON-compatible. Never store Instances, CFrames, Vector3s, functions, or cyclic tables.
- Avoid unnecessary data writes and design rewards or purchases so duplicate requests cannot grant twice.

Simple > clever. Correct > short. Existing systems > duplicates. Small changes > broad refactors.
