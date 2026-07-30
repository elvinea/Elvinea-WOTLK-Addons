# Changelog

All notable changes to ElvinRotation.

Written honestly: most entries are bug fixes, and most of those bugs were
found by a player noticing a recommendation looked wrong rather than by any
test. That pattern is worth preserving in the record.

---

## 6.3

- The command list now prints the version. Twice a command has looked broken
  when the real cause was an older copy still installed; this makes that
  obvious from the same screenshot.

## 6.2

- Added `ElvinRotation:ToggleDisplay(source)`, returning `ok, nowHidden`.
  Scoped to the caller's own source, so toggling cannot release a hide
  another addon is holding — otherwise two addons sharing the display would
  override each other. `/er hidetoggle` does the same from chat.

## 6.1

- **Public API so other addons can hide the display.**

  ```lua
  ElvinRotation:HideDisplay("MyAddon")
  ElvinRotation:ShowDisplay("MyAddon")
  ```

  Hides are tracked **by source**, so two addons can both request one and
  neither reveals the display by releasing first. Also `SetDisplayHidden`,
  `IsDisplayHidden`, `GetHideSources`, `GetDisplayFrame`, and
  `RegisterCallback` for `"hidden"` and `"shown"`.

  An external hide is runtime only and never written to saved variables — a
  boss mod hiding the display for an encounter must not silently switch it
  off permanently. It overrides everything else, including the self-buff
  warning, which can otherwise force the frame open. A callback that errors
  is caught and reported rather than breaking the addon.

  `/er hide` and `/er show` do the same from chat.

## 6.0

No code changes. Version bump only, marking the point where the twelve specs
tested so far are behaving and the keybind work has settled.

- Added `TODO.md`: every item raised in testing, separated into open, fixed
  (with the version that fixed it), answered-but-not-a-bug, and not possible.

The keybind saga is worth recording as a lesson. It took roughly ten versions
because I kept adding heuristics instead of asking two questions that would
have solved it immediately: *how do you set your binds* (a mix of the WoW
settings UI and `/kb`, which store bindings differently), and *does your class
page its bars* (a warrior and a druid, so yes). The fix that finally worked
came from a single line of `/er keys` output — Moonfire at slot 2 resolving
while Wrath at slot 111 did not, on the same bar — which made the
button-versus-slot distinction obvious.

## 5.12

- **Paged slots now resolve through their BUTTON binding.** `ACTIONBUTTON1-12`
  are bound to the button, not the action slot. With bar 1 paged to page 10,
  button 3 shows slot 111 — and the key that presses it is still
  `ACTIONBUTTON3`. I was asking for a binding named after the slot. That is
  why Moonfire (slot 2) resolved while Wrath (slot 111) did not, on the same
  bar, on the same character.
- **The off-GCD suggestion now uses a queue slot frame**, appearing in the row
  you are already watching and tinted blue to read as "press this as well"
  rather than "press this next". Two previous attempts put it on a standalone
  icon off to one side, where it was never noticed.

## 5.11

- **Cleave and Heroic Strike now actually appear.** `evaluate()` returns at the
  first usable ability, and both sit at the bottom of their lists — so
  evaluation stopped at Bloodthirst or Whirlwind and never reached them. The
  off-GCD hook was in the right place but could never fire. There is now a
  dedicated pass that looks for queued abilities separately.

## 5.10

- `/er state` reports the current off-GCD suggestion, to distinguish "the
  engine is not producing one" from "it is produced but not displayed".

## 5.9

- **Paging affects every form and stance spec, not just warriors.** The bonus
  bar offset maps to a page for all of them:

  | Form / stance | Offset | Page | Slots |
  |---|---:|---:|---|
  | none | 0 | 1 | 1-12 |
  | Warrior Battle, Druid Bear, Rogue Stealth | 1 | 7 | 73-84 |
  | Warrior Defensive, Druid Aquatic | 2 | 8 | 85-96 |
  | Warrior Berserker, Druid Cat | 3 | 9 | 97-108 |
  | Druid Moonkin / Travel | 4 | 10 | 109-120 |

  That explains Balance reporting slots 109-120 and Fury reporting 97-108 —
  the same bug in two places.

- **The page calculation is now validated before being trusted.** A bar that
  does NOT page still reports buttons 1-12 while a form is active, and
  shifting those would file every key against slots the button never shows.
  The computed slot is checked against the icon the button actually draws,
  and discarded if they disagree.

## 5.8

- **Page resolution now falls back to Blizzard's own answer.** When a bar
  addon exposes no `actionpage` attribute, the page is derived from
  `GetActionBarPage` and `GetBonusBarOffset`. The bonus offset is what makes a
  warrior's bar 1 show slots 73-120: stance 1 gives page 7, stance 2 page 8,
  stance 3 page 9 — which is the 97-108 range that never resolved.
- `/er bars` now prints the live action page, the bar page, the bonus offset
  and which slot range bar 1 is currently showing, so the arithmetic is
  checkable rather than assumed.

## 5.7

- **Paged bars now resolve to the real action slot.** On a paged bar the
  button's `action` attribute is its INDEX (1-12), not the slot it currently
  shows; the real slot is `(page - 1) * 12 + index`. Every key on such a bar
  was being filed against slots 1-12. A warrior in Berserker Stance has bar 1
  on page 9 showing slots 97-108 — which is exactly the range that never
  resolved.
- **The key the bar addon draws is now the primary source.** Bindings can come
  from two places that store them differently: the WoW settings UI writes
  named bindings (`ACTIONBUTTON3`), ElvUI's `/kb` writes click bindings
  (`CLICK ElvUI_Bar1Button5:LeftButton`). Querying one name finds some and
  misses others, which is why it looked random. Whatever the source, the bar
  addon renders the key you actually press, so that label is now preferred
  over a binding lookup.

## 5.6

- **`/er setkey ... =` now clears a key.** The pattern required at least one
  character after the `=`, so the documented way to clear one just printed the
  usage text. `/er setkey` with no arguments now also lists everything you
  have set manually.
- No new keybind detection heuristics. Five versions of those did not solve
  the Fury slots and each one added surface area. The manual override is
  deterministic and is the recommended route where detection fails.

## 5.5

- **The Rotation panel now follows the spec you are playing.** It picked an
  arbitrary spec of your class via `pairs()` order, so a Balance druid could
  open it and be shown Feral's settings with nothing indicating the mismatch.
  Harmless while every class had one spec; wrong as soon as Druid had two.
  It also re-selects when you reopen the panel after changing spec.
- **Victory Rush now requires the Victorious proc.** It only works after you
  kill something, so on a target dummy — where nothing ever dies — it was
  being recommended constantly.
- **Off-GCD abilities have their own indicator.** Heroic Strike and Cleave are
  queued alongside your next global rather than instead of it, so they no
  longer displace the recommendation. They appear on a small icon to the left
  of the queue with their own keybind. This was the biggest known inaccuracy
  in both Warrior specs.

## 5.4

- **Read LibActionButton bars properly.** ElvUI and Bartender are both built
  on LibActionButton-1.0, which keeps the live action slot in
  `_state_action`. The scan only looked at `.action`, so those buttons looked
  like they held nothing — which is the likely reason slots 97-108 never
  resolved on Fury despite being on a visible bar.
- **Added `/er setkey <spell> = <key>`.** A manual override that wins over all
  detection. After this many rounds of inferring keys from bar addons, being
  able to just state one is worth more than another heuristic. `/er setkey
  bloodthirst =` clears it again.
- **Correction to 5.3:** the stance-paging work did not break anything. The
  same six abilities failed before and after; only the wording of the failure
  changed, from "none bound" to "not drawn in this stance", which made it
  look like a regression.

## 5.3

- **Keybinds now rebuild when your stance changes.** ElvUI pages a warrior's
  bars by stance — Battle to page 7, Defensive to 8, Berserker to page 9
  (slots 97-108) — so the slot a button shows changes with the stance, and
  the cached keybind map went stale. Now invalidated on
  `UPDATE_SHAPESHIFT_FORM`, `UPDATE_BONUS_ACTIONBAR` and page changes, plus a
  5 second safety refresh.
- `/er keys` now says "not drawn in this stance" rather than "no bar draws
  these slots" for slots above 72, since that is usually what it means.

## 5.2

- **Keybinds in action slots above 72.** Nothing resolved there, because no
  Blizzard binding header covers bars 7 to 10 and the button-frame scan was
  the only route. On Fury that meant Bloodthirst, Whirlwind, Recklessness,
  Bloodrage, Cleave and Sunder Armor all reported "none bound". There is now
  a slot-to-bar fallback covering all 120 slots via bar addon binding names.
  This is a heuristic — a warrior's bar 1 changes slots with stance, which
  can break the mapping — so it only runs after the button frames.
- `/er keys` now distinguishes "on a bar but nothing bound to it" from "no bar
  draws these slots at all". Different problems, different fixes.

## 5.1  (first round of test feedback)

- **Warrior stances are stances, not buffs** — the same mistake as DK
  presences. `UnitBuff` never sees them, so Fury kept telling you to enter
  Berserker Stance while you were standing in it. Now read from the
  shapeshift bar.
- **Self-buff warnings.** A red line under the icons lists any of your own
  buffs that are not up: armour, shouts, aspects, forms, shields, presences
  and stances. Works out of combat. Toggleable.
- **Fury:** Recklessness now comes before Death Wish — it is the shorter
  buff, so it belongs inside the longer window.
- **Balance:** Moonfire is arcane and Insect Swarm is nature, so they are now
  tied to Lunar and Solar respectively rather than both being refreshed
  whenever they dropped.
- **Arcane:** a Missile Barrage proc no longer requires four Arcane Blast
  stacks before being spent. Requiring that let procs expire unused.
- **Marksmanship:** separate "back to Dragonhawk" threshold, so it no longer
  flips out of Viper the moment mana crosses the same line it entered on.
- **Options:** the Rotation dropdowns now mark which class and spec you are
  actually playing, and the Keybinds section is labelled with the active spec.

## 5.0

- Added the last four specs: **Feral Druid (Cat)**, **Combat Rogue**,
  **Subtlety Rogue**, **Elemental Shaman**.
- **All 23 damage specs are now built.**
- Three of the four have **no source APL** and are reconstructions rather than
  translations. Feral has a source but omits the damage-per-energy model that
  makes the spec work. All four are marked with reduced confidence in
  SPECS.md, and their debatable choices are exposed as settings rather than
  decided silently.
- Added a Confidence column to SPECS.md covering all 23.

## 4.5

- Added **Demonology Warlock** — Decimation and Molten Core reactions around
  a Metamorphosis burst window.
- Added **Beast Mastery Hunter** — the shortest list in the addon; most of
  the damage is the pet, which is not managed.
- Added **Fury Warrior** — Bloodsurge-gated Slam, rage-reserved Heroic Strike.
- Nineteen of twenty-three built. **Every spec with a translatable source is
  now done except Feral Cat.**
- Both Warrior specs share the same known weakness: Heroic Strike and Cleave
  are off-GCD queued abilities and the addon has no concept of off-GCD, so
  they are recommended as though they cost a global.

## 4.4

- Added **Destruction Warlock** — Immolate upkeep feeding Conflagrate and
  Chaos Bolt, with fight-length-based curse choice.
- Added **Frost Mage** — Fingers of Frost and Brain Freeze reactions.
- Added **Marksmanship Hunter** — Chimera Shot refreshing Serpent Sting, with
  optional Aspect of the Viper mana management.
- Added **Blood Death Knight (DPS)** — everything held for Dancing Rune
  Weapon, including runic power since DRW itself costs 60.
- Sixteen of twenty-three specs built. Death Knight and Mage now have all
  three trees; tests assert no two specs of a class claim the same tab.

## 4.3

- Added **Survival Hunter** — Explosive Shot maintenance.
- Added **Enhancement Shaman** — Maelstrom Weapon stacking.
- Added **Fire Mage** — Hot Streak reaction, second spec for the Mage class.
- **All ten classes now have at least one damage spec.** Twelve of twenty-one.
- Added tests for full class coverage and for two specs of one class claiming
  different talent tabs.

## 4.2

- Added **Balance Druid** — Eclipse fishing and spamming, with internal
  cooldown tracking for both Eclipse states.
- Added **Arms Warrior** — first rage spec.
- Every class in the game now has at least one damage spec built.
- Stance dancing is deliberately omitted from Arms; see SPECS.md.

## 4.1

- Added **Affliction Warlock** — DoT maintenance built around the Haunt
  window, with a Drain Soul execute below 26% health.
- Added **Arcane Mage** — Arcane Blast stacking with two configurable mana
  lines.
- Both dropped in without engine changes.
- Strengthened the structural tests: they now check that no two specs of the
  same class claim the same talent tab, that every ability key matches its
  table key, and that an ungated list entry has a real cooldown or cost
  rather than matching a hardcoded list of names.

## 4.0

- Added **Assassination Rogue** — first combo-point spec.
- Added **Retribution Paladin** — first cooldown-queue spec.
- **Generalised resources.** A spec declares `powerType` (mana, rage, energy,
  runic power) and optionally `usesComboPoints`, and the engine enforces the
  costs. Neither new spec needed engine changes beyond this.
- `/er state` reports combo points and current power.
- Marked Shadow Priest, Frost DK and Unholy DK as tested in `SPECS.md`.

## 3.6

- **Fixed a 3.5 regression that broke the Unholy opener.** The "skip an opener
  step if its aura is already up" rule applied to any ability with an
  `applies` field. Blood Strike applies Desolation as a side effect — it is
  cast for the damage and the rune — so all four of its opener steps were
  skipped whenever Desolation happened to be up, and the Unholy opener leads
  with it. The rule is now opt-in and set only on the diseases.
- Added a test asserting the Unholy opener matches the played sequence step
  for step.

## 3.5

- **Opener steps now skip auras that are already up.** The opener is a fixed
  sequence and was reapplying diseases sitting at thirteen seconds, which is
  what made the rotation look stuck on Icy Touch and Plague Strike. A step is
  treated as satisfied if the thing it exists to apply is up with more than
  half its duration left; a dot that is genuinely running low is still
  refreshed.
- `/er state` reports combat time and whether the opener is active, which is
  what identified this.

## 3.4

- **Fixed abilities appearing twice in the projected queue.** The forward
  projection did not carry cast counts into its simulated state, so every
  opener entry read as "never cast" and the opener replayed from step one
  inside the queue. Plague Strike could show at positions 2 and 5 with its
  disease plainly up. Cast counts, cast times and combat time now all carry
  forward, so the projection can hand over from opener to normal priority
  the way the live rotation does.

## 3.3

- **Combat log fallback for debuffs.** If `UnitDebuff` cannot see a disease we
  know we applied and that has not expired, it is counted as up. Prevents an
  aura-scan failure from turning into endless reapplication. `/er state` marks
  which source each dot came from.

## 3.2

- **Fixed dots being cast twice on the pull.** After casting a disease there is
  a gap — server round trip, combat log, next aura scan — before the debuff
  registers. The priority saw "no disease" and recommended the same one again.
  An ability that applies an aura is now suppressed for a short grace period
  after being cast, until the aura actually appears. Applies to every spec.
- **Howling Blast is now gated on a Rime proc** in AoE as well as single
  target. Off-proc it costs a frost rune that Obliterate wants. Toggleable.

## 3.1

- **Relaxed the "is this debuff mine" check.** It required `unitCaster` to be
  `"player"`, but 3.3.5 frequently reports nil for units outside your group,
  so a plainly ticking disease read as absent and the addon kept saying to
  reapply it. Now only rejects when the client names a different caster.
- Added `/er dots` — dumps every debuff on the target with ID, caster and
  timer, alongside what the addon is looking for and whether it found it.

## 3.0

- **Frost: diseases were falling off.** The list used Pestilence for upkeep,
  which only refreshes with **Glyph of Disease**; without it Pestilence merely
  spreads. Diseases expired, Icy Touch and Plague Strike then needed frost and
  unholy runes that Obliterate had already spent, and the priority fell
  through to Blood Strike — which looked like Blood Strike was ranked too
  high. It was not; the spec was rune starved. Glyph is now detected.
- Diseases now refresh **before** they drop (default 3s), not after, so the
  runes are still available.
- **Keybinds: macros disambiguated by icon.** A macro naming several spells
  matched all of them, so Icy Touch and Plague Strike both resolved to the
  same slot. A macro whose texture matches the spell now outranks one that
  merely mentions it.
- `/er state` reports rune state, runic power and glyph detection.

## 2.9

- **Bone Shield raised** above disease upkeep in the Unholy priority. It costs
  no runes, only a global, and is a damage increase as well as mitigation, so
  a free one-minute cooldown belongs above rune spenders. Added a toggle.
- Added `SPECS.md` — all 21 WotLK damage specs, with separate columns for
  built, tested in game, and whether a source APL exists to translate from.
- Added `README.md` and `LICENSE` (GPL v3, required as a derivative work of
  Hekili).

## 2.8

- **AoE: Pestilence no longer spams.** It was gated on "both diseases up on
  the current target", which is true on nearly every global, so at three
  enemies it was recommended continuously. Pestilence is a spread, not a
  filler.
- Added **per-target debuff tracking** from the combat log, so the addon knows
  how many enemies actually carry each disease. Pestilence now fires only
  while diseased targets are fewer than engaged enemies — restoring the
  source's `active_dot < active_enemies` condition that had been dropped.
- Rewrote the Unholy AoE list against the source's Death and Decay variant.
- `/er state` reports spread counts per debuff.
- Added a structural test rejecting ungated AoE entries that could repeat.

## 2.7

- **Presences are stances, not buffs.** `UnitBuff` never sees them, so every
  presence check was permanently false and the addon kept recommending a
  presence you were already standing in. Now read from `GetShapeshiftForm`.
- **Gargoyle read from its aura** where the server provides one, falling back
  to the cast timestamp only when absent. No longer suggested while already
  summoned.
- `/er state` shows presence, pet and enemy count.

## 2.6

- **Fixed `blood_presence` pointing at Frost Presence.** The ID was `48263`;
  Blood Presence is `48266`. Reported three times before being found, because
  the symptom was "Frost Presence" while the addon contained no such key —
  the label was right and the ID underneath was wrong.
- Added **spell ID verification**: each ability's resolved name is compared
  against its key, so an ID that is valid but points at the wrong spell is
  caught at load. Available on demand as `/er verify`.

## 2.5

- Cooldown swipe now also covers **casts and channels in progress**, scaled
  over the whole cast so it tracks like a cast bar.

## 2.4

- **Removed Frost Presence entirely** from the Frost DK spec. It is the tank
  presence; a Frost DPS runs Blood or Unholy.
- **Rewrote both DK openers** from how they are actually played, replacing the
  source sequences which did not match.
- Raised the opener window to 40s — both sequences run 15–17 globals and were
  being cut off partway.

## 2.3

- **Fixed spec detection.** It returned the first spec whose `IsActive` passed,
  so registration order broke ties and a Frost priority could load for an
  Unholy character. Now picks the spec whose talent tab holds the most points.
- Added **opener support**: entries carry a cast target, counted from the
  combat log and reset on entering combat.
- Added **enemy counting** from the combat log — distinct GUIDs damaged in the
  last five seconds, since 3.3.5 has no nameplate API.
- Added **AoE lists** for all three specs, and `/er aoe auto|single|aoe` with
  a force-single override for fights like Blood Princes.
- Added `/er spec`.

## 2.2

- **Two-way presence swap** for Unholy, on by default. The source list only
  ever swaps *back* to Blood and assumes you were already in Unholy when
  Gargoyle came up — true in a sim, false in a fight.

## 2.1

- Added **cooldown swipe** on the recommendation icons, using the same widget
  as the default action bars. Driven by whichever of spell cooldown, runes or
  the global is actually blocking.
- **Fixed rune timing.** `RunesReadyIn` returned the longest remaining rune
  rather than the soonest moment the cost becomes payable.

## 2.0

- **Unholy now branches on your build** rather than assuming the Ghoul Frenzy
  and Master of Ghouls one: Pestilence when Glyph of Disease is detected, Bone
  Shield when talented, Raise Dead when you have no pet.
- Added glyph and pet detection.
- `/er state` reports live disease timers and pet status.

## 1.9

- **A direct spell placement now outranks a macro that merely mentions it.**
  One multi-spell macro was claiming itself as the home of seven abilities.
- Tightened `#showtooltip` matching to its own line.

## 1.8

- Added **Unholy Death Knight**.
- Added a **generic cooldown layer**: an ability tagged `majorCD` gets a global
  toggle (`/er cd`), its own toggle, and a minimum time-to-die. Options
  generates the toggles by inspecting the spec, so it knows nothing about any
  particular spell.
- The icon border greys out while cooldowns are suppressed.

## 1.7

- **Fixed the display position resetting** on size change — two causes. The
  full anchor is now saved, since `StopMovingOrSizing` re-anchors the frame;
  and resizing happens in place rather than recreating frames, which was
  leaking five per adjustment and re-anchoring from defaults.
- Fixed icons 4 and 5 being nearly invisible (45% and 35% opacity).
- Guarded `BuildDisplay` against running twice.

## 1.6

- Keybind pane is **spec-agnostic** — it had the Priest spell keys hardcoded,
  so it was blank for every other spec.
- Unresolved spell IDs are now reported loudly instead of silently skipped.

## 1.5

- Pestilence refresh window follows **active presence**.
- Dual wield detection; Killing Machine dump as an opt-in.
- **Correction:** an earlier note claimed one Frost list was the two-handed
  variant. The two source lists differ only in the Pestilence threshold, and
  UH/BL refer to presence, not weapon setup.

## 1.4

- Added **Frost Death Knight**.
- Added the **rune model**: six slots, three types, Death Runes substituting
  for any. Cost is solved by allocation rather than counting, so a Death Rune
  is never wasted on a cost a natural rune could cover.

## 1.3

- **Reverted the 1.1 rejection rule**, which had broken three working keybind
  slots. Ranking now uses frame *origin* rather than visibility, since
  `IsVisible` proved unreliable — under a bar addon it is Blizzard's own bars
  that linger hidden with stale labels.

## 1.2

- Real bindings are trusted regardless of frame visibility. Visibility only
  ever mattered for rendered text.

## 1.1

- Added confidence scoring for keybind sources. *(Introduced a regression
  fixed in 1.3.)*

## 1.0

- **Every slot holding a spell is now considered**, preferring one that
  resolves. Previously the first match won, so a copy on a paged bar with no
  rendered button beat the real, bound one — and rebinding changed nothing.
- Fixed dropdown captions remaining visible after collapsing a section.

## 0.9

- **The global frame scan now always runs.** It was gated behind "only if the
  named bars found nothing", and Blizzard's hidden bars always found plenty,
  so bars with no Blizzard binding header (page 2, bars 7–10) were never
  examined.

## 0.8

- Macro parsing handles rank suffixes, conditionals and castsequence.
- Icon-texture fallback when a name cannot be resolved.
- Per-spell keybind diagnosis explaining *why* a lookup failed.

## 0.7

- **Collapsible sections** and a roll-up-to-title-bar button.
- Moved the keybind diagnostic into the options window.

## 0.6

- Fixed dropdowns rendering blank — `SetSelectedValue` sets the value but not
  the displayed text, and the selection was chosen after construction.
- Stopped filtering `-` as junk. It is a real key.
- Added `/er keys`.

## 0.5

- **Options window** with class and spec dropdowns, resizable.
- **Fixed keybind abbreviation eating `=`.** Unordered substitutions meant
  `ALT-=` became `a-`. Modifiers are now stripped from the front only.
- Added ElvUI binding names (`ELVUIBAR<n>BUTTON<i>`), without which bars 2+
  reported nothing bound.
- Added a version marker and `/er version`.

## 0.4

- First options window. Display mode, lock, icon and keybind text size.
- **Shadowfiend gated on mana** (default 50%). The source casts it on cooldown,
  which is a sim assumption — the robot never runs dry.

## 0.3

- **Fixed saved variables overriding new defaults.** The merge only filled keys
  that were entirely nil, so changing a default inside an existing table did
  nothing. Added a migration and `/er reset`.
- Keybind auto-discovery for unrecognised bar addons.

## 0.2

- Recommendation **queue** with forward projection.
- **Keybinds** on icons.
- **Mind Blast made a setting, default off.** The imported `flay_over_blast`
  formula produces spellpower thresholds of 7,600–86,000 against a realistic
  ceiling near 2,400, so it never discriminates and always answered yes.

## 0.1

- Initial build: compatibility shims, present-moment state model, priority
  engine, icon display, Shadow Priest.
- Offline test harness with a mock 3.3.5 client that deliberately omits every
  API added after that patch.
- Fixed on the way in: `GetNetStats` returns three values on 3.3.5, not four,
  which would have silently poisoned every latency term; and spell ranks,
  which modern WoW does not have and the source therefore never handles.
