# ElvinUIToggle Changelog

## v0.3
- **ElvinCDs**: switched from scanning for dynamically-numbered per-player
  frames (unreliable - IDs change constantly and the scan was catching
  internal sub-pieces like tooltip textures) to using the addon's own
  `/ecd show` and `/ecd hide` commands. Button now shows correct
  green/red state and works properly with Hide All / Show All and templates.
- **CD Used**: switched from an unreachable/anonymous frame to using
  the addon's own `/cu show` and `/cu hide` commands. Same fix as ElvinCDs.
- **ElvinRotation**: new toggle added, using `/er show` and `/er hide`.
- **PallyPower**: new toggle added (`PallyPowerAnchor`, `PallyPowerAuto`,
  `PallyPowerAura`).
- **Player Buffs** and **Player Debuffs**: new toggles added
  (`ElvUIPlayerBuffs`, `ElvUIPlayerDebuffs`).
- **VuhDo**: new toggle added (`VdAc1`).
- **Minimap**: new toggle added (`MinimapCluster`).
- **Pet/Player/Target Frame**: new toggles added (`ElvUF_Pet`,
  `ElvUF_Player`, `ElvUF_Target`).
- Fixed ElvUI action bar frame names (`ElvUI_Bar1`-`ElvUI_Bar6`,
  `ElvUI_BarPet`) - originally guessed without the underscore/wrong name
  and never actually found the real frames.
- Fixed Chat toggle to also hide the background panels and tab buttons
  (`LeftChatPanel`, `RightChatPanel`, `ChatFrame1Tab`-`5Tab`,
  `CU_ChatFrameTabButton`) instead of just the text frame, without
  taking CD Used down with it (removed `CU_ChatFrame` /
  `CU_ChatFrameClickAnywhereButton`, which turned out to be large
  invisible click-catchers sitting over CD Used's window).
- Fixed Details toggle to hide all of its sub-windows
  (`DetailsUpFrameInstance1`, `Details_SwitchButtonFrame1`,
  `Details_GumpFrame1`, `Details_WindowFrame1`, `DetailsBaseFrame1`,
  `DetailsRowFrame1`), not just the main window.
- Fixed a race condition where showing a previously-hidden element could
  get immediately undone by the addon's own anti-flicker protection
  (saved state was being written after the Show()/Hide() call instead
  of before it).
- Removed the reload-UI keybind feature (didn't work reliably, pulled
  per request).
- Command-driven toggles (blind toggle-only, no readable state) are
  excluded from Hide All / Show All and templates, since blindly firing
  a toggle command could turn something on instead of off.

## v0.2
- Added in-game UI panel: grid of toggle buttons, Hide All / Show All,
  configurable slash command with a safety fallback (`/elvinuit`)
  that always works, template save/apply/delete list.
- Alpha + mouse-disable (instead of `Hide()`) used for action bars so
  keybinds keep working while "hidden".

## v0.1
- Initial version: slash-command-only toggle/template system for
  ElvUI action bars, chat, Details, and CD tracking addons.
