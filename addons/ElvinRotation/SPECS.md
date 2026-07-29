# ElvinRotation — Spec Coverage

All 23 damage specs in WotLK 3.3.5a, what exists, and what has actually
been proven in game.

**Status** is what the addon contains.
**Tested** is what has been checked *by a player who plays that spec* — not
whether the code runs. The offline harness passing is not testing.

**Source APL** is whether Hekili's `wrath` branch carries a SimulationCraft
priority list for it that can be translated. Where there is none, the
priority would have to be written from scratch.

---

## Death Knight

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Blood (DPS) | **Built** | Not yet | Good | Yes — `DeathKnight-BloodPesti`, `DeathKnightBlood-IV` |
| Frost | **Built** | **PASS** — opener needs a macro | Good | Yes — `FrostBLPesti`, `FrostUHPesti` |
| Unholy | **Built** | **PASS** — opener needs a macro | Good | Yes — `Unholy2HSS`, `UnholyDWSS`, `UnholyDNDAOE` |

## Druid

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Balance | **Built** | **Fixed in 5.1** — Eclipse dot pairing | Good | Yes — `DruidBalance` |
| Feral (Cat) | **Built** | **PASS with quirks** | **LOW — see below** | Yes — `DruidFeral` |

## Hunter

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Beast Mastery | **Built** | Not yet | Good | Yes — `HunterBeastMastery` |
| Marksmanship | **Built** | **Fixed in 5.1** — aspect thrashing | Good | Yes — `HunterMarksmanship` |
| Survival | **Built** | Not yet | Good | Yes — `HunterSurvival` |

## Mage

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Arcane | **Built** | **Fixed in 5.1** — Missile Barrage | Good | Yes — `MageArcane` |
| Fire | **Built** | **PASS** — low gear, unverified | Good | Yes — `MageFire` |
| Frost | **Built** | Not yet | Good | Yes — `MageFrost` |

## Paladin

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Retribution | **Built** | **Inconclusive** — casts, damage unverified | Good | Yes — `PaladinRetributionLightClub` |

## Priest

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Shadow | **Built** | **PASS** | Good | Yes — `PriestShadow` |

## Rogue

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Assassination | **Built** | Not yet | Good | Yes — `RogueAssassination` |
| Combat | **Built** | Not yet | **Medium — reconstructed** | **No source** |
| Subtlety | **Built** | Not yet | **LOWEST — reconstructed** | **No source** |

## Shaman

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Elemental | **Built** | Not yet | **Medium — reconstructed** | **No source** |
| Enhancement | **Built** | Not yet | Good | Yes — `ShamanEnhancement` |

## Warlock

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Affliction | **Built** | **OPEN** — ~5k vs ~7k expected | Good | Yes — `WarlockAffliction` |
| Demonology | **Built** | **OPEN** — ~4k vs ~7k expected | Good | Yes — `WarlockDemonology` |
| Destruction | **Built** | Not yet | Good | Yes — `WarlockDestruction` |

## Warrior

| Spec | Status | Tested | Confidence | Source APL |
|---|---|---|---|---|
| Arms | **Built** | Not yet | Medium — no stance dancing | Yes — `WarriorArms` |
| Fury | **Built** | **Fixed in 5.5** — Victory Rush, off-GCD | Medium — no stance dancing | Yes — `WarriorFury` |

---

## Totals

- **Built:** 23 of 23 — complete
- **Remaining:** 0
- **Tested in game:** 3 — Shadow Priest, Frost DK, Unholy DK
- **Source APL available:** 20 of 23

(An earlier version of this file said 21 specs. That was an arithmetic
error on my part; the correct total is 23.)

Built but untested: everything except Shadow Priest, Frost DK and Unholy DK —
thirteen specs that have never been run in game.

**All 23 damage specs are built.** Twelve have now been run in game.

### Specs affected by bar paging

Any spec with a form or stance pages the action bars, so its keybinds live in
slots 73-120 rather than 1-12. Worth re-checking `/er keys` on all of these:
both Warriors, all three Rogues (Stealth), and both Druids. Death Knight
presences and Priest Shadowform do **not** page.

### Testing progress

| Result | Count | Specs |
|---|---:|---|
| **PASS** | 6 | Shadow, Frost DK, Unholy DK, Fire, Feral (quirks), and Fury/Balance/Arcane/Marksmanship after their fixes |
| **Fixed, awaiting re-test** | 4 | Fury (stance, Victory Rush, off-GCD), Balance (Eclipse dot pairing, keybinds), Arcane (Missile Barrage), Marksmanship (aspect thrashing) |
| **OPEN** | 4 | Affliction and Demonology, both well below expected damage; Arcane and Fire, possibly gear. See TODO.md |
| **Inconclusive** | 1 | Retribution — abilities fire, damage not judged |
| **Not yet tested** | 11 | Blood DK, Arms, Beast Mastery, Survival, Mage Frost, Assassination, Combat, Subtlety, Enhancement, Elemental, Destruction |

Both DK openers are slightly off in play; that is being handled with a macro
rather than in the addon.

Full detail of every item raised in testing, and what happened to it, is in
[TODO.md](TODO.md).

### Confidence

**Good (19)** — translated from a source APL, with omissions documented in
each file.

**Medium — no stance dancing (2)** — Arms and Fury Warrior. The rotations are
translated, but stance swapping is deliberately not implemented, and Heroic
Strike and Cleave are off-GCD queued abilities the addon treats as normal
recommendations. That last point is the biggest single inaccuracy in either.

**Medium — reconstructed (2)** — Combat Rogue and Elemental Shaman. No source
APL exists, so these are my reconstruction rather than a translation. Their
core shapes are well established and uncontroversial (Slice and Dice upkeep
into Eviscerate; Flame Shock into Lava Burst on cooldown). The debatable
choices are exposed as settings rather than guessed at silently.

**LOW — Feral Cat** — built, but missing the thing that actually makes Feral
work. The source runs a live damage-per-energy calculation over attack power,
crit, armour penetration and boss armour, plus a bespoke scheduler resolving
Rip against Savage Roar. None of that is implemented. It will be right about
what to press and wrong about when to clip Rip, when Ferocious Bite beats
Shred, and every weaving decision.

**LOWEST — Subtlety Rogue** — reconstructed, and the spec I would trust least
in the whole addon. Subtlety was rarely raided in Wrath, which is why no
source list exists. Shadow Dance handling in particular is a guess.

Missing source lists: Rogue Combat, Rogue Subtlety, Shaman Elemental. Those
three would need priorities written from scratch rather than translated.


| Rogue Combat | **No** | Write from scratch |
| Rogue Subtlety | **No** | Write from scratch |
| Shaman Elemental | **No** | Write from scratch |

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
- **Frost disease upkeep** — the source uses Pestilence for refreshing, which
  silently requires Glyph of Disease. Without the glyph the diseases simply
  expire. Now detected rather than assumed.

Treat imported numbers as a starting point, not an authority.

---

## Notes on the two newest specs

**Assassination Rogue** is the first combo-point spec. Energy and combo
points are handled generically by the engine — a spec declares `powerType`
and `usesComboPoints` and the costs are enforced for it. Rupture appears only
as a bleed to enable Hunger for Blood, which is how the source uses it, not
as a damage finisher. Poisons are assumed applied; nothing reminds you.

**Affliction Warlock** is the closest relative of Shadow Priest — several
DoTs kept rolling with a nuke filler — with one wrinkle: Haunt buffs every
other DoT while it is on the target, so refreshing inside the Haunt window
matters and the priority is built around it. Below 26% health the whole list
is replaced by a Drain Soul execute. Haunt's travel time is approximated as a
flat 0.5s because 3.3.5 gives no way to measure it, and Corruption snapshot
tracking is not implemented.

**Arcane Mage** is the shortest priority in the addon: stack Arcane Blast to
four, spend with Arcane Missiles when Missile Barrage procs, Arcane Barrage
instead if you are moving, and keep mana above water. Nearly all the skill is
in the mana management rather than the button order, so both mana lines — stop
stacking, and evocate — are sliders.

**Survival Hunter** is the first Hunter spec. Explosive Shot is effectively
the whole rotation — a short DoT you re-apply the moment the last one stops
ticking — and everything else fills around it. Shot weaving against the
auto-shot timer is deliberately not implemented: 3.3.5 exposes the ranged
swing timer poorly and getting it wrong is worse than ignoring it.

**Enhancement Shaman** is the first spec with a stacking proc that converts a
cast into an instant. Maelstrom Weapon builds from melee swings, and at five
stacks Lightning Bolt becomes instant and free. Weapon imbues and the wider
totem subsystem are omitted — both are upkeep rather than rotation, and
dropping the wrong totem mid-fight is worse than dropping none.

**Fire Mage** shares the Mage class with Arcane and claims a different talent
tab, so spec detection picks whichever tree has more points — the same
mechanism as the two Death Knight specs. One proc to react to: Hot Streak
makes the next Pyroblast instant, and sitting on it wastes the next crit.

**Balance Druid** is built entirely around Eclipse, in two states the source
calls fishing and spamming. Fishing means no Eclipse is up, so you cast
whichever nuke procs the one you want next — and it reads backwards, because
Wrath procs Lunar Eclipse which buffs Starfire. Each Eclipse has a 30 second
internal cooldown that 3.3.5 does not expose, so the addon tracks when each
was last seen up and assumes 30 seconds from there. That will be wrong for
the first proc after a reload.

**Arms Warrior** is the first rage spec. **Stance dancing is deliberately not
implemented** — the source runs three lists and swaps into Berserker for
Recklessness and Bladestorm before returning. That is a real part of good Arms
play, and doing it badly would be worse than not doing it, so this assumes you
stay in Battle Stance. Heroic Strike is also imperfect: it is an off-GCD
queued ability, and the addon treats it as a normal recommendation with a rage
reserve slider as the crude substitute.

**Retribution Paladin** is the first spec whose rotation is essentially a
queue of cooldowns rather than a resource loop. The source list threads a
different fraction of one mana threshold through nearly every line; that is
collapsed here into a single floor with a slider. Seals are faction split —
Alliance cast Seal of Vengeance, Horde Seal of Corruption — and both are
registered so whichever the character knows resolves. Auras and blessings are
deliberately omitted: they are raid setup, not rotation. Holy Wrath is off by
default because it is only worth casting against Demons and Undead and 3.3.5
gives no way to check creature type.
