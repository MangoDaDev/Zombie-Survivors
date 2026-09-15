# Codebase Index

Quick reference for the project's first-party Luau scripts. Generated Wally dependencies in `Packages` and `ServerPackages` are intentionally excluded.

## `src/classes` - Client shared classes

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/classes/ConveyorItem.lua` | ConveyorItem | Renders replicated conveyor items, moves them along their path, and forwards purchase prompts through SharedClass. |
| `src/classes/MuseumVisitor.lua` | MuseumVisitor | Renders grounded visitors with environment-only collision, responsive facing, procedural walking, fading, appearance, dialogue, and cash feedback. |

## `src/client` - Client bootstrap

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/client/init.client.lua` | Client | Initializes client DataService, controllers, UI, and character lifecycle hooks. |

## `src/compatibility` - Package compatibility

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/compatibility/TopbarPlus.lua` | TopbarPlus | Exposes the installed TopbarPlus package at the path expected by Satchel. |

## `src/controllers` - Client controllers

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/controllers/CharacterController.lua` | CharacterController | Requests character spawning and manages local camera and respawn behavior. |
| `src/controllers/BatController.lua` | BatController | Predicts responsive crate-only bat swings, applies saved cooldown multipliers, crate reactions, forgiving hitboxes, trails, impacts, and latency-safe crate health. |
| `src/controllers/ConveyorItemController.lua` | ConveyorItemController | Retains the inactive legacy ConveyorItem SharedClass renderer. |
| `src/controllers/CrateController.lua` | CrateController | Plays client-only silhouette roulette, pulsing previews, reveal audio, burst feedback, and scaled rarity pinwheels when supported by Studio assets. |
| `src/controllers/FixingController.lua` | FixingController | Controls Fix prompts, hides and decouples the real avatar, preserves hotbar selection with invisible Tools, and renders a responsive tool/fake-arm viewmodel with surface-following Sponge motion. |
| `src/controllers/InventoryController.lua` | InventoryController | Controls Satchel visibility, keeps the bat in the first slot while preserving item order, and sends validated inventory ordering to the server. |
| `src/controllers/MuseumVisitorController.lua` | MuseumVisitorController | Registers the client MuseumVisitor SharedClass renderer. |
| `src/controllers/TopbarController.lua` | TopbarController | Creates the invite and group TopbarPlus buttons. |

## `src/loading` - Loading screen

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/loading/init.client.lua` | LoadingScreen | Shows startup progress, waits for the interface, requests the initial character, and fades away. |

## `src/modules/Core` - Core utilities

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/modules/Core/ActivateCallbacks.lua` | ActivateCallbacks | Runs callback descriptors in their configured client or server context. |
| `src/modules/Core/AnchorModel.lua` | AnchorModel | Anchors or unanchors every BasePart under an instance. |
| `src/modules/Core/ChangeModelProperties.lua` | ChangeModelProperties | Applies a property set across an instance hierarchy with an optional class filter. |
| `src/modules/Core/GenerateUniqueId.lua` | GenerateUniqueId | Generates a GUID without braces. |
| `src/modules/Core/GetObjectExists.lua` | GetObjectExists | Checks whether a value is a currently parented Roblox Instance. |
| `src/modules/Core/GetRandomChild.lua` | GetRandomChild | Selects a random direct child from an instance. |
| `src/modules/Core/InheritInstance.lua` | InheritInstance | Adds fallback table inheritance while preserving an existing metatable lookup. |
| `src/modules/Core/SharedClass.lua` | SharedClass | Replicates class instances, properties, and allowed method calls between server and clients. |

## `src/modules/Game` - Shared game modules

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/modules/Game/_PlayerFreezeState.lua` | PlayerFreezeState | Stores and manages the local character's anchored freeze state. |
| `src/modules/Game/CleaningConfig.lua` | CleaningConfig | Registers restoration steps and tools, shared viewmodel positioning, Sponge surface/scrub motion, screen-space brushes, VFX, auto-completion, and item-step helpers. |
| `src/modules/Game/CollisionGroups.lua` | CollisionGroups | Defines shared player and NPC collision-group names used by server characters and client-rendered visitors. |
| `src/modules/Game/BatInfo.lua` | BatInfo | Configures Wooden, Stone, and Gold crate-only bat tiers with progressively improved crate damage, timing, range, predicted reactions, validation, and sounds. |
| `src/modules/Game/CrateInfo.lua` | CrateInfo | Configures regular and pity-only crate tiers, bat-scaled health and loot luck, performance-conscious population limits, reveal pacing, UI, sounds, and the synchronized reset cycle. |
| `src/modules/Game/DataTemplate.lua` | DataTemplate | Defines saved defaults for cash, inventory, museum displays, restoration state, and persistent upgrade ownership. |
| `src/modules/Game/DirtRenderer.lua` | DirtRenderer | Calculates surface-area-scaled dirt counts and adds or removes dense dirt layers without treating other restoration overlays as item surfaces. |
| `src/modules/Game/FreezePlayer.lua` | FreezePlayer | Freezes the local player, optionally at a target CFrame. |
| `src/modules/Game/GreaseRenderer.lua` | GreaseRenderer | Places dirt-density translucent yellow-brown circular surface patches and manages their shared HP, fade, removal, and deterministic cleanup. |
| `src/modules/Game/ItemsInfo.lua` | ItemsInfo | Configures all 57 Studio item assets with stable IDs, balanced rarity weights, economy, durability, movement, and rarity-weighted restoration requirements with dirt-only starter items. |
| `src/modules/Game/PaintRenderer.lua` | PaintRenderer | Applies randomized brown color damage while preserving and gradually restoring each target part's original color. |
| `src/modules/Game/RarityInfo.lua` | RarityInfo | Defines the Common through Secret rarity tiers, name gradients, reveal-effect timing, and a simple white Secret treatment. |
| `src/modules/Game/RestorationVisuals.lua` | RestorationVisuals | Applies each item's configured unfinished Dirt, Paint, and Grease appearance consistently across rewards, carrying, inventory, and legacy sources. |
| `src/modules/Game/UpgradeConfig.lua` | UpgradeConfig | Defines progression for capacity, Spray stat tiers branching from its automatic unlock, purchasable Paint/Sponge tools, Stone/Gold bats, and bat cooldown tiers. |
| `src/modules/Game/UpgradeLogic.lua` | UpgradeLogic | Resolves ownership, prerequisites, visibility, capacity, automatic base Spray access, other tool unlocks, tool stats, bat tiers, and bat cooldown. |
| `src/modules/Game/TeleportLocalPlayer.lua` | TeleportLocalPlayer | Moves the local character to a CFrame or BasePart. |
| `src/modules/Game/TeleportPlayer.lua` | TeleportPlayer | Moves a Player's character or a supplied character model to a target. |
| `src/modules/Game/UnfreezePlayer.lua` | UnfreezePlayer | Restores the local character's state after freezing. |

## `src/modules/Math` - Math and formatting utilities

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/modules/Math/AdvancedRound.lua` | AdvancedRound | Rounds a number to a configurable interval and offset. |
| `src/modules/Math/AverageColors.lua` | AverageColors | Calculates an average from weighted or unweighted Color3 values. |
| `src/modules/Math/Color3ToColorSequence.lua` | Color3ToColorSequence | Converts one Color3 into a constant ColorSequence. |
| `src/modules/Math/DetailedRandom.lua` | DetailedRandom | Returns a random decimal within a numeric range. |
| `src/modules/Math/FormatNumber.lua` | FormatNumber | Formats numbers with compact suffixes such as K, M, and B. |
| `src/modules/Math/FormatTime.lua` | FormatTime | Formats seconds as a colon-separated time value. |
| `src/modules/Math/GaussianRandom.lua` | GaussianRandom | Generates normally distributed random numbers. |
| `src/modules/Math/Generate3DBezier.lua` | Generate3DBezier | Samples a 3D Bezier curve from control points. |
| `src/modules/Math/GetRandomFromWeightedTable.lua` | GetRandomFromWeightedTable | Selects weighted entries and calculates luck-adjusted chances. |
| `src/modules/Math/GetRandomPosInPart.lua` | GetRandomPosInPart | Returns a random world position inside a BasePart. |
| `src/modules/Math/MoveCFrameTowards.lua` | MoveCFrameTowards | Moves a CFrame position toward another by a limited distance. |
| `src/modules/Math/MultiplyNumberSequence.lua` | MultiplyNumberSequence | Scales NumberSequence values with optional limits and opacity behavior. |
| `src/modules/Math/MultiplyUDim2.lua` | MultiplyUDim2 | Multiplies every scale and offset component of a UDim2. |
| `src/modules/Math/ToPercentage.lua` | ToPercentage | Converts a decimal value into a rounded percentage string. |

## `src/modules/Platform` - Roblox platform utilities

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/modules/Platform/GetDisplayName.lua` | GetDisplayName | Builds a player display name with configured rank, Premium, and verification markers. |
| `src/modules/Platform/GetProfilePicture.lua` | GetProfilePicture | Fetches a player's Roblox headshot thumbnail. |
| `src/modules/Platform/GetSyncedTime.lua` | GetSyncedTime | Returns Roblox's synchronized server time. |
| `src/modules/Platform/Ranks.lua` | Ranks | Configures special user ranks and their display prefixes. |

## `src/modules/UI` - Shared presentation utilities

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/modules/UI/Images.lua` | Images | Catalogs named image asset IDs and explicit placeholders used by project interfaces and upgrade nodes. |
| `src/modules/UI/FixingInterface.lua` | FixingInterface | Bridges Fixing HUD actions to the client Fixing controller. |
| `src/modules/UI/ItemInfoBillboard.lua` | ItemInfoBillboard | Creates a size-aware elevated item billboard prioritizing guest payment above price and showing required restoration steps. |
| `src/modules/UI/PlayVFX.lua` | PlayVFX | Clones, starts, and cleans up reusable visual and sound effects. |
| `src/modules/UI/Sounds.lua` | Sounds | Resolves any approved Studio-owned sound by name and handles cloned positional playback and cleanup. |
| `src/modules/UI/UIStyle.lua` | UIStyle | Provides the shared ComicNeueAngular game font for first-party and configured package interfaces. |

## `src/server` - Server bootstrap

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/server/init.server.lua` | Server | Initializes DataService and dispatches player and character lifecycle events to server controllers. |

## `src/serverclasses` - Server shared classes

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/serverclasses/ConveyorItem.lua` | ConveyorItem | Owns authoritative conveyor item state, purchase requests, lifetime, and replication. |
| `src/serverclasses/MuseumVisitor.lua` | MuseumVisitor | Replicates authoritative visitor movement, dialogue, payment effects, fading, and destruction commands. |

## `src/servercontrollers` - Server controllers

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/servercontrollers/CarryController.lua` | CarryController | Handles purchased-item carrying, museum delivery, inventory persistence, equipped-item detection, and invisible hotbar Tool selectors for the fixing viewmodel. |
| `src/servercontrollers/BatController.lua` | BatController | Supplies the highest purchased bat, applies tier-independent cooldown progression, validates swings, and relays crate reactions. |
| `src/servercontrollers/CharacterController.lua` | CharacterController | Authorizes character spawning and applies the configured R6 avatar animations. |
| `src/servercontrollers/CollisionController.lua` | CollisionController | Registers collision groups and assigns character parts so players do not collide with players or NPCs while retaining environment collisions. |
| `src/servercontrollers/ConveyorController.lua` | ConveyorController | Retains the inactive legacy conveyor spawning and purchase implementation. |
| `src/servercontrollers/CrateController.lua` | CrateController | Spawns tiered and globally aligned pity crates, owns health and loot rolls, reveals items, updates the outlined PityDisplay countdown, and performs synchronized area resets behind the reset wall. |
| `src/servercontrollers/DataController.lua` | DataController | Handles the self-service `/resetdata` chat command and resets the requesting player's profile through DataService. |
| `src/servercontrollers/FixingController.lua` | FixingController | Owns fixing sessions, freezes/restores characters, validates freely selected tools, renders unfinished damage layers, applies upgrades, and preserves progress. |
| `src/servercontrollers/MuseumController.lua` | MuseumController | Assigns museum plots and physically creates only the purchased 8–12 displays while handling placement, removal, selling, and visitor-facing exhibits. |
| `src/servercontrollers/VisitorController.lua` | VisitorController | Schedules grounded visitor routes and payments with an upgrade-scaled active population while reserving exhibits within each player's purchased per-item visitor limit. |
| `src/servercontrollers/UpgradeController.lua` | UpgradeController | Validates prerequisites and affordability, deducts cash, normalizes default ownership, and persists server-authoritative upgrade purchases. |

## `src/UI` - Vide interface

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/UI/App.lua` | App | Composes the root ScreenGui, cleaning interface, crate reset countdown, and general HUD components. |
| `src/UI/App.story.lua` | App Story | Exposes the App component for UI story previews. |
| `src/UI/Classes/Button.lua` | Button | Provides a reusable reactive Vide button with hover and press feedback. |
| `src/UI/HUD/BottomRight.lua` | BottomRight | Displays saved cash and animates the HUD when cash increases. |
| `src/UI/HUD/CleaningHUD.lua` | CleaningHUD | Displays the cursor-centered cleaning brush and smoothly animated current-step progress. |
| `src/UI/HUD/CrateResetTimer.lua` | CrateResetTimer | Displays the globally synchronized time remaining until the next crate-area reset. |
| `src/UI/HUD/FixingOverlay.lua` | FixingOverlay | Shows the exit-cleaning control while the player is in Fixing mode. |
| `src/UI/Menus/UpgradeTree.lua` | UpgradeTree | Opens centered on Start and renders a compact line-free hex layout on one movable and scalable canvas, with masked ghost details, drag panning, zoom, reveals, and purchasing. |
| `src/UI/UIOrigin.lua` | UIOrigin | Mounts the Vide application once into the local PlayerGui. |
