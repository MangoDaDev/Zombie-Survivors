# Codebase Index

Quick reference for the reusable first-party Luau foundation. Generated Wally dependencies in `Packages` and `ServerPackages` are intentionally excluded.

## Runtime bootstraps

| Path | Responsibility |
| --- | --- |
| `src/client/init.client.lua` | Initializes client DataService, active foundation controllers (including party teleporter networking and presentation), the reduced UI root, and character lifecycle dispatch; simulator controllers are deliberately unregistered. |
| `src/server/init.server.lua` | Resolves lobby/game session context before initializing DataService, maps, active foundation controllers, and player/character lifecycle dispatch; character placement is ordered ahead of yield-prone character hooks, and simulator controllers are deliberately unregistered. |
| `src/loading/init.client.lua` | Shows startup progress, waits for the app and character controller, requests the initial character, and fades away. |

## Controllers

| Path | Responsibility |
| --- | --- |
| `src/controllers/ChatCommandController.lua` | Displays server-authorized command responses in modern chat with a notification fallback. |
| `src/controllers/AnalyticsController.lua` | Reports successful lobby shop opens and item selections to the server-owned funnel tracker. |
| `src/controllers/CharacterController.lua` | Requests server-authorized character spawning, owns the smooth fixed-heading top-down camera and character-centered 3D-audio listener only while the Game map is active, shifts choice-time framing slightly ahead so the player sits lower on-screen, restores lobby camera/audio state, and leaves in-run death/respawn ownership to the run session flow. |
| `src/controllers/GameReadyController.lua` | Mirrors the authoritative in-game ready phase and sends the local player's one-way ready request. |
| `src/controllers/PartyTeleporterController.lua` | Mirrors validated party/setup/loading and pending-join state, sends leader confirmation and join approvals, and presents server messages through the shared notification system. |
| `src/controllers/AbilityController.lua` | Mirrors persistent ability unlocks, opens the Ability shop from its 3D lobby prompt, reports successful shop-open/selection interactions, sends lobby purchase requests, and dispatches validated weapon/passive presentation events. |
| `src/controllers/ClassController.lua` | Mirrors saved class ownership/equipment, opens the lobby Classes menu from its nested 3D booth prompt, tracks and analytically reports local preview selection, sends unlock/equip requests, and presents authoritative class kill-proc effects through the shared stud VFX. |
| `src/controllers/ClassesAbilitiesTutorialController.lua` | Mirrors the server-owned one-time returning-player shop tutorial state used by the Classes flow and guidance overlay. |
| `src/controllers/ClassChangingRoomController.lua` | Clones the oversized Studio-authored room and one frozen player avatar into client-local Workspace 3D, swaps explicitly attached class accessories without changing pose, frames body-only bounds, and restores the camera on close. |
| `src/controllers/LobbyPlayerBillboardController.lua` | Mounts and cleans up lobby-only Vide overhead cards for every replicated player, driven by validated public survival/class snapshots. |
| `src/controllers/ZombieIndexController.lua` | Mirrors persistent zombie discoveries and kill counts, coordinates the lobby index menu, and sends one-time discovery reward claims. |
| `src/controllers/RunProgressionController.lua` | Mirrors the owning player's run-only level, XP, queued legal choices, and current run ability snapshot, and sends indexed card selections. |
| `src/controllers/RoundController.lua` | Mirrors the party's authoritative round, current-round zombie count, staged boss-warning announcement, and cooldown-gated majority skip-vote state while sending only the local player's vote intent. |
| `src/controllers/RunSessionController.lua` | Mirrors shared-run/downed/game-over state, selects and cycles living spectate targets, and coordinates unanimous replay votes with failure feedback. |
| `src/controllers/Ability/ActiveWeaponEffects.lua` | Renders Fireball, Lightning, and latency-corrected Boomerang presentation from authoritative server packets. |
| `src/controllers/Ability/CrowdWeaponEffects.lua` | Renders Aura, Ball, Drill, Mine, and Poison presentation through the shared client render loop, including Aura's filled translucent color-coded damage zones, stronger outlines, and pulses. |
| `src/controllers/Ability/AdditionalWeaponEffects.lua` | Renders stud-built Shotgun, Frost Nova, Meteor, Turret, and Vortex effects, including persistent fields and cleanup, through the shared client render loop. |
| `src/controllers/Ability/ExpandedWeaponEffects.lua` | Renders stud-built Crowbar, Crossfire, Buzzsaw, Crusher, and Laser Sweep models, telegraphs, impacts, persistent effects, sounds, and cleanup through the shared client render loop. |
| `src/controllers/Ability/OrbitingSwordsView.lua` | Renders smoothly reconciled outward-facing spectral sword orbits, Rage blades, trails, and correctly aligned released-blade return flights. |
| `src/controllers/Ability/PassiveEffectsView.lua` | Renders lightweight Blast, Burn, Thorns, Critical, Armor, Magnet, Executioner, and Overcharge feedback from authoritative server packets. |
| `src/controllers/CoinsController.lua` | Exposes the replicated, read-only local coin balance and its change signal. |
| `src/controllers/MonetizationController.lua` | Caches live Marketplace prices/icons, mirrors verified Gamepass and run-boost state, coordinates the gold shop, starts only server-authorized purchase prompts, and emits confirmation-only purchase feedback events. |
| `src/controllers/RunRewardsController.lua` | **Archived/dormant:** mirrors server-held run earnings and safe-area membership, and requests an authoritative return-to-base claim. |
| `src/controllers/CoinDropController.lua` | Renders the party's shared server-authored world coin drops with frame-local backpack destinations and deduplicated billboard sizing, scatter/merge/magnet presentation, latency-hidden first-claim prediction, and batched camera-visibility reports without awarding currency locally. |
| `src/controllers/XPDropController.lua` | Clones the party's shared server-authored XP drops and renders large blue/green/pink-purple tier styling, glow/highlight, scatter, idle, winning collection, cleanup states, and batched camera-visibility reports. |
| `src/controllers/PowerupDropController.lua` | Renders authored breakable power-ups, colored reveal/activation bursts, collection movement, local activation notifications/sounds, and visible timed Stopwatch, Guardian Halo, and Lucky Skull auras. |
| `src/controllers/RageController.lua` | Validates authoritative Rage snapshots and owns run-only activation input and character Rage VFX, including Studio session promotion; Lobby presentation stays dormant. |
| `src/controllers/PlayerStateController.lua` | Receives generic server runtime-state snapshots and updates. |
| `src/controllers/RollController.lua` | **Archived/dormant:** restores saved roll preferences and validates authoritative item/clover, Auto Roll, and completion events. |
| `src/controllers/ZombieController.lua` | Receives compact zombie snapshots/damage events plus dealer-only damage-number events, plays rate-limited positional hit/death audio, exposes dynamic milestone-boss health presentation state, renders boss entrances, charge lanes, additional plague-volley warnings, ability bursts, and death shockwaves from local stud VFX, and drives the single client render loop. |
| `src/controllers/Zombie/ProceduralAnimator.lua` | Produces type-specific procedural movement and attack poses without animation tracks. |
| `src/controllers/Zombie/ZombieView.lua` | Owns one client-rendered zombie model cloned from its exact authored type template, procedural special telegraphs with authoritative per-cast boss warning radii, interpolation, health/hit feedback, independent stud-scaled floating damage numbers, visibility, and cosmetic death ragdolls. |
| `src/servercontrollers/ChatCommandController.lua` | Registers extensible developer-only chat commands, resolves player selectors, and executes built-in utility and confirmed data-reset actions. |
| `src/servercontrollers/AnalyticsController.lua` | Centralizes ordered AnalyticsService funnel logging, reusable session IDs/custom fields, cross-server onboarding progress, coin-shop and paid-commerce checkout conversion, gameplay choices, lifetime milestones, and replay flow. |
| `src/servercontrollers/ChatCommand/ChatCommandConfig.lua` | Configures command cooldowns, bounded gameplay-control inputs, and server-only developer access. |
| `src/servercontrollers/AdminGameplayCommandController.lua` | Registers bounded developer-only commands for inspecting and controlling run levels/XP, Coins, rounds, exact run abilities, Rage, zombie spawning/cleanup, and power-up spawning. |
| `src/servercontrollers/ServerContext.lua` | Classifies normal joins as Lobby, accepts Roblox-verified reserved-server party data in live servers, and owns the strictly Studio-only local Game-session promotion. |
| `src/servercontrollers/MapController.lua` | Keeps only the current session's Lobby or Game map in Workspace, exposes the active map and its inspected spawn, and supports the guarded Studio destination switch. |
| `src/servercontrollers/CharacterController.lua` | Serializes and authorizes character loads, rate-limits client spawn requests, and places characters at the current session map's spawn. |
| `src/servercontrollers/PartyTeleportService.lua` | Provides validated same-place reserved-server party travel, Studio destination simulation, and individual post-run returns to a normal lobby server. |
| `src/servercontrollers/PartyTeleporterController.lua` | Owns closed-elevator entry/exit, leader-approved join requests, explicitly confirmed setup with timeout ejection, party settings/countdowns, Studio loading/completion tracking, and whole-party ejection on teleport failure. |
| `src/servercontrollers/GameReadyController.lua` | Gates combat until the destination roster is ready or the fallback expires, then starts onboarding and gameplay-loop funnel boundaries. |
| `src/servercontrollers/AbilityController.lua` | Owns server-validated coin purchases and unlocks with checkout analytics plus transient run loadouts/levels, replay cleanup, ability refreshes, Rage behavior, and authoritative damage. |
| `src/servercontrollers/ClassController.lua` | Owns saved class purchases/equipment with checkout analytics, starting abilities, combat/stat perks, and intact native Accessory/Hat class gear. |
| `src/servercontrollers/ClassesAbilitiesTutorialController.lua` | Snapshots post-first-round lobby eligibility at join, persists completion only after the free Blade Dancer claim, and replicates the active tutorial state. |
| `src/servercontrollers/SurvivalStatsController.lua` | Persists each player's server-awarded highest completed round, records progression-funnel milestones, and exposes each lobby player's public best and equipped class. |
| `src/servercontrollers/LeaderstatsController.lua` | Mirrors authoritative Coins and highest-round data into display-only Roblox player-list leaderstats. |
| `src/servercontrollers/RunProgressionController.lua` | Owns per-player run XP/levels, legal ability choices with the established upgrade preference and passive catch-up weighting when fewer passives than actives are equipped, and offered/selected/applied upgrade funnel boundaries. |
| `src/servercontrollers/RoundController.lua` | Owns shared-party rounds, boss phases, skip voting, replay resets, completion, synchronized snapshots, and first-round analytics completion. |
| `src/servercontrollers/RunSessionController.lua` | Owns shared-team survival clocks, downed/spectate state, fifth-wave free respawns, self/team revives, team-wipe-only defeat, final statistics, lobby returns, and unanimous same-server replay resets. |
| `src/servercontrollers/BreakableController.lua` | Spawns weighted authored props across the active Game map, owns their health and respawns, produces hit/fragment feedback, and releases one authoritative power-up from every destroyed prop. |
| `src/servercontrollers/Breakable/BreakableConfig.lua` | Defines server-only breakable density, spacing, durability, respawn, feedback timing, authored model weights, and sound choices. |
| `src/servercontrollers/Ability/ActiveWeapons.lua` | Runs the shared authoritative Fireball, Lightning, and Boomerang scheduler, projectile hits, status ticks, area caps, Rage variants, and cleanup only in Game sessions. |
| `src/servercontrollers/Ability/CrowdWeapons.lua` | Runs one authoritative scheduler for zoned Aura ticks/pulses, Ball ricochets, directional piercing Drills, grounded Mines, persistent Poison fields, Rage variants, caps, and cleanup. |
| `src/servercontrollers/Ability/AdditionalWeapons.lua` | Runs one authoritative scheduler for Shotgun, Frost Nova, Meteor, Turret, and Vortex, including their milestones, Rage variants, caps, and cleanup. |
| `src/servercontrollers/Ability/ExpandedWeapons.lua` | Runs the authoritative Crowbar, Crossfire, Buzzsaw, Crusher, and Laser Sweep scheduler, including geometry checks, persistent hazards, milestones, Rage variants, Overcharge repeats, caps, and cleanup. |
| `src/servercontrollers/Ability/CombatTargets.lua` | Keeps automatic targeting zombie-only, merges zombies and breakables for physical/AOE damage queries, applies direct-hit passive hooks, and dispatches authoritative damage to the owning controller. |
| `src/servercontrollers/Ability/OrbitingSwords.lua` | Simulates authoritative sword combat in Game sessions while preserving non-damaging orbit presentation in Lobby sessions. |
| `src/servercontrollers/Ability/PassiveEffects.lua` | Owns Heart, Boots, Blast, Burn, Thorns, Giant, Greed, Critical, Adrenaline, Impact, Armor, Magnet, Executioner, Training Manual, and Overcharge effects, milestones, status cleanup, reward modifiers, and authoritative combat reactions. |
| `src/servercontrollers/CollisionController.lua` | Assigns avatar parts to a generic non-colliding player-character collision group. |
| `src/servercontrollers/CoinsController.lua` | Validates and owns persistent server-authoritative coin balance operations. |
| `src/servercontrollers/MonetizationController.lua` | Owns the single ProcessReceipt pipeline, durable receipt credits, contextual reservations, Gamepass verification, premium grants, run boosts, coin multipliers, and paid slot limits. |
| `src/servercontrollers/BackpackController.lua` | Equips authored physical backpack stages and advances their fullness from authoritative run coin collections. |
| `src/servercontrollers/RunRewardsController.lua` | **Archived/dormant:** holds unbanked run earnings, safe-area membership, return-to-base, and claim behavior. |
| `src/servercontrollers/CoinDropController.lua` | Owns game-only coin spread, run-boundary clearing, safe pre-claim merging, shared first-come proximity claims, all-player offscreen lifetime acceleration, Hoarder stealing/release support, Scrap Magnet collection, winner-only persistent awards, and carried-backpack progression events. |
| `src/servercontrollers/XPDropController.lua` | Owns shared XP crystal values, run-boundary clearing, tier-aware visual scale/height, all-player offscreen lifetime acceleration, first-come collection state, Hoarder stealing/release support, normal/forced magnet movement, and the collector/teammate run-XP split. |
| `src/servercontrollers/PowerupDropController.lua` | Owns weighted and explicitly selected power-up drops, run-boundary clearing, proximity collection, full healing, bonus Rage, bomb damage, global reward magnetism, zombie slowing, invulnerability, timed reward multipliers, and effect replication. |
| `src/servercontrollers/ZombieRewardsController.lua` | Centralizes confirmed zombie-death rewards, applies authoritative Lucky Skull doubling, splits configured boss XP into multi-crystal bursts, creates permanent-coin drops from killer attribution, and guarantees every milestone boss's special drop. |
| `src/servercontrollers/ZombieIndexController.lua` | Records killer-attributed zombie discoveries and kill counts in persistent data and validates each fixed one-time coin reward claim. |
| `src/servercontrollers/RageController.lua` | Owns the server-timed Rage charge cycle, normal activation validation, charge-preserving bonus activation/extension, death resets, and replication while rejecting Lobby activation. |
| `src/servercontrollers/PlayerStateController.lua` | Owns generic per-player runtime state and replicates requested state updates. |
| `src/servercontrollers/PlayerStatController.lua` | Applies the configured starting pace, owns slower natural health regeneration, composes named player health/speed modifiers, preserves gained health, and enforces the final movement-speed limit. |
| `src/servercontrollers/RollController.lua` | **Archived/dormant:** owns ability rolls, luck chains, rewards, Auto Roll scheduling, and saved preferences. |
| `src/servercontrollers/Roll/RollServerConfig.lua` | **Archived/dormant:** defines server-only luck, cooldown, and clover-chain balance values. |
| `src/servercontrollers/ZombieController.lua` | Spawns foot-grounded finite round-assigned groups plus exact bounded developer-selected groups, milestone boss guard rings, reserved eruption locations, and per-boss capped summons; snapshots modest living-player boss health scaling at spawn; owns damaging/slowing plague hazards, full cleanup, boss-death arena clears, pending-attack cleanup, authoritative simulation/status effects, compact replication (including dealer-only exact damage feedback), and centralized combat signals. |
| `src/servercontrollers/Zombie/Zombie.lua` | Defines authoritative targeting, immutable origin-round ownership, arena-bounded movement, temporary speed and support buffs, invulnerability-aware player damage, attacks, special-behavior dispatch, health, and knockback per zombie. |
| `src/servercontrollers/Zombie/ZombieBehaviors.lua` | Provides definition-selected movement and attack strategies without type checks in core logic. |
| `src/servercontrollers/Zombie/ZombieSpecialBehaviors.lua` | Implements all authoritative zombie specials, including shared milestone-boss summon/enrage timers, floor-grounded slams, plague-pool volleys, chained burrow ambushes, swept lane charges and close-range stomps, shared death clear, terrain hazards, support auras, corpse growth, delayed hexes, tethers, frost cones, reward theft, brood hatching, death buffs, observation-sensitive stalking, and momentum. |
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
| `src/modules/Game/MonetizationConfig.lua` | Centralizes every Developer Product/Gamepass/standalone Image ID, shop ordering, product copy, coin-pack value, recommended price, run multiplier, wipe timing, and paid-slot setting. |
| `src/modules/Game/AnalyticsConfig.lua` | Defines stable versioned funnel names, ordered step names, onboarding persistence metadata, and lifetime-round milestone thresholds. |
| `src/modules/Game/PartyTeleporterConfig.lua` | Defines party capacity, setup/countdown timing, zone cadence, teleport watchdog, Studio loading delay, and world-display limits. |
| `src/modules/Game/GameReadyConfig.lua` | Defines the shared in-game ready-phase fallback duration. |
| `src/modules/Game/BackpackConfig.lua` | Maps authoritative carried coin totals to authored physical backpack stages and mount offsets. |
| `src/modules/Game/CoinDropConfig.lua` | Defines permanent-coin magnet/pickup timing, offscreen visibility cadence, and client-prediction batching limits from shared run balance. |
| `src/modules/Game/RunProgressionConfig.lua` | Centralizes the run XP curve, shared first-come pickup rules, all-player offscreen lifetime acceleration, XP teammate-share percentage, pickup tuning, upgrade-focused ability-choice and passive catch-up weights, gently bounded full-run population/reinforcement scaling, boss milestones at rounds 15/30/45/60 with buildup and entrance timing, capped boss health scaling per extra player, gradual strong-archetype weighting, and sublinear `playerCount ^ 0.8` party scaling. |
| `src/modules/Game/SurvivalStatsConfig.lua` | Defines the persistent lifetime rounds-survived data key and default. |
| `src/modules/Game/ClassesAbilitiesTutorialConfig.lua` | Defines the persistent completion key and predetermined Blade Dancer tutorial reward. |
| `src/modules/Game/Abilities/AbilityDefinitions.lua` | Defines the starter unlock pool (including Orbiting Swords), authored permanent-unlock prices with a rarity fallback, five free plus one purchasable active/passive slot per player, expandable ability metadata, upgrade costs, per-level stats, milestones, and Rage tuning. |
| `src/modules/Game/Abilities/AbilityLevelScaling.lua` | Defines distinct shared weapon/passive effectiveness curves, compressing weapons into 25 levels while preserving their level-one baselines and former level-50 continuous-stat totals. |
| `src/modules/Game/Abilities/AdditionalAbilityDefinitions.lua` | Defines Shotgun, Frost Nova, Meteor, Turret, Vortex, Giant, Greed, Critical, Adrenaline, and Impact level stats, milestone perks, and Rage tuning. |
| `src/modules/Game/Abilities/ExpandedAbilityDefinitions.lua` | Defines Crowbar, Crossfire, Buzzsaw, Crusher, Laser Sweep, Armor, Magnet, Executioner, Training Manual, and Overcharge level stats, upgrade milestones, descriptions, and Rage tuning. |
| `src/modules/Game/Classes/ClassDefinitions.lua` | Defines the extensible 17-class catalog, costs, starting abilities, descriptions, prerequisites, colors, perk values, and native same-name Accessory/Hat contract. |
| `src/modules/Game/Abilities/CrowdWeaponDefinitions.lua` | Centralizes level, milestone, combat, zoned Aura growth, cap, and unique Rage balance for Aura, Ball, Drill, Mine, and Poison. |
| `src/modules/Game/Stats/PlayerStatConfig.lua` | Defines shared base health, natural regeneration, starting movement speed, and the global final movement-speed limit. |
| `src/modules/Game/Rage/RageConfig.lua` | Defines shared Rage capacity, 30-second charge, 10-second duration, keybind, and request cadence. |
| `src/modules/Game/PowerupConfig.lua` | Defines the seven breakable power-ups, weighted odds, shared pickup presentation, lifetimes, radii, durations, and effect balance. |
| `src/modules/Game/DataTemplate.lua` | Supplies DataService's JSON-compatible persisted player-data defaults. |
| `src/modules/Game/Rolls/RollDefinitions.lua` | Preserves the dormant weighted roll catalog and legacy data keys; still supplies saved-data compatibility and reveal timing. |
| `src/modules/Game/RuntimeState.lua` | Stores generic transient per-player state and change signals. |
| `src/modules/Game/Zombies/ZombieDefinitions.lua` | Defines per-type combat, rewards, exact authored model names, milestone-boss identity/scaling, elapsed-time unlock/weight growth, special-ability balance, effects, and animation configuration. |
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
| `src/UI/App.lua` | Composes the `App` ScreenGui, groups ordinary lobby/in-match UI behind the downed-spectator visibility gate, and keeps the spectate and game-over overlays independently visible. |
| `src/UI/HUD/RunHUD.lua` | Renders the responsive STUD game HUD with coin-shop routing, contextual run/team offers, ready/round/XP state, and player-specific five-free/six-owned slot grids whose paid slots use the native ability-card treatment. |
| `src/UI/HUD/MonetizationShop.lua` | Renders the responsive navy-and-gold one-scroll product catalog with category jump controls, prominent artwork, live Robux prices, ownership state, and reusable Marketplace purchase routes. |
| `src/UI/HUD/PurchaseCelebration.lua` | Presents the shared animated success banner and reward audio only after a Developer Product is applied or prompted Gamepass ownership is verified. |
| `src/UI/HUD/DownedOverlay.lua` | Extends the death flow with a low-profile spectate/action dock, teammate cycling, fifth-wave free-respawn messaging, the team-wipe grace countdown, and contextual self/team revive offers. |
| `src/UI/HUD/OffscreenPlayerIndicators.lua` | Renders safe-area-aware in-run arrows with Roblox headshots for living teammates outside the current camera viewport. |
| `src/UI/World/PlayerHealthBars.lua` | Renders one stud-scaled in-run overhead health bar for every replicated player, with transparent empty space, scaled outlines, centered remaining health, animated fill, low-health colors, and join/respawn/streaming cleanup. |
| `src/UI/HUD/BossHealthBar.lua` | Renders the responsive top-center health bar with the active milestone boss's name, color, fight hint, and authoritative current/maximum health. |
| `src/UI/HUD/BossWarning.lua` | Renders the responsive warning, guard-wave, and ground-breach announcement banner before each milestone boss becomes active. |
| `src/UI/HUD/LevelUpChoices.lua` | Sequentially consumes every authoritative level-up set in a rolling STUD reel, exposes the server-reserved one-roll-only Take All action, and advances or closes when its confirmed receipt replaces the active set. |
| `src/UI/HUD/GameOver.lua` | Renders the STUD-styled defeated-player run summary, live lobby-return countdown, shared round state, and unanimous Play Again vote while surviving teammates continue. |
| `src/UI/UIOrigin.lua` | Mounts the Vide application once into LocalPlayer.PlayerGui and suppresses Roblox's screen health display in favor of world bars. |
| `src/UI/App.story.lua` | Exposes the app component for UI story previews. |
| `src/UI/World/LobbyPlayerBillboard.lua` | Renders the Vide-backed overhead rounds badge and equipped-class label used only while the Lobby map is active. |
| `src/UI/Classes/Button.lua` | Provides a reusable reactive button with configurable presentation, optional reactive left iconography, unified face/text press motion, interaction feedback, and sounds. |
| `src/UI/Classes/Confirmation.lua` | Provides a reusable modal confirmation component. |
| `src/UI/Classes/StudTexture.lua` | Provides the reusable tiled STUD surface layer used across active HUD panels and menus. |
| `src/UI/Effects/HoverExpand.lua` | Provides reusable hover scaling for GuiObjects. |
| `src/UI/Effects/Notification.lua` | Provides a reusable counted attention badge. |
| `src/UI/HUD/CoinsDisplay.lua` | **Archived/dormant:** reusable responsive permanent-currency display. |
| `src/UI/HUD/RunRewardsDisplay.lua` | **Archived/dormant:** pending-reward claim and backpack-to-balance presentation. |
| `src/UI/HUD/AbilityInterface.lua` | Renders the responsive lobby Ability Arsenal, its shared bottom launcher dock, unlocked counts, rarity-priced locked cards, live coin affordability, and permanent run-choice unlock requests. |
| `src/UI/HUD/ClassInterface.lua` | Renders the responsive Classes launcher plus the left-side selector and right-side description, ability, perks, and unlock/equip action over the Workspace changing-room scene. |
| `src/UI/HUD/ClassesAbilitiesTutorial.lua` | Renders the returning-player instruction banner and animated camera-relative arrow toward the existing Classes booth. |
| `src/UI/HUD/ZombieIndex.lua` | Renders the responsive lobby index launcher and zombie collection with hidden undiscovered entries, kill counts, behavior details, portraits, and discovery reward actions. |
| `src/UI/HUD/RageBar.lua` | Renders the compact centered STUD-styled Rage meter directly above the level bar, with live charge/duration progress, reactive Game-session visibility, and keyboard/touch activation. |
| `src/UI/HUD/Notifications.lua` | Renders transient notifications from NotificationManager. |
| `src/UI/HUD/PartyTeleporterMenu.lua` | Renders the responsive leader-only Creation Menu, reopens it for pending join approvals, and collapses other confirmed/member views to the lock-aware exit control. |
| `src/UI/HUD/RollControls.lua` | **Archived/dormant:** Roll/Hide/Show, Auto Roll progress, and ability-menu controls. |
| `src/UI/HUD/RollInterface.lua` | **Archived/dormant:** full-screen or compact item/clover reel presentation. |
| `src/modules/UI/NotificationManager.lua` | Emits reusable transient notification events. |
| `src/modules/UI/PlayVFX.lua` | Clones, starts, and cleans up reusable effects and sounds. |
| `src/modules/UI/EffectLightingConfig.lua` | Applies the shared 50% intensity scale to runtime lights, emissive particles/trails/beams, and effect post-processing. |
| `src/modules/UI/StudVFX.lua` | Creates consistent client-local crossed stud flashes, layered impacts with echo rings, segmented shock rings, and two-tone debris bursts with bounded counts and automatic cleanup. |
| `src/modules/UI/SafeArea.lua` | Provides dynamic Roblox topbar-safe offsets. |
| `src/modules/UI/Sounds.lua` | Resolves optional Studio-owned sound templates and plays self-cleaning clones from stable 2D or snapshotted positional emitters, independent of temporary visual lifetimes. |
| `src/modules/UI/UIStyle.lua` | Centralizes the reusable STUD design tokens. |

## Local developer tools

| Path | Responsibility |
| --- | --- |
| `tools/model-preview/` | Validates versioned Part/Model construction JSON; exports the same data as Luau; produces deterministic headless Blender angle PNGs, annotated contact sheets, and complete hierarchy/property reports. Includes stdin/file iteration, camera/lighting settings, and focused tests. Offline material/stud shading approximates Roblox; no Studio scripts or runtime dependencies are created. See `tools/model-preview/README.md`. |

## Package compatibility

| Path | Responsibility |
| --- | --- |
| `src/compatibility/TopbarPlus.lua` | Exposes the installed TopbarPlus package at the path expected by Satchel. |
