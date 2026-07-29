--[[ ElvinRotation - Specs/PaladinRetribution.lua
     Retribution Paladin, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/PaladinRetributionLightClub.simc
     credited to the LightClub Classic discord, November 2023.

     The source list is long, but almost all of that length is mana
     threshold arithmetic and raid-buff bookkeeping. The damage
     priority underneath is a plain first-come-first-served queue.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Retribution Paladin",
    class     = "PALADIN",
    tab       = 3,             -- Retribution tree
    school    = 2,             -- holy
    powerType = 0,             -- mana
    gcdProbe  = 35395,         -- Crusader Strike
}

--------------------------------------------------------------------
-- Seals are faction split: Alliance get Seal of Vengeance and its
-- Holy Vengeance debuff, Horde get Seal of Corruption and Blood
-- Corruption. Both are registered and whichever the character knows
-- is the one that resolves.
--------------------------------------------------------------------
spec.auras = {
    the_art_of_war    = { id = 59578, type = "buff" },
    avenging_wrath    = { id = 31884, type = "buff" },
    divine_plea       = { id = 54428, type = "buff" },
    seal_of_vengeance = { id = 31801, type = "buff" },
    seal_of_corruption= { id = 348704, type = "buff" },
    seal_of_command   = { id = 20375, type = "buff" },

    holy_vengeance    = { id = 31803, type = "debuff", mine = true, duration = 15 },
    blood_corruption  = { id = 53742, type = "debuff", mine = true, duration = 15 },
    judgement_of_light  = { id = 20185, type = "debuff", mine = true, duration = 20 },
    judgement_of_wisdom = { id = 20186, type = "debuff", mine = true, duration = 20 },
}

--------------------------------------------------------------------
spec.abilities = {
    crusader_strike = {
        key = "crusader_strike", id = 35395, harmful = true, cd = 4,
    },
    divine_storm = {
        key = "divine_storm", id = 53385, harmful = true, cd = 10,
    },
    judgement_of_wisdom = {
        key = "judgement_of_wisdom", id = 53408, harmful = true, cd = 10,
        applies = "judgement_of_wisdom", appliesFor = 20,
    },
    judgement_of_light = {
        key = "judgement_of_light", id = 20271, harmful = true, cd = 10,
        applies = "judgement_of_light", appliesFor = 20,
    },
    consecration = {
        key = "consecration", id = 48819, harmful = true, cd = 8,
    },
    exorcism = {
        key = "exorcism", id = 48801, harmful = true, cd = 15,
    },
    hammer_of_wrath = {
        key = "hammer_of_wrath", id = 48806, harmful = true, cd = 6,
    },
    holy_wrath = {
        key = "holy_wrath", id = 48817, harmful = true, cd = 30,
    },
    avenging_wrath = {
        key = "avenging_wrath", id = 31884, cd = 180,
        majorCD = true, minTTD = 20, cdLabel = "Avenging Wrath",
        applies = "avenging_wrath", appliesTo = "buff", appliesFor = 20,
    },
    divine_plea = {
        key = "divine_plea", id = 54428, cd = 60,
        applies = "divine_plea", appliesTo = "buff", appliesFor = 15,
    },
    seal_of_vengeance = {
        key = "seal_of_vengeance", id = 31801, castableMoving = true,
        applies = "seal_of_vengeance", appliesTo = "buff", appliesFor = 1800,
            selfBuff = true,
    },
    seal_of_command = {
        key = "seal_of_command", id = 20375, castableMoving = true,
        applies = "seal_of_command", appliesTo = "buff", appliesFor = 1800,
            selfBuff = true,
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

    spec.gcdProbeName = spec.abilities.crusader_strike.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    state.execute_phase = (state.targetHealthPct or 100) < 20

    -- Either faction's main seal counts as "a seal is up".
    state.seal_up = state.buff.seal_of_vengeance.up
                 or state.buff.seal_of_corruption.up
                 or state.buff.seal_of_command.up

    -- Mana gates, expressed once rather than threaded through every
    -- line the way the source does.
    local low = ER:Setting("retManaFloor") or 20
    state.mana_low  = (state.manaPct or 100) < low
    state.mana_fine = (state.manaPct or 100) > low
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "seal_of_vengeance", when = function(s) return not s.seal_up end },
}

-- The core rotation. Judgement, Crusader Strike and Divine Storm are
-- the damage; everything else fills the gaps between their cooldowns.
spec.lists.single = {
    { key = "seal_of_vengeance", when = function(s) return not s.seal_up end },

    { key = "avenging_wrath", when = function(s)
        return (s.ttd or 0) > 20
    end },

    { key = "judgement_of_wisdom", when = function(s)
        return ER:Setting("judgement") ~= "light"
    end },
    { key = "judgement_of_light", when = function(s)
        return ER:Setting("judgement") == "light"
    end },

    { key = "crusader_strike" },
    { key = "divine_storm" },

    { key = "hammer_of_wrath", when = function(s) return s.execute_phase end },

    { key = "divine_plea", when = function(s)
        return s.mana_low and not s.buff.divine_plea.up
    end },

    -- Exorcism is instant only while The Art of War is up.
    { key = "exorcism", when = function(s)
        return s.buff.the_art_of_war.up and s.mana_fine
    end },

    { key = "consecration", when = function(s)
        return not s.moving and s.mana_fine
           and ER:Setting("useConsecration") ~= false
    end },

    { key = "holy_wrath", when = function(s)
        return s.mana_fine and ER:Setting("useHolyWrath") == true
    end },
}

spec.lists.aoe = {
    { key = "seal_of_command", when = function(s)
        return not s.seal_up and ER:Setting("aoeSealOfCommand") == true
    end },
    { key = "seal_of_vengeance", when = function(s) return not s.seal_up end },

    { key = "avenging_wrath", when = function(s) return (s.ttd or 0) > 20 end },

    { key = "divine_storm" },
    { key = "consecration", when = function(s)
        return not s.moving and ER:Setting("useConsecration") ~= false
    end },
    { key = "crusader_strike" },
    { key = "hammer_of_wrath", when = function(s) return s.execute_phase end },

    { key = "judgement_of_wisdom", when = function(s)
        return ER:Setting("judgement") ~= "light"
    end },
    { key = "judgement_of_light", when = function(s)
        return ER:Setting("judgement") == "light"
    end },

    { key = "holy_wrath", when = function(s)
        return s.mana_fine and ER:Setting("useHolyWrath") == true
    end },
    { key = "exorcism", when = function(s)
        return s.buff.the_art_of_war.up and s.mana_fine
    end },
    { key = "divine_plea", when = function(s)
        return s.mana_low and not s.buff.divine_plea.up
    end },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 1 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

--------------------------------------------------------------------
function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t3 > t1 and t3 > t2
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("PALADIN", "retribution", "Paladin", "Retribution", {
    { type = "check", key = "useConsecration",
      label = "Use Consecration", onValue = true, offValue = false,
      tooltip = "Good filler, but expensive. Turn off if you are "
             .. "struggling for mana." },
    { type = "check", key = "useHolyWrath",
      label = "Use Holy Wrath", onValue = true, offValue = false,
      tooltip = "Only worth casting against Demons and Undead, which "
             .. "the addon cannot detect. Off by default." },
    { type = "check", key = "aoeSealOfCommand",
      label = "Seal of Command in AoE", onValue = true, offValue = false,
      tooltip = "The source list swaps seals for multi-target. Costs a "
             .. "global each way." },
    { type = "slider", key = "retManaFloor",
      label = "Divine Plea below", min = 5, max = 60, step = 5,
      fmt = "%d%% mana",
      tooltip = "Mana level at which to use Divine Plea and stop "
             .. "spending on filler." },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. SEALS ARE FACTION SPLIT. Alliance cast Seal of Vengeance and
     apply Holy Vengeance; Horde cast Seal of Corruption and apply
     Blood Corruption. Both are registered and whichever your
     character actually knows resolves. If the seal line misbehaves,
     /er verify will name the one that failed.

  2. AURAS AND BLESSINGS are deliberately omitted. The source list
     manages them, but they are raid setup you do once, not rotation.

  3. HOLY WRATH is off by default. It is only worth casting against
     Demons and Undead, and the addon has no way to check creature
     type on 3.3.5.

  4. THE MANA ARITHMETIC in the source threads a different fraction of
     one threshold through nearly every line. That is collapsed here
     into a single floor with a slider. Less precise, far easier to
     reason about, and the difference only shows when you are already
     running dry.

  5. SET BONUS branches (tier 10 two-piece changes the Divine Storm
     ordering) are not implemented.
------------------------------------------------------------------]]
