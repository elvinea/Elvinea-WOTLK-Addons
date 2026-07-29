--[[ ElvinRotation - Specs/DeathKnightUnholy.lua
     Unholy Death Knight, WotLK 3.3.5a.

     Priority translated from Hekili's Wrath build:
       Wrath/APLs 2.0/DeathKnight-Unholy2HSS.simc
     which credits wowsims.github.io, September 2023.

     This spec is the reason the cooldown layer exists. Almost every
     cooldown in the list is conditioned on Summon Gargoyle - Army of
     the Dead, Empower Rune Weapon, the engineering glove enchant and
     the presence swap all key off it. Gargoyle snapshots your haste
     when summoned, so the whole rotation bends around making that one
     moment as good as possible.

     v1 SCOPE: 2H, single target. DW and AoE noted at the bottom.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name     = "Unholy Death Knight",
    class    = "DEATHKNIGHT",
    tab      = 3,              -- Unholy tree
    school   = 6,              -- shadow
    gcdProbe = 49909,          -- Icy Touch

    usesRunes = true,
    usesPresence = true,
}

--------------------------------------------------------------------
-- Auras
--------------------------------------------------------------------
spec.auras = {
    frost_fever     = { id = 55095, type = "debuff", mine = true, duration = 15 },
    blood_plague    = { id = 55078, type = "debuff", mine = true, duration = 15 },

    desolation      = { id = 66803, type = "buff" },
    ghoul_frenzy    = { id = 63560, type = "buff" },
    unholy_presence = { id = 48265, type = "buff" },
    blood_presence  = { id = 48266, type = "buff" },
    horn_of_winter  = { id = 57623, type = "buff" },
    killing_machine = { id = 51124, type = "buff" },
    bone_shield     = { id = 49222, type = "buff" },
    summon_gargoyle = { id = 49206, type = "buff" },
}

--------------------------------------------------------------------
-- Abilities
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
    scourge_strike = {
        key = "scourge_strike", id = 55271, harmful = true, castableMoving = true,
        runes = { frost = 1, unholy = 1 }, generatesRP = 15,
    },
    blood_strike = {
        key = "blood_strike", id = 49930, harmful = true, castableMoving = true,
        runes = { blood = 1 }, generatesRP = 10,
        applies = "desolation", appliesTo = "buff", appliesFor = 20,
    },
    death_coil = {
        key = "death_coil", id = 49895, harmful = true, castableMoving = true,
        rp = 40,
    },
    blood_boil = {
        key = "blood_boil", id = 49941, harmful = true, castableMoving = true,
        runes = { blood = 1 }, generatesRP = 10,
    },
    death_and_decay = {
        key = "death_and_decay", id = 49938, harmful = true, castableMoving = true,
        runes = { blood = 1, frost = 1, unholy = 1 }, cd = 30,
    },
    ghoul_frenzy = {
        key = "ghoul_frenzy", id = 63560, castableMoving = true,
        runes = { unholy = 1 },
        applies = "ghoul_frenzy", appliesTo = "buff", appliesFor = 30,
    },
    blood_tap = {
        key = "blood_tap", id = 45529, castableMoving = true, cd = 60,
    },
    pestilence = {
        key = "pestilence", id = 50842, harmful = true, castableMoving = true,
        runes = { blood = 1 },
    },
    bone_shield = {
        key = "bone_shield", id = 49222, castableMoving = true, cd = 60,
        applies = "bone_shield", appliesTo = "buff", appliesFor = 300,
    },
    horn_of_winter = {
        key = "horn_of_winter", id = 57623, castableMoving = true, cd = 20,
        generatesRP = 10,
        applies = "horn_of_winter", appliesTo = "buff", appliesFor = 120,
    },
    mind_freeze = {
        key = "mind_freeze", id = 47528, harmful = true, castableMoving = true,
        cd = 10, rp = 20,
    },
    unholy_presence = {
        key = "unholy_presence", id = 48265, castableMoving = true,
        applies = "unholy_presence", appliesTo = "buff", appliesFor = 3600,
    },
    blood_presence = {
        key = "blood_presence", id = 48266, castableMoving = true,
        applies = "blood_presence", appliesTo = "buff", appliesFor = 3600,
    },

    -- MAJOR COOLDOWNS ------------------------------------------------
    summon_gargoyle = {
        key = "summon_gargoyle", id = 49206, harmful = true,
        castableMoving = true, cd = 180,
        majorCD = true, minTTD = 25,
        cdLabel = "Summon Gargoyle",
    },
    army_of_the_dead = {
        key = "army_of_the_dead", id = 42650, castableMoving = true, cd = 600,
        runes = { blood = 1, frost = 1, unholy = 1 },
        majorCD = true, minTTD = 40,
        cdLabel = "Army of the Dead",
    },
    empower_rune_weapon = {
        key = "empower_rune_weapon", id = 47568, castableMoving = true, cd = 300,
        majorCD = true, minTTD = 20,
        cdLabel = "Empower Rune Weapon",
    },
    -- NOT tagged majorCD: keeping the ghoul alive is upkeep, not a
    -- burst cooldown, and should not be suppressed by /er cd.
    raise_dead = {
        key = "raise_dead", id = 46584, castableMoving = true, cd = 180,
    },
}

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
-- Glyph of Disease: makes Pestilence refresh BOTH diseases to full
-- duration, which changes disease upkeep completely.
local GLYPH_OF_DISEASE = 63334

function spec.UpdateExtra(state)
    state.rp = state.runicPower or 0

    -- Read the build rather than assuming one. Anything not talented
    -- fails IsUsableSpell and drops out of the priority on its own;
    -- these flags let the list actively branch instead.
    state.glyph_of_disease = C.HasGlyph(GLYPH_OF_DISEASE)
    state.has_ghoul        = state.pet and true or false

    local refresh = ER:Setting("diseaseRefresh") or 3
    local dots = state.dot or {}
    local ff = dots.frost_fever  or { up = false, remains = 0 }
    local bp = dots.blood_plague or { up = false, remains = 0 }
    state.disease_low      = (ff.remains < refresh) or (bp.remains < refresh)
    state.both_diseases_up = ff.up and bp.up

    -- Gargoyle. Prefer a real aura where the server provides one -
    -- Warmane does expose "Summon Gargoyle" as a trackable aura - and
    -- fall back to the cast timestamp only when it is absent.
    local aura = state.buff and state.buff.summon_gargoyle
    if aura and aura.up then
        state.gargoyle_remains = aura.remains
        state.gargoyle_up = true
    else
        local since = (state.sinceCast and state.sinceCast.summon_gargoyle) or 9999
        state.gargoyle_remains = math.max(0, 30 - since)
        state.gargoyle_up = state.gargoyle_remains > 0
    end

    -- Rune bookkeeping the Unholy list leans on: Ghoul Frenzy wants to
    -- be paid for with a Death Rune so a natural unholy rune stays free
    -- for Scourge Strike.
    local deathRunes, bloodReady = 0, 0
    for _, r in ipairs(state.runes or {}) do
        if r.ready and r.type == "death" then deathRunes = deathRunes + 1 end
        if r.ready and r.type == "blood" then bloodReady = bloodReady + 1 end
    end
    state.death_runes_ready = deathRunes
    state.blood_runes_ready = bloodReady
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    -- You OPEN in Unholy Presence: Gargoyle is up at the pull and
    -- snapshots haste, so it wants Unholy from the first global. The
    -- swap to Blood happens after that window, not before the fight.
    { key = "unholy_presence", when = function(s)
        return s.presence ~= "unholy"
    end },
    { key = "horn_of_winter", when = function(s)
        return not s.buff.horn_of_winter.up
    end },
}

-- OPENER. Runs for the first few seconds of a fight, in order, each
-- entry until it has been cast the stated number of times.
--   diseases up -> Desolation up -> Gargoyle -> burn everything into
--   the Gargoyle window -> drop back to Blood Presence.
spec.lists.opener = {
    -- BS > PS > IT > BS > SS > BT > Gargoyle > Blood Presence > ERW
    -- > SS > BS > SS > BS > DC > DC
    --
    -- Blood Strike leads so Desolation is up before anything else
    -- lands. Gargoyle is summoned while still in Unholy Presence, then
    -- you drop straight to Blood Presence and spend ERW inside the
    -- window. Horn of Winter goes out 2-3s before the pull, which is
    -- precombat, not part of this list.
    { key = "blood_strike",        casts = 1 },
    { key = "plague_strike",       casts = 1 },
    { key = "icy_touch",           casts = 1 },
    { key = "blood_strike",        casts = 2 },
    { key = "scourge_strike",      casts = 1 },
    { key = "blood_tap",           casts = 1 },
    { key = "summon_gargoyle",     casts = 1,
      when = function(s) return not s.gargoyle_up end },
    { key = "blood_presence",      casts = 1,
      when = function(s)
          return ER:Setting("managePresence") ~= false
             and s.presence ~= "blood"
      end },
    { key = "empower_rune_weapon", casts = 1 },
    { key = "scourge_strike",      casts = 2 },
    { key = "blood_strike",        casts = 3 },
    { key = "scourge_strike",      casts = 3 },
    { key = "blood_strike",        casts = 4 },
    { key = "death_coil",          casts = 1 },
    { key = "death_coil",          casts = 2 },
}

-- AoE, following the source's DND list.
--
-- THE BUG THIS FIXES: Pestilence used to fire whenever both diseases
-- were on the current target, which is true almost always - so at 3
-- enemies it recommended Pestilence every single global. Pestilence is
-- a SPREAD, not a filler. It is only worth a rune when there is
-- something nearby that does not already have the disease, which means
-- counting how many targets actually carry it.
spec.lists.aoe = {
    { key = "raise_dead", when = function(s)
        return ER:Setting("keepGhoul") ~= false and not s.has_ghoul
    end },

    { key = "icy_touch",     when = function(s) return s.dot.frost_fever.remains  < 3 end },
    { key = "plague_strike", when = function(s) return s.dot.blood_plague.remains < 3 end },

    { key = "blood_strike", when = function(s) return not s.buff.desolation.up end },

    { key = "empower_rune_weapon", when = function(s) return s.gargoyle_up end },
    { key = "army_of_the_dead",    when = function(s) return s.gargoyle_up end },

    { key = "death_and_decay" },

    { key = "scourge_strike", when = function(s)
        return s.cooldown.death_and_decay.remains > 6
    end },

    -- spread only while something is missing the disease
    { key = "pestilence", when = function(s)
        return s.dot.frost_fever.up
           and (s.activeDot.frost_fever or 0) < (s.activeEnemies or 1)
    end },

    { key = "blood_boil", when = function(s)
        return s.cooldown.death_and_decay.remains > 6
    end },

    { key = "blood_strike", when = function(s)
        return s.cooldown.death_and_decay.remains > 6
           and s.buff.desolation.remains < 10
    end },

    { key = "summon_gargoyle", when = function(s)
        if s.gargoyle_up then return false end
        return ER:Setting("gargoyleNeedsUnholy") == false
            or s.presence == "unholy"
    end },

    { key = "death_coil", when = function(s)
        return s.cooldown.summon_gargoyle.remains > 0
    end },
}

spec.lists.single = {

    -- GHOUL. The imported list assumes a Master of Ghouls build where
    -- the ghoul is permanent and never needs thinking about. If it is
    -- dead or was never summoned, nothing else matters much.
    { key = "raise_dead", when = function(s)
        return ER:Setting("keepGhoul") ~= false and not s.has_ghoul
    end },

    -- BONE SHIELD, high.
    -- Costs no runes, only a global, and is a flat damage increase as
    -- well as mitigation. A free 1-minute cooldown belongs above rune
    -- spenders, not below them. Not in the imported list at all, which
    -- assumes the Ghoul Frenzy build.
    { key = "bone_shield", when = function(s)
        return ER:Setting("useBoneShield") ~= false
           and not s.buff.bone_shield.up
    end },

    -- DISEASES.
    -- With Glyph of Disease, Pestilence refreshes both to full for one
    -- blood rune, which is far cheaper than recasting both. Without it,
    -- reapply individually. The imported 2H list had no Pestilence line
    -- at all, which is correct only for the glyphless build.
    { key = "pestilence", when = function(s)
        return s.glyph_of_disease and s.both_diseases_up and s.disease_low
    end },

    { key = "icy_touch", when = function(s)
        local refresh = ER:Setting("diseaseRefresh") or 3
        return s.dot.frost_fever.remains < refresh
    end },

    { key = "plague_strike", when = function(s)
        local refresh = ER:Setting("diseaseRefresh") or 3
        return s.dot.blood_plague.remains < refresh
    end },


    -- Desolation is a flat damage buff kept up by Blood Strike
    { key = "blood_strike", when = function(s) return not s.buff.desolation.up end },

    -- ---- everything below keys off Gargoyle ----

    -- Army during Gargoyle: the ghouls' damage benefits from the same
    -- burst window, and the runes are otherwise idle.
    { key = "army_of_the_dead", when = function(s) return s.gargoyle_up end },

    -- Blood Tap makes a Death Rune so Ghoul Frenzy does not eat the
    -- unholy rune Scourge Strike wants.
    -- Blood Tap during the Gargoyle window converts a blood rune to a
    -- Death Rune, buying an extra strike while the burst is running.
    { key = "blood_tap", when = function(s) return s.gargoyle_up end },

    { key = "blood_tap", when = function(s)
        return not s.buff.ghoul_frenzy.up and s.blood_runes_ready == 0
    end },

    -- Ghoul Frenzy drops out by itself when untalented (IsUsableSpell
    -- returns nil), so no explicit build check is needed here.
    { key = "ghoul_frenzy", when = function(s)
        return not s.buff.ghoul_frenzy.up and s.death_runes_ready > 0
    end },

    { key = "scourge_strike" },
    { key = "blood_strike" },

    -- PRESENCE SWAP, part 1 of 2.
    -- Gargoyle snapshots haste at summon, so switch to Unholy Presence
    -- shortly BEFORE it comes off cooldown. This has to sit above the
    -- Gargoyle line or the summon happens in the wrong presence.
    { key = "unholy_presence", when = function(s)
        return ER:Setting("managePresence") ~= false
           and s.presence ~= "unholy"
           and s.cooldown.summon_gargoyle.remains <= (ER:Setting("presenceLead") or 3)
           and ER:CooldownEnabled("summon_gargoyle")
    end },

    -- Empower Rune Weapon refunds every rune: spent inside Gargoyle so
    -- the extra strikes land while the burst window is open.
    { key = "empower_rune_weapon", when = function(s) return s.gargoyle_up end },

    { key = "summon_gargoyle", when = function(s)
        if s.gargoyle_up then return false end     -- already out
        -- Wants Unholy Presence up for the haste snapshot. The swap
        -- above puts us there first; this just avoids firing early.
        return ER:Setting("gargoyleNeedsUnholy") == false
            or s.presence == "unholy"
    end },

    -- Only dump runic power once Gargoyle is unavailable
    { key = "death_coil", when = function(s)
        return s.cooldown.summon_gargoyle.remains > 0
    end },

    -- PRESENCE SWAP, part 2 of 2.
    -- Gargoyle is out or on cooldown: go back to Blood Presence for the
    -- damage. Sits below the strikes so it never displaces a global
    -- that could have been damage.
    { key = "blood_presence", when = function(s)
        return ER:Setting("managePresence") ~= false
           and s.presence ~= "blood"
           and not s.gargoyle_up
           and s.cooldown.summon_gargoyle.remains > (ER:Setting("presenceLead") or 3)
    end },

    { key = "horn_of_winter", when = function(s)
        return not s.buff.horn_of_winter.up
    end },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },

    -- The opener only owns the first stretch of a fight.
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
    return t3 > t1 and t3 > t2      -- Unholy is tab 3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("DEATHKNIGHT", "unholy", "Death Knight", "Unholy", {
    { type = "check", key = "gargoyleNeedsUnholy",
      label = "Gargoyle only in Unholy Presence",
      onValue = true, offValue = false,
      tooltip = "Gargoyle snapshots your haste when summoned, so it is "
             .. "worth a lot more cast in Unholy Presence." },
    { type = "check", key = "useBoneShield",
      label = "Keep Bone Shield up", onValue = true, offValue = false,
      tooltip = "Free apart from the global, and a damage increase as "
             .. "well as mitigation, so it sits high in the priority." },
    { type = "check", key = "keepGhoul",
      label = "Remind me to summon my ghoul",
      onValue = true, offValue = false,
      tooltip = "Suggests Raise Dead whenever you have no pet out." },
    { type = "slider", key = "diseaseRefresh",
      label = "Refresh diseases at", min = 1, max = 8, step = 0.5,
      fmt = "%.1fs",
      tooltip = "How much disease duration should be left before "
             .. "refreshing. Glyph of Disease is detected automatically "
             .. "and switches this to Pestilence." },
    { type = "check", key = "managePresence",
      label = "Manage presence around Gargoyle",
      onValue = true, offValue = false,
      tooltip = "Switches to Unholy Presence just before Gargoyle so it "
             .. "snapshots the haste, then back to Blood Presence for "
             .. "the damage. Costs a global each way." },
    { type = "check", key = "useOpener",
      label = "Use the scripted opener", onValue = true, offValue = false,
      tooltip = "Runs a fixed burst sequence for the first few seconds "
             .. "of a fight, then hands over to the normal priority." },
    { type = "slider", key = "presenceLead",
      label = "Switch to Unholy this early", min = 0, max = 10, step = 0.5,
      fmt = "%.1fs",
      tooltip = "How far ahead of Gargoyle coming off cooldown to swap "
             .. "into Unholy Presence." },
}, spec)

--[[ NOTES ---------------------------------------------------------

  0. BUILD VARIANTS. The imported 2H SS list assumes the Ghoul Frenzy
     / Master of Ghouls build: permanent ghoul, no Pestilence, no Bone
     Shield. That is one of two common Unholy builds. This module now
     branches instead of assuming - Pestilence appears when Glyph of
     Disease is detected, Bone Shield when talented, and Raise Dead
     when you have no pet. Anything untalented fails IsUsableSpell and
     drops out on its own.

  1. GARGOYLE IS A PET, not a buff, so there is no aura to read. It is
     tracked from the combat log timestamp of the summon plus its 30s
     duration. If gargoyle-conditioned lines behave oddly, that timer
     is the first thing to check - /er state shows it.

  2. OMITTED from the source list: use_cooldowns, use_items,
     berserking, hyperspeed_acceleration and potion_of_speed. All are
     racial, trinket or engineering specific. The Gargoyle sync logic
     they encode is preserved in the lines that remain.

  3. DUAL WIELD differs more here than it did for Frost. The DW list
     adds Death and Decay to single target, gates Blood Strike on the
     Death and Decay cooldown, adds Blood Boil, and pairs Blood Tap
     with Ghoul Frenzy on consecutive globals. Worth its own spec entry
     rather than a setting.

  4. PRESENCE SWAPPING is on by default and implemented as a real
     two-way swap, not the single line the source has. The source only
     ever switches BACK to Blood; it assumes you were already in Unholy
     when Gargoyle came up. That works in a sim and not in a fight, so
     the swap into Unholy Presence is scheduled a configurable few
     seconds before Gargoyle is ready.
------------------------------------------------------------------]]
