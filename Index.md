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
| `src/controllers/BatController.lua` | BatController | Detects responsive crate and player bat targets, applies saved cooldown multipliers, predicts crate damage, and renders swing, impact, and crate-reaction feedback. |
| `src/controllers/ConveyorItemController.lua` | ConveyorItemController | Retains the inactive legacy ConveyorItem SharedClass renderer. |
| `src/controllers/CrateController.lua` | CrateController | Plays client-only silhouette roulette, pulsing previews, reveal audio, burst feedback, scaled rarity pinwheels, and compact crate-purchase guidance. |
| `src/controllers/FixingController.lua` | FixingController | Owns responsive client-authoritative cleaning damage, visuals, progress, Fix prompts, avatar hiding, and the tool/fake-arm viewmodel. |
| `src/controllers/GuidanceController.lua` | GuidanceController | Resolves authoritative tutorial or contextual objectives, manages their local highlight, directional beam, and objective text, and immediately clears completed interface guidance. |
| `src/controllers/InventoryController.lua` | InventoryController | Controls Satchel visibility, requests carried-item drops, keeps the bat in the first slot, and sends validated inventory ordering to the server. |
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
| `src/modules/Game/CleaningConfig.lua` | CleaningConfig | Registers restoration tools and derives item actions from currency-independent restoration tiers, alongside viewmodel positioning, brushes, VFX, and completion behavior. |
| `src/modules/Game/CollisionGroups.lua` | CollisionGroups | Defines shared player and NPC collision-group names used by server characters and client-rendered visitors. |
| `src/modules/Game/EconomyConfig.lua` | EconomyConfig | Centralizes progression-stage price bands, restoration tiers and rewards, starting cash, and rarity-scaled museum income while deriving final item values from item difficulty. |
| `src/modules/Game/BatInfo.lua` | BatInfo | Configures the Wooden through Obsidian crate-only bat progression with progressively improved damage, timing, range, validation, and sounds. |
| `src/modules/Game/CrateInfo.lua` | CrateInfo | Configures regular and pity-only crate tiers, affordable new-player drops, normalized per-tier rarity distributions, weighted item rolls, population limits, the synchronized 0.6-second reveal pacing, and the reset cycle. |
| `src/modules/Game/DataTemplate.lua` | DataTemplate | Defines saved defaults for cash, guaranteed opening drops, inventory, museum displays, restoration state, tutorial progress, and upgrade ownership. |
| `src/modules/Game/DirtRenderer.lua` | DirtRenderer | Calculates capped surface-area-scaled dirt counts and attaches randomized dirt cubes only to raycast-validated exposed surfaces. |
| `src/modules/Game/FreezePlayer.lua` | FreezePlayer | Freezes the local player, optionally at a target CFrame. |
| `src/modules/Game/GreaseRenderer.lua` | GreaseRenderer | Places spaced, size-scaled grease patches on raycast-validated exterior surfaces and manages their HP, fade, removal, and cleanup. |
| `src/modules/Game/ItemInteractionConfig.lua` | ItemInteractionConfig | Centralizes world-item lifetime, carrying slowdown, contested-price escalation, PvP knockback/stun/protection, fixing rotation, and restoration placement limits. |
| `src/modules/Game/MuseumConfig.lua` | MuseumConfig | Centralizes global museum slot ranges and derives each slot's level, local index, required level count, and per-level display count. |
| `src/modules/Game/ItemsInfo.lua` | ItemsInfo | Configures all 100 Studio item assets with stable IDs, within-rarity difficulty and drop weights, durability, movement values, and economy-derived final prices, income, and restoration tiers. |
| `src/modules/Game/PaintRenderer.lua` | PaintRenderer | Applies faded paint damage while safely preserving and restoring each part's own original color, material, material variant, reflectance, and transparency. |
| `src/modules/Game/RarityInfo.lua` | RarityInfo | Defines the Common through Secret rarity tiers, name gradients, reveal-effect timing, and a simple white Secret treatment. |
| `src/modules/Game/RestorationVisuals.lua` | RestorationVisuals | Applies each item's automatically derived unfinished Dirt, Paint, and Grease appearance consistently across rewards, carrying, inventory, and legacy sources. |
| `src/modules/Game/SurfacePlacement.lua` | SurfacePlacement | Selects area-weighted item surfaces and uses bounded outward raycasts to return validated exterior positions and normals. |
| `src/modules/Game/TutorialConfig.lua` | TutorialConfig | Defines the short ordered objectives used by the persistent guided tutorial. |
| `src/modules/Game/UpgradeConfig.lua` | UpgradeConfig | Defines the edge-adjacent six-branch hex layout, economy-scaled upgrade cost curves, Sponge-to-Spray-Paint tool progression, capacity, Spray stats, bat tiers, and bat cooldowns. |
| `src/modules/Game/UpgradeLogic.lua` | UpgradeLogic | Resolves ownership, prerequisites, affordability, visibility, capacity, automatic base Spray access, tool unlock sources and stats, bat tiers, and bat cooldown. |
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
| `src/modules/UI/ItemDespawnCountdown.lua` | ItemDespawnCountdown | Creates and updates the shared near-expiry billboard used by all unclaimed world items. |
| `src/modules/UI/NotificationManager.lua` | NotificationManager | Provides reusable transient notifications and keyed inactive-to-active transition suppression. |
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
| `src/servercontrollers/CarryController.lua` | CarryController | Owns carried-item identity and ownership metadata, authoritative drop requests, movement penalties and restoration, reset/disconnect recovery, museum delivery, inventory persistence, and fixing tools. |
| `src/servercontrollers/BatController.lua` | BatController | Supplies upgraded bats, validates crate and PvP hits, enforces cooldown and anti-chain-hit protection, and applies server-owned forced drops, knockback, and temporary stuns. |
| `src/servercontrollers/CharacterController.lua` | CharacterController | Authorizes character spawning and applies the configured R6 avatar animations. |
| `src/servercontrollers/CollisionController.lua` | CollisionController | Registers collision groups and assigns character parts so players do not collide with players or NPCs while retaining environment collisions. |
| `src/servercontrollers/ConveyorController.lua` | ConveyorController | Retains the inactive legacy conveyor spawning and purchase implementation. |
| `src/servercontrollers/CrateController.lua` | CrateController | Spawns tiered crate fields and pity crates, owns health, loot rolls, synchronized reveals, interaction-safe world-item despawn countdowns, purchases, and area resets. |
| `src/servercontrollers/DataController.lua` | DataController | Handles the self-service `/resetdata` chat command and resets the requesting player's profile through DataService. |
| `src/servercontrollers/FixingController.lua` | FixingController | Owns fixing sessions, saved progress, validated unfinished damage placement, 2x item rotation, equipped-tool validation, and rarity-scaled completion. |
| `src/servercontrollers/GuidanceController.lua` | GuidanceController | Persists and advances tutorial objectives, assigns and reset-safely replaces each new player's nearest common crate, and sends contextual guidance. |
| `src/servercontrollers/MuseumController.lua` | MuseumController | Builds only purchased museum levels and globally numbered displays, spawns the separate fixing table and movable roof, and handles placement, removal, selling, tutorial milestones, and visitor-facing exhibits. |
| `src/servercontrollers/VisitorController.lua` | VisitorController | Targets active visitors from occupied exhibit count times the player's guests-per-display upgrade, schedules grounded visitor routes and payments, advances the first-income objective, and reserves exhibit viewing capacity. |
| `src/servercontrollers/WorldItemController.lua` | WorldItemController | Owns dropped world items, free owner retrieval, locked contested purchases, capped 1.5× price escalation, movement correction, interaction-paused despawn countdowns, and cleanup. |
| `src/servercontrollers/UpgradeController.lua` | UpgradeController | Validates prerequisites and affordability, deducts cash, advances the guided tool unlock, normalizes ownership, and persists purchases. |

## `src/UI` - Vide interface

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/UI/App.lua` | App | Composes the root ScreenGui, carrying, cleaning, guidance, notification, crate reset, upgrade, and general HUD components. |
| `src/UI/App.story.lua` | App Story | Exposes the App component for UI story previews. |
| `src/UI/Classes/Button.lua` | Button | Provides a reusable reactive Vide button with hover and press feedback. |
| `src/UI/HUD/BottomRight.lua` | BottomRight | Displays saved cash and animates the HUD when cash increases. |
| `src/UI/HUD/CarryOverlay.lua` | CarryOverlay | Shows the Drop button only while the local player is carrying a world item. |
| `src/UI/HUD/CleaningHUD.lua` | CleaningHUD | Displays the cursor-centered cleaning brush and smoothly animated current-step progress. |
| `src/UI/HUD/CrateResetTimer.lua` | CrateResetTimer | Displays the globally synchronized time remaining until the next crate-area reset. |
| `src/UI/HUD/FixingOverlay.lua` | FixingOverlay | Shows the exit-cleaning control while the player is in Fixing mode. |
| `src/UI/HUD/GuidanceHUD.lua` | GuidanceHUD | Shows a gently floating compact instruction and animated directional marker positioned from its current world or interface target without covering target billboards. |
| `src/UI/HUD/Notifications.lua` | Notifications | Renders reusable transient notification messages with compact attention animation. |
| `src/UI/Menus/UpgradeTree.lua` | UpgradeTree | Provides a responsive affordability-emphasized opener, then opens centered on Start and renders edge-touching ownership-colored hex branches on one movable and scalable canvas, with affordable-node highlighting, masked ghost details, drag panning, zoom, reveals, and purchasing. |
| `src/UI/UIOrigin.lua` | UIOrigin | Mounts the Vide application once into the local PlayerGui. |
