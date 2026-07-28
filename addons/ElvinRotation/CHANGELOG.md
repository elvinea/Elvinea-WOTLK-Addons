# Changelog

All notable changes to ElvinRotation.

Written honestly: most entries are bug fixes, and most of those bugs were
found by a player noticing a recommendation looked wrong rather than by any
test. That pattern is worth preserving in the record.

---

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
