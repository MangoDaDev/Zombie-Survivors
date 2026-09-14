# Codebase Index

Quick reference for the project's first-party Luau scripts. Generated Wally dependencies in `Packages` and `ServerPackages` are intentionally excluded.

## `src/classes` - Client shared classes

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/classes/ConveyorItem.lua` | ConveyorItem | Renders replicated conveyor items, moves them along their path, and forwards purchase prompts through SharedClass. |
| `src/classes/MuseumVisitor.lua` | MuseumVisitor | Renders grounded visitors with responsive facing and procedural walking, then handles fading, appearance, dialogue, and cash feedback. |

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
| `src/controllers/ConveyorItemController.lua` | ConveyorItemController | Registers the client ConveyorItem SharedClass renderer. |
| `src/controllers/FixingController.lua` | FixingController | Drives the Fixing camera, movement lock, cursor-following arm, and cursor-aimed SprayBottle input. |
| `src/controllers/InventoryController.lua` | InventoryController | Controls Satchel visibility and sends validated inventory slot ordering to the server. |
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
| `src/modules/Game/DataTemplate.lua` | DataTemplate | Defines saved defaults for cash, ordered inventory items, and museum displays. |
| `src/modules/Game/DirtRenderer.lua` | DirtRenderer | Calculates surface-area-scaled dirt counts and adds or removes dense dirt layers across conveyor, inventory, and Fixing views. |
| `src/modules/Game/FreezePlayer.lua` | FreezePlayer | Freezes the local player, optionally at a target CFrame. |
| `src/modules/Game/ItemsInfo.lua` | ItemsInfo | Configures item IDs, assets, weights, prices, guest payments, speed, and optional carry offsets. |
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
| `src/modules/UI/Images.lua` | Images | Catalogs named image asset IDs used by project interfaces. |
| `src/modules/UI/FixingInterface.lua` | FixingInterface | Bridges Fixing HUD actions to the client Fixing controller. |
| `src/modules/UI/ItemInfoBillboard.lua` | ItemInfoBillboard | Creates the reusable item name, price, and guest-payment BillboardGui. |
| `src/modules/UI/PlayVFX.lua` | PlayVFX | Clones, starts, and cleans up reusable visual and sound effects. |
| `src/modules/UI/Sounds.lua` | Sounds | Resolves any approved Studio-owned sound by name and handles cloned positional playback and cleanup. |

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
| `src/servercontrollers/CarryController.lua` | CarryController | Handles purchased-item carrying, museum delivery, Tool creation, and ordered inventory persistence. |
| `src/servercontrollers/CharacterController.lua` | CharacterController | Authorizes character spawning and applies the configured R6 avatar animations. |
| `src/servercontrollers/ConveyorController.lua` | ConveyorController | Builds conveyor paths, spawns weighted items, and validates purchases and cash deductions. |
| `src/servercontrollers/FixingController.lua` | FixingController | Owns movement-locked Fixing sessions, dirt generation and cleaning, temporary tool loadouts, and persisted progress. |
| `src/servercontrollers/MuseumController.lua` | MuseumController | Assigns museum plots and manages persistent display placement, removal, selling, and viewing regions. |
| `src/servercontrollers/VisitorController.lua` | VisitorController | Concurrently schedules grounded visitor routes and dialogue, chooses positions within display viewing regions, and awards guest-payment cash. |

## `src/UI` - Vide interface

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/UI/App.lua` | App | Composes the root ScreenGui and its current HUD components. |
| `src/UI/App.story.lua` | App Story | Exposes the App component for UI story previews. |
| `src/UI/Classes/Button.lua` | Button | Provides a reusable reactive Vide button with hover and press feedback. |
| `src/UI/HUD/BottomRight.lua` | BottomRight | Displays saved cash and animates the HUD when cash increases. |
| `src/UI/HUD/FixingOverlay.lua` | FixingOverlay | Shows the exit-cleaning control while the player is in Fixing mode. |
| `src/UI/UIOrigin.lua` | UIOrigin | Mounts the Vide application once into the local PlayerGui. |
