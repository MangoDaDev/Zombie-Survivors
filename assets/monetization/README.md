# Monetization product artwork

Each PNG in this folder is a standalone transparent product image. Upload every file as its own
Roblox Image asset, then paste the resulting Image asset ID into the matching `ImageId` field in
`src/modules/Game/MonetizationConfig.lua`.

Do not combine these files into an atlas. Roblox runtime UI uses only `rbxassetid://...` values from
the central config; local filesystem paths are documentation/build inputs only.

| Config key | Upload file |
| --- | --- |
| `Revive` | `revive.png` |
| `ReviveTeam` | `revive-team.png` |
| `CoinPouch` | `coin-pouch.png` |
| `Satchel` | `satchel.png` |
| `Backpack` | `backpack.png` |
| `Crate` | `crate.png` |
| `Vault` | `vault.png` |
| `Arsenal` | `arsenal.png` |
| `RunBoost` | `run-boost.png` |
| `TakeAll` | `take-all.png` |
| `DoubleCoins` | `double-coins.png` |
| `ExtraAbilitySlots` | `extra-ability-slots.png` |
| `Gunslinger` | `gunslinger.png` |
| `Cryomancer` | `cryomancer.png` |
| `Starcaller` | `starcaller.png` |
| `Titan` | `titan.png` |
| `VoidEmperor` | `void-emperor.png` |

The files follow the first-party ability-icon references: transparent cutout, faceted highlights,
strong silhouette, saturated color, and a thick dark outline.
