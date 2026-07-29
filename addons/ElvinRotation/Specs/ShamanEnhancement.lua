--[[ ElvinRotation - Specs/ShamanEnhancement.lua
     Enhancement Shaman, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/ShamanEnhancement.simc

     First Shaman spec, and the first with a stacking proc that turns
     a cast into an instant: Maelstrom Weapon builds to five stacks
     from melee swings, and at five you fire an instant Lightning Bolt.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Enhancement Shaman",
    class     = "SHAMAN",
    tab       = 2,             -- Enhancement tree
    school    = 3,             -- nature
    powerType = 0,             -- mana
    gcdProbe  = 17364,         -- Stormstrike

    hasteRefBase = 2.5,        -- Lightning Bolt: 2.5s base
}

--------------------------------------------------------------------
spec.auras = {
    lightning_shield  = { id = 49281, type = "buff" },
    maelstrom_weapon  = { id = 53817, type = "buff" },
    shamanistic_rage  = { id = 30823, type = "buff" },
    feral_spirit      = { id = 51533, type = "buff" },
    elemental_devastation = { id = 30165, type = "buff" },

    flame_shock  = { id = 49233, type = "debuff", mine = true, duration = 18 },
    stormstrike  = { id = 17364, type = "debuff", mine = true, duration = 12 },
}

--------------------------------------------------------------------
spec.abilities = {
    stormstrike = {
        key = "stormstrike", id = 17364, harmful = true, cd = 8,
        applies = "stormstrike", appliesFor = 12,
    },
    lava_lash = {
        key = "lava_lash", id = 60103, harmful = true, cd = 6,
    },
    earth_shock = {
        key = "earth_shock", id = 49231, harmful = true, cd = 6,
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
    fire_nova = {
        key = "fire_nova", id = 61657, harmful = true, cd = 10,
    },
    magma_totem = {
        key = "magma_totem", id = 58734, castableMoving = true,
    },
    lightning_shield = {
        key = "lightning_shield", id = 49281, castableMoving = true,
        applies = "lightning_shield", appliesTo = "buff", appliesFor = 600,
    },
    feral_spirit = {
        key = "feral_spirit", id = 51533, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 20, cdLabel = "Feral Spirit",
        applies = "feral_spirit", appliesTo = "buff", appliesFor = 45,
    },
    fire_elemental_totem = {
        key = "fire_elemental_totem", id = 2894, cd = 600, castableMoving = true,
        majorCD = true, minTTD = 60, cdLabel = "Fire Elemental Totem",
    },
    shamanistic_rage = {
        key = "shamanistic_rage", id = 30823, cd = 120, castableMoving = true,
        applies = "shamanistic_rage", appliesTo = "buff", appliesFor = 15,
    },
    wind_shear = {
        key = "wind_shear", id = 57994, harmful = true, cd = 6,
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

    spec.gcdProbeName = spec.abilities.stormstrike.name
    spec.hasteRefName = spec.abilities.lightning_bolt.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    -- Maelstrom Weapon stacks from melee swings. At five, your next
    -- Lightning Bolt or Chain Lightning is instant and free, which is
    -- the whole reason a melee spec casts spells at all.
    state.maelstrom = state.buff.maelstrom_weapon.stack or 0
    state.maelstrom_full = state.maelstrom >= 5

    state.mana_low = (state.manaPct or 100) < (ER:Setting("shamanRageMana") or 25)
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "lightning_shield", when = function(s)
        return not s.buff.lightning_shield.up
    end },
}

spec.lists.single = {
    { key = "shamanistic_rage", when = function(s) return s.mana_low end },

    { key = "fire_elemental_totem" },
    { key = "feral_spirit" },

    -- Five stacks: spend them before another swing wastes one.
    { key = "lightning_bolt", when = function(s) return s.maelstrom_full end },

    { key = "flame_shock", when = function(s)
        return not s.dot.flame_shock.up and (s.ttd or 0) >= 9
    end },

    { key = "stormstrike", when = function(s) return not s.dot.stormstrike.up end },

    { key = "earth_shock" },
    { key = "stormstrike" },
    { key = "lava_lash" },

    { key = "lightning_shield", when = function(s)
        return not s.buff.lightning_shield.up
    end },

    -- Nothing else to press: a partial Maelstrom cast still beats
    -- standing there, but only if you are not about to cap.
    { key = "lightning_bolt", when = function(s)
        return s.maelstrom >= (ER:Setting("maelstromFiller") or 5)
    end },
}

spec.lists.aoe = {
    { key = "fire_elemental_totem" },
    { key = "feral_spirit" },

    { key = "fire_nova" },

    { key = "chain_lightning", when = function(s) return s.maelstrom_full end },

    { key = "flame_shock", when = function(s)
        return not s.dot.flame_shock.up and (s.ttd or 0) >= 9
    end },

    { key = "magma_totem", when = function(s)
        return ER:Setting("useMagmaTotem") ~= false
    end },

    { key = "stormstrike" },
    { key = "lava_lash" },
    { key = "earth_shock" },
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
    if class ~= "SHAMAN" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t2 > t1 and t2 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("SHAMAN", "enhancement", "Shaman", "Enhancement", {
    { type = "check", key = "useMagmaTotem",
      label = "Use Magma Totem in AoE", onValue = true, offValue = false,
      tooltip = "Needs the pack on top of you and costs a global to "
             .. "drop." },
    { type = "slider", key = "maelstromFiller",
      label = "Cast at Maelstrom stacks", min = 1, max = 5, step = 1,
      fmt = "%d stacks",
      tooltip = "Five is optimal. Lower it only if you find yourself "
             .. "with nothing to press." },
    { type = "slider", key = "shamanRageMana",
      label = "Shamanistic Rage below", min = 5, max = 60, step = 5,
      fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. WEAPON IMBUES are not managed. The source checks Windfury and
     Flametongue on each weapon; that is upkeep you do once per hour,
     not rotation, and 3.3.5's enchant API is awkward.

  2. TOTEMS beyond Magma and Fire Elemental are omitted. Call of the
     Elements and totem twisting are a whole subsystem, and dropping
     the wrong totem mid-fight is worse than dropping none.

  3. MAELSTROM WEAPON stacks are read from the buff (id 53817). If the
     stack count reads zero while you are visibly stacked, that ID is
     the first thing to check with /er verify.

  4. THE SOURCE has an explicit wait for Fire Nova coming off cooldown
     during AoE. Waits are not implemented; the priority simply moves
     on to the next ability.

  5. MULTI-DOTTING Flame Shock across two targets, which the source
     does with cycle_targets, is single-target only here.
------------------------------------------------------------------]]
