--[[ ElvinRotation - Specs/HunterMarksmanship.lua
     Marksmanship Hunter, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/HunterMarksmanship.simc

     Same frame as Survival, different engine: Chimera Shot refreshes
     Serpent Sting, so the sting goes up once and Chimera keeps it
     there while Aimed and Arcane fill the gaps.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Marksmanship Hunter",
    class     = "HUNTER",
    tab       = 2,             -- Marksmanship tree
    school    = 1,
    powerType = 0,
    gcdProbe  = 49052,         -- Steady Shot
    hasteRefBase = 2,
}

spec.auras = {
    aspect_of_the_dragonhawk = { id = 61847, type = "buff" },
    aspect_of_the_viper      = { id = 34074, type = "buff" },
    rapid_fire               = { id = 3045,  type = "buff" },
    call_of_the_wild         = { id = 53434, type = "buff" },
    improved_steady_shot     = { id = 53220, type = "buff" },

    serpent_sting = { id = 49001, type = "debuff", mine = true, duration = 15 },
    hunters_mark  = { id = 53338, type = "debuff", mine = true, duration = 300 },
}

spec.abilities = {
    chimera_shot = {
        key = "chimera_shot", id = 53209, harmful = true, cd = 10,
        applies = "serpent_sting", appliesFor = 15,
    },
    aimed_shot = {
        key = "aimed_shot", id = 49050, harmful = true, cd = 10, castTime = 2.5,
    },
    arcane_shot = {
        key = "arcane_shot", id = 49045, harmful = true, cd = 6,
    },
    steady_shot = {
        key = "steady_shot", id = 49052, harmful = true, castTime = 2,
    },
    serpent_sting = {
        key = "serpent_sting", id = 49001, harmful = true,
        applies = "serpent_sting", appliesFor = 15, openerSkipIfUp = true,
    },
    kill_shot = {
        key = "kill_shot", id = 61006, harmful = true, cd = 15,
    },
    multi_shot = {
        key = "multi_shot", id = 49048, harmful = true, cd = 10,
    },
    volley = {
        key = "volley", id = 58434, harmful = true,
        channel = true, channelTime = 6,
    },
    explosive_trap = {
        key = "explosive_trap", id = 49067, harmful = true, cd = 30,
    },
    silencing_shot = {
        key = "silencing_shot", id = 34490, harmful = true, cd = 20,
    },
    rapid_fire = {
        key = "rapid_fire", id = 3045, cd = 300, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Rapid Fire",
        applies = "rapid_fire", appliesTo = "buff", appliesFor = 15,
    },
    readiness = {
        key = "readiness", id = 23989, cd = 300, castableMoving = true,
        majorCD = true, minTTD = 20, cdLabel = "Readiness",
    },
    call_of_the_wild = {
        key = "call_of_the_wild", id = 53434, cd = 300, castableMoving = true,
        majorCD = true, minTTD = 20, cdLabel = "Call of the Wild",
    },
    hunters_mark = {
        key = "hunters_mark", id = 53338, harmful = true, castableMoving = true,
        applies = "hunters_mark", appliesFor = 300,
    },
    aspect_of_the_dragonhawk = {
        key = "aspect_of_the_dragonhawk", id = 61847, castableMoving = true,
        applies = "aspect_of_the_dragonhawk", appliesTo = "buff", appliesFor = 3600,
    },
    aspect_of_the_viper = {
        key = "aspect_of_the_viper", id = 34074, castableMoving = true,
        applies = "aspect_of_the_viper", appliesTo = "buff", appliesFor = 3600,
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
    spec.gcdProbeName = spec.abilities.steady_shot.name
    spec.hasteRefName = spec.abilities.steady_shot.name
end

function spec.UpdateExtra(state)
    state.execute_phase = (state.targetHealthPct or 100) < 20
    state.viper_up = state.buff.aspect_of_the_viper.up
    state.mana_low = (state.manaPct or 100) <= (ER:Setting("viperMana") or 25)
end

spec.lists = {}

spec.lists.precombat = {
    { key = "aspect_of_the_dragonhawk", when = function(s)
        return not s.buff.aspect_of_the_dragonhawk.up
    end },
    { key = "hunters_mark", when = function(s)
        return ER:Setting("maintainHuntersMark") ~= false and not s.dot.hunters_mark.up
    end },
}

spec.lists.single = {
    -- Back to Dragonhawk once mana recovers.
    { key = "aspect_of_the_dragonhawk", when = function(s)
        return not s.buff.aspect_of_the_dragonhawk.up and (s.manaPct or 0) > 25
    end },

    { key = "hunters_mark", when = function(s)
        return ER:Setting("maintainHuntersMark") ~= false and not s.dot.hunters_mark.up
    end },

    { key = "rapid_fire",       when = function(s) return not s.buff.rapid_fire.up end },
    { key = "call_of_the_wild", when = function(s) return not s.buff.call_of_the_wild.up end },

    { key = "kill_shot", when = function(s) return s.execute_phase end },

    -- Serpent Sting goes up once; Chimera Shot refreshes it from then on.
    { key = "serpent_sting", when = function(s) return not s.dot.serpent_sting.up end },

    { key = "chimera_shot" },
    { key = "aimed_shot" },

    { key = "readiness", when = function(s)
        return s.cooldown.rapid_fire.remains >= 150
           and s.cooldown.chimera_shot.remains > 0
           and s.cooldown.aimed_shot.remains > 0
    end },

    { key = "arcane_shot" },

    -- Mana emergency: swap to Viper.
    { key = "aspect_of_the_viper", when = function(s)
        return ER:Setting("manageViper") ~= false and s.mana_low and not s.viper_up
    end },

    { key = "steady_shot" },
}

spec.lists.aoe = {
    { key = "explosive_trap", when = function(s)
        return ER:Setting("useExplosiveTrap") == true
    end },
    { key = "multi_shot" },
    { key = "volley", when = function(s)
        return (s.activeEnemies or 1) >= 3 and not s.moving
    end },
    { key = "serpent_sting", when = function(s) return not s.dot.serpent_sting.up end },
    { key = "chimera_shot" },
    { key = "steady_shot" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) >= 2 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t2 > t1 and t2 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("HUNTER", "marksmanship", "Hunter", "Marksmanship", {
    { type = "check", key = "manageViper",
      label = "Swap to Aspect of the Viper when low", onValue = true,
      offValue = false,
      tooltip = "Costs damage but prevents running dry. Swaps back to "
             .. "Dragonhawk above 25% mana." },
    { type = "slider", key = "viperMana",
      label = "Swap to Viper below", min = 5, max = 50, step = 5,
      fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. CHIMERA SHOT refreshes Serpent Sting, so the sting is only cast
     when missing. If it keeps being suggested, Chimera is not landing
     or the sting aura is not being read - check /er dots.
  2. IMPROVED STEADY SHOT is tracked but not acted on. The source has
     a Steady Shot line tied to the Viper swap timing that needs cast
     history the addon does not keep.
  3. NO SHOT WEAVING, same as Survival.
  4. BOTH HUNTER SPECS share the Hunter class on different talent
     tabs, so detection picks whichever has more points.
------------------------------------------------------------------]]
