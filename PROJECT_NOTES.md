# Project Notes

Concise project-specific decisions that should survive future changes. General workflow and coding rules remain in `AGENTS.md`.

## Class accessories

- `ReplicatedStorage.Assets.Models.Classes` contains one sanitized native `Accessory` or legacy `Hat` per class, named exactly after the class ID.
- Preserve the complete imported hierarchy, including its Handle, attachments, `AttachmentPoint`, `OriginalSize`, `AvatarPartScaleType`, and authored weld data. Never extract a Handle or rebuild a legacy Hat into a new Accessory.
- Pass both modern Accessories and legacy Hats intact to `Humanoid:AddAccessory`; never replace either container or its Handle.
- Equipping and previewing a class removes other character accessories with the same `AccessoryType` so the class gear remains visible; accessories in other categories stay.
- Changing-room placement and camera framing use body-only bounds and complete before class accessory setup; accessory geometry must never move or blank the room preview.
- Marketplace source asset IDs: Survivor `127075338318575`, Scout `16667175441`, Pyromaniac `78032180`, Stormcaller `89677097`, Warden `99692799`, Trickshot `75763269`, Engineer `177159720`, Demolitionist `169791657`, Toxicologist `16518508792`, Berserker `99452560`, Scavenger `4639128249`, BladeDancer `9997611579`, Gunslinger `5562701646`, Cryomancer `50642340`, Starcaller `155586467`, Titan `139154508`, VoidEmperor `83688129001446`.
- Imported Toolbox hierarchies are staging input only. Remove scripts, tags, and attributes, but preserve the native accessory's attachments and internal joints/constraints because they define its authored assembly.

## Currency presentation

- Coin amounts and coin-spending/claim actions pair their text with `Images.Coin` on the left; yellow text alone is not sufficient.
- The shared `Button` supports reactive `LeftIcon` and `LeftIconVisible` props for currency actions.

## Class prerequisites

- Missing or temporarily out-of-sync ability definitions fail closed: the class stays locked and both client and server show a safe fallback instead of indexing a missing definition.

## Sound playback

- Runtime one-shot sounds use `Modules.UI.Sounds`; it owns a stable 2D or positional playback parent so destroying a temporary visual, drop, projectile, or prop does not cut the sound off.
