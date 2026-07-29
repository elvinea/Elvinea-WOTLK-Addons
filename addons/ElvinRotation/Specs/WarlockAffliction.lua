--[[ ElvinRotation - Specs/WarlockAffliction.lua
     Affliction Warlock, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/WarlockAffliction.simc

     Closest thing yet to Shadow Priest: keep several DoTs rolling and
     fill with a nuke. The wrinkle is Haunt, which buffs every other
     DoT while it is up, so it gates the whole list.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Affliction Warlock",
    class     = "WARLOCK",
    tab       = 1,             -- Affliction tree
    school    = 6,             -- shadow
    powerType = 0,             -- mana
    gcdProbe  = 47813,         -- Corruption: no cooldown

    hasteRefBase = 3,          -- Shadow Bolt: 3s base cast
}

--------------------------------------------------------------------
spec.auras = {
    fel_armor      = { id = 47893, type = "buff" },
    life_tap       = { id = 63321, type = "buff" },   -- glyph buff
    shadow_trance  = { id = 17941, type = "buff" },   -- Nightfall proc

    corruption          = { id = 47813, type = "debuff", mine = true, duration = 18 },
    unstable_affliction = { id = 47843, type = "debuff", mine = true, duration = 15 },
    haunt               = { id = 59164, type = "debuff", mine = true, duration = 12 },
    curse_of_agony      = { id = 47864, type = "debuff", mine = true, duration = 24 },
    shadow_mastery      = { id = 17800, type = "debuff", mine = false, duration = 30 },
    seed_of_corruption  = { id = 47836, type = "debuff", mine = true, duration = 18 },
}

--------------------------------------------------------------------
spec.abilities = {
    corruption = {
        key = "corruption", id = 47813, harmful = true, castTime = 0,
        applies = "corruption", appliesFor = 18, openerSkipIfUp = true,
    },
    unstable_affliction = {
        key = "unstable_affliction", id = 47843, harmful = true, castTime = 1.5,
        applies = "unstable_affliction", appliesFor = 15, openerSkipIfUp = true,
    },
    haunt = {
        key = "haunt", id = 59164, harmful = true, castTime = 1.5, cd = 8,
        applies = "haunt", appliesFor = 12,
    },
    curse_of_agony = {
        key = "curse_of_agony", id = 47864, harmful = true, castTime = 0,
        applies = "curse_of_agony", appliesFor = 24, openerSkipIfUp = true,
    },
    shadow_bolt = {
        key = "shadow_bolt", id = 47809, harmful = true, castTime = 3,
    },
    drain_soul = {
        key = "drain_soul", id = 47855, harmful = true,
        channel = true, channelTime = 15,
    },
    life_tap = {
        key = "life_tap", id = 57946, castableMoving = true,
        applies = "life_tap", appliesTo = "buff", appliesFor = 40,
    },
    fel_armor = {
        key = "fel_armor", id = 47893, castableMoving = true,
        applies = "fel_armor", appliesTo = "buff", appliesFor = 1800,
            selfBuff = true,
    },
    shadowflame = {
        key = "shadowflame", id = 61291, harmful = true, cd = 15, castTime = 0,
    },
    seed_of_corruption = {
        key = "seed_of_corruption", id = 47836, harmful = true, castTime = 2,
        applies = "seed_of_corruption", appliesFor = 18,
    },
    drain_life = {
        key = "drain_life", id = 47857, harmful = true,
        channel = true, channelTime = 5,
    },
    death_coil = {
        key = "death_coil", id = 47860, harmful = true, cd = 120, castTime = 0,
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

    spec.gcdProbeName = spec.abilities.corruption.name
    spec.hasteRefName = spec.abilities.shadow_bolt.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    local hm = 1 + (state.haste or 0) / 100
    state.sb_cast = 3   / hm
    state.ua_cast = 1.5 / hm
    state.haunt_cast = 1.5 / hm

    -- Below 26% health the source switches to a Drain Soul execute,
    -- which does far more damage than Shadow Bolt at that point.
    state.execute_phase = (state.targetHealthPct or 100) < 26

    -- Haunt buffs every other DoT while it is on the target, so
    -- refreshing DoTs is worth much more with it up. Its travel time
    -- matters: it is a missile, not instant.
    state.haunt_window = (state.dot.haunt.remains or 0)
                         > (state.haunt_cast + 0.5 + (state.latency or 0))

    state.mana_low = (state.manaPct or 100) < (ER:Setting("lifeTapMana") or 30)
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "fel_armor", when = function(s) return not s.buff.fel_armor.up end },
    { key = "life_tap",  when = function(s)
        return ER:Setting("glyphLifeTap") == true and not s.buff.life_tap.up
    end },
}

spec.lists.single = {
    { key = "corruption", when = function(s) return not s.dot.corruption.up end },

    -- Refresh Unstable Affliction inside the Haunt window so it
    -- snapshots the buff.
    { key = "unstable_affliction", when = function(s)
        return s.haunt_window
           and s.dot.unstable_affliction.remains < s.ua_cast + (s.latency or 0)
    end },

    { key = "haunt", when = function(s)
        return not s.dot.haunt.up
            or s.dot.haunt.remains < s.haunt_cast + 0.5 + (s.latency or 0)
    end },

    { key = "unstable_affliction", when = function(s)
        return not s.dot.unstable_affliction.up and (s.ttd or 0) > 15
    end },

    { key = "curse_of_agony", when = function(s)
        return not s.dot.curse_of_agony.up
    end },

    { key = "life_tap", when = function(s)
        return s.mana_low
            or (ER:Setting("glyphLifeTap") == true and s.buff.life_tap.remains < 5)
    end },

    { key = "shadowflame", when = function(s)
        return ER:Setting("useShadowflame") == true
    end },

    { key = "shadow_bolt" },
}

-- Below 26% health: Drain Soul replaces Shadow Bolt entirely.
spec.lists.execute = {
    { key = "unstable_affliction", when = function(s)
        return s.haunt_window
           and s.dot.unstable_affliction.remains < s.ua_cast
           and (s.ttd or 0) >= 15
    end },
    { key = "haunt", when = function(s)
        return not s.dot.haunt.up
            or s.dot.haunt.remains <= s.haunt_cast + 0.5 + (s.latency or 0)
    end },
    { key = "corruption", when = function(s) return not s.dot.corruption.up end },
    { key = "curse_of_agony", when = function(s)
        return not s.dot.curse_of_agony.up and (s.ttd or 0) >= 24
    end },
    { key = "life_tap", when = function(s)
        return s.mana_low
            or (ER:Setting("glyphLifeTap") == true and s.buff.life_tap.remains < 5)
    end },
    { key = "drain_soul" },
}

spec.lists.aoe = {
    { key = "life_tap", when = function(s) return s.mana_low end },
    { key = "seed_of_corruption", when = function(s)
        return (s.activeEnemies or 1) > (ER:Setting("seedThreshold") or 3)
           and not s.dot.seed_of_corruption.up
    end },
    { key = "corruption",          when = function(s) return not s.dot.corruption.up end },
    { key = "unstable_affliction", when = function(s) return not s.dot.unstable_affliction.up end },
    { key = "curse_of_agony",      when = function(s) return not s.dot.curse_of_agony.up end },
    { key = "haunt",               when = function(s) return not s.dot.haunt.up end },
    { key = "shadow_bolt" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "execute", terminal = true,
      when = function(s) return s.execute_phase and (s.activeEnemies or 1) == 1 end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 1 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

--------------------------------------------------------------------
function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "WARLOCK" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("WARLOCK", "affliction", "Warlock", "Affliction", {
    { type = "check", key = "glyphLifeTap",
      label = "I have Glyph of Life Tap", onValue = true, offValue = false,
      tooltip = "Keeps the Life Tap spellpower buff rolling. The addon "
             .. "cannot read this glyph reliably, so tell it." },
    { type = "check", key = "useShadowflame",
      label = "Use Shadowflame", onValue = true, offValue = false,
      tooltip = "Melee range only. Off by default since the addon "
             .. "cannot check your distance to the target." },
    { type = "slider", key = "lifeTapMana",
      label = "Life Tap below", min = 5, max = 60, step = 5, fmt = "%d%% mana" },
    { type = "slider", key = "seedThreshold",
      label = "Seed of Corruption above", min = 2, max = 8, step = 1,
      fmt = "%d targets" },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. PET is not managed. The source summons a Felhunter precombat;
     that is a one-off, not rotation.

  2. HAUNT TRAVEL TIME is approximated as a flat 0.5s. The source
     models it properly; 3.3.5 gives no way to measure it.

  3. MULTI-DOTTING in the AoE list is single-target only here. The
     source uses cycle_targets, which 3.3.5 cannot express.

  4. SHADOW MASTERY (Improved Shadow Bolt) upkeep is omitted. It is
     usually another caster's debuff and the source only maintains it
     under a setting.

  5. PERSISTENT MULTIPLIER. The source re-applies Corruption when it
     would snapshot stronger buffs. That needs snapshot tracking the
     addon does not do, so Corruption is only refreshed when missing.
------------------------------------------------------------------]]
