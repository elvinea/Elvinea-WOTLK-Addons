# ElvinRaidPlan (v0.4.3)

A drag-and-drop raid strategy planner for WotLK 3.3.5 (Warmane), inspired by
raidplan.io. Lay out a boss arena, drop icons and shapes onto it, and save a
plan per boss/phase.

## Install
Copy the whole `ElvinRaidPlan` folder (with its `textures` and `maps`
subfolders) into `Interface\AddOns\`, so you have
`Interface\AddOns\ElvinRaidPlan\ElvinRaidPlan.toc`.

## Open it
`/erp` or `/raidplan` toggles the window. Escape or the X closes it.

## Palette (left strip)
Press and drag any item onto the canvas, then release to drop it:
- Shapes: square, circle, wedge/cone, arrow
- Text label
- All 8 raid target markers
- All 10 class icons

## Working with placed objects
- **Move:** left-click and drag.
- **Select:** click it — a gold outline appears with a resize handle (corner)
  and a rotate handle (above). Drag the handles. Click empty canvas to deselect.
- **Resize:** the corner handle, or mouse-wheel over the object.
- **Rotate:** the handle above the object (shapes/markers/class icons only).
- **Delete:** right-click.
- **Recolor a shape:** shift + right-click cycles colors.
- **Edit text:** double-click a text label.

## Backgrounds
- **Color** cycles a few flat panel colors.
- **Map...** opens the picker: Icecrown Citadel -> pick a boss to load its
  arena as the background.

## Plans (top row)
- **Open** — browse and load any saved plan (current one has a green arrow).
- **New** — create a fresh plan.
- **Save** — store the current canvas to the named plan.
- **Delete** — remove the named plan (asks to confirm; keeps at least one).
- **Rename** — type a new name in the box and press Enter.

Plans are saved to `WTF\Account\<account>\SavedVariables\ElvinRaidPlan.lua`.
The game writes this file on **logout or /reload**, so log out or reload to be
sure changes are kept — don't just force-close the client.

## Maps included
- **Icecrown Citadel** — all 12 bosses
- **Trial of the Crusader** — Coliseum arena (Beasts, Jaraxxus, Champions,
  Twin Val'kyr) + Anub'arak ice pit
- **Ulduar** — all 14 bosses (map/boss pairings matched by best guess; some may
  need swapping, and Algalon has no map yet)
- **Eye of Eternity** — Malygos

If a map appears under the wrong boss, it's a quick label fix. Remaining raids
(Naxxramas, Onyxia, VoA, Obsidian Sanctum, Ruby Sanctum) can be added the same
way.

## Notes
- Plans are account-wide; there's no cross-player sharing yet.
- No undo or multi-select yet.
- Class icons are bundled emblems (the client's class-icon atlas shows the
  wrong art on this build).
