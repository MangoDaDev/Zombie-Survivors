# Economy Rebalance Report

## Model and assumptions

This rebalance models the full cash loop as `purchase price -> restoration reward -> restored sale value`, plus optional visitor income while the item is displayed. All values below use the default tuning controls in `EconomyConfig`.

- Active net profit per completed-and-sold item is `SaleValue + RestorationReward - PurchasePrice`.
- Restoration-time estimates use the real surface areas and visible-part counts of all 100 Studio item models. The table below was produced with the former 75% assisted-completion threshold; the implemented threshold is now 85%, so players must manually cover 13.3% more of each restoration step before assisted cleanup.
- Crate break time is `(ceil(Health / Damage) - 1) * SwingCooldown`; the first hit is immediate. Travel, target selection, reveal, and an 8-second handling allowance are included only in active-income estimates.
- Passive estimates use six successful inspections per visitor slot per minute. Actual results depend on museum geometry, travel paths, random activity counts, reservations, and occupied displays.
- No playtest was run. These are static estimates intended to be checked against telemetry.

## Major old-economy problems

1. Restoration tiers and the unlock chain contradicted each other. An Epic item starting at 55,000 could require the Polisher, but the Polisher sat after Hammer and Magnet at a 4,756,150 cumulative unlock cost.
2. Common crates had a nominal 72% Common outcome, but tiny late-rarity chances made their expected item price 11,693. That headline EV was unusable for new players because the item still had to be purchased and its tools unlocked.
3. Adjacent upgrade costs had extreme cliffs. Examples include Display9 1,000 -> Display10 35,000, Spray Speed I 500 -> II 25,000, and Polisher Speed II 150,000,000 -> III 1,000,000,000.
4. Common-to-Secret item prices scaled faster than the rest of the loop, while restoration added up to seven cumulative steps. Late values became large without creating proportionate decisions.
5. Visitor pay rates were tuned from nominal item value without an explicit model for concurrent visitors, repeated activities, travel, inspection duration, and reservations.
6. Dropped-item ownership could escalate to 10x base value, creating punitive or progression-breaking prices after a few transfers.
7. A player with no item and less than the minimum purchase price had no guaranteed recovery path.

## Central tuning controls

| Control | Default | Direction and scope |
| --- | ---: | --- |
| `ProgressionSpeedMultiplier` | 1.00 | Above 1 increases active/passive payouts and reduces all upgrade costs. It never changes damaged-item purchase prices. |
| `ActiveIncomeMultiplier` | 1.10 | Scales restoration rewards and restored-item sale values only. |
| `OnboardingIncomeMultiplier` | 2.00 | Multiplies Common active income, then blends down across later rarities. |
| `OnboardingIncomeBlendEndStage` | 5 | Ends the blend at Legendary, where active income returns to its normal 1.00x rarity scale. |
| `PassiveIncomeMultiplier` | 0.90 | Scales visitor payments only. |
| `UpgradeCostMultiplier` | 1.00 | Above 1 increases all upgrade costs. |
| `LateGameCurveMultiplier` | 1.00 | Above 1 compounds rarity prices and later-stage upgrade costs after stage 3. |

The onboarding rarity scales are Common 2.00x, Uncommon 1.75x, Rare 1.50x, Epic 1.25x, and Legendary onward 1.00x. They apply to restoration rewards and restored sale values, not purchase prices or visitor income. Every multiplier is applied once in a named EconomyConfig calculation. Item purchase price, restored sale value, restoration reward, visitor pay, and upgrade cost each have one authoritative calculation.

## Item values and income

| Rarity | Old price range | New price range | Old -> new average | New average sale | New average restore reward | Old -> new guest rate | New average guest pay |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Common | 80-320 | 120-500 | 202 -> 313 | 690 | 517 | 8% -> 2.5% | 7 |
| Uncommon | 650-3,200 | 700-2,200 | 2,090 -> 1,546 | 2,976 | 2,233 | 5% -> 1.8% | 25 |
| Rare | 8,000-32,000 | 4,000-12,000 | 22,811 -> 8,937 | 14,753 | 11,061 | 2.2% -> 1.2% | 97 |
| Epic | 55,000-220,000 | 30,000-90,000 | 151,540 -> 65,045 | 89,430 | 67,085 | 0.9% -> 0.8% | 469 |
| Legendary | 350,000-950,000 | 150,000-450,000 | 733,273 -> 341,545 | 375,727 | 281,636 | 0.4% -> 0.5% | 1,539 |
| Mythic | 1,500,000-4,500,000 | 800,000-2,400,000 | 3,450,000 -> 1,840,000 | 2,022,500 | 1,518,750 | 0.18% -> 0.3% | 4,975 |
| Secret | 7,500,000-20,000,000 | 5,000,000-12,000,000 | 14,493,333 -> 8,916,667 | 9,808,333 | 7,358,333 | 0.08% -> 0.2% | 16,050 |

Other economy settings:

| Setting | Old | New |
| --- | ---: | ---: |
| Starting cash | 500 | 750 |
| Minimum restoration reward | 60 | 75 |
| Restoration reward rate | 60% | 75% before the active-income multiplier |
| Restored sale value | 100% of purchase price | 220% for Common, blended to the 110% base by Legendary |
| Guaranteed early drops | Wrench, Toaster, Basketball | Wrench, Toaster, Basketball, Alarm Clock |
| Dropped-item transfer multiplier | 1.50x | 1.25x |
| Maximum dropped-item price | 10x base | 3x base |

The four guaranteed items cost 120, 400, 260, and 190. Their expected active net profits are 345, 1,140, 740, and 545, so they add about 2,770 cash before visitor income. This accelerates onboarding without changing item purchase prices or visitor income.

## Restoration order, time, and gating

The tool chain is now:

`Spray (free) -> Sponge -> Soft Brush -> Hairdryer -> Spray Paint -> Polisher -> Hammer -> Magnet`

This matches the cumulative restoration steps: tiers 1-6 introduce Spray; Sponge and Soft Brush; Hairdryer; Spray Paint and Polisher; Hammer; then Magnet. Secret keeps the complete tier-6 tool set rather than adding another arbitrary gate.

| Tier / first rarity | Required unlocked tools | Old cumulative unlock cost | New cumulative unlock cost | Old -> new minimum item price | New gate/price ratio |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 / Common | Spray | 0 | 0 | 80 -> 120 | 0% |
| 2 / Uncommon | Sponge, Soft Brush | 9,150 | 550 | 650 -> 700 | 79% |
| 3 / Rare | + Hairdryer | 21,150 | 2,350 | 8,000 -> 4,000 | 59% |
| 4 / Epic | + Spray Paint, Polisher | 4,756,150 | 21,350 | 55,000 -> 30,000 | 71% |
| 5 / Legendary | + Hammer | 4,756,150 | 61,350 | 350,000 -> 150,000 | 41% |
| 6 / Mythic | + Magnet | 4,756,150 | 241,350 | 1,500,000 -> 800,000 | 30% |
| 7 / Secret | Same complete set | 4,756,150 | 241,350 | 7,500,000 -> 5,000,000 | 5% |

| Restoration setting | Old | New |
| --- | ---: | ---: |
| Assisted completion threshold | 80% | 85% |
| Assisted cleanup duration | 0.32s | 0.25s |
| Step transition delay | 0.45s | 0.30s |
| Full completion delay | 1.80s | 1.20s |
| Spray strength / radius | 3.2 / 0.075 | 3.6 / 0.080 |
| Sponge strength / radius | 2.8 / 0.0501 | 3.2 / 0.055 |
| Soft Brush strength / radius | 2.4 / 0.0471 | 3.0 / 0.052 |
| Hairdryer strength / radius | 3.4 / 0.0945 | 3.8 / 0.100 |
| Spray Paint strength / radius | 3.2 / 0.075 | 3.4 / 0.080 |
| Polisher strength / radius | 1.9 / 0.0582 | 2.8 / 0.065 |
| Hammer strength / radius | 5.0 / 0.0417 | 5.0 / 0.045 |
| Magnet strength / radius | 1.8 / 0.0639 | 2.6 / 0.070 |
| Speed upgrade strength multipliers | 1.2 / 1.5 / 1.9 | 1.25 / 1.6 / 2.05 |
| Speed upgrade radius multipliers | 1.1 / 1.25 / 1.4 | 1.12 / 1.28 / 1.45 |

Estimated base restoration time from the real model geometry:

| Rarity | Old representative time | New measured average | New minimum-maximum |
| --- | ---: | ---: | ---: |
| Common | 10.7s | 6.7s | 4.1-7.9s |
| Uncommon | 43.0s | 26.3s | 11.2-42.6s |
| Rare | 50.0s | 32.1s | 9.9-44.6s |
| Epic | 78.0s | 48.6s | 17.2-70.0s |
| Legendary | 89.3s | 60.0s | 21.1-91.5s |
| Mythic | 114.6s | 73.8s | 22.7-95.5s |
| Secret | 112.8s | 74.8s | 31.4-91.2s |

## Crates

| Crate | Old -> new health | Old -> new expected item price | New minimum-average-maximum outcome |
| --- | ---: | ---: | ---: |
| Common | 12 -> 16 | 11,693 -> 535 | 120 / 535 / 12,000 |
| Uncommon | 48 -> 72 | 24,734 -> 2,784 | 120 / 2,784 / 90,000 |
| Rare | 160 -> 280 | 66,059 -> 24,273 | 120 / 24,273 / 450,000 |
| Epic | 600 -> 900 | 153,498 -> 129,913 | 120 / 129,913 / 2,400,000 |
| Legendary | 1,800 -> 2,600 | 401,312 -> 408,654 | 700 / 408,654 / 12,000,000 |
| Mythical pity | 5,000 -> 7,000 | 1,052,059 -> 1,147,907 | 4,000 / 1,147,907 / 12,000,000 |
| Secret pity | 12,000 -> 18,000 | 2,704,664 -> 3,136,949 | 4,000 / 3,136,949 / 12,000,000 |

Rarity odds are listed Common through Secret:

| Crate | Old odds (%) | New odds (%) |
| --- | --- | --- |
| Common | 72 / 20 / 6 / 1.5 / 0.4 / 0.09 / 0.01 | 88 / 11 / 1 / 0 / 0 / 0 / 0 |
| Uncommon | 52 / 30 / 13 / 4 / 0.8 / 0.18 / 0.02 | 35 / 50 / 14 / 1 / 0 / 0 / 0 |
| Rare | 32 / 32 / 23 / 10 / 2.4 / 0.54 / 0.06 | 8 / 25 / 45 / 20 / 2 / 0 / 0 |
| Epic | 16 / 27 / 29 / 20 / 6.5 / 1.35 / 0.15 | 2 / 8 / 25 / 45 / 18 / 2 / 0 |
| Legendary | 7 / 16 / 27 / 28 / 17 / 4.5 / 0.5 | 0 / 2 / 13 / 32 / 44 / 8 / 1 |
| Mythical pity | 2 / 8 / 18 / 28 / 27 / 15 / 2 | 0 / 0 / 5 / 20 / 40 / 30 / 5 |
| Secret pity | 0.5 / 3 / 8.5 / 18 / 27 / 34 / 9 | 0 / 0 / 1 / 7 / 22 / 45 / 25 |

The reset interval changed from 150s to 180s, normal respawn delay from 0.75s to 0.60s, Mythical pity from 600s to 420s, and Secret pity from 1,800s to 1,200s. Common crates are now predictable and affordable; their value comes from fast repetition rather than unaffordable lottery outcomes. Each successive regular crate has a strictly higher expected rarity stage.

## Bats and break times

| Bat | Old -> new damage | Cooldown |
| --- | ---: | ---: |
| Wooden | 4 -> 4 | 0.55s |
| Stone | 20 -> 12 | 0.52s |
| Bronze | 50 -> 32 | 0.50s |
| Iron | 80 -> 65 | 0.49s |
| Gold | 140 -> 130 | 0.47s |
| Emerald | 300 -> 260 | 0.45s |
| Titanium | 550 -> 450 | 0.43s |
| Diamond | 900 -> 750 | 0.42s |
| Reinforced Steel | 1,400 -> 1,150 | 0.41s |
| Obsidian | 2,400 -> 1,800 | 0.39s |
| Meteorite | 4,500 -> 2,800 | 0.37s |

New time to break, before cooldown upgrades:

| Crate | Wooden | Stone | Iron | Emerald | Meteorite |
| --- | ---: | ---: | ---: | ---: | ---: |
| Common | 1.65s | 0.52s | immediate | immediate | immediate |
| Uncommon | 9.35s | 2.60s | 0.49s | immediate | immediate |
| Rare | 37.95s | 11.96s | 1.96s | 0.45s | immediate |
| Epic | 123.20s | 38.48s | 6.37s | 1.35s | immediate |
| Legendary | 356.95s | 112.32s | 19.11s | 4.05s | immediate |
| Mythical | 961.95s | 303.16s | 52.43s | 11.70s | 0.74s |
| Secret | 2,474.45s | 779.48s | 135.24s | 31.05s | 2.22s |

Cooldown upgrade multipliers changed from `0.90 / 0.78 / 0.64` to `0.88 / 0.75 / 0.62`.

## Upgrade costs and cumulative paths

The total price of every purchasable upgrade fell from approximately 2.397B to 193.324M. Late progression still has substantial goals, but the 1B single-node cliff is gone.

### Museum

| Upgrade | Old -> new direct cost | New cumulative branch cost |
| --- | ---: | ---: |
| Display9 | 1,000 -> 1,200 | 1,200 |
| Display10 | 35,000 -> 8,000 | 9,200 |
| Display11 | 650,000 -> 40,000 | 49,200 |
| Display12 | 8,000,000 -> 160,000 | 209,200 |
| Display13 | 15,000,000 -> 500,000 | 709,200 |
| Display14 | 25,000,000 -> 1,300,000 | 2,009,200 |
| Display15 | 40,000,000 -> 3,000,000 | 5,009,200 |
| Display16 | 60,000,000 -> 6,000,000 | 11,009,200 |
| Display17 | 85,000,000 -> 11,000,000 | 22,009,200 |
| Display18 | 115,000,000 -> 18,000,000 | 40,009,200 |
| Display19 | 150,000,000 -> 28,000,000 | 68,009,200 |
| Display20 | 200,000,000 -> 42,000,000 | 110,009,200 |
| Visitors3 | 2,000 -> 1,500 | 1,500 |
| Visitors4 | 80,000 -> 20,000 | 21,500 |
| Visitors5 | 2,000,000 -> 250,000 | 271,500 |

### Restoration unlocks

| Upgrade | Old -> new direct cost | New cumulative unlock cost |
| --- | ---: | ---: |
| Sponge | 250 -> 200 | 200 |
| Soft Brush | 900 -> 350 | 550 |
| Hairdryer | 12,000 -> 1,800 | 2,350 |
| Spray Paint | 8,000 -> 7,000 | 9,350 |
| Polisher | 4,000,000 -> 12,000 | 21,350 |
| Hammer | 85,000 -> 40,000 | 61,350 |
| Magnet | 650,000 -> 180,000 | 241,350 |

### Restoration speed paths

The cumulative column includes that tool's full unlock prerequisites.

| Tool | Old I / II / III | New I / II / III | New cumulative I / II / III |
| --- | ---: | ---: | ---: |
| Spray | 500 / 25,000 / 1,000,000 | 400 / 4,000 / 40,000 | 400 / 4,400 / 44,400 |
| Sponge | 3,000 / 60,000 / 1,250,000 | 700 / 7,000 / 70,000 | 900 / 7,900 / 77,900 |
| Soft Brush | 5,000 / 100,000 / 2,000,000 | 900 / 9,000 / 90,000 | 1,450 / 10,450 / 100,450 |
| Hairdryer | 50,000 / 750,000 / 10,000,000 | 2,500 / 25,000 / 250,000 | 4,850 / 29,850 / 279,850 |
| Spray Paint | 35,000 / 400,000 / 5,000,000 | 8,000 / 80,000 / 800,000 | 17,350 / 97,350 / 897,350 |
| Polisher | 15,000,000 / 150,000,000 / 1,000,000,000 | 12,000 / 120,000 / 1,200,000 | 33,350 / 153,350 / 1,353,350 |
| Hammer | 350,000 / 5,000,000 / 60,000,000 | 50,000 / 500,000 / 5,000,000 | 111,350 / 611,350 / 5,611,350 |
| Magnet | 2,500,000 / 30,000,000 / 300,000,000 | 220,000 / 2,200,000 / 22,000,000 | 461,350 / 2,661,350 / 24,661,350 |

### Combat

| Upgrade | Old -> new direct cost | New cumulative branch cost |
| --- | ---: | ---: |
| Stone | 1,200 -> 700 | 700 |
| Bronze | 12,000 -> 3,500 | 4,200 |
| Iron | 45,000 -> 12,000 | 16,200 |
| Gold | 180,000 -> 45,000 | 61,200 |
| Emerald | 800,000 -> 160,000 | 221,200 |
| Titanium | 2,250,000 -> 550,000 | 771,200 |
| Diamond | 5,000,000 -> 1,600,000 | 2,371,200 |
| Reinforced Steel | 12,000,000 -> 4,500,000 | 6,871,200 |
| Obsidian | 25,000,000 -> 12,000,000 | 18,871,200 |
| Meteorite | 60,000,000 -> 30,000,000 | 48,871,200 |
| Cooldown I | 2,500 -> 1,200 | 1,200 |
| Cooldown II | 120,000 -> 40,000 | 41,200 |
| Cooldown III | 3,000,000 -> 1,200,000 | 1,241,200 |

## Expected income and payback

Representative active income includes item purchase, restoration reward, sale, expected restoration time, matching-stage crate break time, and eight seconds for reveal/transport/handling. The 85%-threshold cycle times are estimates derived from the measured 75%-threshold restoration times by scaling their active restoration portion by `85 / 75`.

| Stage | Representative crate / bat | Cycle time | Net cash per item | Active income/minute |
| --- | --- | ---: | ---: | ---: |
| Early Common | Common / Wooden | 17.2s | 894 | 3,120 |
| Early-mid Uncommon | Uncommon / Stone | 40.4s | 3,663 | 5,439 |
| Mid Rare | Rare / Iron | 46.4s | 16,877 | 21,833 |
| Mid-late Epic | Epic / Gold | 65.9s | 91,470 | 83,306 |
| Late Legendary | Legendary / Emerald | 80.1s | 315,818 | 236,568 |
| Late Mythic | Mythical / Titanium | 98.1s | 1,701,250 | 1,040,096 |
| Endgame Secret | Secret / Obsidian | 96.3s | 8,249,999 | 5,141,610 |

Representative passive income at six inspections per visitor slot per minute:

| Museum | Composition | Visitor capacity | Passive income/minute |
| --- | --- | ---: | ---: |
| Early | 4 Common displays | 2 per display | about 336 |
| Mid | 4 Rare + 4 Epic displays | 3 per display | about 40,752 |
| Late | 5 Epic + 8 Legendary + 5 Mythic + 2 Secret | 5 per display | about 2,148,960 |

Representative payback checks:

| Upgrade example | Assumption | Approximate payback |
| --- | --- | ---: |
| Display9 | One Common item, two visitor slots | 14 minutes |
| Display10 | One Uncommon item, two visitor slots | 27 minutes |
| Display12 | One Epic item, two visitor slots | 28 minutes |
| Visitors3 | Four Common displays; adds one visitor slot each | 9 minutes |
| Visitors4 | Eight Rare displays; adds one visitor slot each | 4 minutes |
| Visitors5 | Twelve Epic displays; adds one visitor slot each | 7 minutes |
| Spray Speed I | 15% throughput improvement at the Common stage | 3 minutes |
| Hairdryer Speed I | 12% throughput improvement at the Rare stage | 2 minutes |
| Polisher Speed I | 12% throughput improvement at the Epic stage | 2 minutes |
| Magnet Speed I | 8% throughput improvement at the Mythic stage | 3 minutes |
| Stone Bat | Saves about 1.13s per Common crate | about 9 minutes |
| Iron Bat | Saves about 2.04s per Rare crate versus Bronze | about 21 minutes |
| Gold Bat | Saves about 3.55s per Epic crate versus Iron | about 13 minutes |
| Emerald Bat | Saves about 4.88s per Legendary crate versus Gold | about 9 minutes |

Higher speed levels cost roughly 10x the prior level, so their payback intentionally moves from minutes toward tens of minutes and then longer endgame optimization. Display payback depends heavily on what the player chooses to exhibit; empty slots produce no income.

## Milestone timing

| Milestone | Static estimate for a new player |
| --- | --- |
| First useful upgrade | Sponge is affordable immediately; Spray Speed I and Stone Bat are each reachable after the first few Common restorations. |
| Four guaranteed Common restorations | Roughly 4-8 minutes including tutorial movement and reveal time; yields about 2,770 net cash before visitor payments. |
| Sponge + Soft Brush + Spray Speed I + Stone Bat | Roughly 6-12 minutes without needing a rare drop. |
| Hairdryer and meaningful museum/combat choices | Roughly 10-20 minutes depending on display use and crate choice. |
| Complete Epic tool set through Polisher | Roughly 25-45 minutes. |
| Hammer / established midgame | Roughly 40-75 minutes. |
| Magnet / Mythic-ready restoration | Roughly 1-2 hours. |
| High late-game branches | Multi-hour goals; top display, tool-speed, and bat paths remain optional specializations rather than required gates. |

## Recovery protection and validation

- If a player has less than the minimum item price, no inventory, and no displayed items, breaking a Common crate produces the recovery item and covers only the missing purchase amount. The purchase still consumes the available cash, so the protection creates a small self-correcting loop rather than a large free grant.
- The recovery route stops once the player can afford the minimum item again.
- Four guaranteed Common drops prevent early tool-lock surprises.
- Runtime assertions check positive tuning multipliers, rarity ordering and ranges, item IDs/difficulty/weights, crate probabilities, strictly improving regular-crate quality, increasing bat damage, non-increasing bat cooldown, cleaning-tool validity, non-decreasing restoration tiers, upgrade IDs/links/prerequisites, non-decreasing prerequisite costs, and cumulative tool affordability.

## Telemetry still needed

The largest uncertainty is physical visitor and restoration interaction time. Production telemetry should record:

- item purchase, restoration start/finish, display, and sale timestamps by rarity and item;
- actual target coverage and restoration duration by tool and upgrade level;
- crate hits, crate type, bat tier, reveal outcome, purchase/expiry, and player cash at reveal;
- visitor spawn-to-exit duration, inspections and payments per visitor, reservation occupancy, and idle time;
- upgrade purchase timestamps and cash balance after purchase;
- recovery protection activations and repeated activations;
- first-session retention milestones at 5, 10, 15, 30, 60, and 120 minutes.

Use median and 10th/90th percentiles, not only averages. The first live adjustment should use the centralized multipliers; change individual tables only if telemetry shows a specific branch or rarity is wrong.
