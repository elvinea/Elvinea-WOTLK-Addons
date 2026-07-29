--[[ ElvinRotation - Specs/HunterSurvival.lua
     Survival Hunter, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/HunterSurvival.simc

     First Hunter spec. Explosive Shot is the whole rotation: it is a
     three-tick DoT you re-apply the instant the previous one ends,
     and everything else fills the gaps around it.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Survival Hunter",
    class     = "HUNTER",
    tab       = 3,             -- Survival tree
    school    = 1,             -- physical
    powerType = 0,             -- mana
    gcdProbe  = 49052,         -- Steady Shot

    hasteRefBase = 2,          -- Steady Shot: 2s base
}

--------------------------------------------------------------------
spec.auras = {
    aspect_of_the_dragonhawk = { id = 61847, type = "buff" },
    rapid_fire               = { id = 3045,  type = "buff" },
    lock_and_load            = { id = 56453, type = "buff" },
    call_of_the_wild         = { id = 53434, type = "buff" },

    explosive_shot = { id = 60053, type = "debuff", mine = true, duration = 2 },
    serpent_sting  = { id = 49001, type = "debuff", mine = true, duration = 15 },
    black_arrow    = { id = 63672, type = "debuff", mine = true, duration = 15 },
    hunters_mark   = { id = 53338, type = "debuff", mine = true, duration = 300 },
}

--------------------------------------------------------------------
spec.abilities = {
    explosive_shot = {
        key = "explosive_shot", id = 60053, harmful = true, cd = 6,
        applies = "explosive_shot", appliesFor = 2,
    },
    black_arrow = {
        key = "black_arrow", id = 63672, harmful = true, cd = 30,
        applies = "black_arrow", appliesFor = 15,
    },
    aimed_shot = {
        key = "aimed_shot", id = 49050, harmful = true, cd = 10, castTime = 2.5,
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
    kill_command = {
        key = "kill_command", id = 34026, harmful = true, cd = 60,
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

    spec.gcdProbeName = spec.abilities.steady_shot.name
    spec.hasteRefName = spec.abilities.steady_shot.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    state.execute_phase = (state.targetHealthPct or 100) < 20

    -- Lock and Load makes the next two Explosive Shots free and off
    -- cooldown, which is the single biggest thing to react to.
    state.lnl_up = state.buff.lock_and_load.up
    state.has_pet = state.pet and true or false
end

--------------------------------------------------------------------
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
    { key = "kill_command", when = function(s) return s.has_pet end },

    -- Explosive Shot is the rotation. Re-apply the moment the previous
    -- one has finished ticking.
    { key = "explosive_shot", when = function(s)
        return not s.dot.explosive_shot.up
    end },

    { key = "black_arrow" },

    { key = "kill_shot", when = function(s) return s.execute_phase end },

    { key = "aimed_shot" },

    { key = "serpent_sting", when = function(s)
        return not s.dot.serpent_sting.up
    end },

    { key = "steady_shot" },
}

spec.lists.aoe = {
    { key = "explosive_shot", when = function(s)
        return not s.dot.explosive_shot.up
    end },
    { key = "black_arrow" },
    { key = "explosive_trap", when = function(s)
        return ER:Setting("useExplosiveTrap") == true
    end },
    { key = "multi_shot" },
    { key = "volley", when = function(s) return not s.moving end },
    { key = "steady_shot" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 2 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

--------------------------------------------------------------------
function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "HUNTER" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t3 > t1 and t3 > t2
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("HUNTER", "survival", "Hunter", "Survival", {
    { type = "check", key = "maintainHuntersMark",
      label = "Maintain Hunter's Mark", onValue = true, offValue = false,
      tooltip = "Often another hunter's job in a raid." },
    { type = "check", key = "useExplosiveTrap",
      label = "Use Explosive Trap in AoE", onValue = true, offValue = false,
      tooltip = "Needs the pack standing on it, and the addon cannot "
             .. "check your distance. Off by default." },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. NO SHOT WEAVING. Real Survival play weaves Steady Shot against the
     auto-shot timer. 3.3.5 exposes the ranged swing timer poorly and
     getting it wrong is worse than ignoring it, so this treats Steady
     Shot as a plain filler.

  2. LOCK AND LOAD is read into state but not acted on separately.
     The proc resets the Explosive Shot cooldown, so the existing
     "cast it when the debuff is down" line already catches it.

  3. PET MANAGEMENT is not handled beyond gating Kill Command on
     having one. Nothing reminds you to summon or revive.

  4. TRAP PLACEMENT cannot be judged by the addon - Explosive Trap
     and Frost Trap both need the target standing in them, and there
     is no reliable distance check on 3.3.5.

  5. AMMO, tranquilizing and misdirection are all out of scope.
------------------------------------------------------------------]]
