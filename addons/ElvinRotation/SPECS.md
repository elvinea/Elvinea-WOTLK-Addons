# ElvinRotation — Spec Coverage

All 21 damage specs in WotLK 3.3.5a, what exists, and what has actually
been proven in game.

**Status** is what the addon contains.
**Tested** is what has been checked *by a player who plays that spec* — not
whether the code runs. The offline harness passing is not testing.

**Source APL** is whether Hekili's `wrath` branch carries a SimulationCraft
priority list for it that can be translated. Where there is none, the
priority would have to be written from scratch.

---

## Death Knight

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Blood (DPS) | Not started | — | Yes — `DeathKnight-BloodPesti`, `DeathKnightBlood-IV` |
| Frost | **Built** | Partly — keybinds and presence verified, rotation not yet parsed | Yes — `FrostBLPesti`, `FrostUHPesti` |
| Unholy | **Built** | In progress — opener and AoE corrected from play, more to check | Yes — `Unholy2HSS`, `UnholyDWSS`, `UnholyDNDAOE` |

## Druid

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Balance | Not started | — | Yes — `DruidBalance` |
| Feral (Cat) | Not started | — | Yes — `DruidFeral` |

## Hunter

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Beast Mastery | Not started | — | Yes — `HunterBeastMastery` |
| Marksmanship | Not started | — | Yes — `HunterMarksmanship` |
| Survival | Not started | — | Yes — `HunterSurvival` |

## Mage

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Arcane | Not started | — | Yes — `MageArcane` |
| Fire | Not started | — | Yes — `MageFire` |
| Frost | Not started | — | Yes — `MageFrost` |

## Paladin

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Retribution | Not started | — | Yes — `PaladinRetributionLightClub` |

## Priest

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Shadow | **Built** | Partly — used in game, Mind Blast behaviour corrected from play | Yes — `PriestShadow` |

## Rogue

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Assassination | Not started | — | Yes — `RogueAssassination` |
| Combat | Not started | — | **No** — would need writing from scratch |
| Subtlety | Not started | — | **No** — would need writing from scratch |

## Shaman

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Elemental | Not started | — | **No** — would need writing from scratch |
| Enhancement | Not started | — | Yes — `ShamanEnhancement` |

## Warlock

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Affliction | Not started | — | Yes — `WarlockAffliction` |
| Demonology | Not started | — | Yes — `WarlockDemonology` |
| Destruction | Not started | — | Yes — `WarlockDestruction` |

## Warrior

| Spec | Status | Tested | Source APL |
|---|---|---|---|
| Arms | Not started | — | Yes — `WarriorArms` |
| Fury | Not started | — | Yes — `WarriorFury` |

---

## Totals

- **Built:** 3 of 21
- **Tested in game:** 0 fully, 3 partly
- **Source APL available:** 18 of 21

Missing source lists: Rogue Combat, Rogue Subtlety, Shaman Elemental.

---

## What "tested" needs to mean

The offline harness catches API misuse and structural mistakes. It cannot
catch a priority that is simply wrong, and it has not caught a single one so
far. Every rotation error found in this addon was found by a player noticing
that a recommendation looked off.

Things worth checking per spec before marking it tested:

1. `/er verify` — every spell ID resolves to the spell its name claims.
   A valid ID for the *wrong* spell is invisible to all other checks.
2. `/er keys` — every ability resolves to the key you actually press.
3. `/er state` — resources, dots, presence, pet, enemy count all read
   correctly during a fight.
4. Opener matches how the spec is actually played.
5. Single target: nothing gets suggested on repeat that should not.
6. AoE: spread effects fire when there is something to spread to, not
   every global.
7. Cooldowns fire in the intended windows and respect `/er cd`.

## Known imported-data problems

The priorities come from Hekili's `wrath` branch, which credits
wowsims.github.io (2023) and targets **Wrath Classic 3.4.x**, not original
3.3.5a, and not Warmane's scripting. It has been wrong in play on:

- **Shadow, Mind Blast** — the `flay_over_blast` formula produces spellpower
  thresholds of 7,600–86,000 against a realistic ceiling near 2,400, so it
  never discriminates and always answered "yes". Now a setting, default off.
- **Unholy, build assumptions** — the imported list assumes the Ghoul Frenzy
  and Master of Ghouls build: permanent ghoul, no Pestilence, no Bone Shield.
  The module now branches on glyphs, talents and pet state instead.
- **Unholy and Frost openers** — the source opener does not match how either
  is actually opened. Both were rewritten from play.
- **Presence handling** — the source only ever swaps *back* to Blood, and
  assumes you were already in Unholy when Gargoyle came up. Now a real
  two-way swap.

Treat imported numbers as a starting point, not an authority.
