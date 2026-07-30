# ElvinRotation

A rotation and priority helper for World of Warcraft **3.3.5a** (WotLK).
Suggests the next ability to press, with a short projected queue, keybinds
and cooldown swipes.

Display only. It does not and cannot automate casting — 3.3.5 protects the
functions that would be required, and automation is against the rules of
every server worth playing on.

## Specs

Shadow Priest, Frost Death Knight, Unholy Death Knight.
See [SPECS.md](SPECS.md) for full coverage and testing status.

## Install

Drop the `ElvinRotation` folder into `Interface\AddOns\`.
Delete any previous copy rather than extracting over it — a stale file can
shadow a new one.

## Commands

| Command | Purpose |
|---|---|
| `/er options` | Settings window |
| `/er version` | Version, and whether all files loaded |
| `/er spec` | Talent points and which spec is active |
| `/er verify` | Check every spell ID resolves to the right spell |
| `/er keys` | Keybind resolution per ability |
| `/er state` | Live resources, dots, presence, pet, enemy count, queue |
| `/er cd` | Toggle major cooldowns |
| `/er aoe <auto\|single\|aoe>` | Target mode. `single` for fights like Blood Princes |
| `/er lock` | Lock or unlock the icon position |
| `/er reset` | Clear saved settings |

## API for other addons

The display can be hidden by another addon — a boss mod during a cutscene, a
UI manager, anything.

```lua
local ER = _G.ElvinRotation
if ER then
    ER:HideDisplay("MyAddon")   -- hide
    ER:ShowDisplay("MyAddon")   -- release
end
```

Pass a **source name**. Hides are tracked per source, so two addons can both
ask for a hide and neither reveals the display by releasing first — it stays
hidden while any source still holds a request.

| Call | Does |
|---|---|
| `ER:HideDisplay(source)` | Request a hide |
| `ER:ShowDisplay(source)` | Release your request |
| `ER:SetDisplayHidden(bool, source)` | Either, from a boolean |
| `ER:ToggleDisplay(source)` | Flip your own request. Returns `ok, nowHidden` |
| `ER:IsDisplayHidden()` | Is anything hiding it |
| `ER:GetHideSources()` | Sorted list of who |
| `ER:GetDisplayFrame()` | The frame itself, or nil before load |
| `ER:RegisterCallback(event, fn, owner)` | `"hidden"` or `"shown"`, called with the source |

An external hide is **runtime only** — never written to saved variables — so
hiding the display during an encounter cannot silently switch it off for good.
It also overrides everything else, including the missing-self-buff warning,
which is otherwise allowed to force the frame open.

A callback that errors is caught and reported rather than breaking the addon.

`ToggleDisplay` is scoped to **your** source: it will not release a hide some
other addon is holding, so two addons sharing the display cannot override each
other by toggling.

`/er hide`, `/er show` and `/er hidetoggle` do the same from chat, useful for
testing an integration.

## Design

- **Present-moment state, not simulation.** Hekili's `State.lua` is 7,447
  lines because it simulates the fight forward. This snapshots now, and
  projects a few steps only for the queue display. That is why the whole
  addon is roughly 2,000 lines.
- **Priorities are Lua predicates**, hand-translated from SimulationCraft
  `.simc` files rather than parsed at runtime.
- **Specs are self-contained.** A spec file declares its abilities, auras,
  priority lists and settings, and registers itself. Adding a class touches
  no shared code.
- **Compatibility shims are documented.** `Compat.lua` notes which patch
  introduced each thing it replaces, because most of the difficulty in this
  project was API drift, not rotation logic.

## Testing

An offline harness in `test/` runs the addon against a mock 3.3.5 client
that deliberately omits every API added after that patch.

```
lua5.1 test/run.lua
```

It catches API misuse, wrong spell IDs, keybind resolution and structural
mistakes in priority lists. It cannot tell you a rotation is wrong — only a
player can.

## Status

[SPECS.md](SPECS.md) tracks which specs are built and tested.
[TODO.md](TODO.md) tracks what is still open.

## History

See [CHANGELOG.md](CHANGELOG.md). Worth reading if you plan to add a spec —
almost every entry is a bug in client integration rather than rotation logic,
and the same traps will be waiting.

## Adding a spec

A spec file is self-contained: it declares its abilities, auras, priority
lists and settings, then registers itself. No shared code needs touching.

1. Copy the closest existing spec in `Specs/`.
2. Set `class`, `tab` (1-3, matching the talent tree), and a resource:
   `powerType` (0 mana, 1 rage, 3 energy, 6 runic power) and optionally
   `usesComboPoints`, `usesRunes`, `usesPresence`, `usesStance`.
3. Fill in `abilities` and `auras` with spell IDs.
4. Write `lists.single`, `lists.aoe` and `lists.default`.
5. Add the file to `ElvinRotation.toc`.
6. Run `lua5.1 test/run.lua` — structural checks will catch a missing list, a
   duplicated talent tab, a key that does not match its table key, and an
   ungated entry that could spam.
7. In game, run `/er verify` **first**. It catches a spell ID that resolves to
   the *wrong* spell, which looks exactly like a bad priority.

## Credits and licence

Licensed **GPL v3**, because it is a derivative work of
[Hekili](https://github.com/Hekili/hekili) (GPL v3), from which the action
priority lists were translated.

Priority data ultimately derives from [wowsims](https://wowsims.github.io/wotlk/),
via Hekili's `wrath` branch. Those lists target Wrath Classic 3.4.x rather
than original 3.3.5a, and have needed correction in several places — see
SPECS.md.

See [LICENSE](LICENSE).
