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

## Credits and licence

Licensed **GPL v3**, because it is a derivative work of
[Hekili](https://github.com/Hekili/hekili) (GPL v3), from which the action
priority lists were translated.

Priority data ultimately derives from [wowsims](https://wowsims.github.io/wotlk/),
via Hekili's `wrath` branch. Those lists target Wrath Classic 3.4.x rather
than original 3.3.5a, and have needed correction in several places — see
SPECS.md.

See [LICENSE](LICENSE).
