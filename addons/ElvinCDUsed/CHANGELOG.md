# ElvinCDUsed Changelog

Fork/customization of the third-party "Cooldown Used" addon by Kiki/Espêrance
(Warmane WotLK 3.3.5). Base version 3.1.

## Unreleased

- Renamed the addon from `CDUsed` to `ElvinCDUsed` — folder name, `.toc` file
  and `Title` field, `GetAddOnMetadata` lookup, chat print prefix, and the
  icon/draghandle texture paths were all updated to match.
- Removed "Log by Espêrance" from the main window's tab title; it now reads
  `CD Used - v<version>`.
- Added explicit `/cu show` and `/cu hide` commands. Previously any command
  that wasn't `help` or `announce` (including a bare `/cu`) just toggled the
  window's visibility. The toggle behavior is kept as the fallback for a bare
  `/cu`, but `show`/`hide` now let you set the state directly. `/cu help`
  lists both.
