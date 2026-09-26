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
| `src/controllers/CharacterController.lua` | Requests server-authorized character spawning, owns the smooth fixed-heading top-down camera only while the Game map is active, restores lobby camera state, and leaves in-run death/respawn ownership to the run session flow. |
| `src/controllers/GameReadyController.lua` | Mirrors the authoritative in-game ready phase and sends the local player's one-way ready request. |
| `src/controllers/PartyTeleporterController.lua` | Mirrors validated party/setup/loading state, sends leader confirmation and member requests, and presents server messages through the shared notification system. |
| `src/controllers/AbilityController.lua` | Mirrors persistent ability unlocks, sends lobby purchase requests, and dispatches validated weapon/passive presentation events; run loadouts are presented by the progression snapshot. |
| `src/controllers/ClassController.lua` | Mirrors saved class ownership/equipment, opens the lobby Classes menu from its structure prompt or UI, tracks local preview selection, and sends unlock/equip requests. |
| `src/controllers/ClassChangingRoomController.lua` | Clones the Studio-authored room and player avatar into client-local Workspace 3D, frames them with the game camera, previews selected headpieces, and restores the camera on close. |
| `src/controllers/ZombieIndexController.lua` | Mirrors persistent zombie discoveries and kill counts, coordinates the lobby index menu, and sends one-time discovery reward claims. |
| `src/controllers/RunProgressionController.lua` | Mirrors the owning player's run-only level, XP, queued legal choices, and current run ability snapshot, and sends indexed card selections. |
| `src/controllers/RoundController.lua` | Mirrors the party's authoritative round, current-round zombie count, and cooldown-gated majority skip-vote state while sending only the local player's vote intent. |
| `src/controllers/RunSessionController.lua` | Mirrors the authoritative survival-clock/game-over and unanimous replay-vote state with failure feedback. |
| `src/controllers/Ability/ActiveWeaponEffects.lua` | Renders Fireball, Lightning, and latency-corrected Boomerang presentation from authoritative server packets. |
| `src/controllers/Ability/CrowdWeaponEffects.lua` | Renders block-built Aura, Ball, Drill, Mine, and Poison presentation through the shared client render loop. |
| `src/controllers/Ability/AdditionalWeaponEffects.lua` | Renders stud-built Shotgun, Frost Nova, Meteor, Turret, and Vortex effects, including persistent fields and cleanup, through the shared client render loop. |
| `src/controllers/Ability/OrbitingSwordsView.lua` | Renders smoothly reconciled outward-facing spectral sword orbits, Rage blades, trails, and correctly aligned released-blade return flights. |
| `src/controllers/Ability/PassiveEffectsView.lua` | Renders lightweight Blast, Burn, Thorns, and Critical feedback from authoritative server packets. |
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
| `src/controllers/Zombie/ZombieView.lua` | Owns one client-rendered zombie model cloned from its exact authored type template, procedural special telegraphs, interpolation, health/hit feedback, visibility, and cosmetic death ragdolls. |
| `src/servercontrollers/ChatCommandController.lua` | Registers extensible developer-only chat commands, resolves player selectors, and executes built-in utility and confirmed data-reset actions. |
| `src/servercontrollers/ChatCommand/ChatCommandConfig.lua` | Configures command cooldowns and server-only developer access. |
| `src/servercontrollers/ServerContext.lua` | Classifies normal joins as Lobby, accepts Roblox-verified reserved-server party data in live servers, and owns the strictly Studio-only local Game-session promotion. |
| `src/servercontrollers/MapController.lua` | Keeps only the current session's Lobby or Game map in Workspace, exposes the active map and its inspected spawn, and supports the guarded Studio destination switch. |
| `src/servercontrollers/CharacterController.lua` | Serializes and authorizes character loads, rate-limits client spawn requests, and places characters at the current session map's spawn. |
| `src/servercontrollers/PartyTeleportService.lua` | Provides validated same-place reserved-server party travel, Studio destination simulation, and individual post-run returns to a normal lobby server. |
| `src/servercontrollers/PartyTeleporterController.lua` | Owns closed-elevator entry/exit, explicitly confirmed leader setup with timeout ejection, party settings/countdowns, Studio loading/completion tracking, and whole-party ejection on teleport failure. |
| `src/servercontrollers/GameReadyController.lua` | Gates combat in Game sessions until the authoritative destination roster is unanimously ready or the 30-second fallback expires. |
| `src/servercontrollers/AbilityController.lua` | Owns server-validated coin purchases and persistent unlocks plus transient game-run loadouts/levels, including fresh same-server replay loadouts, active/passive refreshes, ability-specific Rage behavior, and authoritative damage. |
| `src/servercontrollers/ClassController.lua` | Owns saved class purchases/equipment, class starting abilities and combat/stat perks, and block-built character headpieces cloned from `Assets.Models.Classes`. |
| `src/servercontrollers/RunProgressionController.lua` | Owns and resets per-player run XP/levels, queues every earned level-up, rolls three distinct legal unlocked ability choices, and validates one indexed selection at a time. |
| `src/servercontrollers/RoundController.lua` | Owns shared party round progression, cooldown-gated strict-majority skip voting, replay resets to round one, current-round completion, and synchronized round snapshots without removing zombies from skipped rounds. |
| `src/servercontrollers/RunSessionController.lua` | Starts survival clocks, owns final run statistics/death cleanup, delays each lobby return independently, and performs same-server resets only after every connected party member votes to replay. |
| `src/servercontrollers/BreakableController.lua` | Spawns weighted authored props across the active Game map, owns their health and respawns, produces hit/fragment feedback, and releases one authoritative power-up from every destroyed prop. |
| `src/servercontrollers/Breakable/BreakableConfig.lua` | Defines server-only breakable density, spacing, durability, respawn, feedback timing, authored model weights, and sound choices. |
| `src/servercontrollers/Ability/ActiveWeapons.lua` | Runs the shared authoritative Fireball, Lightning, and Boomerang scheduler, projectile hits, status ticks, area caps, Rage variants, and cleanup only in Game sessions. |
| `src/servercontrollers/Ability/CrowdWeapons.lua` | Runs one authoritative scheduler for Aura ticks/pulses, Ball ricochets, directional piercing Drills, grounded Mines, persistent Poison fields, Rage variants, caps, and cleanup. |
| `src/servercontrollers/Ability/AdditionalWeapons.lua` | Runs one authoritative scheduler for Shotgun, Frost Nova, Meteor, Turret, and Vortex, including their milestones, Rage variants, caps, and cleanup. |
| `src/servercontrollers/Ability/CombatTargets.lua` | Keeps automatic targeting zombie-only, merges zombies and breakables for physical/AOE damage queries, applies direct-hit passive hooks, and dispatches authoritative damage to the owning controller. |
| `src/servercontrollers/Ability/OrbitingSwords.lua` | Simulates authoritative sword combat in Game sessions while preserving non-damaging orbit presentation in Lobby sessions. |
| `src/servercontrollers/Ability/PassiveEffects.lua` | Owns Heart, Boots, Blast, Burn, Thorns, Giant, Greed, Critical, Adrenaline, and Impact effects, milestone behavior, status cleanup, and authoritative passive combat reactions. |
| `src/servercontrollers/CollisionController.lua` | Assigns avatar parts to a generic non-colliding player-character collision group. |
| `src/servercontrollers/CoinsController.lua` | Validates and owns persistent server-authoritative coin balance operations. |
| `src/servercontrollers/BackpackController.lua` | Equips authored physical backpack stages and advances their fullness from authoritative run coin collections. |
| `src/servercontrollers/RunRewardsController.lua` | **Archived/dormant:** holds unbanked run earnings, safe-area membership, return-to-base, and claim behavior. |
| `src/servercontrollers/CoinDropController.lua` | Owns game-only coin spread, cleanup, merging, ownership-aware proximity claims, Hoarder stealing/release support, Scrap Magnet collection, direct persistent awards, and carried-backpack progression events. |
| `src/servercontrollers/XPDropController.lua` | Owns XP crystal values, tier-aware visual scale/height, lifetime, ownership, Hoarder stealing/release support, normal/forced magnet movement, single-collector arbitration, and run-XP grants. |
| `src/servercontrollers/PowerupDropController.lua` | Owns weighted breakable power-up drops, proximity collection, full healing, bonus Rage, bomb damage, global reward magnetism, zombie slowing, invulnerability, timed reward multipliers, and effect replication. |
| `src/servercontrollers/ZombieRewardsController.lua` | Centralizes confirmed zombie-death rewards, applies authoritative Lucky Skull doubling, and creates configured XP and permanent-coin drops from killer attribution. |
| `src/servercontrollers/ZombieIndexController.lua` | Records killer-attributed zombie discoveries and kill counts in persistent data and validates each fixed one-time coin reward claim. |
| `src/servercontrollers/RageController.lua` | Owns the server-timed Rage charge cycle, normal activation validation, charge-preserving bonus activation/extension, death resets, and replication while rejecting Lobby activation. |
| `src/servercontrollers/PlayerStateController.lua` | Owns generic per-player runtime state and replicates requested state updates. |
| `src/servercontrollers/PlayerStatController.lua` | Applies the configured starting pace, composes named player health/speed modifiers, preserves gained health, and enforces the final movement-speed limit. |
| `src/servercontrollers/RollController.lua` | **Archived/dormant:** owns ability rolls, luck chains, rewards, Auto Roll scheduling, and saved preferences. |
| `src/servercontrollers/Roll/RollServerConfig.lua` | **Archived/dormant:** defines server-only luck, cooldown, and clover-chain balance values. |
| `src/servercontrollers/ZombieController.lua` | Spawns finite round-assigned groups around players on the authored Baseplate arena, clears the horde for shared replays, preserves skipped-round zombies, runs authoritative simulation and status effects, and provides compact replication plus centralized combat signals. |
| `src/servercontrollers/Zombie/Zombie.lua` | Defines authoritative targeting, immutable origin-round ownership, arena-bounded movement, temporary speed and support buffs, invulnerability-aware player damage, attacks, special-behavior dispatch, health, and knockback per zombie. |
| `src/servercontrollers/Zombie/ZombieBehaviors.lua` | Provides definition-selected movement and attack strategies without type checks in core logic. |
| `src/servercontrollers/Zombie/ZombieSpecialBehaviors.lua` | Implements all authoritative zombie specials, including terrain hazards, support auras, corpse growth, delayed hexes, tethers, frost cones, reward theft, brood hatching, death buffs, observation-sensitive stalking, and momentum. |
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
| `src/modules/Game/GameReadyConfig.lua` | Defines the shared in-game ready-phase fallback duration. |
| `src/modules/Game/BackpackConfig.lua` | Maps authoritative carried coin totals to authored physical backpack stages and mount offsets. |
| `src/modules/Game/CoinDropConfig.lua` | Defines permanent-coin magnet/pickup timing and client-prediction batching limits from shared run balance. |
| `src/modules/Game/RunProgressionConfig.lua` | Centralizes the run XP curve, pickup tuning, ability-choice rules, finite round group growth, and sublinear `playerCount ^ 0.8` party scaling. |
| `src/modules/Game/Abilities/AbilityDefinitions.lua` | Defines the current all-but-Divine starter unlock pool, rarity-priced permanent purchases, five active/five passive per-player limits, expandable ability metadata, upgrade costs, per-level stats, milestones, and Rage tuning. |
| `src/modules/Game/Abilities/AdditionalAbilityDefinitions.lua` | Defines Shotgun, Frost Nova, Meteor, Turret, Vortex, Giant, Greed, Critical, Adrenaline, and Impact level stats, milestone perks, and Rage tuning. |
| `src/modules/Game/Classes/ClassDefinitions.lua` | Defines the extensible 12-class catalog, costs, starting abilities, descriptions, prerequisites, colors, and perk values. |
| `src/modules/Game/Classes/ClassAccessoryFit.lua` | Fits authored block headpieces to the avatar's actual head size for both equipped characters and changing-room previews. |
| `src/modules/Game/Abilities/CrowdWeaponDefinitions.lua` | Centralizes the level, milestone, combat, cap, and unique Rage balance for Aura, Ball, Drill, Mine, and Poison. |
| `src/modules/Game/Stats/PlayerStatConfig.lua` | Defines the shared starting movement speed, base health, and the global final movement-speed limit. |
| `src/modules/Game/Rage/RageConfig.lua` | Defines shared Rage capacity, 30-second charge, 10-second duration, keybind, and request cadence. |
| `src/modules/Game/PowerupConfig.lua` | Defines the seven breakable power-ups, weighted odds, shared pickup presentation, lifetimes, radii, durations, and effect balance. |
| `src/modules/Game/DataTemplate.lua` | Supplies DataService's JSON-compatible persisted player-data defaults. |
| `src/modules/Game/Rolls/RollDefinitions.lua` | Preserves the dormant weighted roll catalog and legacy data keys; still supplies saved-data compatibility and reveal timing. |
| `src/modules/Game/RuntimeState.lua` | Stores generic transient per-player state and change signals. |
| `src/modules/Game/Zombies/ZombieDefinitions.lua` | Defines per-type combat, rewards, exact authored model names, elapsed-time unlock/weight growth, special-ability balance, effects, and animation configuration. |
| `src/modules/Game/Zombies/ZombieIndexConfig.lua` | Defines the ordered zombie encyclopedia, player-facing behavior descriptions, discovery rewards, and shared derived display stats. |
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
| `src/UI/App.lua` | Composes the `App` ScreenGui, lobby Ability/Classes menus, party Creation Menu, reactive in-match HUD, and retained generic overlays. |
| `src/UI/HUD/RunHUD.lua` | Renders the responsive, safe-area-aware STUD game HUD with coins, ready and round/skip-vote status, survival time, animated run XP, and compact five-active/five-passive player-specific slot grids. |
| `src/UI/HUD/LevelUpChoices.lua` | Sequentially consumes every authoritative level-up set in a slower, higher-positioned rolling STUD reel that settles compactly with artwork/title-first cards, subdued reward-type footers, layered sound, bursts, and camera/FOV feedback. |
| `src/UI/HUD/GameOver.lua` | Renders the STUD-styled defeated-player run summary, live lobby-return countdown, shared round state, and unanimous Play Again vote while surviving teammates continue. |
| `src/UI/UIOrigin.lua` | Mounts the Vide application once into LocalPlayer.PlayerGui. |
| `src/UI/App.story.lua` | Exposes the app component for UI story previews. |
| `src/UI/Classes/Button.lua` | Provides a reusable reactive button with configurable presentation, unified face/text press motion, interaction feedback, and sounds. |
| `src/UI/Classes/Confirmation.lua` | Provides a reusable modal confirmation component. |
| `src/UI/Classes/StudTexture.lua` | Provides the reusable tiled STUD surface layer used across active HUD panels and menus. |
| `src/UI/Effects/HoverExpand.lua` | Provides reusable hover scaling for GuiObjects. |
| `src/UI/Effects/Notification.lua` | Provides a reusable counted attention badge. |
| `src/UI/HUD/CoinsDisplay.lua` | **Archived/dormant:** reusable responsive permanent-currency display. |
| `src/UI/HUD/RunRewardsDisplay.lua` | **Archived/dormant:** pending-reward claim and backpack-to-balance presentation. |
| `src/UI/HUD/AbilityInterface.lua` | Renders the responsive lobby Ability Arsenal, its shared bottom launcher dock, unlocked counts, rarity-priced locked cards, live coin affordability, and permanent run-choice unlock requests. |
| `src/UI/HUD/ClassInterface.lua` | Renders the responsive Classes launcher plus the left-side selector and right-side description, ability, perks, and unlock/equip action over the Workspace changing-room scene. |
| `src/UI/HUD/ZombieIndex.lua` | Renders the responsive lobby index launcher and zombie collection with hidden undiscovered entries, kill counts, behavior details, portraits, and discovery reward actions. |
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

## Local developer tools

| Path | Responsibility |
| --- | --- |
| `tools/model-preview/` | Validates versioned Part/Model construction JSON; exports the same data as Luau; produces deterministic headless Blender angle PNGs, annotated contact sheets, and complete hierarchy/property reports. Includes stdin/file iteration, camera/lighting settings, and focused tests. Offline material/stud shading approximates Roblox; no Studio scripts or runtime dependencies are created. See `tools/model-preview/README.md`. |

## Package compatibility

| Path | Responsibility |
| --- | --- |
| `src/compatibility/TopbarPlus.lua` | Exposes the installed TopbarPlus package at the path expected by Satchel. |
