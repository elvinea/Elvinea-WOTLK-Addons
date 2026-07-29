# ElvinRotation — TODO

Everything raised in testing, with what happened to it. Items move from
**Open** to **Done** only once the fix has been verified, not merely written.

---

## Open

### Damage output looks low

| Spec | Reported | Notes |
|---|---|---|
| **Demonology** | ~4k where others do ~7k | Worst gap of any spec. Too large to be priority ordering — suspect something structural. First checks: `/er verify` for Molten Core (71165) and Decimation (63167), and whether the Felguard is out, since Demonic Empowerment is gated on having a pet. |
| **Affliction** | ~5k where others do ~7k | Better than Demo but still low. Suspect the Haunt aura (59164) — Unstable Affliction is only refreshed inside the Haunt window, so if Haunt never reads as up, UA never gets refreshed and a large chunk of damage disappears. `/er dots` will show it. |
| **Arcane** | ~4k on a 5k-geared mage | No gems or enchants, so possibly gear rather than rotation. Worth re-testing now that Missile Barrage is spent correctly. |
| **Fire** | 2-3k, below Arcane | Same character, low gear. Re-test before judging. |

### Needs a knowledgeable eye

| Spec | Notes |
|---|---|
| **Retribution** | Abilities fire, but damage has not been judged by anyone who plays Ret. Inconclusive rather than broken. |
| **Feral (Cat)** | "A few quirks", damage unknown. Expected — this is the lowest-confidence spec in the addon and is missing the damage-per-energy model entirely. See SPECS.md. |

### Unresolved question

- **Feral: "what's furies deck?"** — could not parse this. Faerie Fire (Feral)?
  Tiger's Fury? Say which and it can be explained or changed.

### Known structural gaps

- **Warrior stance dancing** is not implemented in either Arms or Fury. The
  source runs separate lists per stance; doing it badly is worse than not
  doing it.
- **Pet management** is not handled anywhere. Beast Mastery is worst affected,
  since most of its damage is the pet.
- **Feral** has no damage-per-energy model, no Rip clipping, no weaving.
- **Multi-dotting** is single-target only everywhere; 3.3.5 cannot express
  `cycle_targets`.

---

## Done

### Cross-cutting

| Item | Fixed in |
|---|---|
| Rotation options section had no relation to the active spec | 5.5 — both dropdowns now mark the class and spec you are playing, and default to it. It was picking an arbitrary spec of your class via `pairs()` order. |
| No indication which spec the keybinds were for | 5.1 — the Keybinds section is titled with the active spec. There is one set, for whatever you are currently playing. |
| No warning when a self buff is missing | 5.1 — a red line under the icons lists any missing armour, shout, aspect, form, shield, presence or stance. Works out of combat. |

### Keybind resolution

| Item | Fixed in |
|---|---|
| Abilities on bars 7-10 never resolved | 5.12 — `ACTIONBUTTON1-12` are bound to the **button**, not the slot. Paged to page 10, button 3 shows slot 111 but is still pressed with `ACTIONBUTTON3`. The lookup was named after the slot. |
| Paged bars reported the wrong slot | 5.7 / 5.9 — a paged button reports its index (1-12), not the slot shown. Real slot is `(page-1)*12 + index`, with the page derived from `GetBonusBarOffset`. Affects every form and stance spec, validated against the button's own icon so unpaged bars are not shifted. |
| Keys set through `/kb` versus the WoW settings UI behaved randomly | 5.7 — those store bindings differently. The label the bar addon draws is right for both, so it is now the primary source. |
| Keybinds went stale after changing stance | 5.3 — rebuilt on `UPDATE_SHAPESHIFT_FORM` and `UPDATE_BONUS_ACTIONBAR`. |
| One macro claimed every spell it mentioned | 1.9 / 5.x — a direct placement outranks a macro, and a macro whose icon matches outranks one that merely names the spell. |
| No way to override detection | 5.4 / 5.6 — `/er setkey <spell> = <key>`, and `=` with nothing after it clears. |

### Per spec

| Spec | Item | Fixed in |
|---|---|---|
| **Fury** | Told to enter Berserker Stance while already in it | 5.1 — stances are stances, not buffs; read from the shapeshift bar. |
| **Fury** | Recklessness should come before Death Wish | 5.1 |
| **Fury** | Victory Rush suggested constantly | 5.5 — now requires the Victorious proc, which only happens after a kill. |
| **Fury** | Cleave and Heroic Strike never appeared | 5.12 — `evaluate()` returned at the first usable ability and never reached them. Now a separate pass, shown in the queue row tinted blue. |
| **Balance** | Insect Swarm and Moonfire used wrongly | 5.1 — Moonfire is arcane so Lunar buffs it; Insect Swarm is nature so Solar buffs it. Each is now tied to its own Eclipse. |
| **Arcane** | Missile Barrage proc not spent | 5.1 — it required four Arcane Blast stacks as well as the proc, so procs expired unused. |
| **Marksmanship** | Left Aspect of the Viper far too early | 5.1 — Viper and Dragonhawk shared one threshold, so it flipped the moment mana crossed back. Separate slider, default 60%. |

---

## Answered, not bugs

- **Arcane Barrage** is an Arcane talent: an instant nuke that consumes your
  Arcane Blast stacks. Suggested when you are moving with stacks up.
- **Fire: cannot find Blast Wave, Dragon's Breath or Icy Veins** — those are
  deep Fire and Frost talents. On a Torment the Weak build you likely do not
  have them, and `IsUsableSpell` correctly filters them out.
- **Frost DK and Unholy DK openers are slightly scuffed in play** — being
  handled with a macro rather than in the addon, as agreed.

---

## Not possible

- **A button that casts the recommendation.** Casting goes through protected
  functions, reachable only from a secure button whose attributes cannot be
  changed in combat. That restriction exists specifically to prevent this, and
  it is why every rotation helper in every version of WoW is display-only.
  Working around it needs an unlocker, which is a ban on Warmane.
