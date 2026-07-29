--[[ ElvinRotation - Compat.lua
     3.3.5a compatibility shims. Load FIRST.

     Everything here exists because the reference material (Hekili's
     Wrath Classic build) targets a much newer client. Each shim notes
     which patch introduced the thing it replaces.
--]]

local ER = _G.ElvinRotation or {}
_G.ElvinRotation = ER

ER.Compat = {}
local C = ER.Compat

--------------------------------------------------------------------
-- C_Timer  (added 5.x) - backed by one OnUpdate frame
--------------------------------------------------------------------
if not _G.C_Timer then
    local timers = {}
    local driver = CreateFrame("Frame")

    driver:SetScript("OnUpdate", function()
        local now = GetTime()
        for i = #timers, 1, -1 do
            local t = timers[i]
            if now >= t.at then
                table.remove(timers, i)
                local ok, err = pcall(t.fn)
                if not ok then ER:Debug("timer error: " .. tostring(err)) end
            end
        end
    end)

    _G.C_Timer = {
        After = function(delay, fn)
            table.insert(timers, { at = GetTime() + delay, fn = fn })
        end,
        NewTimer = function(delay, fn)
            local h = { at = GetTime() + delay, fn = fn }
            table.insert(timers, h)
            return { Cancel = function()
                for i, t in ipairs(timers) do
                    if t == h then table.remove(timers, i) return end
                end
            end }
        end,
    }
end

-- GetSpellCharges (5.0) - no charge system in WotLK
if not _G.GetSpellCharges then _G.GetSpellCharges = function() return nil end end

-- C_Container.GetItemCooldown (10.x)
if not _G.C_Container then
    _G.C_Container = { GetItemCooldown = function(id) return GetItemCooldown(id) end }
end

--------------------------------------------------------------------
-- Latency
-- 3.3.5's GetNetStats returns only 3 values (bandwidthIn, bandwidthOut,
-- latency). The 4-value form arrived in 4.0.1. Hekili uses select(4,...)
-- which is nil here and would poison every latency term it feeds.
--------------------------------------------------------------------
function C.Latency()
    local _, _, lag = GetNetStats()
    return (lag or 0) / 1000
end

--------------------------------------------------------------------
-- Spell haste
-- UnitSpellHaste does not exist in 3.3.5 (added 4.0.1).
-- GetCombatRatingBonus(CR_HASTE_SPELL) sees only haste from RATING and
-- misses Bloodlust / Wrath of Air / Power Infusion. Deriving from a
-- reference spell's live cast time captures everything.
--------------------------------------------------------------------
function C.SpellHaste(refSpellName, refBaseCast)
    if refSpellName and refBaseCast and refBaseCast > 0 then
        local castMS = select(4, GetSpellInfo(refSpellName))
        if castMS and castMS > 0 then
            return ((refBaseCast / (castMS / 1000)) - 1) * 100
        end
    end
    if GetCombatRatingBonus and CR_HASTE_SPELL then
        return GetCombatRatingBonus(CR_HASTE_SPELL) or 0
    end
    return 0
end

if not _G.UnitSpellHaste then
    _G.UnitSpellHaste = function() return C.SpellHaste() end
end

--------------------------------------------------------------------
-- Combat log
-- 3.3.5 COMBAT_LOG_EVENT_UNFILTERED arg order:
--   timestamp, event, sourceGUID, sourceName, sourceFlags,
--   destGUID, destName, destFlags, [suffix...]
-- No raid flags (4.2) and no hideCaster (5.x).
-- CombatLogGetCurrentEventInfo is 8.0 and does not exist here.
--------------------------------------------------------------------
function C.ParseCombatLog(...)
    local timestamp, event, sourceGUID, sourceName, sourceFlags,
          destGUID, destName, destFlags = ...
    return {
        timestamp = timestamp, event = event,
        sourceGUID = sourceGUID, sourceName = sourceName, sourceFlags = sourceFlags,
        destGUID = destGUID, destName = destName, destFlags = destFlags,
        spellID = select(9, ...), spellName = select(10, ...),
        spellSchool = select(11, ...),
    }
end

--------------------------------------------------------------------
-- Aura scanning
-- 3.3.5 UnitBuff/UnitDebuff return 11 values with spellId last.
-- Match by NAME first: a lower-rank spell has a different global ID,
-- so ID-only matching silently misses non-max-rank auras.
--------------------------------------------------------------------
function C.FindBuff(unit, spellName, spellID)
    for i = 1, 40 do
        local name, _, _, count, _, duration, expires, _, _, _, id = UnitBuff(unit, i)
        if not name then break end
        if (spellName and name == spellName) or (id and id == spellID) then
            return (count and count > 0) and count or 1, expires or 0, duration or 0
        end
    end
    return nil
end

function C.FindDebuff(unit, spellName, spellID, mineOnly)
    for i = 1, 40 do
        local name, _, _, count, _, duration, expires, caster, _, _, id = UnitDebuff(unit, i)
        if not name then break end

        local matches = (spellName and name == spellName) or (id and id == spellID)
        if matches then
            -- "Is it mine?" is only enforceable when the client tells
            -- us who cast it. On 3.3.5 unitCaster is frequently nil for
            -- units outside your group, and rejecting on a nil caster
            -- meant a disease that was plainly ticking read as absent -
            -- so the addon kept telling you to reapply it.
            local ok = true
            if mineOnly and caster and caster ~= "player"
               and caster ~= "pet" and caster ~= "vehicle" then
                ok = false
            end
            if ok then
                return (count and count > 0) and count or 1, expires or 0, duration or 0
            end
        end
    end
    return nil
end

-- Dump everything currently on a unit, for diagnosis.
function C.DumpAuras(unit)
    local out = {}
    for i = 1, 40 do
        local name, _, _, count, _, duration, expires, caster, _, _, id = UnitDebuff(unit, i)
        if not name then break end
        table.insert(out, {
            index = i, name = name, id = id, count = count,
            caster = caster, duration = duration,
            remains = expires and expires > 0 and (expires - GetTime()) or -1,
        })
    end
    return out
end

--------------------------------------------------------------------
-- Talents. GetTalentTabInfo EXISTS in 3.3.5 and returns
-- name, iconTexture, pointsSpent - the same shape Hekili's Wrath
-- build already uses, so spec detection needs no rework.
--------------------------------------------------------------------
function C.TalentPoints()
    return select(3, GetTalentTabInfo(1)) or 0,
           select(3, GetTalentTabInfo(2)) or 0,
           select(3, GetTalentTabInfo(3)) or 0
end

function C.TalentRank(tab, index)
    return (select(5, GetTalentInfo(tab, index))) or 0
end

--------------------------------------------------------------------
-- GCD. No GCD "spell" on 3.3.5 (61304 is retail-only); query a known
-- zero-cooldown spell by NAME instead.
--------------------------------------------------------------------
function C.GCDRemaining(probeSpellName)
    if not probeSpellName then return 0 end
    local start, duration = GetSpellCooldown(probeSpellName)
    if not start or start == 0 then return 0 end
    local remain = start + duration - GetTime()
    return remain > 0 and remain or 0
end

--------------------------------------------------------------------
-- Glyphs. 3.3.5 exposes these directly; a spec can branch on them.
--------------------------------------------------------------------
function C.HasGlyph(glyphSpellID)
    if not GetGlyphSocketInfo then return false end
    for i = 1, 6 do
        local enabled, _, _, spellID = GetGlyphSocketInfo(i)
        if enabled and spellID == glyphSpellID then return true end
    end
    return false
end

--------------------------------------------------------------------
-- PRESENCE
--
-- Death Knight presences are STANCES, not buffs. They sit on the
-- shapeshift bar, so UnitBuff does not find them - which is why the
-- addon kept suggesting Blood Presence to someone already standing in
-- it. Read the shapeshift form instead.
--------------------------------------------------------------------
function C.ActivePresence()
    if not GetShapeshiftForm then return nil end
    local form = GetShapeshiftForm()
    if not form or form == 0 then return nil end

    if GetShapeshiftFormInfo then
        local _, name = GetShapeshiftFormInfo(form)
        if name then return name, form end
    end

    -- fall back to the standard WotLK ordering
    return ({ [1] = "Blood Presence", [2] = "Frost Presence",
              [3] = "Unholy Presence" })[form], form
end

--------------------------------------------------------------------
-- Pet. Needed for anything that summons: is it actually out?
--------------------------------------------------------------------
function C.HasPet()
    if not UnitExists then return false end
    if not UnitExists("pet") then return false end
    if UnitIsDead and UnitIsDead("pet") then return false end
    return true
end

--------------------------------------------------------------------
-- RUNES  (Death Knight)
--
-- 3.3.5 gives first-class APIs here, which is a relief after the
-- action bars. Slot mapping is fixed:
--     1, 2  Blood       3, 4  Unholy       5, 6  Frost
-- GetRuneType(slot) returns 1 Blood, 2 Unholy, 3 Frost, 4 DEATH.
-- A Death Rune substitutes for any type, which is why rune cost has to
-- be solved by allocation rather than by counting.
--------------------------------------------------------------------
C.RUNE_BLOOD, C.RUNE_UNHOLY, C.RUNE_FROST, C.RUNE_DEATH = 1, 2, 3, 4

local RUNE_NAME = { [1] = "blood", [2] = "unholy", [3] = "frost", [4] = "death" }

-- Six slots: { type = "frost", ready = bool, remains = seconds }
function C.ReadRunes(now)
    local out = {}
    if not GetRuneCooldown or not GetRuneType then return out end

    for i = 1, 6 do
        local start, duration, ready = GetRuneCooldown(i)
        local remains = 0
        if not ready and start and start > 0 and duration then
            remains = start + duration - now
            if remains < 0 then remains = 0 end
        end
        out[i] = {
            slot     = i,
            type     = RUNE_NAME[GetRuneType(i) or 0] or "blood",
            ready    = ready and true or (remains <= 0),
            remains  = remains,
            duration = duration or 10,
        }
    end
    return out
end

-- Can a cost like { frost = 1, unholy = 1 } be paid right now?
-- Greedy: spend matching runes first, fall back to Death Runes, so a
-- Death Rune is never wasted on a cost a natural rune could cover.
function C.RunesAvailable(runes, cost)
    if not cost then return true end

    local used = {}
    local function take(kind)
        for i, r in ipairs(runes) do
            if not used[i] and r.ready and r.type == kind then used[i] = true return true end
        end
        for i, r in ipairs(runes) do
            if not used[i] and r.ready and r.type == "death" then used[i] = true return true end
        end
        return false
    end

    for _, kind in ipairs({ "blood", "frost", "unholy" }) do
        for _ = 1, (cost[kind] or 0) do
            if not take(kind) then return false end
        end
    end
    return true
end

-- Soonest time the cost could be paid, plus the cooldown length of the
-- rune we are waiting on (so a swipe can be drawn at the right scale).
--
-- The old version returned the LONGEST remaining of any rune, which is
-- not the answer to the question: we need the soonest moment the whole
-- cost becomes payable, allocating each requirement to the earliest
-- rune that can cover it.
function C.RunesReadyIn(runes, cost)
    if not cost then return 0, 0 end
    if C.RunesAvailable(runes, cost) then return 0, 0 end

    local used, wait, cdLen = {}, 0, 10

    local function claim(kind)
        -- a ready rune costs no time
        for i, r in ipairs(runes) do
            if not used[i] and r.ready and r.type == kind then used[i] = true return 0 end
        end
        for i, r in ipairs(runes) do
            if not used[i] and r.ready and r.type == "death" then used[i] = true return 0 end
        end
        -- otherwise the soonest recharging rune that fits
        local best, bestIdx, bestDur
        for i, r in ipairs(runes) do
            if not used[i] and (r.type == kind or r.type == "death") then
                if not best or r.remains < best then
                    best, bestIdx, bestDur = r.remains, i, r.duration or 10
                end
            end
        end
        if bestIdx then
            used[bestIdx] = true
            if bestDur then cdLen = bestDur end
            return best
        end
        return nil
    end

    for _, kind in ipairs({ "blood", "frost", "unholy" }) do
        for _ = 1, (cost[kind] or 0) do
            local t = claim(kind)
            if t == nil then return 9999, 10 end
            if t > wait then wait = t end
        end
    end

    return wait, cdLen
end

--------------------------------------------------------------------
-- KEYBIND LOOKUP
--
-- v0.2 failed two ways, both fixed here:
--
--  1. GetActionInfo(slot) does NOT reliably return a global spell ID
--     for type "spell" on 3.3.5. It may return a spellbook index with
--     the book type in the third return. Resolve via BOTH.
--
--  2. Mapping slots to hardcoded ACTIONBUTTON%d binding names only
--     works on Blizzard's default bars. Bartender4, Dominos and ElvUI
--     rebind them, so GetBindingKey came back nil and nothing showed.
--
-- Instead we read the HotKey FontString the bar addon already draws.
-- If the key is visible on your bars, we can read it.
--------------------------------------------------------------------
local BUTTON_PREFIXES = {
    -- ORDER MATTERS: later entries overwrite earlier ones for the same
    -- action slot. Blizzard's bars still EXIST under ElvUI/Bartender -
    -- just hidden - and carry stale default bindings. So third-party
    -- bars must be scanned last, and visible buttons beat hidden ones.
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton",
    "BT4Button", "DominosActionButton",
    "ElvUI_Bar1Button", "ElvUI_Bar2Button", "ElvUI_Bar3Button",
    "ElvUI_Bar4Button", "ElvUI_Bar5Button", "ElvUI_Bar6Button",
    "ElvUI_Bar7Button", "ElvUI_Bar8Button", "ElvUI_Bar9Button",
    "ElvUI_Bar10Button",
}

-- Keybind abbreviation.
--
-- Modifiers are stripped from the FRONT one at a time; only what is
-- left after them gets token substitution. The old version ran
-- unordered gsubs over the whole string, so on "ALT-=" the "-"
-- handling could swallow the "=" and alt+= displayed as "a-".
local MODIFIERS = { { "SHIFT-", "s" }, { "CTRL-", "c" }, { "ALT-", "a" } }
local TOKENS = {
    { "MOUSEWHEELUP", "mwu" }, { "MOUSEWHEELDOWN", "mwd" },
    { "BUTTON", "m" }, { "NUMPAD", "n" }, { "SPACE", "spc" },
}

local function abbreviate(key)
    if not key or key == "" then return nil end

    local prefix, rest, found = "", key, true
    while found do
        found = false
        for _, m in ipairs(MODIFIERS) do
            local mod = m[1]
            if string.upper(string.sub(rest, 1, string.len(mod))) == mod then
                prefix = prefix .. m[2]
                rest = string.sub(rest, string.len(mod) + 1)
                found = true
                break
            end
        end
    end

    -- Only the terminal key is token-substituted, so "-" and "=" survive.
    for _, t in ipairs(TOKENS) do
        rest = string.gsub(rest, t[1], t[2])
    end

    return prefix .. rest
end

-- slot -> { key = "s4", src = "ElvUI_Bar2Button2", vis = true }
local keyMap, keyMapStale, lastMethod = {}, true, "none"

function C.InvalidateKeybinds() keyMapStale = true end

--------------------------------------------------------------------
-- Get the hotkey for one button, trying every scheme bar addons use.
--------------------------------------------------------------------
-- Text that is NOT a keybind. RANGE_INDICATOR is the dot an action
-- button shows when the target is out of range; it was being read as
-- the keybind for Mind Flay.
local function isJunk(txt)
    if not txt or txt == "" then return true end
    if RANGE_INDICATOR and txt == RANGE_INDICATOR then return true end
    -- bullet / middle dot / interpunct variants used as range markers
    -- NOTE: "-" and "=" are REAL keys and must not be filtered here.
    -- Only range/marker glyphs belong in this list.
    for _, junk in ipairs({ "\226\128\162", "\194\183" }) do
        if txt == junk then return true end
    end
    return false
end

-- Last resort: walk the button's own regions looking for the hotkey
-- FontString. Needed because bar addons do not agree on where they
-- put it - global name, .HotKey, .hotkey, or nowhere findable.
local function hotkeyFromRegions(btn)
    if not btn.GetRegions then return nil end
    local ok, regions = pcall(function() return { btn:GetRegions() } end)
    if not ok then return nil end

    local best
    for _, r in ipairs(regions) do
        if type(r) == "table" and r.GetObjectType and r.GetText then
            local ok2, objType = pcall(r.GetObjectType, r)
            if ok2 and objType == "FontString" then
                local ok3, txt = pcall(r.GetText, r)
                if ok3 and not isJunk(txt) and string.len(txt) <= 8 then
                    -- prefer whatever sits top-right, like a real hotkey
                    local ok4, point = pcall(r.GetPoint, r)
                    if ok4 and point and string.find(point, "TOP") then
                        return txt
                    end
                    best = best or txt
                end
            end
        end
    end
    return best
end

--------------------------------------------------------------------
-- Binding names a button might be bound under.
-- Bar addons register their OWN binding headers - ElvUI uses
-- ELVUIBAR<n>BUTTON<i>, which is why slots on ElvUI bars 2+ came back
-- nil: nothing was ever asking for that name.
--------------------------------------------------------------------
local PREFIX_BINDINGS = {
    ["ActionButton"]               = "ACTIONBUTTON%d",
    ["MultiBarBottomLeftButton"]   = "MULTIACTIONBAR1BUTTON%d",
    ["MultiBarBottomRightButton"]  = "MULTIACTIONBAR2BUTTON%d",
    ["MultiBarRightButton"]        = "MULTIACTIONBAR3BUTTON%d",
    ["MultiBarLeftButton"]         = "MULTIACTIONBAR4BUTTON%d",
}

local function bindingNamesFor(name)
    local out = {}
    if not name then return out end

    -- ElvUI_Bar3Button7 -> ELVUIBAR3BUTTON7
    local bar, idx = string.match(name, "^ElvUI_Bar(%d+)Button(%d+)$")
    if bar and idx then
        table.insert(out, "ELVUIBAR" .. bar .. "BUTTON" .. idx)
    end

    -- Blizzard default headers
    local prefix, i = string.match(name, "^(%a[%a_]-)(%d+)$")
    if prefix and i and PREFIX_BINDINGS[prefix] then
        table.insert(out, string.format(PREFIX_BINDINGS[prefix], tonumber(i)))
    end

    -- Bartender / Dominos and anything else using click-casting
    table.insert(out, "CLICK " .. name .. ":LeftButton")
    return out
end

local function hotkeyOf(btn, name)
    -- 1. Real bindings first. GetBindingKey is ground truth and gives
    --    the unabbreviated key ("ALT-="), which we abbreviate
    --    ourselves. Rendered text is a bar addon's own display string
    --    and can be lossy.
    if GetBindingKey then
        for _, b in ipairs(bindingNamesFor(name)) do
            local k = GetBindingKey(b)
            if k and k ~= "" then return k, "binding:" .. b end
        end
    end

    -- 2. the fontstring the bar addon draws
    local hk = (name and _G[name .. "HotKey"]) or btn.HotKey or btn.hotkey
    local txt = hk and hk.GetText and hk:GetText()
    if not isJunk(txt) then return txt, "hotkey-text" end

    -- 3. scan the button's own regions
    local scanned = hotkeyFromRegions(btn)
    if scanned then return scanned, "region-scan" end

    return nil
end

local function slotOf(btn)
    local slot = btn.action
    if not slot and btn.GetAttribute then
        local ok, v = pcall(btn.GetAttribute, btn, "action")
        if ok then slot = v end
    end
    return tonumber(slot)
end

local visibleSeen, buttonsSeen = 0, 0

local function isVisible(btn)
    -- IsVisible() is false unless every ancestor is shown too, which
    -- some bar addons break during setup. Accept IsShown() as well.
    local vis = false
    if btn.IsVisible then
        local ok, v = pcall(btn.IsVisible, btn)
        if ok and v then vis = true end
    end
    if not vis and btn.IsShown then
        local ok, v = pcall(btn.IsShown, btn)
        if ok and v then vis = true end
    end
    return vis
end

function C.VisibilityStats() return visibleSeen, buttonsSeen end

--------------------------------------------------------------------
-- Default-bar fallback: slot -> ACTIONBUTTON%d style binding names.
--------------------------------------------------------------------
local BAR_RANGES = {
    {  1, 12, "ACTIONBUTTON%d" },
    { 61, 72, "MULTIACTIONBAR1BUTTON%d" },
    { 49, 60, "MULTIACTIONBAR2BUTTON%d" },
    { 25, 36, "MULTIACTIONBAR3BUTTON%d" },
    { 37, 48, "MULTIACTIONBAR4BUTTON%d" },
}

local function bindingForSlot(slot)
    if not GetBindingKey then return nil end
    for _, r in ipairs(BAR_RANGES) do
        if slot >= r[1] and slot <= r[2] then
            return GetBindingKey(string.format(r[3], slot - r[1] + 1))
        end
    end
    return nil
end

function C.BuildKeybindMap()
    local map, found = {}, 0
    visibleSeen, buttonsSeen = 0, 0

    -- Confidence scoring.
    --
    -- Blizzard's bars persist HIDDEN under ElvUI and still carry their
    -- default hotkey FontStrings ("9", "0", "-"...). Reading those is
    -- how two different spells ended up displaying the same key: a
    -- spell sitting on a hidden default bar picked up that bar's stale
    -- label, which the player cannot actually press.
    --
    --   3  visible button, key from a real binding   - trust
    --   2  visible button, key from rendered text    - trust
    --   1  hidden  button, key from a real binding   - plausible
    --   0  hidden  button, key from rendered text    - REJECT, stale
    -- Ranking, and NOTHING is rejected.
    --
    -- v1.1 threw away "rendered text from a non-visible frame", which
    -- silently broke slots 77/81/82 that had been working. The cause is
    -- that IsVisible()/IsShown() are not reliable here - frames plainly
    -- drawn on screen report false - so gating on them loses real data.
    --
    -- Frame ORIGIN is a far better signal than frame visibility. Under
    -- ElvUI/Bartender it is Blizzard's own bars that linger hidden with
    -- stale labels, so anything from a third-party bar outranks
    -- anything from a default one.
    --
    --   4  binding, third-party bar
    --   3  rendered text, third-party bar
    --   2  binding, Blizzard default bar
    --   1  rendered text, Blizzard default bar
    local BLIZZ_FRAME = {
        ActionButton = true, MultiBarBottomLeftButton = true,
        MultiBarBottomRightButton = true, MultiBarRightButton = true,
        MultiBarLeftButton = true,
    }

    local function isBlizzardFrame(src)
        if not src then return false end
        local base = string.match(src, "^(%a[%a_]-)%d+")
        return base and BLIZZ_FRAME[base] or false
    end

    local function scoreOf(src, vis)
        local fromBinding = src and string.find(src, "binding", 1, true)
        if isBlizzardFrame(src) then
            return fromBinding and 2 or 1
        end
        return fromBinding and 4 or 3
    end

    local function record(slot, key, src, vis)
        if not slot or not key then return end

        local score = scoreOf(src, vis)
        local prev = map[slot]
        if prev and prev.score >= score then return end
        if not prev then found = found + 1 end
        map[slot] = { key = abbreviate(key), raw = key, src = src,
                      vis = vis, score = score }
    end

    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for i = 1, 120 do
            local name = prefix .. i
            local btn = _G[name]
            if type(btn) == "table" then
                local slot = slotOf(btn)
                if slot then
                    buttonsSeen = buttonsSeen + 1
                    local vis = isVisible(btn)
                    if vis then visibleSeen = visibleSeen + 1 end
                    local key, how = hotkeyOf(btn, name)
                    if key then record(slot, key, name .. " (" .. how .. ")", vis) end
                end
            end
        end
    end
    local namedCount = found

    -- ALWAYS run the global scan, not just when the named pass found
    -- nothing.
    --
    -- THE BUG: Blizzard's hidden bars supplied ~48 slots, so found > 0
    -- and this pass was skipped entirely. Any slot whose button lives
    -- on a frame we did not name - action bar page 2 (13-24) and bars
    -- 7-10 (73-120), which have no Blizzard binding header at all -
    -- was therefore never examined, and reported NO KEY BOUND even
    -- though the bar addon was visibly drawing the key.
    for name, obj in pairs(_G) do
        if type(obj) == "table" and type(name) == "string" then
            local ok, slot = pcall(slotOf, obj)
            if ok and slot then
                local ok2, key, how = pcall(hotkeyOf, obj, name)
                if ok2 and key then
                    record(slot, key, name .. " (" .. tostring(how) .. ")", isVisible(obj))
                end
            end
        end
    end

    lastMethod = "named bars: " .. namedCount .. ", total after scan: " .. found

    keyMap, keyMapStale = map, false
    return found
end

--------------------------------------------------------------------
-- Which action slot holds this spell?
-- Handles three cases:
--   "spell" where id is a global spell ID
--   "spell" where id is a spellbook index (3.3.5 does both)
--   "macro" - resolved by parsing the macro body for /cast
-- GetMacroSpell does not exist on 3.3.5 (added 4.0), hence the parse.
--------------------------------------------------------------------
local function macroCastsSpell(macroIndex, spellName)
    if not GetMacroBody then return false end
    local body = GetMacroBody(macroIndex)
    if not body then return false end

    local lowerBody, lowerSpell = string.lower(body), string.lower(spellName)

    for line in string.gmatch(lowerBody, "[^\r\n]+") do
        if string.find(line, "/cast", 1, true)
        or string.find(line, "/use", 1, true)
        or string.find(line, "/castsequence", 1, true)
        or string.find(line, "/castrandom", 1, true) then
            if string.find(line, lowerSpell, 1, true) then return true end
        end
    end

    -- "#showtooltip Spell Name" only. The old version accepted the
    -- spell name appearing ANYWHERE in a macro that merely contained
    -- #showtooltip, so one long multi-spell macro claimed itself as
    -- the home of every spell it mentioned - which is how a single
    -- action slot ended up owning seven different abilities.
    local shown = string.match(lowerBody, "#showtooltip%s+([^\r\n]+)")
    if shown and string.find(shown, lowerSpell, 1, true) then return true end

    return false
end

-- Every action slot holding this spell, in slot order.
-- A spell is commonly on more than one: a visible bar plus a copy on a
-- paged bar (13-24 is page 2 of the main bar and is only rendered when
-- you page to it).
-- Returns { slot = n, kind = "spell"|"macro"|"texture" }.
--
-- KIND MATTERS. A spell placed directly on a bar is unambiguous. A
-- macro that merely mentions it is a guess, and a multi-spell macro
-- mentions many. A direct placement must always win.
function C.FindActionSlots(spellName)
    local out = {}
    if not spellName or not GetActionInfo then return out end

    for slot = 1, 120 do
        local actionType, id, subType = GetActionInfo(slot)
        if actionType == "spell" and id then
            local n = GetSpellInfo(id)
            if n ~= spellName and GetSpellName then
                n = GetSpellName(id, subType or BOOKTYPE_SPELL)
            end
            if n == spellName then
                table.insert(out, { slot = slot, kind = "spell" })
            end
        elseif actionType == "macro" and id then
            if macroCastsSpell(id, spellName) then
                -- A macro naming several spells matches all of them.
                -- Its ICON tells us which one it actually shows, so a
                -- texture match is far stronger evidence than a name
                -- appearing somewhere in the body.
                local kind = "macro"
                if GetActionTexture then
                    local want = select(3, GetSpellInfo(spellName))
                    if want and GetActionTexture(slot) == want then
                        kind = "macro-icon"
                    end
                end
                table.insert(out, { slot = slot, kind = kind })
            end
        end
    end

    if #out == 0 and GetActionTexture then
        local wantTex = select(3, GetSpellInfo(spellName))
        if wantTex then
            for slot = 1, 120 do
                if GetActionTexture(slot) == wantTex then
                    table.insert(out, { slot = slot, kind = "texture" })
                end
            end
        end
    end

    return out
end

function C.FindActionSlot(spellName)
    local slots = C.FindActionSlots(spellName)
    -- direct placements first
    for _, e in ipairs(slots) do if e.kind == "spell" then return e.slot end end
    return slots[1] and slots[1].slot or nil
end

function C.Keybind(spellName)
    if keyMapStale then C.BuildKeybindMap() end

    -- Every slot holding this spell, then the best of them.
    --
    -- Two things are being weighed. HOW the slot was identified: a
    -- direct placement is certain, a macro mention is a guess, a
    -- texture match is a last resort. And where the KEY came from:
    -- a real binding beats a bar addon's rendered label.
    --
    -- Identification dominates. A direct placement with a weak key
    -- source still beats a macro guess with a strong one - otherwise
    -- one multi-spell macro claims every ability it names.
    local slots = C.FindActionSlots(spellName)
    local KIND = { spell = 300, ["macro-icon"] = 200, macro = 100, texture = 50 }

    local best, bestScore
    for _, e in ipairs(slots) do
        local entry = keyMap[e.slot]
        if entry then
            local total = (KIND[e.kind] or 0) + entry.score
            if not bestScore or total > bestScore then
                best, bestScore = entry.key, total
            end
        end
    end
    if best then return best end

    -- No button anywhere: fall back to the default-bar binding for the
    -- slot, direct placements first.
    for _, e in ipairs(slots) do
        if e.kind == "spell" then
            local b = bindingForSlot(e.slot)
            if b then return abbreviate(b) end
        end
    end
    for _, e in ipairs(slots) do
        local b = bindingForSlot(e.slot)
        if b then return abbreviate(b) end
    end
    return nil
end

-- Why did this spell fail? Returns a short reason string.
function C.KeybindDiagnosis(spellName)
    if not spellName then return "no name" end
    local slots = C.FindActionSlots(spellName)
    if #slots == 0 then return "not on any bar" end
    if keyMapStale then C.BuildKeybindMap() end

    local KIND = { spell = 300, ["macro-icon"] = 200, macro = 100, texture = 50 }
    local best, bestScore, bestKind
    for _, e in ipairs(slots) do
        local entry = keyMap[e.slot]
        if entry then
            local total = (KIND[e.kind] or 0) + entry.score
            if not bestScore or total > bestScore then
                best, bestScore, bestKind = e.slot, total, e.kind
            end
        end
    end

    local list = {}
    for _, e in ipairs(slots) do
        table.insert(list, e.slot .. (e.kind == "spell" and "" or ("~" .. e.kind)))
    end

    if not best then
        return "slots " .. table.concat(list, ",") .. " - none bound"
    end

    local label = (bestKind == "spell") and "direct"
               or ("|cffffaa00" .. tostring(bestKind) .. "|r")
    local extra = (#slots > 1)
        and (" of " .. #slots .. " [" .. table.concat(list, ",") .. "]") or ""
    return "slot " .. best .. extra .. " " .. label
end

-- Raw binding string before abbreviation, so a mangled key can be told
-- apart from a missing one.
function C.KeybindRaw(spellName)
    if keyMapStale then C.BuildKeybindMap() end
    local slots = C.FindActionSlots(spellName)
    for _, e in ipairs(slots) do
        if e.kind == "spell" and keyMap[e.slot] then
            return keyMap[e.slot].raw, keyMap[e.slot].src, e.slot
        end
    end
    for _, e in ipairs(slots) do
        if keyMap[e.slot] then return keyMap[e.slot].raw, keyMap[e.slot].src, e.slot end
    end
    return nil, nil, slots[1] and slots[1].slot
end

--------------------------------------------------------------------
-- Diagnostics
--------------------------------------------------------------------
function C.KeybindReport()
    keyMapStale = true
    C.BuildKeybindMap()
    local bars = {}
    for _, prefix in ipairs(BUTTON_PREFIXES) do
        if _G[prefix .. "1"] then table.insert(bars, prefix) end
    end
    local slots = 0
    for _ in pairs(keyMap) do slots = slots + 1 end
    return bars, slots, lastMethod
end

-- Deep dive on a single spell: what slot, and every button claiming it.
function C.KeybindTrace(spellName)
    if keyMapStale then C.BuildKeybindMap() end
    local out = {}
    local slot = C.FindActionSlot(spellName)
    table.insert(out, "slot=" .. tostring(slot))

    if not slot then
        -- is it on a bar at all, under any action type?
        for i = 1, 120 do
            local t, id = GetActionInfo(i)
            if t then table.insert(out, "  raw slot " .. i .. ": " .. tostring(t)
                                        .. " id=" .. tostring(id)) end
            if #out > 14 then break end
        end
        return out
    end

    local entry = keyMap[slot]
    table.insert(out, "map=" .. (entry and (entry.key .. " from " .. entry.src
                    .. (entry.vis and " [visible]" or " [hidden]")) or "nil"))
    table.insert(out, "slotBinding=" .. tostring(bindingForSlot(slot)))

    for _, prefix in ipairs(BUTTON_PREFIXES) do
        for i = 1, 120 do
            local name = prefix .. i
            local btn = _G[name]
            if type(btn) == "table" and slotOf(btn) == slot then
                local key, how = hotkeyOf(btn, name)
                table.insert(out, "  " .. name .. " key=" .. tostring(key)
                    .. " via=" .. tostring(how)
                    .. (isVisible(btn) and " [visible]" or " [hidden]"))
                -- dump every FontString so an unknown layout is visible
                if btn.GetRegions then
                    local ok, regions = pcall(function() return { btn:GetRegions() } end)
                    if ok then
                        for _, r in ipairs(regions) do
                            if type(r) == "table" and r.GetObjectType then
                                local ok2, t = pcall(r.GetObjectType, r)
                                if ok2 and t == "FontString" then
                                    local _, txt = pcall(r.GetText, r)
                                    table.insert(out, "      fs: '" .. tostring(txt) .. "'")
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

--------------------------------------------------------------------
-- SPELL ID SANITY
--
-- A wrong spell ID that happens to be a VALID spell is invisible to
-- every other check: the name resolves, the keybind resolves, the
-- cooldown resolves - it is just the wrong spell. That is exactly how
-- blood_presence carried id 48263 (Frost Presence) for several
-- versions while a grep for "frost_presence" came back clean.
--
-- Compare the resolved name against the ability key. They are written
-- to match by convention, so a mismatch is nearly always a typo'd ID.
--------------------------------------------------------------------
local function normalise(str)
    if not str then return "" end
    str = string.lower(str)
    str = string.gsub(str, "[^%a%d]", "")
    return str
end

-- Returns a list of { key, id, name } where the name does not match.
function C.CheckSpellIDs(tbl)
    local bad = {}
    for key, entry in pairs(tbl or {}) do
        if entry.nameCheck ~= false and entry.id then
            local name = GetSpellInfo(entry.id)
            if name and normalise(name) ~= normalise(key) then
                table.insert(bad, { key = key, id = entry.id, name = name })
            end
        end
    end
    table.sort(bad, function(a, b) return a.key < b.key end)
    return bad
end

--------------------------------------------------------------------
-- API PREFLIGHT
-- Report every missing global at load rather than discovering them
-- one error at a time. Anything here is required and absent on this
-- client - almost always something added after 3.3.5.
--------------------------------------------------------------------
local REQUIRED = {
    "GetTime", "GetSpellInfo", "GetSpellCooldown", "GetSpellName",
    "GetSpellLink", "GetSpellBonusDamage", "IsUsableSpell",
    "GetTalentInfo", "GetTalentTabInfo", "GetNetStats", "GetUnitSpeed",
    "GetActionInfo",
    "UnitBuff", "UnitDebuff", "UnitMana", "UnitManaMax",
    "UnitCastingInfo", "UnitChannelInfo", "UnitAffectingCombat",
    "UnitExists", "UnitCanAttack", "UnitIsDead", "UnitHealth",
    "UnitHealthMax", "UnitGUID", "UnitName", "UnitClass",
}

function C.Preflight()
    local missing = {}
    for _, fn in ipairs(REQUIRED) do
        if type(_G[fn]) ~= "function" then table.insert(missing, fn) end
    end
    return missing
end

return C
