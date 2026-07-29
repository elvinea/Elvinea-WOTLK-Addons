--[[ ElvinRotation - Specs/MageFrost.lua
     Frost Mage, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs 2.0/MageFrost.simc

     Two procs to react to: Fingers of Frost enables Deep Freeze, and
     Brain Freeze makes the next Frostfire Bolt instant and free.
     Everything else is Frostbolt.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Frost Mage",
    class     = "MAGE",
    tab       = 3,             -- Frost tree
    school    = 5,             -- frost
    powerType = 0,
    gcdProbe  = 42842,         -- Frostbolt
    hasteRefBase = 3,          -- Frostbolt: 3s base
}

spec.auras = {
    fingers_of_frost = { id = 44544, type = "buff" },
    brain_freeze     = { id = 57761, type = "buff" },
    icy_veins        = { id = 12472, type = "buff" },
    molten_armor     = { id = 43046, type = "buff" },
    frozen           = { id = 12494, type = "debuff", mine = true, duration = 8 },
}

spec.abilities = {
    frostbolt = {
        key = "frostbolt", id = 42842, harmful = true, castTime = 3,
    },
    frostfire_bolt = {
        key = "frostfire_bolt", id = 47610, harmful = true, castTime = 3,
    },
    deep_freeze = {
        key = "deep_freeze", id = 44572, harmful = true, cd = 30, castTime = 0,
    },
    ice_lance = {
        key = "ice_lance", id = 42914, harmful = true, castTime = 0,
        castableMoving = true,
    },
    blizzard = {
        key = "blizzard", id = 42940, harmful = true,
        channel = true, channelTime = 8,
    },
    cone_of_cold = {
        key = "cone_of_cold", id = 42931, harmful = true, cd = 10, castTime = 0,
    },
    arcane_explosion = {
        key = "arcane_explosion", id = 42921, harmful = true, castTime = 0,
    },
    fire_blast = {
        key = "fire_blast", id = 42873, harmful = true, cd = 8, castTime = 0,
        castableMoving = true,
    },
    icy_veins = {
        key = "icy_veins", id = 12472, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Icy Veins",
        applies = "icy_veins", appliesTo = "buff", appliesFor = 20,
    },
    cold_snap = {
        key = "cold_snap", id = 11958, cd = 384, castableMoving = true,
        majorCD = true, minTTD = 20, cdLabel = "Cold Snap",
    },
    mirror_image = {
        key = "mirror_image", id = 55342, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 20, cdLabel = "Mirror Image",
    },
    summon_water_elemental = {
        key = "summon_water_elemental", id = 31687, cd = 180,
        castableMoving = true,
    },
    evocation = {
        key = "evocation", id = 12051, cd = 240,
        channel = true, channelTime = 8,
    },
    molten_armor = {
        key = "molten_armor", id = 43046, castableMoving = true,
        applies = "molten_armor", appliesTo = "buff", appliesFor = 1800,
    },
    counterspell = {
        key = "counterspell", id = 2139, harmful = true, cd = 24,
        castableMoving = true,
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
    spec.gcdProbeName = spec.abilities.frostbolt.name
    spec.hasteRefName = spec.abilities.frostbolt.name
end

function spec.UpdateExtra(state)
    state.fof = state.buff.fingers_of_frost.up
    state.fof_stacks = state.buff.fingers_of_frost.stack or 0
    state.brain_freeze = state.buff.brain_freeze.up
    state.mana_evocate = (state.manaPct or 100) < (ER:Setting("frostEvocationMana") or 30)
    state.has_pet = state.pet and true or false
end

spec.lists = {}

spec.lists.precombat = {
    { key = "molten_armor", when = function(s) return not s.buff.molten_armor.up end },
    { key = "summon_water_elemental", when = function(s)
        return ER:Setting("eternalWater") == true and not s.has_pet
    end },
}

spec.lists.single = {
    { key = "mirror_image" },
    { key = "summon_water_elemental", when = function(s)
        return ER:Setting("eternalWater") ~= true
    end },
    { key = "icy_veins" },

    { key = "cold_snap", when = function(s)
        return not s.buff.icy_veins.up and s.cooldown.icy_veins.remains > 60
    end },

    -- Deep Freeze needs the target frozen or a Fingers of Frost charge.
    { key = "deep_freeze", when = function(s)
        return s.fof or s.dot.frozen.up
    end },

    -- Brain Freeze: instant, free Frostfire Bolt. Never sit on it.
    { key = "frostfire_bolt", when = function(s) return s.brain_freeze end },

    { key = "evocation", when = function(s) return s.mana_evocate end },

    { key = "fire_blast", when = function(s) return s.moving end },
    { key = "ice_lance",  when = function(s) return s.moving and s.fof end },

    { key = "frostbolt" },
}

spec.lists.aoe = {
    { key = "icy_veins" },
    { key = "frostfire_bolt", when = function(s) return s.brain_freeze end },
    { key = "blizzard", when = function(s) return not s.moving end },
    { key = "cone_of_cold", when = function(s)
        return s.moving and ER:Setting("frostMeleeAoe") == true
    end },
    { key = "arcane_explosion", when = function(s)
        return s.moving and ER:Setting("frostMeleeAoe") == true
    end },
    { key = "evocation", when = function(s) return s.mana_evocate end },
    { key = "frostbolt" },
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
    if class ~= "MAGE" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t3 > t1 and t3 > t2
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("MAGE", "frost", "Mage", "Frost", {
    { type = "check", key = "eternalWater",
      label = "I have Glyph of Eternal Water", onValue = true, offValue = false,
      tooltip = "Makes the Water Elemental permanent, so it is summoned "
             .. "before the pull rather than on cooldown." },
    { type = "check", key = "frostMeleeAoe",
      label = "Use Cone of Cold and Arcane Explosion", onValue = true,
      offValue = false,
      tooltip = "Both need the pack close to you. Off by default." },
    { type = "slider", key = "frostEvocationMana",
      label = "Evocate below", min = 5, max = 50, step = 5, fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. THE SOURCE holds a Frostbolt in flight to line up Deep Freeze
     with a Fingers of Frost charge. In-flight spell tracking is not
     implemented, so Deep Freeze simply fires when it is usable.
  2. MANA GEMS and potions are omitted, as elsewhere.
  3. THREE MAGE SPECS now share a class, each claiming a different
     talent tab. Spec detection picks whichever has the most points.
  4. THE WATER ELEMENTAL is summoned on cooldown without the glyph,
     or once before the pull with it. Tell the addon which via the
     setting - the glyph is not reliably readable.
------------------------------------------------------------------]]
