# Changelog

All notable changes to the GemPriceTracker addon.

## 1.0.0

Initial release — ported the "Gem Prices" tab from `Heros.xlsm` into an in-game addon.

- Raw Materials section: editable prices for the 4 Eternals + 6 uncommon feeder gems.
- Cut Gems section: the 6 rare gems (Ametrine, Cardinal Ruby, Dreadstone, Eye of Zul,
  King's Amber, Majestic Zircon), each wired to its real material recipe. Mat cost and
  profit recalculate automatically as raw material prices change.
- Gem Kit Calculator: gold budget field, per-gem include checkbox, optional manual qty
  lock, auto-distributes remaining budget in stacks of 20 across unlocked gems.
- Small Gem Kit: quick qty x price calculator for the feeder gems themselves.
- All four sections are independently collapsible.
- All data persists via SavedVariables (`GemPriceTrackerDB`), account-wide.
- Slash commands: `/gpt`, `/gemtracker`.

## 1.0.1

- Fixed edit boxes rendering with a floating, disconnected border cap off to the right
  of the typed number. Cause: Blizzard's `InputBoxTemplate` border pieces weren't
  tracking the box's actual width. Replaced with a hand-drawn backdrop box sized
  exactly to fit, and shrank the box widths to match typical value lengths.

## 1.0.2

- Fixed a stray gold highlight bar appearing across the full section width on hover.
  Cause: a stretched `HIGHLIGHT` texture on the section header not designed for that
  width. Replaced with a simple text-brighten-on-hover effect.
- Made the main window resizable via a drag handle in the bottom-right corner.
  Window size (and position) now save between sessions.
