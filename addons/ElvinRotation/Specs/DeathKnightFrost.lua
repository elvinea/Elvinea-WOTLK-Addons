--[[ ElvinRotation - Specs/DeathKnightFrost.lua
     Frost Death Knight, WotLK 3.3.5a.

     Priority translated from Hekili's Wrath build:
       Wrath/APLs 2.0/DeathKnight-FrostUHPesti.simc
     which credits wowsims.github.io, September 2023.

     v1 SCOPE: 2H Frost, single target, Pestilence-based disease
     upkeep. Opener list and AoE omitted - see NOTES at the bottom.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name     = "Frost Death Knight",
    class    = "DEATHKNIGHT",
    tab      = 2,              -- Frost tree
    school   = 4,              -- frost, for GetSpellBonusDamage
    gcdProbe = 49909,          -- Icy Touch: no cooldown, safe GCD probe

    usesRunes    = true,
    usesPresence = true,
    hasteRefBase = nil,        -- DK has no fixed-cast reference spell
}

--------------------------------------------------------------------
-- Auras
--------------------------------------------------------------------
spec.auras = {
    -- our diseases
    frost_fever      = { id = 55095, type = "debuff", mine = true, duration = 15 },
    blood_plague     = { id = 55078, type = "debuff", mine = true, duration = 15 },

    -- procs and buffs
    freezing_fog     = { id = 59052, type = "buff" },   -- Rime
    killing_machine  = { id = 51124, type = "buff" },
    unbreakable_armor= { id = 51271, type = "buff" },
    blood_presence   = { id = 48266, type = "buff" },
    unholy_presence  = { id = 48265, type = "buff" },
    horn_of_winter   = { id = 57623, type = "buff" },
}

--------------------------------------------------------------------
-- Abilities
--
-- runes = { blood/frost/unholy } consumed. Death Runes substitute for
-- any of them, handled by Compat.RunesAvailable.
-- rp = runic power spent. generatesRP = runic power gained.
--------------------------------------------------------------------
spec.abilities = {
    icy_touch = {
        key = "icy_touch", id = 49909, harmful = true, castableMoving = true,
        runes = { frost = 1 }, generatesRP = 10,
        applies = "frost_fever", appliesFor = 15, openerSkipIfUp = true,
    },
    plague_strike = {
        key = "plague_strike", id = 49921, harmful = true, castableMoving = true,
        runes = { unholy = 1 }, generatesRP = 10,
        applies = "blood_plague", appliesFor = 15, openerSkipIfUp = true,
    },
    obliterate = {
        key = "obliterate", id = 51425, harmful = true, castableMoving = true,
        runes = { frost = 1, unholy = 1 }, generatesRP = 20,
    },
    blood_strike = {
        key = "blood_strike", id = 49930, harmful = true, castableMoving = true,
        runes = { blood = 1 }, generatesRP = 10,
    },
    frost_strike = {
        key = "frost_strike", id = 55268, harmful = true, castableMoving = true,
        rp = 40,
    },
    howling_blast = {
        key = "howling_blast", id = 51411, harmful = true, castableMoving = true,
        runes = { frost = 1 }, generatesRP = 10,
    },
    pestilence = {
        key = "pestilence", id = 50842, harmful = true, castableMoving = true,
        runes = { blood = 1 },
    },
    blood_tap = {
        key = "blood_tap", id = 45529, castableMoving = true, cd = 60,
    },
    unbreakable_armor = {
        key = "unbreakable_armor", id = 51271, castableMoving = true, cd = 60,
        runes = { frost = 1 }, majorCD = true, minTTD = 15,
        cdLabel = "Unbreakable Armor",
        applies = "unbreakable_armor", appliesTo = "buff", appliesFor = 20,
    },
    empower_rune_weapon = {
        key = "empower_rune_weapon", id = 47568, castableMoving = true, cd = 300,
        majorCD = true, minTTD = 20, cdLabel = "Empower Rune Weapon",
    },
    horn_of_winter = {
        key = "horn_of_winter", id = 57623, castableMoving = true, cd = 20,
        generatesRP = 10,
        applies = "horn_of_winter", appliesTo = "buff", appliesFor = 120,
            selfBuff = true,
    },
    raise_dead = {
        key = "raise_dead", id = 46584, castableMoving = true, cd = 180,
        majorCD = true, minTTD = 30, cdLabel = "Raise Dead",
    },
    death_strike = {
        key = "death_strike", id = 49924, harmful = true, castableMoving = true,
        runes = { frost = 1, unholy = 1 }, generatesRP = 15,
    },
    mind_freeze = {
        key = "mind_freeze", id = 47528, harmful = true, castableMoving = true,
        cd = 10, rp = 20,
    },
    -- NOTE: no Frost Presence. It is the TANK presence in WotLK; a
    -- Frost DPS death knight runs Blood (dual wield) or Unholy (two
    -- handed). An earlier version of this file had it in precombat,
    -- which is simply wrong.
    blood_presence = {
        key = "blood_presence", id = 48266, castableMoving = true,
        applies = "blood_presence", appliesTo = "buff", appliesFor = 3600,
            selfBuff = true,
    },
    unholy_presence = {
        key = "unholy_presence", id = 48265, castableMoving = true,
        applies = "unholy_presence", appliesTo = "buff", appliesFor = 3600,
            selfBuff = true,
    },
}

--------------------------------------------------------------------
-- Rank resolution and name binding (see PriestShadow for why names
-- rather than IDs are used for every runtime query on 3.3.5).
--------------------------------------------------------------------
function spec.ResolveRanks()
    for _, ab in pairs(spec.abilities) do ab.name = GetSpellInfo(ab.id) end
    for _, def in pairs(spec.auras)     do def.name = GetSpellInfo(def.id) end

    local byName = {}
    for _, ab in pairs(spec.abilities) do
        if ab.name then
            byName[ab.name] = byName[ab.name] or {}
            table.insert(byName[ab.name], ab)
        end
    end

    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local entries = byName[name]
        if entries then
            local link = GetSpellLink(i, BOOKTYPE_SPELL)
            local id = link and tonumber(string.match(link, "spell:(%d+)"))
            if id then for _, ab in ipairs(entries) do ab.id = id end end
        end
        i = i + 1
    end

    spec.gcdProbeName = spec.abilities.icy_touch.name
end

--------------------------------------------------------------------
-- Glyph of Disease. Without it Pestilence SPREADS but does not refresh
-- the primary target, so a Pestilence-based upkeep plan silently lets
-- diseases fall off - and then Icy Touch and Plague Strike need runes
-- Obliterate has already spent, which is what made Blood Strike look
-- like it was ranked too high.
local GLYPH_OF_DISEASE = 63334

function spec.UpdateExtra(state)
    state.rp = state.runicPower or 0
    state.glyph_of_disease = C.HasGlyph(GLYPH_OF_DISEASE)

    -- Dual wield detection. Changes nothing in the imported priority
    -- (see NOTES) but Killing Machine procs per swing, so it procs far
    -- more often with two weapons - which is why the KM option below
    -- exists and matters mainly for DW.
    state.dual_wield = OffhandHasWeapon and (OffhandHasWeapon() and true or false) or false

    -- Pestilence refresh window follows PRESENCE, which is the only
    -- thing that differs between the two source lists:
    --   Unholy Presence -> 8.5s   (faster GCD and rune regen)
    --   otherwise       -> 4s
    local setting = ER:Setting("pestilenceWindow")
    if setting and setting > 0 then
        state.pesti_window = setting
    elseif state.presence == "unholy" then
        state.pesti_window = 8.5
    else
        state.pesti_window = 4
    end

    -- Runic power is capped at 100 (130 with the talent); dumping it
    -- with Frost Strike before it overcaps is the whole reason
    -- Frost Strike sits low in the priority but still gets cast.
    state.rp_capped = state.rp >= ((state.runicPowerMax or 130) - 20)
end

--------------------------------------------------------------------
-- Priority. Order matches DeathKnight-FrostUHPesti.simc actions list.
--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "blood_presence", when = function(s)
        return ER:Setting("frostPresence") ~= "unholy"
           and s.presence ~= "blood"
    end },
    { key = "unholy_presence", when = function(s)
        return ER:Setting("frostPresence") == "unholy"
           and s.presence ~= "unholy"
    end },
    { key = "horn_of_winter", when = function(s)
        return not s.buff.horn_of_winter.up
    end },
}

-- OPENER.
--   IT > PS > UA + BT > Obli > FS > Pesti > ERW
--   > Obli x3
--   > FS > Ghoul > FS
--   > Obli x2 > Pesti > FS > BS > FS ...
-- Counts are cumulative: an entry retires once that ability has been
-- cast that many times this fight.
spec.lists.opener = {
    { key = "icy_touch",           casts = 1 },
    { key = "plague_strike",       casts = 1 },
    { key = "unbreakable_armor",   casts = 1 },
    { key = "blood_tap",           casts = 1 },
    { key = "obliterate",          casts = 1 },
    { key = "frost_strike",        casts = 1 },
    { key = "pestilence",          casts = 1 },
    { key = "empower_rune_weapon", casts = 1 },
    { key = "obliterate",          casts = 4 },
    { key = "frost_strike",        casts = 2 },
    { key = "raise_dead",          casts = 1 },
    { key = "frost_strike",        casts = 3 },
    { key = "obliterate",          casts = 6 },
    { key = "pestilence",          casts = 2 },
    { key = "frost_strike",        casts = 4 },
    { key = "blood_strike",        casts = 1 },
    { key = "frost_strike",        casts = 5 },
}

spec.lists.aoe = {
    { key = "icy_touch",     when = function(s) return not s.dot.frost_fever.up end },
    { key = "plague_strike", when = function(s) return not s.dot.blood_plague.up end },
    -- spread, not filler: only while something is missing the disease
    { key = "pestilence", when = function(s)
        return s.dot.frost_fever.up
           and (s.activeDot.frost_fever or 0) < (s.activeEnemies or 1)
    end },
    -- Howling Blast is the AoE spell, but it still costs a frost rune
    -- unless Rime has procced. Gated by the same setting as single
    -- target so it cannot fire off-proc unless you ask it to.
    { key = "howling_blast", when = function(s)
        return s.buff.freezing_fog.up
            or ER:Setting("howlingBlastRimeOnly") == false
    end },
    { key = "obliterate" },
    { key = "blood_strike" },
    { key = "frost_strike" },
}

spec.lists.single = {

    -- DISEASES.
    --
    -- Refresh BEFORE they drop, not after. The old version only acted
    -- once a disease was already gone, by which point Obliterate has
    -- usually spent the frost and unholy runes needed to reapply it -
    -- so the priority fell through to Blood Strike and looked like it
    -- had the ordering wrong. It did not; it was rune starved.
    { key = "icy_touch", when = function(s)
        return s.dot.frost_fever.remains < (ER:Setting("diseaseRefresh") or 3)
    end },

    { key = "plague_strike", when = function(s)
        return s.dot.blood_plague.remains < (ER:Setting("diseaseRefresh") or 3)
    end },

    -- Pestilence only REFRESHES with Glyph of Disease. Without the
    -- glyph it merely spreads, so using it for upkeep quietly lets both
    -- diseases expire. Detected, not assumed.
    { key = "pestilence", when = function(s)
        return s.glyph_of_disease
           and s.dot.frost_fever.up
           and s.dot.frost_fever.remains < 1.5
    end },

    { key = "unbreakable_armor" },

    -- Blood Tap converts a blood rune to a Death Rune, used right
    -- after Unbreakable Armor to pay for it.
    { key = "blood_tap", when = function(s)
        return s.lastCast == "unbreakable_armor"
    end },

    { key = "pestilence", when = function(s)
        return s.glyph_of_disease
           and s.dot.frost_fever.up
           and s.dot.frost_fever.remains < s.pesti_window
    end },

    -- Rime proc (Freezing Fog): Howling Blast costs no runes.
    -- Off-proc it is a frost rune that Obliterate wants, so it is
    -- never worth casting on single target without the buff.
    { key = "howling_blast", when = function(s)
        return s.buff.freezing_fog.up
            or ER:Setting("howlingBlastRimeOnly") == false
    end },

    -- KILLING MACHINE dump. NOT in the wowsims list - opt in.
    -- KM guarantees a crit on the next Icy Touch / Howling Blast /
    -- Frost Strike / Obliterate. It procs per weapon swing, so dual
    -- wield generates far more of them than two-handed, and the usual
    -- DW practice is to spend them on Frost Strike rather than let
    -- them fall off.
    { key = "frost_strike", when = function(s)
        return ER:Setting("kmFrostStrike") == true and s.buff.killing_machine.up
    end },

    { key = "obliterate" },

    { key = "raise_dead" },

    { key = "blood_strike" },

    -- Runic power dump
    { key = "frost_strike" },

    { key = "horn_of_winter", when = function(s)
        return not s.buff.horn_of_winter.up
    end },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },

    { runList = "opener", terminal = false,
      when = function(s)
          return s.inCombat
             and s.combatTime < (ER:Setting("openerWindow") or 20)
             and ER:Setting("useOpener") ~= false
      end },

    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 1 end },

    { runList = "single", terminal = true,
      when = function(s) return true end },
}

--------------------------------------------------------------------
function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "DEATHKNIGHT" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t2 > t1 and t2 > t3      -- Frost is tab 2
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("DEATHKNIGHT", "frost", "Death Knight", "Frost", {
    { type = "check", key = "kmFrostStrike",
      label = "Spend Killing Machine on Frost Strike",
      onValue = true, offValue = false,
      tooltip = "Not in the source priority. Killing Machine procs per "
             .. "weapon swing, so dual wield gets far more of them. "
             .. "Try it against your own parses." },
    { type = "check", key = "howlingBlastRimeOnly",
      label = "Howling Blast only on a Rime proc",
      onValue = true, offValue = false,
      tooltip = "Off-proc, Howling Blast costs a frost rune that "
             .. "Obliterate wants. Applies to AoE as well." },
    { type = "slider", key = "diseaseRefresh",
      label = "Refresh diseases at", min = 1, max = 8, step = 0.5,
      fmt = "%.1fs",
      tooltip = "Refresh before they drop, so the runes are still "
             .. "available. Pestilence is only used for upkeep when "
             .. "Glyph of Disease is detected." },
    { type = "check", key = "useOpener",
      label = "Use the scripted opener", onValue = true, offValue = false,
      tooltip = "Runs the source opener sequence for the first few "
             .. "seconds of a fight." },
    { type = "slider", key = "pestilenceWindow",
      label = "Pestilence refresh at", min = 0, max = 12, step = 0.5,
      fmt = "%.1fs",
      tooltip = "0 = automatic: 8.5s in Unholy Presence, 4s otherwise. "
             .. "That threshold is the ONLY difference between the two "
             .. "source Frost priorities." },
}, spec)

--[[ NOTES / DELIBERATE OMISSIONS ---------------------------------

  1. OPENER. The .simc has a separate opener list driven by
     "casts=N" counters (IT > PS > UA > BT > Obliterate > FS ...).
     That needs per-ability cast counting since combat start. Omitted:
     an opener is a fixed sequence you learn once, and the steady-state
     priority converges on it within a few globals anyway.

  2. AOE / Death and Decay. Single target only for now.

  3. TRINKETS AND RACIALS. The .simc lines use_cooldowns, use_items,
     blood_fury and hyperspeed_acceleration are omitted. Engineering
     glove enchants and trinket procs are gear-specific.

  4. KILLING MACHINE is tracked in state but not used in the priority.
     The wowsims list does not gate Frost Strike on it for 2H, which
     surprised me - worth checking against your own parses before
     trusting it.

  5. DUAL WIELD. CORRECTION to an earlier note in this file: there is
     no separate 2H and DW priority in the source. The two Frost lists
     (FrostUHPesti and FrostBLPesti) are byte-identical except for the
     Pestilence refresh threshold, 8.5s versus 4s, and UH/BL refer to
     Unholy versus Blood PRESENCE - not weapon setup. That threshold is
     now driven by your active presence, or overridden by the slider.

     What genuinely differs for dual wield is proc RATE, not priority:
     Killing Machine and Rime both proc per weapon swing, so two
     weapons generate roughly twice as many. The source list never
     spends Killing Machine deliberately, which is defensible for 2H
     and questionable for DW - hence the opt-in setting.
------------------------------------------------------------------]]
