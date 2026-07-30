# ElvinKeybinds Changelog

## 0.2.2
- Fixed `Clear failed - attempt to call global 'ClearBinding' (a nil value)`.
  `ClearBinding` is a retail-only API and doesn't exist in the 3.3.5 client.
  Unbinding a key now uses `SetBinding(key)` with no command argument, which
  is the correct 3.3.5 way to clear a key.

## 0.2.1
- Fixed `/ekb` doing nothing at all. The config window was built with
  `BasicFrameTemplateWithInset`, a retail-only frame template that doesn't
  exist in 3.3.5; `CreateFrame` erroring on it silently aborted the whole
  file before the slash command registered. Panel is now built manually
  (backdrop + close button) instead of relying on a retail template.
- Raised the panel to `DIALOG` frame strata so its buttons can't be
  click-blocked by other UI underneath.
- Wrapped both button actions in `pcall` so any future error prints a
  message in chat instead of failing silently.
- Added an `InCombatLockdown()` guard with a chat warning.

## 0.2.0
- Replaced the automatic "run on every login" behaviour with an in-game
  config window (`/ekb`) containing two buttons: **Standardize Keybinds**
  and **Clear Only**. Nothing changes bindings until a button is clicked.

## 0.1.0
- Initial version. Clears all action bar bindings (bars 1-4 + bonus bar)
  and applies bars 1-3 to `1-=`, `ALT-1-=`, `SHIFT-1-=`, running
  automatically on `PLAYER_LOGIN`.
