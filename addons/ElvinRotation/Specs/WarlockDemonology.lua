--[[ ElvinRotation - Specs/WarlockDemonology.lua
     Demonology Warlock, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/WarlockDemonology.simc

     Two DoTs and a filler, with two procs that override everything:
     Decimation makes Soul Fire nearly instant, and Molten Core makes
     Incinerate cheaper and harder. Metamorphosis is the burst window.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Demonology Warlock",
    class     = "WARLOCK",
    tab       = 2,             -- Demonology tree
    school    = 6,
    powerType = 0,
    gcdProbe  = 47809,         -- Shadow Bolt
    hasteRefBase = 3,
}

spec.auras = {
    fel_armor       = { id = 47893, type = "buff" },
    life_tap        = { id = 63321, type = "buff" },
    metamorphosis   = { id = 47241, type = "buff" },
    decimation      = { id = 63167, type = "buff" },
    molten_core     = { id = 71165, type = "buff" },
    immolation_aura = { id = 50589, type = "buff" },
    demonic_empowerment = { id = 47193, type = "buff" },

    immolate       = { id = 47811, type = "debuff", mine = true, duration = 15 },
    corruption     = { id = 47813, type = "debuff", mine = true, duration = 18 },
    curse_of_agony = { id = 47864, type = "debuff", mine = true, duration = 24 },
}

spec.abilities = {
    immolate = {
        key = "immolate", id = 47811, harmful = true, castTime = 2,
        applies = "immolate", appliesFor = 15, openerSkipIfUp = true,
    },
    corruption = {
        key = "corruption", id = 47813, harmful = true, castTime = 0,
        applies = "corruption", appliesFor = 18, openerSkipIfUp = true,
    },
    curse_of_agony = {
        key = "curse_of_agony", id = 47864, harmful = true, castTime = 0,
        applies = "curse_of_agony", appliesFor = 24,
    },
    shadow_bolt = {
        key = "shadow_bolt", id = 47809, harmful = true, castTime = 3,
    },
    incinerate = {
        key = "incinerate", id = 47838, harmful = true, castTime = 2.5,
    },
    soul_fire = {
        key = "soul_fire", id = 47825, harmful = true, castTime = 6,
    },
    metamorphosis = {
        key = "metamorphosis", id = 47241, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 25, cdLabel = "Metamorphosis",
        applies = "metamorphosis", appliesTo = "buff", appliesFor = 30,
    },
    demonic_empowerment = {
        key = "demonic_empowerment", id = 47193, cd = 60, castableMoving = true,
        applies = "demonic_empowerment", appliesTo = "buff", appliesFor = 15,
    },
    immolation_aura = {
        key = "immolation_aura", id = 50589, cd = 30, castableMoving = true,
        applies = "immolation_aura", appliesTo = "buff", appliesFor = 15,
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
    spec.gcdProbeName = spec.abilities.shadow_bolt.name
    spec.hasteRefName = spec.abilities.shadow_bolt.name
end

function spec.UpdateExtra(state)
    state.meta_up   = state.buff.metamorphosis.up
    state.decimation = state.buff.decimation.up
    state.molten_core = state.buff.molten_core.up
    state.mana_low  = (state.manaPct or 100) < (ER:Setting("demoLifeTapMana") or 20)
end

spec.lists = {}

spec.lists.precombat = {
    { key = "fel_armor", when = function(s) return not s.buff.fel_armor.up end },
    { key = "life_tap",  when = function(s)
        return ER:Setting("glyphLifeTap") == true and not s.buff.life_tap.up
    end },
}

spec.lists.single = {
    { key = "demonic_empowerment", when = function(s)
        return s.pet and not s.buff.demonic_empowerment.up
    end },

    { key = "immolate", when = function(s)
        return not s.dot.immolate.up and (s.ttd or 0) > 15
    end },

    { key = "curse_of_agony", when = function(s)
        return not s.dot.curse_of_agony.up
    end },

    { key = "corruption", when = function(s)
        return not s.dot.corruption.up and (s.ttd or 0) > 18
    end },

    { key = "metamorphosis" },

    { key = "immolation_aura", when = function(s)
        return s.meta_up and not s.buff.immolation_aura.up
           and ER:Setting("useImmolationAura") == true
    end },

    { key = "life_tap", when = function(s)
        return ER:Setting("glyphLifeTap") == true and not s.buff.life_tap.up
    end },

    -- Decimation drops Soul Fire's cast time to almost nothing.
    { key = "soul_fire", when = function(s)
        return s.decimation and (s.ttd or 0) > 2
    end },

    -- Molten Core makes Incinerate the better filler.
    { key = "incinerate", when = function(s) return s.molten_core end },

    { key = "life_tap", when = function(s) return s.mana_low end },

    { key = "shadow_bolt" },
}

spec.lists.aoe = {
    { key = "metamorphosis", when = function(s) return (s.activeEnemies or 1) > 3 end },
    { key = "immolation_aura", when = function(s)
        return not s.buff.immolation_aura.up
           and ER:Setting("useImmolationAura") == true
    end },
    { key = "shadowflame", when = function(s)
        return (s.activeEnemies or 1) > 3 and ER:Setting("useShadowflame") == true
    end },
    { key = "seed_of_corruption", when = function(s)
        return (s.activeEnemies or 1) > 3
    end },
    { key = "corruption", when = function(s) return not s.dot.corruption.up end },
    { key = "immolate",   when = function(s) return not s.dot.immolate.up end },
    { key = "life_tap",   when = function(s) return s.mana_low end },
    { key = "shadow_bolt" },
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
    return t2 > t1 and t2 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("WARLOCK", "demonology", "Warlock", "Demonology", {
    { type = "check", key = "useImmolationAura",
      label = "Use Immolation Aura in Metamorphosis", onValue = true,
      offValue = false,
      tooltip = "Only does damage to things standing next to you, and "
             .. "the addon cannot check range. Off by default." },
    { type = "slider", key = "demoLifeTapMana",
      label = "Life Tap below", min = 5, max = 60, step = 5, fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. DEMONIC EMPOWERMENT is gated on having a pet, but nothing
     reminds you to summon a Felguard. Pet management is out of scope
     everywhere in this addon.
  2. METAMORPHOSIS timing in the source depends on fight_remains,
     which needs boss health prediction the addon does not do. Here it
     is a major cooldown with a minimum time-to-die.
  3. DEMON CHARGE is omitted - it needs a distance check.
  4. ALL THREE Warlock specs are now built, one per talent tab.
------------------------------------------------------------------]]
