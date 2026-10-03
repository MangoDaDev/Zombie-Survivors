# Project Notes

Concise project-specific decisions that should survive future changes. General workflow and coding rules remain in `AGENTS.md`.

## Class accessories

- `ReplicatedStorage.Assets.Models.Classes` contains one sanitized native `Accessory` or legacy `Hat` per class, named exactly after the class ID.
- Preserve the complete imported hierarchy, including its Handle, attachments, `AttachmentPoint`, `OriginalSize`, `AvatarPartScaleType`, and authored weld data. Never extract a Handle or rebuild a legacy Hat into a new Accessory.
- Pass both modern Accessories and legacy Hats intact to `Humanoid:AddAccessory`; never replace either container or its Handle.
- Equipping and previewing a class removes other character accessories with the same `AccessoryType` so the class gear remains visible; accessories in other categories stay.
- Changing-room placement and camera framing use body-only bounds and complete before class accessory setup; accessory geometry must never move or blank the room preview.
- The changing room keeps one animation-free avatar clone while browsing classes. Selection changes swap only the accessory, using an explicit local attachment weld because the anchored preview cannot rely on runtime Humanoid attachment.
- Preview legacy Hats use `Head.CFrame * CFrame.new(0, Head.Size.Y / 2, 0) * AttachmentPoint:Inverse()`; omitting the half-head-height offset misplaces every attachment-less Hat.
- Same-type avatar accessories are temporarily unparented and restored when the preview category changes or the room closes; do not permanently delete them from the preview clone.
- The authored changing-room set deliberately oversizes its floor and walls around the camera frustum so sky is not visible at supported aspect ratios.
- Marketplace source asset IDs: Survivor `127075338318575`, Scout `16667175441`, Pyromaniac `78032180`, Stormcaller `89677097`, Warden `99692799`, Trickshot `75763269`, Engineer `177159720`, Demolitionist `169791657`, Toxicologist `16518508792`, Berserker `99452560`, Scavenger `4639128249`, BladeDancer `9997611579`, Gunslinger `5562701646`, Cryomancer `50642340`, Starcaller `155586467`, Titan `139154508`, VoidEmperor `83688129001446`.
- Imported Toolbox hierarchies are staging input only. Remove scripts, tags, and attributes, but preserve the native accessory's attachments and internal joints/constraints because they define its authored assembly.

## Currency presentation

- Coin amounts and coin-spending/claim actions pair their text with `Images.Coin` on the left; yellow text alone is not sufficient.
- The shared `Button` supports reactive `LeftIcon` and `LeftIconVisible` props for currency actions.
- Roblox player-list leaderstats mirror Coins and the highest round survived for display only; DataService remains authoritative and gameplay must never read the leaderstats ValueObjects.

## Monetization

- `src/modules/Game/MonetizationConfig.lua` is the sole editable catalog for commerce IDs, one standalone Image ID per product, coin amounts, merchandising, and major balance settings.
- The shared lobby launcher dock stays hidden while the monetization shop is open so its controls never overlap the modal catalog.
- Robux purchase controls render Roblox's Unicode Robux glyph in their text; do not restore image icons beside Robux prices.
- `MonetizationController` is the only owner of `MarketplaceService.ProcessReceipt`; repeatable rewards use persisted receipt credits and contextual products bind to server-owned run state before prompting.
- Permanent x2 Coins and the current-run boost multiply at the authoritative coin/XP award boundaries. The run boost is cleared at every final run/replay boundary.
- Gunslinger, Cryomancer, Starcaller, Titan, and Void Emperor are premium Gamepass classes. Verified ownership grants into the existing class/ability data; the legacy coin-unlock remote cannot bypass the pass.
- Five Weapon and five Passive slots remain free. The slot Gamepass adds exactly one server-enforced slot to each category.
- A player death is a downed state while any teammate lives. Downed players spectate; every fifth completed wave revives all downed party members, and only a full-team wipe can start the final result/lobby-return flow.
- Monetization artwork uses one standalone transparent PNG and one Roblox Image asset ID per product/class; never use atlases or runtime local-file paths. Source PNGs live under `assets/monetization/`, and runtime UI falls back to Marketplace/generic art until the corresponding Image IDs are configured.
- The monetization shop is one continuous scrolling catalog. Its top category controls only jump the existing scroll position to section anchors; do not turn them back into filtered pages.
- Purchase celebration is confirmation-driven: Developer Products celebrate only after their receipt applies, Gamepasses only after verified ownership, and cancellations never produce success feedback.
- A confirmed Take All receipt must consume the current level-up presentation and either roll the next queued choice or close it; never leave the purchased choice set on screen.

## Responsive menus

- Every composed menu keeps its authored panel proportions with a `UIAspectRatioConstraint`; use `FitWithinMaxSize` so the limiting axis can change safely between narrow, standard, and ultrawide viewports.
- Authored HUD surfaces such as the round timer, currency chip, status bars, compact offers, and ability tray also preserve their breakpoint-specific proportions with `UIAspectRatioConstraint`; full-screen composition roots and intentionally fluid layout wrappers remain unconstrained.
- Major catalog menus combine scale and positive pixel offsets so they continue growing across resolutions while occupying proportionally less space on larger displays; do not hard-cap them with pixel ceilings.
- Ability Arsenal, Shop, Zombie Index, Party Creation, and Run Over use the shared `UIStyle.NonClassMenuScale` value of `0.84`; Classes deliberately remains at its authored scale.
- The party setup panel uses a fixed `1.25` aspect ratio.
- UI sizing must not use `UISizeConstraint`; use responsive `Size` values and aspect-ratio constraints instead.

## Multiplayer wayfinding

- Game sessions show safe-edge arrows with Roblox headshots for living offscreen teammates; lobby, local-player, dead-player, and on-screen markers stay hidden, and all projections share one render callback.

## Spectator UI

- While a downed player spectates a living teammate, hide all ordinary App UI (including queued ability choices and combat HUD) and show only the dedicated downed/spectate overlay. Keep the final game-over screen outside this gate so a team wipe can replace spectator mode normally.

## Party formation

- The first player entering an empty lobby teleporter becomes its leader; every later entrant remains outside until that leader explicitly approves the server-owned join request.

## World rewards

- Coin and XP drops share a 120-second authoritative lifetime through `RunProgressionConfig`; lifetime advances at 3x only while every eligible player's fresh camera report confirms the drop is offscreen.
- Coin and XP drops are single shared world pickups claimed first-come-first-served. Coins go entirely to the collector; up to 25% of an XP drop's integer base value is divided among the other present players, with the indivisible remainder staying with the collector and no base XP duplicated.

## Effect lighting

- `EffectLightingConfig` applies the required 50% intensity scale to gameplay lights, emissive particles/trails/beams, and short Lighting-service post-processing flashes.

## Class prerequisites

- Missing or temporarily out-of-sync ability definitions fail closed: the class stays locked and both client and server show a safe fallback instead of indexing a missing definition.
- Orbiting Swords is a permanent starter unlock for new and existing profiles, and Blade Dancer costs 300 Coins as the cheapest purchasable class.
- A locked class card replaces its coin cost with `ABILITY LOCKED` until the required starting ability is owned.
- The 3D lobby Classes booth opens the Classes menu through the `Classes > PromptPart` proximity prompt; bind by that hierarchy beneath Workspace because the active booth is nested in the Lobby map and the prompt display name is not authoritative.

## Returning-player shop tutorial

- A lobby join with at least one previously cleared round and no saved tutorial completion starts the one-time Classes tutorial; completing a first round during the current session never starts it immediately.
- Blade Dancer is the fixed tutorial claim. Only its authoritative successful claim saves completion, and that path never calls the coin controller; leaving earlier causes the tutorial to return next join.
- Tutorial copy stays guidance-first and limited to short three- or four-word cues; use UI-built arrow geometry rather than a font glyph so the direction remains visible on every supported client.

## Sound playback

- Runtime one-shot sounds use `Modules.UI.Sounds`; it owns a stable 2D or positional playback parent so destroying a temporary visual, drop, projectile, or prop does not cut the sound off.
- Zombie damage feedback reuses positional `BulletHit` for surviving hits and a lower-pitched `BodyImpact` for deaths, with separate shared rate limits so simultaneous horde damage cannot create an unbounded sound burst.

## Combat feedback

- Floating zombie damage numbers use the server's post-mitigation health loss and are sent only to the player credited by the damage context. Each hit owns a separate client-local, stud-scaled BillboardGui so simultaneous hits do not replace one another or modify the shared health bar.
- Zombie spawn height is measured from authored foot/leg geometry rather than the complete model bounds, preventing roots, accessories, or effect parts below the body from lifting visible feet off the ground.

## Player regeneration

- `PlayerStatController` owns baseline natural regeneration at 0.25% of maximum health per second; the empty mapped `StarterCharacterScripts.Health` only suppresses Roblox's competing default. Heart recovery and other authored healing remain separate.

## Player health presentation

- `UI.World.PlayerHealthBars` replaces the screen health HUD with a 3.8-by-0.5-stud BillboardGui above every player during Game sessions. Every client reads all replicated Humanoids; damage and healing remain server-owned.
- Keep the empty bar transparent, with a scaled outline, health fill, and only the remaining health number centered inside. Do not restore a HEALTH caption, backing panel, pixel-sized billboard, or duplicate native overhead/screen health display.
- World health bars sit outside App's ordinary screen-UI spectator gate so downed players can still see their observed teammates' health.

## Character placement

- The server bootstrap dispatches `CharacterController` before yield-prone character hooks so initial map placement cannot arrive late and teleport a player after gameplay has begun.

## Part-built VFX

- Client-local part effects share `Modules.UI.StudVFX` for studded Plastic blocks, layered flashes, segmented rings, and bounded two-tone debris bursts; keep gameplay timing and authority in their existing controllers.
- Impact and area effects use layered stud compositions (crossed rays, echo rings, debris, broken tiles, or moving segments) rather than a single expanding sphere, cylinder, or plate; keep persistent effect part counts bounded for dense multiplayer hordes.

## Rendering performance

- Optimisations must preserve the exact visuals, animation frequency, timing, and mechanics; do not introduce culling, reduced VFX density, or gameplay/balance changes as performance shortcuts.
- Keep native `PivotTo` for weapon/sword models. Detached asset comparisons found that rebuilding 39-part Dagger and 61-part Sword poses in Luau for bulk submission costs more than Roblox's native model transform cache.
- Coin backpack opening positions are shared only within the current frame, preserving respawns and authored backpack-stage swaps. Keep holder movement before pickup prediction and camera-visibility reads, and avoid redundant billboard size writes.
- XP magnet destinations and sword-owner roots also share only frame-local lookups. Runtime burst/ring/warning fade targets are captured after construction and released with the existing effect state; preserve all segments, scale pulses, opacity formulas, and lifetimes.

## Ability progression

- Permanent weapon and passive unlocks use explicit simulator-style prices instead of rarity-only pricing. Class-linked weapons cost roughly half their corresponding class benchmark, culminating in Vortex at 750,000 Coins against Void Emperor at 1,500,000; starter abilities remain free.
- Weapon progression is capped at level 25, with its already-condensed special milestones culminating at that cap. The shorter continuous curve preserves the former level-one baseline and level-50 maximum power; passive progression remains capped at level 50 with its gentler curve.
- Weapon balance reviews must model dense-horde mechanics from the server implementation—including retargeting, unique-hit chains, persistent overlap, geometry, active caps, and crowd control—not rank weapons from displayed stats or single-target damage alone.
- Level-up spins preserve the higher offer chance for abilities already owned in the current run. While fewer passives than active weapons are equipped, passive candidates have twice the active weight within both upgrade and new-ability groups; otherwise candidates have equal weight. Rarity and current level never bias candidates; max levels and available category slots still determine eligibility. `RunProgressionConfig.Abilities.PassiveCatchUpWeight` owns the bonus.
- Aura begins at a 5-stud radius and gains a diminishing but always-positive amount of radius every level with no radius cap. Its radius unlocks shared color-coded Outer, Inner, and Core zones whose damage increases toward the player; final modified radius controls both authoritative zones and visuals.
- Aura damage zones stay visibly filled with translucent studded disk rows and stronger segmented outlines; outline-only rings are too difficult to see. Each zone uses 16 fill rows regardless of radius, with inner colors layered above the outer field.
- The 3D lobby Abilities booth opens the permanent unlock menu through the `Abilities > PromptPart` proximity prompt; prompt binding follows the booth hierarchy and normalizes its labels to `Abilities` / `Open Abilities` because the Studio-authored prompt may retain duplicated Classes metadata.

## Round difficulty

- Every boss snapshots living player count at spawn and gains 25% health per additional player, capped at 2x solo health; downed players do not add scaling, and existing bosses never rescale mid-fight. `RunProgressionConfig.Rounds` owns the tuning.
- Every milestone boss summons on an independent timer, including while its primary attack is out of range; finish committed attacks/recovery first. Per-boss surviving and pending summon caps are 10/12/14/16 for Grave Titan/Plague Matron/Rift Stalker/Bone Colossus, and offspring keep the boss's originating round. Never add recursive summoner types to boss packs.
- Solo boss health progresses through 6,000/24,000/60,000/120,000. All bosses permanently enrage at half health with faster movement, damage, and future cooldowns; active telegraphs keep their complete dodge time. Plague Matron casts three damaging/slowing pools (four enraged), Rift Stalker chains two fully warned eruptions (three enraged), and Bone Colossus uses swept charges plus close-range stomps with punish windows.
- Boss area damage and lane warnings use arena-floor height, never elevated model pivots; charges sweep the full constrained horizontal travel segment once per player. Boss circular warnings use the cast's replicated radius so summon/stomp areas match their damage geometry. Plague pools tick through the existing authoritative damage path once per second and disappear with their owner or arena clear.
- Round one starts with six zombies, then population grows through gentle bounded density and post-round-15 slopes so the run does not hit a population/replication cliff around round 30. Reinforcement batches grow slowly and remain capped at 12 initially/10 thereafter; never lower the interval below 1.4 seconds. Strong-archetype weighting remains secondary and gradual.
- Shielders enter after the first boss and reduce frontal direct damage instead of nullifying it, so every solo build can still defeat them while flanking and bypass effects remain rewarded.
- The persisted `RoundsSurvived` public stat is a personal best: it stores the highest authoritative round the player completed while alive, never a cumulative lifetime total.

## Developer commands

- Developer chat controls reuse `ChatCommandController` authorization; run ability injection is transient, while Coin edits are intentionally persistent. Exact round jumps clear the active horde without awarding abandoned-round completion.

## Analytics funnels

- `AnalyticsConfig` owns stable, versioned Roblox funnel and step names; preserve existing names so dashboard history remains comparable.
- `AnalyticsController` logs server-side success boundaries, uses Roblox's dedicated one-time onboarding funnel, enforces ordered steps, and uses fresh session IDs for each repeatable shop checkout, run choice, gameplay run, and replay attempt.
- First-run onboarding persists only its current step/version so it can continue across the lobby-to-game teleport without changing gameplay data or behavior.
- Funnel custom fields are capped at Roblox's three supported string fields; put important breakdown dimensions on step one because Roblox funnel charts use the first step's fields.
