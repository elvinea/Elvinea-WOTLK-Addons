# ElvinKeybinds

WotLK 3.3.5 (Warmane) addon that standardizes action bar keybinds on demand,
via an in-game config window rather than running automatically on login.

## What it does

Clicking **Standardize Keybinds** in the `/ekb` window:

1. Clears every existing binding on action bars 1-4 and the bonus/shapeshift
   bar (`ACTIONBUTTON1-12`, `MULTIACTIONBAR1-4BUTTON1-12`,
   `BONUSACTIONBUTTON1-12`) — regardless of what set them (ElvUI, Bartender,
   Dominos, plain Blizzard UI), since they all go through the same Blizzard
   binding API.
2. Applies a fixed layout to bars 1-3:
   - Bar 1 (`ACTIONBUTTON1-12`) → `1 2 3 4 5 6 7 8 9 0 - =`
   - Bar 2 (`MULTIACTIONBAR1BUTTON1-12`) → `ALT-1 ... ALT-=`
   - Bar 3 (`MULTIACTIONBAR2BUTTON1-12`) → `SHIFT-1 ... SHIFT-=`
3. Saves the result to the current character's binding set.

**Clear Only** just does step 1, without reapplying the layout.

## Usage

`/ekb` toggles the config window (Escape also closes it). Nothing runs
automatically — you choose when to apply it on each character.

## Files

- `ElvinKeybinds.toc`
- `ElvinKeybinds.lua`
- `CHANGELOG.md`

See CHANGELOG.md for version history.
