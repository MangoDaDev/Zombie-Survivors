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

<<<<<<< HEAD
## Multiplayer wayfinding

- Game sessions show safe-edge arrows with Roblox headshots for living offscreen teammates; lobby, local-player, dead-player, and on-screen markers stay hidden, and all projections share one render callback.

## World rewards

- Coin and XP drops share a 120-second authoritative lifetime through `RunProgressionConfig`.

=======
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
## Class prerequisites

- Missing or temporarily out-of-sync ability definitions fail closed: the class stays locked and both client and server show a safe fallback instead of indexing a missing definition.
- Orbiting Swords is a permanent starter unlock for new and existing profiles, and Blade Dancer costs 300 Coins as the cheapest purchasable class.
- A locked class card replaces its coin cost with `ABILITY LOCKED` until the required starting ability is owned.

## Sound playback

- Runtime one-shot sounds use `Modules.UI.Sounds`; it owns a stable 2D or positional playback parent so destroying a temporary visual, drop, projectile, or prop does not cut the sound off.

<<<<<<< HEAD
## Part-built VFX

- Client-local part effects share `Modules.UI.StudVFX` for studded Plastic blocks, layered flashes, segmented rings, and bounded two-tone debris bursts; keep gameplay timing and authority in their existing controllers.

## Ability progression

- Ability milestone requirements use half of their former levels, rounded down, so former level-50 milestones unlock at level 25; continuous weapon upgrades remain available through level 50 and use a stronger early/mid-level curve without changing their level-one baselines or level-50 totals. Passive upgrades retain their gentler curve.
- Weapon balance reviews must model dense-horde mechanics from the server implementation—including retargeting, unique-hit chains, persistent overlap, geometry, active caps, and crowd control—not rank weapons from displayed stats or single-target damage alone.
- Level-up spins progressively reduce an owned ability's upgrade weight when it leads the average level of the player's other owned abilities by more than three levels; the card remains possible and its base rarity still applies.

## Round difficulty

- Later-round difficulty is population-led: the smooth density curve gains a second population slope after the round-15 boss, while capped reinforcement-batch growth and a shrinking interval (floored for server safety) put substantially more zombies on the field together instead of only extending rounds. Strong-archetype weighting remains secondary.
- Shielders enter after the first boss and reduce frontal direct damage instead of nullifying it, so every solo build can still defeat them while flanking and bypass effects remain rewarded.

## Developer commands

- Developer chat controls reuse `ChatCommandController` authorization; run ability injection is transient, while Coin edits are intentionally persistent. Exact round jumps clear the active horde without awarding abandoned-round completion.
=======
## Ability progression

- Ability milestone requirements use half of their former levels, rounded down, so former level-50 milestones unlock at level 25; continuous upgrades remain available through level 50 and use a mild early-level boost without increasing their level-50 totals.
>>>>>>> 68678be8aad91d85f9c550f7e9bdad4477f0f6b3
