--[[ ElvinRotation - Specs/ShamanElemental.lua
     Elemental Shaman, WotLK 3.3.5a.

     *** NO SOURCE APL. WRITTEN FROM SCRATCH. ***

     Hekili's Wrath build has an Enhancement list but no Elemental
     one, so this is a reconstruction rather than a translation.

     The shape here is far less contentious than the two Rogue specs:
     Elemental in Wrath is essentially Flame Shock, Lava Burst on
     cooldown while Flame Shock is up (it is a guaranteed crit), Chain
     Lightning for multiple targets, and Lightning Bolt as filler.
     That much is well established. The judgement calls are marked.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Elemental Shaman",
    class     = "SHAMAN",
    tab       = 1,
    school    = 3,             -- nature
    powerType = 0,             -- mana
    gcdProbe  = 49238,         -- Lightning Bolt
    hasteRefBase = 2.5,
}

spec.auras = {
    lightning_shield  = { id = 49281, type = "buff" },
    water_shield      = { id = 57960, type = "buff" },
    elemental_mastery = { id = 16166, type = "buff" },
    clearcasting      = { id = 16246, type = "buff" },   -- Elemental Focus

    flame_shock = { id = 49233, type = "debuff", mine = true, duration = 18 },
}

spec.abilities = {
    lava_burst = {
        key = "lava_burst", id = 60043, harmful = true, cd = 8, castTime = 2,
    },
    flame_shock = {
        key = "flame_shock", id = 49233, harmful = true, cd = 6,
        applies = "flame_shock", appliesFor = 18, openerSkipIfUp = true,
    },
    lightning_bolt = {
        key = "lightning_bolt", id = 49238, harmful = true, castTime = 2.5,
    },
    chain_lightning = {
        key = "chain_lightning", id = 49271, harmful = true, castTime = 2, cd = 6,
    },
    earth_shock = {
        key = "earth_shock", id = 49231, harmful = true, cd = 6,
    },
    thunderstorm = {
        key = "thunderstorm", id = 59159, harmful = true, cd = 45,
        castableMoving = true,
    },
    elemental_mastery = {
        key = "elemental_mastery", id = 16166, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Elemental Mastery",
        applies = "elemental_mastery", appliesTo = "buff", appliesFor = 15,
    },
    fire_elemental_totem = {
        key = "fire_elemental_totem", id = 2894, cd = 600, castableMoving = true,
        majorCD = true, minTTD = 60, cdLabel = "Fire Elemental Totem",
    },
    lightning_shield = {
        key = "lightning_shield", id = 49281, castableMoving = true,
        applies = "lightning_shield", appliesTo = "buff", appliesFor = 600,
    },
    water_shield = {
        key = "water_shield", id = 57960, castableMoving = true,
        applies = "water_shield", appliesTo = "buff", appliesFor = 600,
    },
    wind_shear = {
        key = "wind_shear", id = 57994, harmful = true, cd = 6,
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
    spec.gcdProbeName = spec.abilities.lightning_bolt.name
    spec.hasteRefName = spec.abilities.lightning_bolt.name
end

function spec.UpdateExtra(state)
    -- Lava Burst is a guaranteed crit against a Flame Shocked target,
    -- so Flame Shock uptime is worth far more than its own damage.
    state.fs_up = state.dot.flame_shock.up
    state.mana_low = (state.manaPct or 100) < (ER:Setting("eleManaFloor") or 20)
end

spec.lists = {}

spec.lists.precombat = {
    { key = "water_shield", when = function(s)
        return ER:Setting("useWaterShield") == true and not s.buff.water_shield.up
    end },
    { key = "lightning_shield", when = function(s)
        return ER:Setting("useWaterShield") ~= true and not s.buff.lightning_shield.up
    end },
}

spec.lists.single = {
    { key = "fire_elemental_totem" },
    { key = "elemental_mastery" },

    { key = "flame_shock", when = function(s)
        return not s.fs_up and (s.ttd or 0) > 9
    end },

    -- Lava Burst crits automatically while Flame Shock is ticking.
    { key = "lava_burst", when = function(s) return s.fs_up end },

    -- JUDGEMENT CALL: whether to cast Lava Burst without Flame Shock
    -- up. It loses the guaranteed crit but is still a strong nuke.
    { key = "lava_burst", when = function(s)
        return ER:Setting("lavaBurstAlways") == true
    end },

    { key = "chain_lightning", when = function(s)
        return (s.activeEnemies or 1) > 1
    end },

    { key = "earth_shock", when = function(s)
        return ER:Setting("eleEarthShock") == true and s.fs_up
           and s.dot.flame_shock.remains > 6
    end },

    { key = "lightning_bolt" },
}

spec.lists.aoe = {
    { key = "fire_elemental_totem" },
    { key = "elemental_mastery" },
    { key = "flame_shock", when = function(s) return not s.fs_up end },
    { key = "lava_burst",  when = function(s) return s.fs_up end },
    { key = "chain_lightning" },
    { key = "thunderstorm", when = function(s)
        return s.mana_low and ER:Setting("useThunderstorm") == true
    end },
    { key = "lightning_bolt" },
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
    if class ~= "SHAMAN" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("SHAMAN", "elemental", "Shaman", "Elemental", {
    { type = "check", key = "useWaterShield",
      label = "Use Water Shield instead of Lightning Shield",
      onValue = true, offValue = false,
      tooltip = "Water Shield for mana, Lightning Shield for damage." },
    { type = "check", key = "lavaBurstAlways",
      label = "Lava Burst without Flame Shock", onValue = true, offValue = false,
      tooltip = "Loses the guaranteed crit. Usually wrong, but not "
             .. "always if Flame Shock is about to be reapplied." },
    { type = "check", key = "eleEarthShock",
      label = "Use Earth Shock as filler", onValue = true, offValue = false,
      tooltip = "Shares a cooldown with Flame Shock, so this can cost "
             .. "you Flame Shock uptime. Off by default." },
    { type = "check", key = "useThunderstorm",
      label = "Use Thunderstorm for mana", onValue = true, offValue = false,
      tooltip = "Knocks enemies back, which can be a disaster in a "
             .. "raid. Off by default." },
    { type = "slider", key = "eleManaFloor",
      label = "Low mana below", min = 5, max = 60, step = 5, fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------
  RECONSTRUCTED, NOT TRANSLATED. No source APL exists for Elemental.
  The core - Flame Shock, then Lava Burst on cooldown while it ticks,
  Lightning Bolt filler - is well established and I am reasonably
  confident in it. Less sure about: Earth Shock as a filler (it shares
  a cooldown with Flame Shock), and Chain Lightning's exact target
  threshold. Both are settings.
------------------------------------------------------------------]]
