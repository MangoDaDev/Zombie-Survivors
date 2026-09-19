# Codebase Index

Quick reference for the project's first-party Luau scripts. Generated Wally dependencies in `Packages` and `ServerPackages` are intentionally excluded.

## `src/classes` - Client shared classes

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/classes/ConveyorItem.lua` | ConveyorItem | Renders replicated conveyor items, moves them along their path, and forwards purchase prompts through SharedClass. |
| `src/classes/MuseumVisitor.lua` | MuseumVisitor | Renders grounded visitors through one shared frame loop with environment-only collision, responsive facing, procedural walking, fading, randomized clothing, welded hair, skin tones, dialogue, and cash feedback. |

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
| `src/controllers/BatController.lua` | BatController | Detects responsive crate and player bat targets, applies saved cooldown multipliers, predicts crate damage and lethal hits, immediately renders local debris/break feedback, and sends prediction IDs for server reconciliation. |
| `src/controllers/ConveyorItemController.lua` | ConveyorItemController | Retains the inactive legacy ConveyorItem SharedClass renderer. |
| `src/controllers/CrateController.lua` | CrateController | Renders reconciled crate health locally, starts predicted crate roulette immediately, waits for its minimum duration and authoritative result, then hands off through a dirty local reward model so network latency cannot leave a reveal gap. |
| `src/controllers/AmbientAudioController.lua` | AmbientAudioController | Shuffles and plays every track in the Music asset folder without repeats, preserves each Sound's authored volume, and smoothly ducks music for high-rarity reveals and restoration completion states. |
| `src/controllers/FixingController.lua` | FixingController | Owns smoothly blended fixing cameras that fit each item's full rotating bounds with size-dependent margins, viewport-relative cleaning/fixing columns projected through the active item's full depth, radius-assisted Hammer targeting, 80%-threshold assisted cleanup, responsive client-authoritative cleaning damage, contact-timed click/hold Hammer strikes, presentation feedback, Fix prompts, avatar hiding, and Handle-sized surface-contact tool/fake-arm viewmodels. |
| `src/controllers/GuidanceController.lua` | GuidanceController | Resolves authoritative tutorial or contextual objectives, manages their local highlight, directional beam, and objective text, and immediately clears completed interface guidance. |
| `src/controllers/InventoryController.lua` | InventoryController | Controls Satchel visibility, displays native Tool texture icons, requests carried-item drops, keeps the bat in the first slot, and sends validated inventory ordering to the server. |
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
| `src/modules/Game/CleaningConfig.lua` | CleaningConfig | Registers the tier-ordered restoration tools and actions, balanced strength/radius values, viewport-relative targeting, size-aware camera framing, geometry-aware viewmodel positioning, VFX, 85%-threshold assisted completion, and static tool/tier validation. |
| `src/modules/Game/AmbientAudioConfig.lua` | AmbientAudioConfig | Centralizes playlist folder selection and presentation ducking values while track volume remains authored on each Sound. |
| `src/modules/Game/CollisionGroups.lua` | CollisionGroups | Defines shared player, NPC, ground, and crate-debris collision-group names. |
| `src/modules/Game/EconomyConfig.lua` | EconomyConfig | Centralizes economy tuning controls, progression-stage price bands, blended onboarding income, purchase/sale values, active and passive rewards, starting and recovery cash rules, readable rounding, and item/range validation. |
| `src/modules/Game/BatInfo.lua` | BatInfo | Configures the eleven-tier Wooden-through-Meteorite crate-only bat progression with progressively improved damage, timing, range, latency-tolerant validation, and sounds. |
| `src/modules/Game/CrateInfo.lua` | CrateInfo | Configures regular and pity-only crate tiers, an unbounded high-tailed scale distribution averaging normal size, size-based rarity luck, four affordable new-player drops, normalized and validated rarity distributions, weighted item rolls, population limits, health/respawn pacing, and the reset cycle. |
| `src/modules/Game/DataTemplate.lua` | DataTemplate | Defines saved defaults for cash, guaranteed opening drops, inventory, museum displays, restoration state, tutorial progress, and upgrade ownership. |
| `src/modules/Game/DirtRenderer.lua` | DirtRenderer | Calculates capped surface-area-scaled dirt counts and attaches randomized dirt cubes only to raycast-validated exposed surfaces. |
| `src/modules/Game/FreezePlayer.lua` | FreezePlayer | Freezes the local player, optionally at a target CFrame. |
| `src/modules/Game/GreaseRenderer.lua` | GreaseRenderer | Places spaced, size-scaled grease patches on raycast-validated exterior surfaces and manages their HP, fade, removal, and cleanup. |
| `src/modules/Game/ItemInteractionConfig.lua` | ItemInteractionConfig | Centralizes world-item lifetime, billboard display settings, carrying slowdown, contested-price escalation, PvP knockback/stun/protection, fixing rotation, and restoration placement limits. |
| `src/modules/Game/MuseumConfig.lua` | MuseumConfig | Centralizes global museum slot ranges and derives each slot's level, local index, required level count, and per-level display count. |
| `src/modules/Game/ItemsInfo.lua` | ItemsInfo | Configures all 100 Studio item assets with stable IDs, validated within-rarity difficulty and drop weights, durability, movement values, and economy-derived purchase prices, restored sale values, income, and restoration tiers. |
| `src/modules/Game/PaintRenderer.lua` | PaintRenderer | Applies faded paint damage while safely preserving and restoring each part's own original color, material, material variant, reflectance, and transparency. |
| `src/modules/Game/RarityInfo.lua` | RarityInfo | Centralizes Common through Secret colors, name gradients, reveal timing, intensity, pinwheel, vignette, flash, sparkle, particle, and reveal-audio tuning. |
| `src/modules/Game/RestorationVisuals.lua` | RestorationVisuals | Applies every unfinished restoration layer consistently across rewards, carrying, inventory, and legacy item sources. |
| `src/modules/Game/RestorationTargetRenderer.lua` | RestorationTargetRenderer | Creates and tracks visibly dense, capped, surface-distributed light-dust and loose-debris plus embedded-metal and stage-owned dull-finish targets, and deterministically misaligns at least half of each item's real visible geometry for Hammer repairs while preserving exact model-relative restore transforms. |
| `src/modules/Game/SurfacePlacement.lua` | SurfacePlacement | Selects area-weighted item surfaces and uses bounded outward raycasts to return validated exterior positions and normals. |
| `src/modules/Game/TutorialConfig.lua` | TutorialConfig | Defines the short ordered objectives used by the persistent guided tutorial. |
| `src/modules/Game/UpgradeConfig.lua` | UpgradeConfig | Defines the deterministic upgrade graph, economy-scaled costs, tier-aligned restoration chain, capacity, tool stats, eleven bat tiers, cooldowns, cumulative tool costs, and graph/gating assertions. |
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
| `src/modules/UI/ItemInfoBillboard.lua` | ItemInfoBillboard | Creates the single size-aware world-item billboard containing identity, rarity, value, restoration steps, and optional despawn information. |
| `src/controllers/ItemInfoBillboardController.lua` | ItemInfoBillboardController | Applies lightweight distance disclosure and local overlap prioritization to shared item information billboards. |
| `src/modules/UI/ItemDespawnCountdown.lua` | ItemDespawnCountdown | Creates and updates the real-time despawn label inside each unclaimed world item's unified information billboard. |
| `src/modules/UI/NotificationManager.lua` | NotificationManager | Provides reusable transient text alerts with optional duration and color plus keyed inactive-to-active transition suppression. |
| `src/modules/UI/PlayVFX.lua` | PlayVFX | Clones, starts, and cleans up reusable visual and sound effects. |
| `src/modules/UI/SafeArea.lua` | SafeArea | Provides dynamic Roblox topbar-safe offsets for inset-ignoring HUD elements. |
| `src/modules/UI/Sounds.lua` | Sounds | Resolves any approved Studio-owned sound by name and handles cloned positional playback and cleanup. |
| `src/modules/UI/UIStyle.lua` | UIStyle | Centralizes the STUD design system font, palette, textures, corner radii, and outline tokens for first-party interfaces. |

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
| `src/servercontrollers/CarryController.lua` | CarryController | Owns carried-item identity and ownership metadata, builds restoration layers before welding so all damage follows carried items, and manages drops, movement, museum delivery, inventory, and tools. |
| `src/servercontrollers/BatController.lua` | BatController | Supplies upgraded bats, validates predicted crate and PvP hits against the same historical box volume used by the client, echoes authoritative results, and applies server-owned forced drops, knockback, and temporary stuns. |
| `src/servercontrollers/CharacterController.lua` | CharacterController | Authorizes character spawning and applies the configured R6 avatar animations. |
| `src/servercontrollers/CollisionController.lua` | CollisionController | Registers character and transient crate-debris collision groups, marks the ground, and keeps players, NPCs, and debris from unwanted collisions. |
| `src/servercontrollers/ConveyorController.lua` | ConveyorController | Retains the inactive legacy conveyor spawning and purchase implementation. |
| `src/servercontrollers/CrateController.lua` | CrateController | Uses the authored map regions to spawn size-and-luck-varied crate fields and return players in the crate zone to their museums during wall-clock-aligned resets, authoritatively owns health and loot rolls, and manages reveals, purchases, despawns, and resets. |
| `src/servercontrollers/DataController.lua` | DataController | Registers argument-aware chat commands, enforces Owner-rank administration permissions, performs DataService-backed cash and reset operations, and restores the minimum purchase cash for players with no earning source. |
| `src/controllers/DataController.lua` | DataController | Receives server chat-command feedback and displays it through the shared notification system. |
| `src/servercontrollers/FixingController.lua` | FixingController | Owns fixing sessions, BoundingBox-centered tabletop placement and fixing rotation, saved progress, stage-timed damage preparation, persistent completed Hammer alignment, equipped-tool validation, and sequenced rarity-scaled completion reveals. |
| `src/servercontrollers/GuidanceController.lua` | GuidanceController | Persists and advances tutorial objectives, assigns and reset-safely replaces each new player's nearest common crate, and sends contextual guidance. |
| `src/servercontrollers/MuseumController.lua` | MuseumController | Builds the museum base once, builds purchased levels and globally numbered displays separately, spawns the fixing table and movable roof, and handles placement, removal, selling, tutorial milestones, and level-aware visitor-facing exhibits. |
| `src/servercontrollers/VisitorController.lua` | VisitorController | Independently targets visitors per museum level from that level's occupied exhibit count times the player's guests-per-display upgrade, keeps routes on their spawn level, schedules payments, advances the first-income objective, and reserves exhibit viewing capacity. |
| `src/servercontrollers/WorldItemController.lua` | WorldItemController | Owns dropped world items, free owner retrieval, locked contested purchases, capped 1.5× price escalation, movement correction, interaction-paused despawn countdowns, and cleanup. |
| `src/servercontrollers/UpgradeController.lua` | UpgradeController | Enforces Sponge-only onboarding purchases, validates normal prerequisites and affordability, deducts cash, advances the guided tool unlock, normalizes ownership, and persists purchases. |

## `src/UI` - Vide interface

| Path | Name | Responsibility |
| --- | --- | --- |
| `src/UI/App.lua` | App | Composes the root ScreenGui, carrying, cleaning, guidance, notification, crate reset, upgrade, and general HUD components. |
| `src/UI/App.story.lua` | App Story | Exposes the App component for UI story previews. |
| `src/UI/Classes/Button.lua` | Button | Provides a reusable reactive STUD-style Vide button with layered depth, texture, disabled state, and hover/press feedback. |
| `src/UI/HUD/BottomRight.lua` | BottomRight | Displays saved cash and animates the HUD when cash increases. |
| `src/UI/HUD/CarryOverlay.lua` | CarryOverlay | Shows the shared red destructive-action Drop button only while the local player is carrying a world item. |
| `src/UI/HUD/CleaningHUD.lua` | CleaningHUD | Displays the cursor-centered cleaning brush and smoothly animated current-step progress. |
| `src/UI/HUD/CrateResetTimer.lua` | CrateResetTimer | Displays the globally synchronized time remaining until the next crate-area reset. |
| `src/UI/HUD/FixingOverlay.lua` | FixingOverlay | Shows the shared red destructive-action exit control while the player is in Fixing mode. |
| `src/UI/HUD/GuidanceHUD.lua` | GuidanceHUD | Shows a gently floating compact instruction and animated directional marker positioned from its current world or interface target without covering target billboards. |
| `src/UI/HUD/Notifications.lua` | Notifications | Stacks transient text-only alerts with compact enter/exit animation, optional colors, sound, scale-sized text strokes, and lifecycle cleanup. |
| `src/UI/Effects/HoverExpand.lua` | HoverExpand | Provides the reusable hover scaling used by attention notification badges. |
| `src/UI/Effects/Notification.lua` | Notification | Provides counted attention badges with periodic pulse, shake, color, hover, and lifecycle cleanup. |
| `src/UI/Menus/UpgradeTree.lua` | UpgradeTree | Provides a responsive STUD-style upgrade panel and opener with Sponge-only onboarding visibility, dynamic blue/grey purchase-state hexagons, a live purchasable-upgrade count, single-newly-affordable-upgrade alerts, BatInfo-driven bat icons, drag panning, zoom, reveals, and purchasing. |
| `src/UI/UIOrigin.lua` | UIOrigin | Mounts the Vide application once into the local PlayerGui. |
