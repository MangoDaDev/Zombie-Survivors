# Codebase Index

Quick reference for the reusable first-party Luau foundation. Generated Wally dependencies in `Packages` and `ServerPackages` are intentionally excluded.

## Runtime bootstraps

| Path | Responsibility |
| --- | --- |
| `src/client/init.client.lua` | Initializes client DataService, active foundation controllers (including party teleporter networking and presentation), the reduced UI root, and character lifecycle dispatch; simulator controllers are deliberately unregistered. |
| `src/server/init.server.lua` | Resolves lobby/game session context before initializing DataService, maps, active foundation controllers, and player/character lifecycle dispatch; simulator controllers are deliberately unregistered. |
| `src/loading/init.client.lua` | Shows startup progress, waits for the app and character controller, requests the initial character, and fades away. |

## Controllers

| Path | Responsibility |
| --- | --- |
| `src/controllers/ChatCommandController.lua` | Displays server-authorized command responses in modern chat with a notification fallback. |
| `src/controllers/CharacterController.lua` | Requests server-authorized character spawning and manages local camera and respawn behavior. |
| `src/controllers/PartyTeleporterController.lua` | Mirrors validated party/setup/loading state, sends leader confirmation and member requests, and presents server messages through the shared notification system. |
| `src/controllers/AbilityController.lua` | Mirrors authoritative ability state and dispatches validated weapon and passive presentation events. |
| `src/controllers/Ability/ActiveWeaponEffects.lua` | Renders Fireball, Lightning, and latency-corrected Boomerang presentation from authoritative server packets. |
| `src/controllers/Ability/OrbitingSwordsView.lua` | Renders smoothly reconciled spectral sword orbits, Rage blades, trails, and released-blade return flights. |
| `src/controllers/Ability/PassiveEffectsView.lua` | Renders lightweight Blast, Burn, and Thorns feedback from authoritative server packets. |
| `src/controllers/CoinsController.lua` | Exposes the replicated, read-only local coin balance and its change signal. |
| `src/controllers/RunRewardsController.lua` | **Archived/dormant:** mirrors server-held run earnings and safe-area membership, and requests an authoritative return-to-base claim. |
| `src/controllers/CoinDropController.lua` | **Archived/dormant:** renders world coin drops and curved collection presentation for possible generic item-drop reuse. |
| `src/controllers/RageController.lua` | Validates authoritative Rage snapshots and owns run-only activation input and character Rage VFX, including Studio session promotion; Lobby presentation stays dormant. |
| `src/controllers/PlayerStateController.lua` | Receives generic server runtime-state snapshots and updates. |
| `src/controllers/RollController.lua` | **Archived/dormant:** restores saved roll preferences and validates authoritative item/clover, Auto Roll, and completion events. |
| `src/controllers/ZombieController.lua` | Receives compact zombie snapshots/damage events and drives the single client render loop. |
| `src/controllers/Zombie/ProceduralAnimator.lua` | Produces type-specific procedural movement and attack poses without animation tracks. |
| `src/controllers/Zombie/ZombieView.lua` | Owns one client-rendered zombie model, interpolation, health/hit feedback, visibility, and cosmetic death ragdolls. |
| `src/servercontrollers/ChatCommandController.lua` | Registers extensible developer-only chat commands, resolves player selectors, and executes built-in utility and confirmed data-reset actions. |
| `src/servercontrollers/ChatCommand/ChatCommandConfig.lua` | Configures command cooldowns and server-only developer access. |
| `src/servercontrollers/ServerContext.lua` | Classifies normal joins as Lobby, accepts Roblox-verified reserved-server party data in live servers, and owns the strictly Studio-only local Game-session promotion. |
| `src/servercontrollers/MapController.lua` | Keeps only the current session's Lobby or Game map in Workspace, exposes its inspected spawn, and supports the guarded Studio destination switch. |
| `src/servercontrollers/CharacterController.lua` | Serializes and authorizes character loads, rate-limits client spawn requests, and places characters at the current session map's spawn. |
| `src/servercontrollers/PartyTeleportService.lua` | Provides one validated party-teleport interface: same-place reserved servers in live games and a cancellable local destination simulation in Studio using the same payload. |
| `src/servercontrollers/PartyTeleporterController.lua` | Owns closed-elevator entry/exit, timed leader setup, party settings/countdowns, Studio loading/completion tracking, and whole-party ejection on teleport failure. |
| `src/servercontrollers/AbilityController.lua` | Owns ability state, active/passive refreshes, ability-specific Rage behavior, and authoritative damage; lobby sessions keep loadouts but do not schedule dagger attacks. |
| `src/servercontrollers/Ability/ActiveWeapons.lua` | Runs the shared authoritative Fireball, Lightning, and Boomerang scheduler, projectile hits, status ticks, area caps, Rage variants, and cleanup only in Game sessions. |
| `src/servercontrollers/Ability/OrbitingSwords.lua` | Simulates authoritative sword combat in Game sessions while preserving non-damaging orbit presentation in Lobby sessions. |
| `src/servercontrollers/Ability/PassiveEffects.lua` | Owns Heart, Boots, Blast, Burn, and Thorns effects, milestone behavior, status cleanup, and authoritative passive combat reactions. |
| `src/servercontrollers/CollisionController.lua` | Assigns avatar parts to a generic non-colliding player-character collision group. |
| `src/servercontrollers/CoinsController.lua` | Validates and owns persistent server-authoritative coin balance operations. |
| `src/servercontrollers/BackpackController.lua` | **Archived/dormant:** equips authored non-physical backpack stages from authoritative carried-item totals. |
| `src/servercontrollers/RunRewardsController.lua` | **Archived/dormant:** holds unbanked run earnings, safe-area membership, return-to-base, and claim behavior. |
| `src/servercontrollers/CoinDropController.lua` | **Archived/dormant:** owns world-drop spread, cleanup, merging, proximity claims, and authoritative collection. |
| `src/servercontrollers/RageController.lua` | Owns the server-timed Rage charge cycle, activation validation, duration, death resets, and replication while rejecting Lobby activation. |
| `src/servercontrollers/PlayerStateController.lua` | Owns generic per-player runtime state and replicates requested state updates. |
| `src/servercontrollers/PlayerStatController.lua` | Composes named player health/speed modifiers, preserves gained health, and applies the final movement-speed limit. |
| `src/servercontrollers/RollController.lua` | **Archived/dormant:** owns ability rolls, luck chains, rewards, Auto Roll scheduling, and saved preferences. |
| `src/servercontrollers/Roll/RollServerConfig.lua` | **Archived/dormant:** defines server-only luck, cooldown, and clover-chain balance values. |
| `src/servercontrollers/ZombieController.lua` | Provides its shared client endpoint in every session, but only builds spawns and runs authoritative zombie simulation in Game sessions, including Studio-promoted sessions. |
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
| `src/modules/Game/PartyTeleporterConfig.lua` | Defines party capacity, setup/countdown timing, zone cadence, teleport watchdog, Studio loading delay, and world-display limits. |
| `src/modules/Game/BackpackConfig.lua` | **Archived/dormant:** maps carried totals to authored backpack stages and mount offsets. |
| `src/modules/Game/CoinDropConfig.lua` | **Archived/dormant:** defines world-drop pickup distance, timing, and client-prediction batching limits. |
| `src/modules/Game/Abilities/AbilityDefinitions.lua` | Defines expandable ability metadata, rarity odds, equip limits, upgrade costs, per-level stats, visible milestones, Rage tuning, and configurable Blast, Burn, and Thorns progression. |
| `src/modules/Game/Stats/PlayerStatConfig.lua` | Defines fallback player base stats and the global final movement-speed limit. |
| `src/modules/Game/Rage/RageConfig.lua` | Defines shared Rage capacity, 30-second charge, 10-second duration, keybind, and request cadence. |
| `src/modules/Game/DataTemplate.lua` | Supplies DataService's JSON-compatible persisted player-data defaults. |
| `src/modules/Game/Rolls/RollDefinitions.lua` | Preserves the dormant weighted roll catalog and legacy data keys; still supplies saved-data compatibility and reveal timing. |
| `src/modules/Game/RuntimeState.lua` | Stores generic transient per-player state and change signals. |
| `src/modules/Game/Zombies/ZombieAreas.lua` | Defines progression-scaled spawn volumes, caps, group sizes, and weighted zombie pools. |
| `src/modules/Game/Zombies/ZombieDefinitions.lua` | Defines expandable per-type combat, movement, legacy dormant coin metadata, asset, and animation configuration. |
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
| `src/UI/App.lua` | Composes the neutral `App` ScreenGui, party Creation Menu, and retained generic overlays. |
| `src/UI/UIOrigin.lua` | Mounts the Vide application once into LocalPlayer.PlayerGui. |
| `src/UI/App.story.lua` | Exposes the app component for UI story previews. |
| `src/UI/Classes/Button.lua` | Provides a reusable reactive STUD-style button. |
| `src/UI/Classes/Confirmation.lua` | Provides a reusable modal confirmation component. |
| `src/UI/Effects/HoverExpand.lua` | Provides reusable hover scaling for GuiObjects. |
| `src/UI/Effects/Notification.lua` | Provides a reusable counted attention badge. |
| `src/UI/HUD/CoinsDisplay.lua` | **Archived/dormant:** reusable responsive permanent-currency display. |
| `src/UI/HUD/RunRewardsDisplay.lua` | **Archived/dormant:** pending-reward claim and backpack-to-balance presentation. |
| `src/UI/HUD/AbilityInterface.lua` | **Archived/dormant:** ability management and roll-discovery presentation. |
| `src/UI/HUD/RageBar.lua` | Renders the responsive STUD-style Rage meter, ready/active states, activation control, and screen pulse. |
| `src/UI/HUD/Notifications.lua` | Renders transient notifications from NotificationManager. |
| `src/UI/HUD/PartyTeleporterMenu.lua` | Renders the responsive party Creation Menu, leader-only setup controls, departure status, and lock-aware member or leader exit. |
| `src/UI/HUD/RollControls.lua` | **Archived/dormant:** Roll/Hide/Show, Auto Roll progress, and ability-menu controls. |
| `src/UI/HUD/RollInterface.lua` | **Archived/dormant:** full-screen or compact item/clover reel presentation. |
| `src/modules/UI/NotificationManager.lua` | Emits reusable transient notification events. |
| `src/modules/UI/PlayVFX.lua` | Clones, starts, and cleans up reusable effects and sounds. |
| `src/modules/UI/SafeArea.lua` | Provides dynamic Roblox topbar-safe offsets. |
| `src/modules/UI/Sounds.lua` | Resolves optional Studio-owned sound templates and plays cloned copies. |
| `src/modules/UI/UIStyle.lua` | Centralizes the reusable STUD design tokens. |

## Package compatibility

| Path | Responsibility |
| --- | --- |
| `src/compatibility/TopbarPlus.lua` | Exposes the installed TopbarPlus package at the path expected by Satchel. |
