--[[ ElvinRotation - Specs/WarriorFury.lua
     Fury Warrior, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/WarriorFury.simc

     Bloodthirst and Whirlwind on cooldown, Slam when Bloodsurge
     procs, Heroic Strike as the rage dump. Like Arms, the source
     runs separate lists per stance and this does not - see NOTES.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Fury Warrior",
    class     = "WARRIOR",
    tab       = 2,             -- Fury tree
    school    = 1,
    powerType = 1,             -- rage
    gcdProbe  = 23881,         -- Bloodthirst
}

spec.auras = {
    berserker_stance = { id = 2458,  type = "buff" },
    battle_stance    = { id = 2457,  type = "buff" },
    bloodsurge       = { id = 46916, type = "buff" },
    death_wish       = { id = 12292, type = "buff" },
    recklessness     = { id = 1719,  type = "buff" },
    battle_shout     = { id = 47436, type = "buff" },
    enrage           = { id = 12880, type = "buff" },

    rend         = { id = 47465, type = "debuff", mine = true, duration = 15 },
    sunder_armor = { id = 7386,  type = "debuff", mine = false, duration = 30 },
}

spec.abilities = {
    bloodthirst = {
        key = "bloodthirst", id = 23881, harmful = true, cd = 4, power = 30,
    },
    whirlwind = {
        key = "whirlwind", id = 1680, harmful = true, cd = 10, power = 25,
    },
    slam = {
        key = "slam", id = 47475, harmful = true, castTime = 1.5, power = 15,
    },
    execute = {
        key = "execute", id = 47471, harmful = true, power = 15,
    },
    heroic_strike = {
        key = "heroic_strike", id = 47450, harmful = true, power = 15,
    },
    cleave = {
        key = "cleave", id = 47520, harmful = true, power = 20,
    },
    death_wish = {
        key = "death_wish", id = 12292, cd = 180, castableMoving = true, power = 10,
        majorCD = true, minTTD = 15, cdLabel = "Death Wish",
        applies = "death_wish", appliesTo = "buff", appliesFor = 30,
    },
    recklessness = {
        key = "recklessness", id = 1719, cd = 300, castableMoving = true,
        majorCD = true, minTTD = 12, cdLabel = "Recklessness",
        applies = "recklessness", appliesTo = "buff", appliesFor = 12,
    },
    bloodrage = {
        key = "bloodrage", id = 2687, cd = 60, castableMoving = true,
        generatesPower = 20,
    },
    battle_shout = {
        key = "battle_shout", id = 47436, castableMoving = true,
        applies = "battle_shout", appliesTo = "buff", appliesFor = 120,
    },
    berserker_stance = {
        key = "berserker_stance", id = 2458, castableMoving = true,
        applies = "berserker_stance", appliesTo = "buff", appliesFor = 3600,
    },
    sunder_armor = {
        key = "sunder_armor", id = 7386, harmful = true, power = 15,
        applies = "sunder_armor", appliesFor = 30,
    },
    pummel = {
        key = "pummel", id = 6552, harmful = true, cd = 10, power = 10,
    },
    victory_rush = {
        key = "victory_rush", id = 34428, harmful = true,
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
    spec.gcdProbeName = spec.abilities.bloodthirst.name
end

function spec.UpdateExtra(state)
    state.rage = state.power or 0
    state.execute_phase = (state.targetHealthPct or 100) < 20
    state.bloodsurge = state.buff.bloodsurge.up
    state.rage_to_queue = ER:Setting("furyHeroicStrikeRage") or 50
end

spec.lists = {}

spec.lists.precombat = {
    { key = "berserker_stance", when = function(s)
        return not s.buff.berserker_stance.up
    end },
    { key = "battle_shout", when = function(s) return not s.buff.battle_shout.up end },
}

spec.lists.single = {
    { key = "bloodrage", when = function(s)
        return (s.powerMax or 100) - s.rage > 20
    end },

    { key = "death_wish" },
    { key = "recklessness" },

    { key = "bloodthirst" },
    { key = "whirlwind" },

    -- Bloodsurge makes Slam instant. Without it the cast is a loss.
    { key = "slam", when = function(s) return s.bloodsurge end },

    { key = "execute", when = function(s) return s.execute_phase end },

    { key = "victory_rush" },

    -- Rage dump, held back so Bloodthirst is always affordable.
    { key = "heroic_strike", when = function(s)
        return s.rage >= s.rage_to_queue
    end },
}

spec.lists.aoe = {
    { key = "death_wish" },
    { key = "whirlwind" },
    { key = "bloodthirst" },
    { key = "slam", when = function(s) return s.bloodsurge end },
    { key = "cleave", when = function(s) return s.rage >= s.rage_to_queue end },
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
    if class ~= "WARRIOR" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t2 > t1 and t2 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("WARRIOR", "fury", "Warrior", "Fury", {
    { type = "slider", key = "furyHeroicStrikeRage",
      label = "Queue Heroic Strike above", min = 20, max = 100, step = 5,
      fmt = "%d rage",
      tooltip = "Rage kept in reserve so Bloodthirst and Whirlwind are "
             .. "always affordable." },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. STANCE DANCING IS NOT IMPLEMENTED, same as Arms. Fury lives in
     Berserker Stance; the source's Battle and Defensive lists are
     for situations this addon does not model.

  2. HEROIC STRIKE AND CLEAVE are off-GCD queued abilities. The addon
     has no concept of off-GCD, so they are recommended as if they
     took a global. The rage reserve slider is the crude substitute.
     This is the single biggest inaccuracy in both Warrior specs.

  3. SLAM WEAVING against the swing timer is not modelled. Slam is
     only suggested on a Bloodsurge proc, which is the safe subset.

  4. SUNDER ARMOR upkeep is omitted - normally a tank's job, and the
     source's build-and-maintain logic is elaborate.

  5. BOTH WARRIOR SPECS are now built, one per talent tab.
------------------------------------------------------------------]]
