# GearCheck — Changelog

A raid gear/gem/enchant/talent auditor for **WotLK 3.3.5a (Warmane)**.

Scans yourself, a target, or the whole raid and shows, in one pop-up window, a
collapsible row per player: **GearScore**, hard issues (empty sockets, missing
enchants, off-role gems), **off-BiS / pre-BiS** items, and a **talent** verdict.
Click a player to expand their gear; click any item (or the Talents line) for a
per-item / per-talent breakdown.

Reference data (BiS items, acceptable gems/enchants, tier versions, talent builds)
is generated from the guild spreadsheet into `Items.lua` and `Talents.lua`.

## Commands
`/gc self` · `/gc target` · `/gc raid` · `/gc check` · `/gc show` · `/gc hide` ·
`/gc clear` (window button) · `/gc talents` (grade + spec debug) ·
`/gc dump <slot> [target]` (print an item's raw tooltip lines/colours) ·
right-click a player row to cycle their role.

---

## v2.8
- Talent line render is now guarded — if anything errors it shows an inline
  "render error" instead of silently dropping the line (makes load/render issues
  obvious). Version number shown in the window title.

## v2.7
- Talent reading now resolves and passes the **active talent group**, fixing empty
  or off-spec reads on inspected and dual-spec players.
- Talent grading wrapped so an error can never abort a scan/render.
- `/gc talents` now prints the detected spec and grades the build in chat.

## v2.6 — Talent check
- Reads each player's talents (self + inspected) and grades them against a
  per-spec **reference build** (`Talents.lua`, generated from the spreadsheet's
  *Talent Builds* tab).
- New **Talents** dropdown per player: overall `correct` / `N wrong` verdict,
  expandable to a per-talent list (`v Talent 5/5` right, `x Talent 3/5` wrong,
  `x Talent 2 (not in build)` for off-build points). Talent-wrong count also shown
  in the player header. Specs without a reference show "no reference".

## v2.5
- Profession enchants are now matched **by name** off the tooltip (they render as a
  red name line, not a stat line): Lightweave / Swordguard / Darkglow Embroidery,
  Flexweave Underlay, Springy Arachnoweave, Hyperspeed Accelerators, Nitro Boosts,
  Reticulated Armor Webbing. Fixes Tailoring cloak enchants reading as "missing".

## v2.4
- Raid inspection **polls** for the data instead of relying only on
  `INSPECT_TALENT_READY` (which Warmane frequently drops), and **spaces requests**
  out to avoid the server silently throttling them. Big reduction in in-range
  timeouts.

## v2.3
- `/gc dump <slot> [target]` debug command — prints every tooltip line with its RGB
  colour plus the raw link enchant/gem IDs, for diagnosing enchant/gem parsing.

## v2.2
- Proc / profession / DK-rune enchants are exempt from the "wrong enchant for role"
  check (stops embroideries being flagged wrong).
- Engineering enchants (Hyperspeed, Nitro) are detected even when their `Use:` line
  renders **red** on inspected items.
- Gems can be read from the tooltip by their **stat line** (`GEM_BY_STAT`) when the
  link only carries enchant-ids instead of gem item-ids (common on inspected units).

## v2.1
- Raid scan **retries** players who time out / are out of range across multiple
  passes (they move into range and the one-at-a-time inspect frees up) instead of
  giving up after one pass.

## v2.0 — Consolidated baseline
- **GearScore** computed per item and shown in each player's header (+ item level).
- Gem reading driven by `GetItemGem` with a wrong-name guard, plus a tooltip
  fallback for inspected units whose link is stripped of gem data.
- Reworked inspection: one-at-a-time queue that waits for both talent and inventory
  data before scanning.
- Enchantability decided by the item's `INVTYPE` rather than hardcoded slot IDs.
- **Gems validated by name only** against a master acceptable-gem list.
- Hit-hybrid gem names corrected to **Ametrine**; **Nightmare Tear** treated as a
  prismatic, not a meta.
- **pre-BiS vs off-BiS** determined by the item's **Heroic tag + name**, not item
  level (Warmane item levels are unreliable). Ranged/relic slot excluded (no HC
  relics).
- Belt buckle presence checked; empty sockets flagged as hard errors.

## v1.x — Early builds
- **v1.0** — Initial addon: scan gear/gems/enchants for self / target / raid;
  pop-up window with a collapsible row per player; slash commands.
- **v1.1–v1.9** — per-item dropdowns; **item-BiS checking** generated from the guild
  spreadsheet (`Items.lua`); enchant **name + stats** display; **manual role
  override** (right-click a row); **Clear** button; **resizable** window;
  **Dragon's Eye** (JC) gems accepted; robust gem reading (link IDs + item-cache
  priming + timed retries); reliable tooltip-based empty-socket detection; and a
  string of enchant/gem detection fixes (socket-hint exclusion, "Heroic" tag no
  longer mistaken for an enchant, etc.).
