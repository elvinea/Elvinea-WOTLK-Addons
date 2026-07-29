--[[ ElvinRotation - Specs/RogueAssassination.lua
     Assassination Rogue, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/RogueAssassination.simc

     First combo-point spec in the addon. Energy and combo points are
     handled generically by the engine - the spec only declares costs.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name     = "Assassination Rogue",
    class    = "ROGUE",
    tab      = 1,              -- Assassination tree
    school   = 1,              -- physical

    powerType       = 3,       -- SPELL_POWER_ENERGY
    usesComboPoints = true,
    hasteRefBase    = nil,
    gcdProbe        = 1752,    -- Sinister Strike: no cooldown
}

--------------------------------------------------------------------
spec.auras = {
    slice_and_dice   = { id = 6774,  type = "buff" },
    envenom          = { id = 32645, type = "buff" },
    hunger_for_blood = { id = 51662, type = "buff" },
    cold_blood       = { id = 14177, type = "buff" },
    stealth          = { id = 1784,  type = "buff" },
    overkill         = { id = 58426, type = "buff" },

    deadly_poison    = { id = 43233, type = "debuff", mine = true, duration = 12 },
    rupture          = { id = 48672, type = "debuff", mine = true, duration = 16 },
    garrote          = { id = 48676, type = "debuff", mine = true, duration = 18 },
    expose_armor     = { id = 48669, type = "debuff", mine = true, duration = 30 },
}

--------------------------------------------------------------------
spec.abilities = {
    mutilate = {
        key = "mutilate", id = 48666, harmful = true,
        power = 60, buildsCombo = 2,
    },
    envenom = {
        key = "envenom", id = 57993, harmful = true,
        power = 35, spendsCombo = true, minCombo = 1,
        applies = "envenom", appliesTo = "buff", appliesFor = 6,
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
    hunger_for_blood = {
        key = "hunger_for_blood", id = 51662,
        power = 15,
        applies = "hunger_for_blood", appliesTo = "buff", appliesFor = 60,
    },
    garrote = {
        key = "garrote", id = 48676, harmful = true,
        power = 50, buildsCombo = 1,
        applies = "garrote", appliesFor = 18,
    },
    ambush = {
        key = "ambush", id = 48691, harmful = true,
        power = 60, buildsCombo = 2,
    },
    fan_of_knives = {
        key = "fan_of_knives", id = 51723, harmful = true,
        power = 50,
    },
    cold_blood = {
        key = "cold_blood", id = 14177, cd = 180,
        majorCD = true, minTTD = 10, cdLabel = "Cold Blood",
        applies = "cold_blood", appliesTo = "buff", appliesFor = 30,
    },
    kick = {
        key = "kick", id = 1766, harmful = true, cd = 10, power = 25,
    },
    stealth = {
        key = "stealth", id = 1787, castableMoving = true,
        applies = "stealth", appliesTo = "buff", appliesFor = 3600,
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

    spec.gcdProbeName = spec.abilities.mutilate.name
end

--------------------------------------------------------------------
-- The source list works through three "should I Envenom" variables.
-- Kept as named state so the priority below reads like the original.
--------------------------------------------------------------------
function spec.UpdateExtra(state)
    local cp     = state.comboPoints or 0
    local poison = state.debuff.deadly_poison and state.debuff.deadly_poison.up

    -- refresh the Envenom buff itself
    state.envenom_for_buff  = poison and cp >= 4 and not state.buff.envenom.up
    -- spend before energy caps
    state.envenom_for_spend = poison and cp >= 4 and (state.energy or 0) > 90
    -- keep Slice and Dice alive
    state.envenom_for_snd   = poison and cp >= 2
                              and state.buff.slice_and_dice.up
                              and state.buff.slice_and_dice.remains < 2

    state.envenom_pending = state.envenom_for_buff
                         or state.envenom_for_spend
                         or state.envenom_for_snd
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "stealth", when = function(s) return not s.buff.stealth.up end },
}

-- Opening from stealth.
spec.lists.stealth = {
    { key = "garrote", when = function(s)
        return not s.dot.garrote.up and not s.buff.hunger_for_blood.up
    end },
    { key = "ambush" },
}

spec.lists.single = {
    { key = "hunger_for_blood", when = function(s)
        return s.buff.hunger_for_blood.remains < 2
    end },

    -- Armour debuff, off by default: usually someone else's job.
    { key = "expose_armor", when = function(s)
        return ER:Setting("maintainExpose") == true
           and (s.comboPoints or 0) >= 4
           and not s.dot.expose_armor.up
    end },

    { key = "slice_and_dice", when = function(s)
        return not s.buff.slice_and_dice.up
            or (s.buff.slice_and_dice.remains < 1 and not s.envenom_pending)
    end },

    { key = "cold_blood", when = function(s)
        return (s.energy or 0) >= 35
           and (s.envenom_for_buff or s.envenom_for_spend)
    end },

    { key = "envenom", when = function(s) return s.envenom_for_buff  end },
    { key = "envenom", when = function(s) return s.envenom_for_spend end },
    { key = "envenom", when = function(s) return s.envenom_for_snd   end },

    -- Rupture is only in the source list as a bleed for Hunger for
    -- Blood, not as a damage finisher.
    { key = "rupture", when = function(s)
        return not s.dot.rupture.up
           and not s.dot.garrote.up
           and not s.buff.hunger_for_blood.up
    end },

    { key = "mutilate", when = function(s)
        return (s.comboPoints or 0) < 4 or (s.energy or 0) > 90
    end },
}

spec.lists.aoe = {
    { key = "slice_and_dice", when = function(s)
        return not s.buff.slice_and_dice.up
    end },
    { key = "mutilate", when = function(s) return (s.comboPoints or 0) == 0 end },
    { key = "fan_of_knives" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },

    { runList = "stealth", terminal = true,
      when = function(s) return s.buff.stealth.up end },

    -- The source switches to AoE only above five targets: Fan of
    -- Knives is weak until then.
    { runList = "aoe", terminal = true,
      when = function(s)
          return (s.activeEnemies or 1) > (ER:Setting("rogueAoeThreshold") or 5)
      end },

    { runList = "single", terminal = true, when = function(s) return true end },
}

--------------------------------------------------------------------
function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "ROGUE" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("ROGUE", "assassination", "Rogue", "Assassination", {
    { type = "check", key = "maintainExpose",
      label = "Maintain Expose Armor", onValue = true, offValue = false,
      tooltip = "Off by default - the armour debuff is usually another "
             .. "player's job, and it costs you a finisher." },
    { type = "slider", key = "rogueAoeThreshold",
      label = "Fan of Knives above", min = 2, max = 10, step = 1,
      fmt = "%d targets",
      tooltip = "The source list only switches to AoE above five "
             .. "targets, because Fan of Knives is weak below that." },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. POISONS are assumed applied. The priority checks for Deadly
     Poison on the target because Envenom consumes stacks, but nothing
     reminds you to apply poisons to your weapons.

  2. RUPTURE appears only as a bleed to enable Hunger for Blood, which
     is how the source list uses it. It is not a damage finisher here.

  3. TRICKS OF THE TRADE, racials, trinkets and Overkill handling are
     omitted, as elsewhere.

  4. ENERGY POOLING is approximate. The source uses pool_resource for
     Hunger for Blood; this simply waits for the energy.
------------------------------------------------------------------]]
