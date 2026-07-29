--[[ ElvinRotation - Specs/HunterBeastMastery.lua
     Beast Mastery Hunter, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/HunterBeastMastery.simc

     The shortest Hunter list: cooldowns, Kill Command, keep Serpent
     Sting up, then Arcane Shot and Steady Shot. Most of the damage
     comes from the pet, which the addon cannot manage for you.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Beast Mastery Hunter",
    class     = "HUNTER",
    tab       = 1,             -- Beast Mastery tree
    school    = 1,
    powerType = 0,
    gcdProbe  = 49052,         -- Steady Shot
    hasteRefBase = 2,
}

spec.auras = {
    aspect_of_the_dragonhawk = { id = 61847, type = "buff" },
    bestial_wrath            = { id = 19574, type = "buff" },
    rapid_fire               = { id = 3045,  type = "buff" },
    call_of_the_wild         = { id = 53434, type = "buff" },
    the_beast_within         = { id = 34471, type = "buff" },

    serpent_sting = { id = 49001, type = "debuff", mine = true, duration = 15 },
    hunters_mark  = { id = 53338, type = "debuff", mine = true, duration = 300 },
}

spec.abilities = {
    kill_command = {
        key = "kill_command", id = 34026, harmful = true, cd = 60,
    },
    bestial_wrath = {
        key = "bestial_wrath", id = 19574, cd = 120, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Bestial Wrath",
        applies = "bestial_wrath", appliesTo = "buff", appliesFor = 18,
    },
    serpent_sting = {
        key = "serpent_sting", id = 49001, harmful = true,
        applies = "serpent_sting", appliesFor = 15, openerSkipIfUp = true,
    },
    arcane_shot = {
        key = "arcane_shot", id = 49045, harmful = true, cd = 6,
    },
    steady_shot = {
        key = "steady_shot", id = 49052, harmful = true, castTime = 2,
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
    intimidation = {
        key = "intimidation", id = 19577, harmful = true, cd = 60,
    },
    rapid_fire = {
        key = "rapid_fire", id = 3045, cd = 300, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Rapid Fire",
        applies = "rapid_fire", appliesTo = "buff", appliesFor = 15,
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
    spec.gcdProbeName = spec.abilities.steady_shot.name
    spec.hasteRefName = spec.abilities.steady_shot.name
end

function spec.UpdateExtra(state)
    state.execute_phase = (state.targetHealthPct or 100) < 20
    state.has_pet = state.pet and true or false
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
    { key = "hunters_mark", when = function(s)
        return ER:Setting("maintainHuntersMark") ~= false and not s.dot.hunters_mark.up
    end },

    { key = "rapid_fire" },
    { key = "call_of_the_wild" },
    { key = "bestial_wrath", when = function(s) return s.has_pet end },
    { key = "kill_command",  when = function(s) return s.has_pet end },

    { key = "kill_shot", when = function(s) return s.execute_phase end },

    { key = "serpent_sting", when = function(s) return not s.dot.serpent_sting.up end },

    { key = "arcane_shot" },
    { key = "steady_shot" },
}

spec.lists.aoe = {
    { key = "bestial_wrath", when = function(s) return s.has_pet end },
    { key = "kill_command",  when = function(s) return s.has_pet end },
    { key = "explosive_trap", when = function(s)
        return ER:Setting("useExplosiveTrap") == true
    end },
    { key = "multi_shot" },
    { key = "volley", when = function(s)
        return (s.activeEnemies or 1) > 2 and not s.moving
    end },
    { key = "serpent_sting", when = function(s) return not s.dot.serpent_sting.up end },
    { key = "arcane_shot" },
    { key = "steady_shot" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 2 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("HUNTER", "beastmastery", "Hunter", "Beast Mastery", {
    { type = "check", key = "maintainHuntersMark",
      label = "Maintain Hunter's Mark", onValue = true, offValue = false },
    { type = "check", key = "useExplosiveTrap",
      label = "Use Explosive Trap in AoE", onValue = true, offValue = false },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. MOST OF YOUR DAMAGE IS THE PET, and the addon does not manage it.
     Bestial Wrath and Kill Command are gated on having one out, but
     nothing reminds you to summon, revive, or keep it on the target.
     That is the biggest gap in this spec and it is not fixable from
     the priority side.
  2. INTIMIDATION is in the ability list but not the priority; the
     source uses it as an interrupt, which needs cast detection on the
     target.
  3. ALL THREE Hunter specs are now built, one per talent tab.
------------------------------------------------------------------]]
