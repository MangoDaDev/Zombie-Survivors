# Ability implementation notes

## Catalog extension

- Crowbar, Crossfire, Buzzsaw, Crusher, and Laser Sweep are server-authored weapons rendered as client-local stud-built effects.
- Armor, Magnet, Executioner, Training Manual, and Overcharge are server-authoritative passives.
- Every added ability has continuous level scaling, condensed milestone upgrades through level 25, and a distinct Rage variant.

## Preserved decisions

- Fixed-direction Crossfire intentionally does not auto-aim; positioning is its identity.
- Armor modifies only zombie damage and is applied before health loss.
- Executioner reads authoritative live zombie health; clients never decide its bonus.
- Training Manual changes awarded run XP, never permanent Coins.
- Overcharge counts only successful scheduled activations and echoes damage without consuming another charge.
- Runtime weapon models and VFX use Plastic rectangular Parts with studded surfaces; no permanent Studio models are required.

## Art handoff

- Final transparent icon files are staged in `assets/ability-icons/`.
- The human-approved files were uploaded to Roblox and their Image asset IDs are registered in `Modules.UI.Images.Abilities`.
- Keep using the uploaded Image asset IDs rather than Decal container IDs so the icons render in `ImageLabel` instances.
