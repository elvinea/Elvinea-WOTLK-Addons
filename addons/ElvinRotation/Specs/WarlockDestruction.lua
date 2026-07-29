--[[ ElvinRotation - Specs/WarlockDestruction.lua
     Destruction Warlock, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/WarlockDestruction.simc

     Immolate is the engine: Conflagrate consumes it and Chaos Bolt
     wants it up, so the whole list orbits keeping it rolling.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Destruction Warlock",
    class     = "WARLOCK",
    tab       = 3,             -- Destruction tree
    school    = 4,             -- fire
    powerType = 0,
    gcdProbe  = 47838,         -- Incinerate
    hasteRefBase = 2.5,        -- Incinerate: 2.5s base
}

spec.auras = {
    fel_armor   = { id = 47893, type = "buff" },
    life_tap    = { id = 63321, type = "buff" },
    backdraft   = { id = 54277, type = "buff" },
    molten_core = { id = 71165, type = "buff" },

    immolate       = { id = 47811, type = "debuff", mine = true, duration = 15 },
    corruption     = { id = 47813, type = "debuff", mine = true, duration = 18 },
    curse_of_doom  = { id = 47867, type = "debuff", mine = true, duration = 60 },
    curse_of_agony = { id = 47864, type = "debuff", mine = true, duration = 24 },
}

spec.abilities = {
    immolate = {
        key = "immolate", id = 47811, harmful = true, castTime = 2,
        applies = "immolate", appliesFor = 15, openerSkipIfUp = true,
    },
    conflagrate = {
        key = "conflagrate", id = 17962, harmful = true, cd = 10, castTime = 0,
    },
    chaos_bolt = {
        key = "chaos_bolt", id = 59172, harmful = true, cd = 12, castTime = 2.5,
    },
    incinerate = {
        key = "incinerate", id = 47838, harmful = true, castTime = 2.5,
    },
    corruption = {
        key = "corruption", id = 47813, harmful = true, castTime = 0,
        applies = "corruption", appliesFor = 18, openerSkipIfUp = true,
    },
    curse_of_doom = {
        key = "curse_of_doom", id = 47867, harmful = true, castTime = 0,
        applies = "curse_of_doom", appliesFor = 60,
    },
    curse_of_agony = {
        key = "curse_of_agony", id = 47864, harmful = true, castTime = 0,
        applies = "curse_of_agony", appliesFor = 24,
    },
    shadowflame = {
        key = "shadowflame", id = 61291, harmful = true, cd = 15, castTime = 0,
    },
    seed_of_corruption = {
        key = "seed_of_corruption", id = 47836, harmful = true, castTime = 2,
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
}

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
    spec.gcdProbeName = spec.abilities.incinerate.name
    spec.hasteRefName = spec.abilities.incinerate.name
end

function spec.UpdateExtra(state)
    state.mana_low = (state.manaPct or 100) < (ER:Setting("destroLifeTapMana") or 20)
    -- Curse of Doom is only worth it on something that will live a
    -- full minute; below that Curse of Agony wins.
    state.long_fight = (state.ttd or 0) > 60
end

spec.lists = {}

spec.lists.precombat = {
    { key = "fel_armor", when = function(s) return not s.buff.fel_armor.up end },
    { key = "life_tap",  when = function(s)
        return ER:Setting("glyphLifeTap") == true and not s.buff.life_tap.up
    end },
}

spec.lists.single = {
    -- Immolate first: Conflagrate eats it and Chaos Bolt is worth
    -- more while it is ticking.
    { key = "immolate", when = function(s)
        return not s.dot.immolate.up or s.dot.immolate.remains < 1
    end },

    { key = "conflagrate", when = function(s)
        return s.dot.immolate.up or ER:Setting("conflagrateFreely") == true
    end },

    { key = "life_tap", when = function(s)
        return ER:Setting("glyphLifeTap") == true and not s.buff.life_tap.up
    end },

    { key = "chaos_bolt" },

    { key = "corruption", when = function(s)
        return not s.dot.corruption.up or s.dot.corruption.remains < 2
    end },

    { key = "curse_of_doom", when = function(s)
        return s.long_fight and not s.dot.curse_of_doom.up
    end },
    { key = "curse_of_agony", when = function(s)
        return not s.long_fight and (s.ttd or 0) > 30 and not s.dot.curse_of_agony.up
    end },

    { key = "life_tap", when = function(s) return s.mana_low end },

    { key = "incinerate" },
}

spec.lists.aoe = {
    { key = "life_tap", when = function(s) return s.mana_low end },
    { key = "shadowflame", when = function(s)
        return (s.activeEnemies or 1) > 3 and ER:Setting("useShadowflame") == true
    end },
    { key = "seed_of_corruption", when = function(s)
        return (s.activeEnemies or 1) > 3
    end },
    { key = "immolate", when = function(s) return not s.dot.immolate.up end },
    { key = "conflagrate", when = function(s) return s.dot.immolate.up end },
    { key = "incinerate" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 1 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "WARLOCK" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t3 > t1 and t3 > t2
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("WARLOCK", "destruction", "Warlock", "Destruction", {
    { type = "check", key = "conflagrateFreely",
      label = "Conflagrate without Immolate up", onValue = true, offValue = false,
      tooltip = "Conflagrate consumes Immolate. Off by default so it is "
             .. "never wasted." },
    { type = "slider", key = "destroLifeTapMana",
      label = "Life Tap below", min = 5, max = 60, step = 5, fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. CURSE CHOICE follows fight length: Curse of Doom above 60s,
     Curse of Agony between 30 and 60, nothing below that. The source
     also handles raid-assigned curses, which is out of scope.
  2. BACKDRAFT and Molten Core are tracked but not acted on; the
     source does not gate on them either.
  3. PET is not managed. Destruction wants an Imp out for the buff.
  4. MULTI-DOTTING in the AoE list is single-target only, as elsewhere.
------------------------------------------------------------------]]
