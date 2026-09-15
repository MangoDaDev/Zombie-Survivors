# Codebase Index

Quick reference for the project's first-party Luau scripts. Generated Wally dependencies in `Packages` and `ServerPackages` are intentionally excluded.

## `src/classes` - Client shared classes

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/classes/ConveyorItem.lua` | ConveyorItem | Renders replicated conveyor items, moves them along their path, and forwards purchase prompts through SharedClass. |
| `src/classes/MuseumVisitor.lua` | MuseumVisitor | Renders grounded visitors through one shared frame loop with environment-only collision, responsive facing, procedural walking, fading, appearance, dialogue, and cash feedback. |

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
| `src/controllers/CrateController.lua` | CrateController | Plays client-only silhouette roulette, pulsing previews, reveal audio, burst feedback, scaled rarity pinwheels, and compact crate-purchase guidance. |
| `src/controllers/FixingController.lua` | FixingController | Owns responsive client-authoritative cleaning damage, visuals, progress, Fix prompts, avatar hiding, and the tool/fake-arm viewmodel. |
| `src/controllers/GuidanceController.lua` | GuidanceController | Resolves authoritative tutorial or contextual objectives, manages their local highlight, directional beam, and objective text, and immediately clears completed interface guidance. |
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
| `src/modules/Game/CleaningConfig.lua` | CleaningConfig | Registers restoration tools and derives item actions automatically from item prices and upgrade unlock costs, alongside rewards, viewmodel positioning, brushes, VFX, and completion behavior. |
| `src/modules/Game/CollisionGroups.lua` | CollisionGroups | Defines shared player and NPC collision-group names used by server characters and client-rendered visitors. |
| `src/modules/Game/BatInfo.lua` | BatInfo | Configures the Wooden through Obsidian crate-only bat progression with progressively improved damage, timing, range, validation, and sounds. |
| `src/modules/Game/CrateInfo.lua` | CrateInfo | Configures regular and pity-only crate tiers, the optimized new-player drop sequence, rarity-based spawn-depth bias, health, loot luck, population limits, reveal pacing, and the synchronized reset cycle. |
| `src/modules/Game/DataTemplate.lua` | DataTemplate | Defines saved defaults for cash, guaranteed opening drops, inventory, museum displays, restoration state, tutorial progress, and upgrade ownership. |
| `src/modules/Game/DirtRenderer.lua` | DirtRenderer | Calculates surface-area-scaled dirt counts and places randomized dirt cubes, using a slightly enlarged cube size for stronger coverage. |
| `src/modules/Game/FreezePlayer.lua` | FreezePlayer | Freezes the local player, optionally at a target CFrame. |
| `src/modules/Game/GreaseRenderer.lua` | GreaseRenderer | Places smaller, more numerous, size-scaled grease patches and manages their shared HP, fade, removal, and deterministic cleanup. |
| `src/modules/Game/ItemsInfo.lua` | ItemsInfo | Configures all 100 Studio item assets with stable IDs, balanced rarity weights, economy, durability, and movement values consumed by automatic restoration-action selection. |
| `src/modules/Game/PaintRenderer.lua` | PaintRenderer | Applies strongly faded, discolored, patch-varied paint damage while preserving and gradually restoring each target part's vibrant original color. |
| `src/modules/Game/RarityInfo.lua` | RarityInfo | Defines the Common through Secret rarity tiers, name gradients, reveal-effect timing, and a simple white Secret treatment. |
| `src/modules/Game/RestorationVisuals.lua` | RestorationVisuals | Applies each item's automatically derived unfinished Dirt, Paint, and Grease appearance consistently across rewards, carrying, inventory, and legacy sources. |
| `src/modules/Game/TutorialConfig.lua` | TutorialConfig | Defines the short ordered objectives used by the persistent guided tutorial. |
| `src/modules/Game/UpgradeConfig.lua` | UpgradeConfig | Defines the faster early cost curve for capacity, Spray stat tiers, Paint/Sponge tools, the Stone-to-Obsidian bat branch, and bat cooldown tiers. |
| `src/modules/Game/UpgradeLogic.lua` | UpgradeLogic | Resolves ownership, prerequisites, visibility, capacity, automatic base Spray access, tool unlock sources and stats, bat tiers, and bat cooldown. |
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
| `src/modules/UI/Images.lua` | Images | Catalogs named image asset IDs, including dedicated icon entries for every bat tier, for project interfaces and upgrade nodes. |
| `src/modules/UI/FixingInterface.lua` | FixingInterface | Bridges Fixing HUD actions to the client Fixing controller. |
| `src/modules/UI/ItemInfoBillboard.lua` | ItemInfoBillboard | Creates a size-aware item billboard that hides dirty item identities as `???`, reveals rarity styling after cleaning, and shows required restoration steps. |
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
| `src/servercontrollers/CarryController.lua` | CarryController | Handles purchased-item carrying, museum delivery, inventory persistence, tutorial acquisition milestones, equipped-item detection, and invisible hotbar Tool selectors for the fixing viewmodel. |
| `src/servercontrollers/BatController.lua` | BatController | Supplies the highest purchased bat with its tier-specific hotbar icon, applies cooldown progression, validates swings, and relays crate reactions. |
| `src/servercontrollers/CharacterController.lua` | CharacterController | Authorizes character spawning and applies the configured R6 avatar animations. |
| `src/servercontrollers/CollisionController.lua` | CollisionController | Registers collision groups and assigns character parts so players do not collide with players or NPCs while retaining environment collisions. |
| `src/servercontrollers/ConveyorController.lua` | ConveyorController | Retains the inactive legacy conveyor spawning and purchase implementation. |
| `src/servercontrollers/CrateController.lua` | CrateController | Spawns tiered crate fields and pity crates, owns health, persistent opening-drop guarantees, loot rolls, purchases, nearby feedback, pity countdowns, and synchronized area resets. |
| `src/servercontrollers/DataController.lua` | DataController | Handles the self-service `/resetdata` chat command and resets the requesting player's profile through DataService. |
| `src/servercontrollers/FixingController.lua` | FixingController | Owns fixing sessions, saved progress, unfinished damage setup, equipped-tool validation, and rarity-scaled reveals while accepting client-authoritative cleaning completion. |
| `src/servercontrollers/GuidanceController.lua` | GuidanceController | Persists and advances tutorial objectives, assigns and reset-safely replaces each new player's nearest common crate, and sends contextual guidance. |
| `src/servercontrollers/MuseumController.lua` | MuseumController | Assigns museum plots, creates purchased displays, explains rejected placement, and handles placement, removal, selling, tutorial milestones, and visitor-facing exhibits. |
| `src/servercontrollers/VisitorController.lua` | VisitorController | Gates visitor spawning on occupied exhibits, schedules grounded visitor routes and payments, advances the first-income objective, and reserves exhibits within each player's purchased visitor limit. |
| `src/servercontrollers/UpgradeController.lua` | UpgradeController | Validates prerequisites and affordability, deducts cash, advances the guided tool unlock, normalizes ownership, and persists purchases. |

## `src/UI` - Vide interface

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/UI/App.lua` | App | Composes the root ScreenGui, cleaning and guidance interfaces, crate reset countdown, and general HUD components. |
| `src/UI/App.story.lua` | App Story | Exposes the App component for UI story previews. |
| `src/UI/Classes/Button.lua` | Button | Provides a reusable reactive Vide button with hover and press feedback. |
| `src/UI/HUD/BottomRight.lua` | BottomRight | Displays saved cash and animates the HUD when cash increases. |
| `src/UI/HUD/CleaningHUD.lua` | CleaningHUD | Displays the cursor-centered cleaning brush and smoothly animated current-step progress. |
| `src/UI/HUD/CrateResetTimer.lua` | CrateResetTimer | Displays the globally synchronized time remaining until the next crate-area reset. |
| `src/UI/HUD/FixingOverlay.lua` | FixingOverlay | Shows the exit-cleaning control while the player is in Fixing mode. |
| `src/UI/HUD/GuidanceHUD.lua` | GuidanceHUD | Shows a gently floating compact instruction and animated directional marker positioned from its current world or interface target without covering target billboards. |
| `src/UI/Menus/UpgradeTree.lua` | UpgradeTree | Provides a larger responsive tutorial-emphasized opener, then opens centered on Start and renders connected ownership-colored upgrade branches on one movable and scalable canvas, with masked ghost details, drag panning, zoom, reveals, and purchasing. |
| `src/UI/UIOrigin.lua` | UIOrigin | Mounts the Vide application once into the local PlayerGui. |
