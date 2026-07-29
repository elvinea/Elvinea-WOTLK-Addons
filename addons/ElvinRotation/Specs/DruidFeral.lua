--[[ ElvinRotation - Specs/DruidFeral.lua
     Feral Druid (Cat), WotLK 3.3.5a.

     *** LOWEST CONFIDENCE SPEC IN THE ADDON. READ THIS. ***

     The source (Wrath/APLs/DruidFeral.simc plus Wrath/Druid.lua) does
     something no other spec here does: it runs a live damage-per-energy
     calculation using attack power, crit, armour penetration and boss
     armour, and schedules Rip and Savage Roar refreshes against each
     other with a bespoke pending_actions system. Roughly:

       shred_dpe = ((54.5 + tigers_fury + att_power/14)*2.25 + 666
                   + shred_idol - 42/35*(att_power/100 + 176))
                   *(1 + 1.266*crit_pct)*(1 - armour_term)/42

     None of that is implemented. This is the plain priority underneath:
     keep Savage Roar and Rip up, maintain the Mangle debuff and Rake,
     fill with Shred, and use Tiger's Fury when energy is low.

     Expect it to be RIGHT about what to press and WRONG about when to
     clip Rip for a better one, when Ferocious Bite beats Shred, and
     every bearweave decision. If you play Feral seriously, treat this
     as a reminder rather than an advisor.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Feral Druid (Cat)",
    class     = "DRUID",
    tab       = 2,             -- Feral tree
    school    = 1,
    powerType = 3,             -- energy
    usesComboPoints = true,
    gcdProbe  = 48572,         -- Shred
}

spec.auras = {
    cat_form      = { id = 768,   type = "buff" },
    savage_roar   = { id = 52610, type = "buff" },
    tigers_fury   = { id = 50213, type = "buff" },
    berserk       = { id = 50334, type = "buff" },
    clearcasting  = { id = 16870, type = "buff" },

    rip           = { id = 49800, type = "debuff", mine = true, duration = 16 },
    rake          = { id = 48574, type = "debuff", mine = true, duration = 9 },
    mangle        = { id = 33876, type = "debuff", mine = false, duration = 60 },
    faerie_fire   = { id = 770,   type = "debuff", mine = false, duration = 300 },
}

spec.abilities = {
    shred = {
        key = "shred", id = 48572, harmful = true, power = 42, buildsCombo = 1,
    },
    mangle_cat = {
        key = "mangle_cat", id = 48566, harmful = true, power = 40, buildsCombo = 1,
        applies = "mangle", appliesFor = 60,
    },
    rake = {
        key = "rake", id = 48574, harmful = true, power = 40, buildsCombo = 1,
        applies = "rake", appliesFor = 9, openerSkipIfUp = true,
    },
    rip = {
        key = "rip", id = 49800, harmful = true, power = 30,
        spendsCombo = true, minCombo = 5,
        applies = "rip", appliesFor = 16,
    },
    savage_roar = {
        key = "savage_roar", id = 52610, power = 25,
        spendsCombo = true, minCombo = 1,
        applies = "savage_roar", appliesTo = "buff", appliesFor = 34,
    },
    ferocious_bite = {
        key = "ferocious_bite", id = 48577, harmful = true, power = 35,
        spendsCombo = true, minCombo = 5,
    },
    tigers_fury = {
        key = "tigers_fury", id = 50213, cd = 30, castableMoving = true,
        applies = "tigers_fury", appliesTo = "buff", appliesFor = 6,
    },
    berserk = {
        key = "berserk", id = 50334, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Berserk",
        applies = "berserk", appliesTo = "buff", appliesFor = 15,
    },
    faerie_fire_feral = {
        key = "faerie_fire_feral", id = 60401, harmful = true,
        applies = "faerie_fire", appliesFor = 300,
    },
    cat_form = {
        key = "cat_form", id = 768, castableMoving = true,
        applies = "cat_form", appliesTo = "buff", appliesFor = 3600,
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
    spec.gcdProbeName = spec.abilities.shred.name
end

function spec.UpdateExtra(state)
    state.cp = state.comboPoints or 0
    state.energy = state.power or 0
    state.clearcast = state.buff.clearcasting.up

    -- Tiger's Fury restores energy, so it wants to be used when you
    -- have room for it rather than on cooldown.
    state.tf_worth_it = state.energy < (30 - (state.clearcast and 15 or 0))
end

spec.lists = {}

spec.lists.precombat = {
    { key = "cat_form", when = function(s) return not s.buff.cat_form.up end },
}

spec.lists.single = {
    { key = "tigers_fury", when = function(s) return s.tf_worth_it end },

    { key = "berserk", when = function(s)
        return s.dot.rip.up and not s.clearcast
    end },

    -- Savage Roar first: it buffs everything and falling off is the
    -- single biggest loss in the rotation.
    { key = "savage_roar", when = function(s)
        return not s.buff.savage_roar.up and s.cp >= 1
    end },

    { key = "rip", when = function(s)
        return s.cp >= 5 and not s.dot.rip.up and (s.ttd or 0) > 10
    end },

    { key = "savage_roar", when = function(s)
        return s.cp >= 1 and s.buff.savage_roar.remains < 3
    end },

    { key = "ferocious_bite", when = function(s)
        return ER:Setting("useFerociousBite") == true
           and s.cp >= 5 and s.dot.rip.up
           and s.buff.savage_roar.remains > 6
    end },

    { key = "mangle_cat", when = function(s)
        return not s.dot.mangle.up and (s.ttd or 0) > 1
    end },

    { key = "rake", when = function(s)
        return not s.dot.rake.up and (s.ttd or 0) > 9
    end },

    { key = "faerie_fire_feral", when = function(s)
        return ER:Setting("feralFaerieFire") == true and not s.dot.faerie_fire.up
    end },

    { key = "shred" },
}

spec.lists.aoe = {
    { key = "savage_roar", when = function(s)
        return not s.buff.savage_roar.up and s.cp >= 1
    end },
    { key = "mangle_cat", when = function(s) return not s.dot.mangle.up end },
    { key = "rake", when = function(s) return not s.dot.rake.up end },
    { key = "shred" },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 3 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t2 > t1 and t2 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("DRUID", "feral", "Druid", "Feral (Cat)", {
    { type = "check", key = "useFerociousBite",
      label = "Use Ferocious Bite", onValue = true, offValue = false,
      tooltip = "Whether Bite beats another Shred depends on a "
             .. "damage-per-energy calculation this addon does not do. "
             .. "Off by default." },
    { type = "check", key = "feralFaerieFire",
      label = "Maintain Faerie Fire", onValue = true, offValue = false },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. NO DAMAGE-PER-ENERGY MODEL. See the header. This is the single
     biggest gap of any spec in the addon.
  2. NO BEARWEAVING OR FLOWERWEAVING.
  3. NO RIP CLIPPING. Rip is only applied when missing, never
     replaced with a stronger snapshot.
  4. SHRED REQUIRES BEING BEHIND THE TARGET and 3.3.5 gives no
     reliable facing check, so it is suggested regardless.
  5. SNAPSHOTTING. WotLK Feral bleeds lock in attack power and crit
     when applied. Nothing here tracks that.
------------------------------------------------------------------]]
