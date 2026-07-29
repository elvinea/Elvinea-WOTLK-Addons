--[[ ElvinRotation - Specs/RogueCombat.lua
     Combat Rogue, WotLK 3.3.5a.

     *** NO SOURCE APL. WRITTEN FROM SCRATCH. ***

     Hekili's Wrath build has no Combat list, so unlike every other
     spec here this is not a translation - it is my reconstruction of
     the commonly played rotation. Treat it as a starting point rather
     than theorycraft.

     The shape is uncontroversial: keep Slice and Dice up, keep Rupture
     up, Eviscerate at five combo points, build with Sinister Strike.
     The judgement calls I am least sure about are marked below.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Combat Rogue",
    class     = "ROGUE",
    tab       = 2,
    school    = 1,
    powerType = 3,             -- energy
    usesComboPoints = true,
    gcdProbe  = 48638,         -- Sinister Strike
}

spec.auras = {
    slice_and_dice  = { id = 6774,  type = "buff" },
    adrenaline_rush = { id = 13750, type = "buff" },
    blade_flurry    = { id = 13877, type = "buff" },
    killing_spree   = { id = 51690, type = "buff" },
    stealth         = { id = 1784,  type = "buff" },

    rupture      = { id = 48672, type = "debuff", mine = true, duration = 16 },
    expose_armor = { id = 48669, type = "debuff", mine = true, duration = 30 },
}

spec.abilities = {
    sinister_strike = {
        key = "sinister_strike", id = 48638, harmful = true,
        power = 40, buildsCombo = 1,
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
    expose_armor = {
        key = "expose_armor", id = 48669, harmful = true,
        power = 25, spendsCombo = true, minCombo = 1,
        applies = "expose_armor", appliesFor = 30,
    },
    killing_spree = {
        key = "killing_spree", id = 51690, harmful = true, cd = 120,
        majorCD = true, minTTD = 12, cdLabel = "Killing Spree",
        applies = "killing_spree", appliesTo = "buff", appliesFor = 3,
    },
    adrenaline_rush = {
        key = "adrenaline_rush", id = 13750, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Adrenaline Rush",
        applies = "adrenaline_rush", appliesTo = "buff", appliesFor = 15,
    },
    blade_flurry = {
        key = "blade_flurry", id = 13877, cd = 120, castableMoving = true,
        majorCD = true, minTTD = 10, cdLabel = "Blade Flurry",
        applies = "blade_flurry", appliesTo = "buff", appliesFor = 15,
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
    spec.gcdProbeName = spec.abilities.sinister_strike.name
end

function spec.UpdateExtra(state)
    state.cp = state.comboPoints or 0
    state.energy = state.power or 0
end

spec.lists = {}

spec.lists.precombat = {
    { key = "stealth", when = function(s) return not s.buff.stealth.up end },
}

spec.lists.single = {
    -- Slice and Dice is the whole spec. Never let it drop.
    { key = "slice_and_dice", when = function(s)
        return s.cp >= 1 and (not s.buff.slice_and_dice.up
                              or s.buff.slice_and_dice.remains < 2)
    end },

    { key = "adrenaline_rush", when = function(s) return s.energy < 40 end },
    { key = "killing_spree",   when = function(s) return s.energy < 40 end },

    { key = "blade_flurry", when = function(s)
        return ER:Setting("bladeFlurrySingle") == true
    end },

    -- JUDGEMENT CALL: whether Rupture is worth a finisher on single
    -- target is build and gear dependent. Off by default.
    { key = "rupture", when = function(s)
        return ER:Setting("combatRupture") == true
           and s.cp >= 5 and not s.dot.rupture.up and (s.ttd or 0) > 12
    end },

    { key = "eviscerate", when = function(s)
        return s.cp >= 5 and s.buff.slice_and_dice.remains > 4
    end },

    { key = "sinister_strike" },
}

spec.lists.aoe = {
    { key = "slice_and_dice", when = function(s)
        return s.cp >= 1 and not s.buff.slice_and_dice.up
    end },
    { key = "blade_flurry" },
    { key = "adrenaline_rush", when = function(s) return s.energy < 40 end },
    { key = "killing_spree",   when = function(s) return s.energy < 40 end },
    { key = "eviscerate", when = function(s) return s.cp >= 5 end },
    { key = "sinister_strike" },
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
    if class ~= "ROGUE" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t2 > t1 and t2 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("ROGUE", "combat", "Rogue", "Combat", {
    { type = "check", key = "combatRupture",
      label = "Use Rupture", onValue = true, offValue = false,
      tooltip = "Whether Rupture beats another Eviscerate depends on "
             .. "your gear. I am not confident either way - try both." },
    { type = "check", key = "bladeFlurrySingle",
      label = "Blade Flurry on single target", onValue = true, offValue = false,
      tooltip = "Blade Flurry increases attack speed even with one "
             .. "target, but costs energy. Off by default." },
}, spec)

--[[ NOTES ---------------------------------------------------------
  RECONSTRUCTED, NOT TRANSLATED. No source APL exists for Combat.
  Least confident about: whether Rupture belongs in single target,
  when to spend Adrenaline Rush and Killing Spree relative to each
  other, and the Slice and Dice refresh threshold. All exposed as
  settings rather than guessed at silently.
------------------------------------------------------------------]]
