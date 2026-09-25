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
| `src/controllers/CharacterController.lua` | Requests server-authorized character spawning, manages the local camera, and leaves in-run death/respawn ownership to the run session flow. |
| `src/controllers/PartyTeleporterController.lua` | Mirrors validated party/setup/loading state, sends leader confirmation and member requests, and presents server messages through the shared notification system. |
| `src/controllers/AbilityController.lua` | Mirrors persistent ability unlocks, sends lobby purchase requests, and dispatches validated weapon/passive presentation events; run loadouts are presented by the progression snapshot. |
| `src/controllers/RunProgressionController.lua` | Mirrors the owning player's run-only level, XP, queued legal choices, and current run ability snapshot, and sends indexed card selections. |
| `src/controllers/RunSessionController.lua` | Mirrors the authoritative survival-clock/game-over state and sends same-server replay requests with failure feedback. |
| `src/controllers/Ability/ActiveWeaponEffects.lua` | Renders Fireball, Lightning, and latency-corrected Boomerang presentation from authoritative server packets. |
| `src/controllers/Ability/CrowdWeaponEffects.lua` | Renders block-built Aura, Ball, Drill, Mine, and Poison presentation through the shared client render loop. |
| `src/controllers/Ability/OrbitingSwordsView.lua` | Renders smoothly reconciled outward-facing spectral sword orbits, Rage blades, trails, and correctly aligned released-blade return flights. |
| `src/controllers/Ability/PassiveEffectsView.lua` | Renders lightweight Blast, Burn, and Thorns feedback from authoritative server packets. |
| `src/controllers/CoinsController.lua` | Exposes the replicated, read-only local coin balance and its change signal. |
| `src/controllers/RunRewardsController.lua` | **Archived/dormant:** mirrors server-held run earnings and safe-area membership, and requests an authoritative return-to-base claim. |
| `src/controllers/CoinDropController.lua` | Renders server-authored world coin drops, scatter/merge/magnet presentation, and latency-hidden proximity claims without awarding currency locally. |
| `src/controllers/XPDropController.lua` | Clones the authored XP crystal for server-authored world drops and renders large blue/green/pink-purple tier styling, glow/highlight, scatter, idle, magnet, collection, and cleanup states. |
| `src/controllers/PowerupDropController.lua` | Renders authored breakable power-ups, colored reveal/activation bursts, collection movement, local activation notifications/sounds, and visible timed Stopwatch, Guardian Halo, and Lucky Skull auras. |
| `src/controllers/RageController.lua` | Validates authoritative Rage snapshots and owns run-only activation input and character Rage VFX, including Studio session promotion; Lobby presentation stays dormant. |
| `src/controllers/PlayerStateController.lua` | Receives generic server runtime-state snapshots and updates. |
| `src/controllers/RollController.lua` | **Archived/dormant:** restores saved roll preferences and validates authoritative item/clover, Auto Roll, and completion events. |
| `src/controllers/ZombieController.lua` | Receives compact zombie snapshots/damage events and drives the single client render loop. |
| `src/controllers/Zombie/ProceduralAnimator.lua` | Produces type-specific procedural movement and attack poses without animation tracks. |
| `src/controllers/Zombie/ZombieView.lua` | Owns one client-rendered zombie model, definition-driven recoloring/scaling, special-ability ground telegraphs, interpolation, health/hit feedback, visibility, and cosmetic death ragdolls. |
| `src/servercontrollers/ChatCommandController.lua` | Registers extensible developer-only chat commands, resolves player selectors, and executes built-in utility and confirmed data-reset actions. |
| `src/servercontrollers/ChatCommand/ChatCommandConfig.lua` | Configures command cooldowns and server-only developer access. |
| `src/servercontrollers/ServerContext.lua` | Classifies normal joins as Lobby, accepts Roblox-verified reserved-server party data in live servers, and owns the strictly Studio-only local Game-session promotion. |
| `src/servercontrollers/MapController.lua` | Keeps only the current session's Lobby or Game map in Workspace, exposes the active map and its inspected spawn, and supports the guarded Studio destination switch. |
| `src/servercontrollers/CharacterController.lua` | Serializes and authorizes character loads, rate-limits client spawn requests, and places characters at the current session map's spawn. |
| `src/servercontrollers/PartyTeleportService.lua` | Provides validated same-place reserved-server party travel, Studio destination simulation, and individual post-run returns to a normal lobby server. |
| `src/servercontrollers/PartyTeleporterController.lua` | Owns closed-elevator entry/exit, explicitly confirmed leader setup with timeout ejection, party settings/countdowns, Studio loading/completion tracking, and whole-party ejection on teleport failure. |
| `src/servercontrollers/AbilityController.lua` | Owns server-validated coin purchases and persistent unlocks plus transient game-run loadouts/levels, including fresh same-server replay loadouts, active/passive refreshes, ability-specific Rage behavior, and authoritative damage. |
| `src/servercontrollers/RunProgressionController.lua` | Owns and resets per-player run XP/levels, queues every earned level-up, rolls three distinct legal unlocked ability choices, and validates one indexed selection at a time. |
| `src/servercontrollers/RunSessionController.lua` | Starts survival clocks, owns final run statistics/death cleanup, delays each lobby return independently, and validates same-server character replays that cancel the pending return. |
| `src/servercontrollers/BreakableController.lua` | Spawns weighted authored props across the active Game map, owns their health and respawns, produces hit/fragment feedback, and releases one authoritative power-up from every destroyed prop. |
| `src/servercontrollers/Breakable/BreakableConfig.lua` | Defines server-only breakable density, spacing, durability, respawn, feedback timing, authored model weights, and sound choices. |
| `src/servercontrollers/Ability/ActiveWeapons.lua` | Runs the shared authoritative Fireball, Lightning, and Boomerang scheduler, projectile hits, status ticks, area caps, Rage variants, and cleanup only in Game sessions. |
| `src/servercontrollers/Ability/CrowdWeapons.lua` | Runs one authoritative scheduler for Aura ticks/pulses, Ball ricochets, directional piercing Drills, grounded Mines, persistent Poison fields, Rage variants, caps, and cleanup. |
| `src/servercontrollers/Ability/CombatTargets.lua` | Keeps automatic targeting zombie-only, merges zombies and breakables for physical/AOE damage queries, and dispatches authoritative damage to the owning controller. |
| `src/servercontrollers/Ability/OrbitingSwords.lua` | Simulates authoritative sword combat in Game sessions while preserving non-damaging orbit presentation in Lobby sessions. |
| `src/servercontrollers/Ability/PassiveEffects.lua` | Owns Heart, Boots, Blast, Burn, and Thorns effects, milestone behavior, status cleanup, and authoritative passive combat reactions. |
| `src/servercontrollers/CollisionController.lua` | Assigns avatar parts to a generic non-colliding player-character collision group. |
| `src/servercontrollers/CoinsController.lua` | Validates and owns persistent server-authoritative coin balance operations. |
| `src/servercontrollers/BackpackController.lua` | Equips authored physical backpack stages and advances their fullness from authoritative run coin collections. |
| `src/servercontrollers/RunRewardsController.lua` | **Archived/dormant:** holds unbanked run earnings, safe-area membership, return-to-base, and claim behavior. |
| `src/servercontrollers/CoinDropController.lua` | Owns game-only coin spread, cleanup, merging, ownership-aware proximity claims, Scrap Magnet collection, direct persistent awards, and carried-backpack progression events. |
| `src/servercontrollers/XPDropController.lua` | Owns XP crystal values, tier-aware visual scale/height, lifetime, ownership, normal/forced magnet movement, single-collector arbitration, and run-XP grants. |
| `src/servercontrollers/PowerupDropController.lua` | Owns weighted breakable power-up drops, proximity collection, full healing, bonus Rage, bomb damage, global reward magnetism, zombie slowing, invulnerability, timed reward multipliers, and effect replication. |
| `src/servercontrollers/ZombieRewardsController.lua` | Centralizes confirmed zombie-death rewards, applies authoritative Lucky Skull doubling, and creates configured XP and permanent-coin drops from killer attribution. |
| `src/servercontrollers/RageController.lua` | Owns the server-timed Rage charge cycle, normal activation validation, charge-preserving bonus activation/extension, death resets, and replication while rejecting Lobby activation. |
| `src/servercontrollers/PlayerStateController.lua` | Owns generic per-player runtime state and replicates requested state updates. |
| `src/servercontrollers/PlayerStatController.lua` | Applies the configured starting pace, composes named player health/speed modifiers, preserves gained health, and enforces the final movement-speed limit. |
| `src/servercontrollers/RollController.lua` | **Archived/dormant:** owns ability rolls, luck chains, rewards, Auto Roll scheduling, and saved preferences. |
| `src/servercontrollers/Roll/RollServerConfig.lua` | **Archived/dormant:** defines server-only luck, cooldown, and clover-chain balance values. |
| `src/servercontrollers/ZombieController.lua` | Runs uncapped game-only, ground-validated player-centered spawning, authoritative simulation, compact replication, area slowdown application, Guardian Halo damage checks, and centralized combat signals. |
| `src/servercontrollers/Zombie/Zombie.lua` | Defines authoritative targeting, area-bounded movement, temporary speed status, invulnerability-aware player damage, attacks, special-behavior dispatch, health, and knockback per zombie. |
| `src/servercontrollers/Zombie/ZombieBehaviors.lua` | Provides definition-selected movement and attack strategies without type checks in core logic. |
| `src/servercontrollers/Zombie/ZombieSpecialBehaviors.lua` | Implements the authoritative Spitter, Charger, Screamer, Tank, Leaper, Shielder, Bomber, Grabber, Summoner, Splitter, Burrower, Frenzy, Medic, Hardened, and Dodger strategies. |
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
| `src/modules/Game/BackpackConfig.lua` | Maps authoritative carried coin totals to authored physical backpack stages and mount offsets. |
| `src/modules/Game/CoinDropConfig.lua` | Defines permanent-coin magnet/pickup timing and client-prediction batching limits from shared run balance. |
| `src/modules/Game/RunProgressionConfig.lua` | Centralizes the faster-opening run XP curve, three XP pickup visual tiers, pickup tuning, baseline ability pool, choice count, and unbounded five-minute horde difficulty steps with sublinear `playerCount ^ 0.8` party scaling. |
| `src/modules/Game/Abilities/AbilityDefinitions.lua` | Defines the current all-but-Divine starter unlock pool, rarity-priced permanent purchases, ten-slot category limits, expandable ability metadata, upgrade costs, per-level stats, milestones, and Rage tuning. |
| `src/modules/Game/Abilities/CrowdWeaponDefinitions.lua` | Centralizes the level, milestone, combat, cap, and unique Rage balance for Aura, Ball, Drill, Mine, and Poison. |
| `src/modules/Game/Stats/PlayerStatConfig.lua` | Defines the shared starting movement speed, base health, and the global final movement-speed limit. |
| `src/modules/Game/Rage/RageConfig.lua` | Defines shared Rage capacity, 30-second charge, 10-second duration, keybind, and request cadence. |
| `src/modules/Game/PowerupConfig.lua` | Defines the seven breakable power-ups, weighted odds, shared pickup presentation, lifetimes, radii, durations, and effect balance. |
| `src/modules/Game/DataTemplate.lua` | Supplies DataService's JSON-compatible persisted player-data defaults. |
| `src/modules/Game/Rolls/RollDefinitions.lua` | Preserves the dormant weighted roll catalog and legacy data keys; still supplies saved-data compatibility and reveal timing. |
| `src/modules/Game/RuntimeState.lua` | Stores generic transient per-player state and change signals. |
| `src/modules/Game/Zombies/ZombieAreas.lua` | Defines uncapped spawn regions, walkable movement bounds, the quick single-zombie opening cadence, later group sizes, and weighted zombie pools. |
| `src/modules/Game/Zombies/ZombieDefinitions.lua` | Defines expandable per-type combat and threat ratings, threat-scaled rewards, map-scale sight, reduced contact reach, high-speed/low-damage horde multipliers, special-ability balance, presentation, and animation configuration. |
| `src/modules/Game/Zombies/ZombieProtocol.lua` | Shares compact movement/special state codes and snapshot timing between server simulation and client rendering. |
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
| `src/UI/App.lua` | Composes the neutral `App` ScreenGui, untouched party Creation Menu, reactive in-match HUD, and retained generic overlays. |
| `src/UI/HUD/RunHUD.lua` | Renders the STUD-styled game HUD with center-left coins, a top-center first-spawn survival timer, animated run XP, abilities, and tooltips. |
| `src/UI/HUD/LevelUpChoices.lua` | Sequentially consumes every authoritative level-up set in a slower, higher-positioned rolling STUD reel that settles compactly with artwork/title-first cards, subdued reward-type footers, layered sound, bursts, and camera/FOV feedback. |
| `src/UI/HUD/GameOver.lua` | Renders the STUD-styled defeated-player run summary, live lobby-return countdown, and Play Again action while surviving teammates continue. |
| `src/UI/UIOrigin.lua` | Mounts the Vide application once into LocalPlayer.PlayerGui. |
| `src/UI/App.story.lua` | Exposes the app component for UI story previews. |
| `src/UI/Classes/Button.lua` | Provides a reusable reactive button with configurable presentation, unified face/text press motion, interaction feedback, and sounds. |
| `src/UI/Classes/Confirmation.lua` | Provides a reusable modal confirmation component. |
| `src/UI/Classes/StudTexture.lua` | Provides the reusable tiled STUD surface layer used across active HUD panels and menus. |
| `src/UI/Effects/HoverExpand.lua` | Provides reusable hover scaling for GuiObjects. |
| `src/UI/Effects/Notification.lua` | Provides a reusable counted attention badge. |
| `src/UI/HUD/CoinsDisplay.lua` | **Archived/dormant:** reusable responsive permanent-currency display. |
| `src/UI/HUD/RunRewardsDisplay.lua` | **Archived/dormant:** pending-reward claim and backpack-to-balance presentation. |
| `src/UI/HUD/AbilityInterface.lua` | Renders the responsive lobby Ability Arsenal, unlocked counts, rarity-priced locked cards, live coin affordability, and permanent run-choice unlock requests. |
| `src/UI/HUD/RageBar.lua` | Renders the compact centered STUD-styled Rage meter directly above the level bar, with live charge/duration progress, reactive Game-session visibility, and keyboard/touch activation. |
| `src/UI/HUD/Notifications.lua` | Renders transient notifications from NotificationManager. |
| `src/UI/HUD/PartyTeleporterMenu.lua` | Renders the responsive leader-only Creation Menu and collapses confirmed or member views to the lock-aware exit control. |
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
