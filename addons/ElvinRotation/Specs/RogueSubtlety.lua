--[[ ElvinRotation - Specs/RogueSubtlety.lua
     Subtlety Rogue, WotLK 3.3.5a.

     *** NO SOURCE APL. WRITTEN FROM SCRATCH. LOW CONFIDENCE. ***

     Subtlety was rarely played as PvE damage in Wrath, which is
     probably why no source list exists. This is a reconstruction of
     the Hemorrhage build: keep Slice and Dice and Rupture up,
     maintain the Hemorrhage debuff, Eviscerate at five, build with
     Hemorrhage.

     Of everything in this addon, this is the spec I would trust least.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Subtlety Rogue",
    class     = "ROGUE",
    tab       = 3,
    school    = 1,
    powerType = 3,
    usesComboPoints = true,
    gcdProbe  = 48660,         -- Hemorrhage
}

spec.auras = {
    slice_and_dice = { id = 6774,  type = "buff" },
    shadow_dance   = { id = 51713, type = "buff" },
    stealth        = { id = 1784,  type = "buff" },
    master_of_subtlety = { id = 31665, type = "buff" },

    hemorrhage = { id = 48660, type = "debuff", mine = true, duration = 15 },
    rupture    = { id = 48672, type = "debuff", mine = true, duration = 16 },
}

spec.abilities = {
    hemorrhage = {
        key = "hemorrhage", id = 48660, harmful = true,
        power = 35, buildsCombo = 1,
        applies = "hemorrhage", appliesFor = 15,
    },
    backstab = {
        key = "backstab", id = 48657, harmful = true,
        power = 60, buildsCombo = 1,
    },
    eviscerate = {
        key = "eviscerate", id = 48668, harmful = true,
        power = 35, spendsCombo = true, minCombo = 1,
    },
    rupture = {
        key = "rupture", id = 48672, harmful = true,
        power = 25, spendsCombo = true, minCombo = 1,
        applies = "rupture", appliesFor = 16,
    },
    slice_and_dice = {
        key = "slice_and_dice", id = 6774,
        power = 25, spendsCombo = true, minCombo = 1,
        applies = "slice_and_dice", appliesTo = "buff", appliesFor = 21,
    },
    shadow_dance = {
        key = "shadow_dance", id = 51713, cd = 120, castableMoving = true,
        majorCD = true, minTTD = 12, cdLabel = "Shadow Dance",
        applies = "shadow_dance", appliesTo = "buff", appliesFor = 10,
    },
    premeditation = {
        key = "premeditation", id = 14183, harmful = true, cd = 120,
    },
    ambush = {
        key = "ambush", id = 48691, harmful = true, power = 60, buildsCombo = 2,
    },
    kick = {
        key = "kick", id = 1766, harmful = true, cd = 10, power = 25,
    },
    stealth = {
        key = "stealth", id = 1787, castableMoving = true,
        applies = "stealth", appliesTo = "buff", appliesFor = 3600,
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
    spec.gcdProbeName = spec.abilities.hemorrhage.name
end

function spec.UpdateExtra(state)
    state.cp = state.comboPoints or 0
    state.energy = state.power or 0
    state.dancing = state.buff.shadow_dance.up or state.buff.stealth.up
end

spec.lists = {}

spec.lists.precombat = {
    { key = "stealth", when = function(s) return not s.buff.stealth.up end },
}

spec.lists.stealth = {
    { key = "premeditation" },
    { key = "ambush" },
}

spec.lists.single = {
    { key = "slice_and_dice", when = function(s)
        return s.cp >= 1 and (not s.buff.slice_and_dice.up
                              or s.buff.slice_and_dice.remains < 2)
    end },

    { key = "shadow_dance", when = function(s)
        return s.buff.slice_and_dice.up
    end },

    { key = "rupture", when = function(s)
        return s.cp >= 5 and not s.dot.rupture.up and (s.ttd or 0) > 12
    end },

    { key = "eviscerate", when = function(s)
        return s.cp >= 5 and s.buff.slice_and_dice.remains > 4
    end },

    -- Hemorrhage is both the builder and a raid debuff.
    { key = "hemorrhage", when = function(s) return not s.dot.hemorrhage.up end },

    { key = "backstab", when = function(s)
        return ER:Setting("subUseBackstab") == true and s.energy > 60
    end },

    { key = "hemorrhage" },
}

spec.lists.aoe = {
    { key = "slice_and_dice", when = function(s)
        return s.cp >= 1 and not s.buff.slice_and_dice.up
    end },
    { key = "eviscerate", when = function(s) return s.cp >= 5 end },
    { key = "hemorrhage" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "stealth", terminal = true,
      when = function(s) return s.buff.stealth.up end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 1 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "ROGUE" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t3 > t1 and t3 > t2
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("ROGUE", "subtlety", "Rogue", "Subtlety", {
    { type = "check", key = "subUseBackstab",
      label = "Use Backstab as a builder", onValue = true, offValue = false,
      tooltip = "Backstab hits harder but costs far more energy and "
             .. "needs you behind the target. Off by default." },
}, spec)

--[[ NOTES ---------------------------------------------------------
  RECONSTRUCTED, NOT TRANSLATED, and the least confident spec here.
  Subtlety was rarely raided in Wrath, which is why no source list
  exists. Shadow Dance handling in particular is a guess: it opens a
  window for stealth abilities that this does not exploit.
------------------------------------------------------------------]]
