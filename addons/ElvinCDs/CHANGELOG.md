# Changelog — !ElvinCDs

All notable changes to this fork of **!ElvinCDs** are documented here.

This project loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased] — Tower layout, class colours & customisation

Base version: `0.4b`.

### Added

- **Locked tower layout.** All spell windows now behave as a single tower:
  dragging moves the whole set together, and they keep their relative
  positions instead of being placed independently.
- **Automatic vertical stacking.** Windows stack one under another instead of
  overlapping on the same spot, and the stack reflows automatically when a
  window grows or shrinks (for example when a second player of the same class
  joins the group).
- **Multi-column support.** A column can hold a set number of windows before
  wrapping into a new column. Configurable in the options panel:
  - *Max per Column* — how many windows a column holds before a new one starts
    (`Off` = a single continuous column).
  - *Grow Tower Upward* — stack windows upward instead of downward.
  - *New Columns To Left* — add extra columns to the left instead of the right.
- **Class grouping.** Windows are ordered by class and a class is never split
  across a column break — if a class does not fit in the remaining space it
  moves to the next column as a whole.
- **Class-coloured bars.** "Ready" bars now use each player's class colour
  instead of a single green. On-cooldown bars stay red and dead players stay
  grey.
- **Spell icon on bars.** The spell icon is shown on the right of each bar.
- **Customisable request message.** A text box in the options panel sets the
  message used for the "use on me" click action. The same text is used for both
  the right-click menu label and the whisper that gets sent, so they always
  match. Use `{spell}` as a placeholder for the spell name
  (default: `Please use {spell} on me`).

### Changed

- **Removed the window title row.** The spell-name header is gone; spells are
  now identified by the icon on each bar.
- **Moving the tower** is now done by holding **Shift** and dragging any bar
  (there is no longer a title bar to grab). A normal click still opens the
  whisper menu.
- **Middle-click a bar** toggles the window lock (previously on the title bar).
- **Alt+click a bar** opens that spell's log (previously on the title bar).
- Bars no longer display raid-target markers; that space is now used for the
  spell icon.

### Fixed

- **Snap-to-edge bug.** Dropping the tower near the middle of the screen no
  longer jumps to a screen corner. Movement now tracks the cursor directly
  instead of relying on the game's frame anchoring, which was re-anchoring to
  the nearest corner on release.
- **Overlapping windows.** Windows with several player bars (a spell used by
  multiple people) could be overlapped by the next window in the tower. Each
  window's height is now calculated directly from its bar count and every window
  is placed at an explicit position, so stacking no longer depends on
  frame-height propagation between anchored frames.
- **Doubled names / stray empty bars.** Leftover bar frames from a previous
  layout stayed attached to a window when it was rebuilt, so a fresh bar could
  render on top of a stale one (doubled text) and old bars could linger as empty
  rows. All existing bars are now hidden before the current set is drawn.

### Removed

- The old per-window right-click **"hide window"** action, which lived on the
  now-removed title bar. (Can be reintroduced on a modifier or in the options
  panel if needed.)

### Notes / known rough edges

- Several layout values are fixed defaults that may need tuning in-game:
  the horizontal gap between columns (8px), the vertical gap between windows
  (`bar spacing + 4`), and the bar icon size (`bar height − 2`).
- The custom message applies to the main "use on me" action (menu label, its
  whisper, and Ctrl+click). The "Use Now" wording for blind/self-cast spells and
  the "on &lt;player&gt;" targeting submenu still use their default phrasing.
- Class grouping keys off the spell's class in the addon's spell data. Custom
  spells that are not part of a built-in class list are grouped together at the
  end of the tower.
- After updating, run `/ecd reset all` once to clear any window positions saved
  by older versions so the new tower layout starts from a clean state. A
  `/reload` also clears any accumulated leftover bar frames.
