# Codebase Index

Quick reference for the reusable first-party Luau foundation. Generated Wally dependencies in `Packages` and `ServerPackages` are intentionally excluded.

## Runtime bootstraps

| Path | Responsibility |
| --- | --- |
| `src/client/init.client.lua` | Initializes client DataService, generic controllers, the UI root, and character lifecycle dispatch. |
| `src/server/init.server.lua` | Initializes server DataService, generic server controllers, and player/character lifecycle dispatch. |
| `src/loading/init.client.lua` | Shows startup progress, waits for the app and character controller, requests the initial character, and fades away. |

## Controllers

| Path | Responsibility |
| --- | --- |
| `src/controllers/CharacterController.lua` | Requests server-authorized character spawning and manages local camera and respawn behavior. |
| `src/controllers/AbilityController.lua` | Mirrors authoritative ability state and dispatches validated weapon presentation events. |
| `src/controllers/Ability/ActiveWeaponEffects.lua` | Renders Fireball, Lightning, and latency-corrected Boomerang presentation from authoritative server packets. |
| `src/controllers/Ability/OrbitingSwordsView.lua` | Renders smoothly reconciled spectral sword orbits, Rage blades, trails, and released-blade return flights. |
| `src/controllers/CoinsController.lua` | Exposes the replicated, read-only local coin balance and its change signal. |
| `src/controllers/CoinDropController.lua` | Renders lit, world-sized BillboardGui coin bursts, trails, smooth merges, expiration, and accelerating server-directed collection. |
| `src/controllers/RageController.lua` | Validates authoritative Rage snapshots, predicts activation presentation, and owns local character Rage VFX. |
| `src/controllers/PlayerStateController.lua` | Receives generic server runtime-state snapshots and updates. |
| `src/controllers/RollController.lua` | Sends roll intent and validates authoritative item/clover, auto-roll, and completion events for presentation. |
| `src/controllers/ZombieController.lua` | Receives compact zombie snapshots/damage events and drives the single client render loop. |
| `src/controllers/Zombie/ProceduralAnimator.lua` | Produces type-specific procedural movement and attack poses without animation tracks. |
| `src/controllers/Zombie/ZombieView.lua` | Owns one client-rendered zombie model, interpolation, health/hit feedback, visibility, and cosmetic death ragdolls. |
| `src/servercontrollers/CharacterController.lua` | Rate-limits and authorizes character spawn requests while `CharacterAutoLoads` is disabled. |
| `src/servercontrollers/AbilityController.lua` | Owns ability discovery, loadouts, coin upgrades, Dagger scheduling, active/passive refreshes, ability-specific Rage behavior, and authoritative damage requests. |
| `src/servercontrollers/Ability/ActiveWeapons.lua` | Runs the shared authoritative Fireball, Lightning, and Boomerang scheduler, projectile hits, status ticks, area caps, Rage variants, and cleanup. |
| `src/servercontrollers/Ability/OrbitingSwords.lua` | Simulates authoritative sword orbits, hit cooldowns, Wounded, momentum, inner blades, releases, and Rage behavior. |
| `src/servercontrollers/Ability/PassiveEffects.lua` | Applies Heart and Boots through named stat modifiers and owns their server-authoritative milestone behavior. |
| `src/servercontrollers/CollisionController.lua` | Assigns avatar parts to a generic non-colliding player-character collision group. |
| `src/servercontrollers/CoinsController.lua` | Validates and owns persistent server-authoritative coin balance operations. |
| `src/servercontrollers/CoinDropController.lua` | Owns zombie coin values, spread, lifetime cleanup, capped spatial merging, proximity claims, and authoritative collection awards. |
| `src/servercontrollers/RageController.lua` | Owns the server-timed Rage charge cycle, activation validation, duration, death resets, and replication. |
| `src/servercontrollers/PlayerStateController.lua` | Owns generic per-player runtime state and replicates requested state updates. |
| `src/servercontrollers/PlayerStatController.lua` | Composes named player health/speed modifiers, preserves gained health, and applies the final movement-speed limit. |
| `src/servercontrollers/RollController.lua` | Owns per-player duplicate-inclusive ability rolls, cooldowns, clover luck chains, rewards, and auto-roll scheduling. |
| `src/servercontrollers/Roll/RollServerConfig.lua` | Defines server-only luck, cooldown, and clover-chain balance values. |
| `src/servercontrollers/ZombieController.lua` | Runs grouped area spawning, batched authoritative simulation, damage feedback, death rewards, and compact replication. |
| `src/servercontrollers/Zombie/Zombie.lua` | Defines authoritative targeting, area-bounded movement, attacks, health, and knockback per zombie. |
| `src/servercontrollers/Zombie/ZombieBehaviors.lua` | Provides definition-selected movement and attack strategies without type checks in core logic. |
| `src/servercontrollers/Zombie/ZombieSeparation.lua` | Applies throttled spatial-hash separation so dense crowds do not occupy identical positions. |

## Core modules

| Path | Responsibility |
| --- | --- |
| `src/modules/Core/ActivateCallbacks.lua` | Runs callback descriptors in their configured client or server context. |
| `src/modules/Core/AnchorModel.lua` | Anchors or unanchors every BasePart under an instance. |
| `src/modules/Core/ChangeModelProperties.lua` | Applies a property set across an instance hierarchy with an optional class filter. |
| `src/modules/Core/GenerateUniqueId.lua` | Generates a GUID without braces. |
| `src/modules/Core/GetObjectExists.lua` | Checks whether a value is a currently parented Roblox Instance. |
| `src/modules/Core/GetRandomChild.lua` | Selects a random direct child from an instance. |
| `src/modules/Core/InheritInstance.lua` | Adds fallback table inheritance while preserving an existing metatable lookup. |
| `src/modules/Core/SharedClass.lua` | Provides the retained cross-boundary class replication protocol for systems that genuinely need paired objects. |

## Game foundation modules

These modules provide shared game configuration, persistent player-data defaults, and player-control helpers.

| Path | Responsibility |
| --- | --- |
| `src/modules/Game/CoinsConfig.lua` | Defines the shared coin data key, default, and exact-integer balance limit. |
| `src/modules/Game/CoinDropConfig.lua` | Defines shared coin pickup distance, timing, and client-prediction batching limits. |
| `src/modules/Game/Abilities/AbilityDefinitions.lua` | Defines expandable ability metadata, equip limits, upgrade costs, per-level stats, visible milestones, and ability-specific Rage tuning, including Fireball, Lightning, and Boomerang. |
| `src/modules/Game/Stats/PlayerStatConfig.lua` | Defines fallback player base stats and the global final movement-speed limit. |
| `src/modules/Game/Rage/RageConfig.lua` | Defines shared Rage capacity, 30-second charge, 10-second duration, keybind, and request cadence. |
| `src/modules/Game/DataTemplate.lua` | Supplies DataService's JSON-compatible persisted player-data defaults. |
| `src/modules/Game/Rolls/RollDefinitions.lua` | Builds the weighted roll catalog from obtainable abilities and defines data keys and presentation timing. |
| `src/modules/Game/RuntimeState.lua` | Stores generic transient per-player state and change signals. |
| `src/modules/Game/Zombies/ZombieAreas.lua` | Defines progression-scaled spawn volumes, caps, group sizes, and weighted zombie pools. |
| `src/modules/Game/Zombies/ZombieDefinitions.lua` | Defines expandable per-type combat, movement, coin reward, asset, and animation configuration. |
| `src/modules/Game/Zombies/ZombieProtocol.lua` | Shares compact state codes and snapshot timing between server simulation and client rendering. |
| `src/modules/Game/TeleportPlayer.lua` | Teleports a Player or character Model to a CFrame or BasePart. |
| `src/modules/Game/TeleportLocalPlayer.lua` | Teleports the local character for client-side presentation use. |
| `src/modules/Game/FreezePlayer.lua` | Freezes the local character, optionally at a target CFrame. |
| `src/modules/Game/UnfreezePlayer.lua` | Restores the local character's prior anchored state. |
| `src/modules/Game/_PlayerFreezeState.lua` | Owns the shared local freeze state used by the freeze helpers. |

## Math modules

| Path | Responsibility |
| --- | --- |
| `src/modules/Math/AdvancedRound.lua` | Rounds a number to a configurable interval and offset. |
| `src/modules/Math/AverageColors.lua` | Calculates a weighted or unweighted average Color3. |
| `src/modules/Math/Color3ToColorSequence.lua` | Converts a Color3 into a constant ColorSequence. |
| `src/modules/Math/DetailedRandom.lua` | Returns a random decimal within a numeric range. |
| `src/modules/Math/FormatNumber.lua` | Formats numbers with compact suffixes. |
| `src/modules/Math/FormatTime.lua` | Formats seconds as colon-separated time. |
| `src/modules/Math/GaussianRandom.lua` | Generates normally distributed random numbers. |
| `src/modules/Math/Generate3DBezier.lua` | Samples a 3D Bezier curve from control points. |
| `src/modules/Math/GetRandomFromWeightedTable.lua` | Selects weighted entries and calculates adjusted chances. |
| `src/modules/Math/GetRandomPosInPart.lua` | Returns a random world position inside a BasePart. |
| `src/modules/Math/MoveCFrameTowards.lua` | Moves one CFrame position toward another by a limited distance. |
| `src/modules/Math/MultiplyNumberSequence.lua` | Scales NumberSequence values. |
| `src/modules/Math/MultiplyUDim2.lua` | Multiplies every scale and offset component of a UDim2. |
| `src/modules/Math/ToPercentage.lua` | Converts a decimal value into a rounded percentage string. |

## Platform modules

| Path | Responsibility |
| --- | --- |
| `src/modules/Platform/GetDisplayName.lua` | Returns a player's display name with a safe fallback. |
| `src/modules/Platform/GetProfilePicture.lua` | Fetches a player's Roblox headshot thumbnail. |
| `src/modules/Platform/GetSyncedTime.lua` | Returns Roblox's synchronized server time. |

## UI foundation

| Path | Responsibility |
| --- | --- |
| `src/UI/App.lua` | Composes the neutral `App` ScreenGui and retained generic overlays. |
| `src/UI/UIOrigin.lua` | Mounts the Vide application once into LocalPlayer.PlayerGui. |
| `src/UI/App.story.lua` | Exposes the app component for UI story previews. |
| `src/UI/Classes/Button.lua` | Provides a reusable reactive STUD-style button. |
| `src/UI/Classes/Confirmation.lua` | Provides a reusable modal confirmation component. |
| `src/UI/Effects/HoverExpand.lua` | Provides reusable hover scaling for GuiObjects. |
| `src/UI/Effects/Notification.lua` | Provides a reusable counted attention badge. |
| `src/UI/HUD/CoinsDisplay.lua` | Renders the responsive left-side coin balance display from replicated data. |
| `src/UI/HUD/AbilityInterface.lua` | Renders equipped-first ability lists, concealed locked entries, direct card actions, details, and discovery. |
| `src/UI/HUD/RageBar.lua` | Renders the responsive STUD-style Rage meter, ready/active states, activation control, and screen pulse. |
| `src/UI/HUD/Notifications.lua` | Renders transient notifications from NotificationManager. |
| `src/UI/HUD/RollControls.lua` | Renders independent bottom-aligned Roll/Hide/Show, Auto Roll, and Abilities controls. |
| `src/UI/HUD/RollInterface.lua` | Renders the full-screen or compact top-center item/clover reel chain with distance-based center scaling and selection feedback. |
| `src/modules/UI/NotificationManager.lua` | Emits reusable transient notification events. |
| `src/modules/UI/PlayVFX.lua` | Clones, starts, and cleans up reusable effects and sounds. |
| `src/modules/UI/SafeArea.lua` | Provides dynamic Roblox topbar-safe offsets. |
| `src/modules/UI/Sounds.lua` | Resolves optional Studio-owned sound templates and plays cloned copies. |
| `src/modules/UI/UIStyle.lua` | Centralizes the reusable STUD design tokens. |

## Package compatibility

| Path | Responsibility |
| --- | --- |
| `src/compatibility/TopbarPlus.lua` | Exposes the installed TopbarPlus package at the path expected by Satchel. |
