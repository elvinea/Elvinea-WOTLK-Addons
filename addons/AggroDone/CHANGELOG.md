# AggroDone Changelog

## 1.2 - 2026-07-15
- Added a proper Interface Options panel (Interface Options > AddOns >
  AggroDone), with a dropdown for whisper mode (full/damage-only/off) and
  a checkbox per scenario (Tricks on you, Tricks by you, MD on you, MD by
  you). Reflects and edits the same AggroDoneDB settings as the /ad
  whisper commands.
- New `/ad config` (or `/ad options`) command opens the panel directly.

## 1.1 - 2026-07-15
- Added whisper controls to reduce chat-flood risk on fast pull chains:
  - `/ad whisper mode full|damage|off` - switch between a full timing+damage
    report, a bonus-damage-only message, or no whisper at all (window log
    still records everything regardless).
  - `/ad whisper totonme|totbyme|mdonme|mdbyme on|off` - mute whispers for
    a specific scenario (e.g. just "Tricks used on you") while leaving the
    others active.
  - `/ad whisper status` - print current mode and per-scenario settings.
- Settings persist in AggroDoneDB across sessions.

## 1.0 - 2026-07-15
- Initial release.
- Tracks Tricks of the Trade (57934) and Misdirection (34477) casts via
  COMBAT_LOG_EVENT_UNFILTERED.
- Judges timing against combat start (PLAYER_REGEN_DISABLED); good/late
  threshold set at 3s, configurable via GOOD_TIMING_THRESHOLD.
- Tallies caster damage for a 6s window after cast.
- Whispers the other party (caster <-> target) with a timing + damage
  report when the player is directly involved.
- Logs every tracked event (involved or not) to a draggable popup window
  (ScrollingMessageFrame) for players not part of the exchange.
- Slash commands: /ad, /ad show, /ad hide, /ad clear.
