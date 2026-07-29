--[[ ElvinRotation - Specs/MageFire.lua
     Fire Mage, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs 2.0/MageFire.simc

     Keep Living Bomb rolling, react to Hot Streak with an instant
     Pyroblast, fill with Fireball. Short list, one proc to watch.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Fire Mage",
    class     = "MAGE",
    tab       = 2,             -- Fire tree
    school    = 4,             -- fire
    powerType = 0,             -- mana
    gcdProbe  = 42833,         -- Fireball

    hasteRefBase = 3.5,        -- Fireball: 3.5s base
}

--------------------------------------------------------------------
spec.auras = {
    hot_streak   = { id = 48108, type = "buff" },
    firestarter  = { id = 54741, type = "buff" },
    combustion   = { id = 11129, type = "buff" },
    icy_veins    = { id = 12472, type = "buff" },
    molten_armor = { id = 43046, type = "buff" },

    living_bomb  = { id = 55360, type = "debuff", mine = true, duration = 12 },
    improved_scorch = { id = 22959, type = "debuff", mine = false, duration = 30 },
}

--------------------------------------------------------------------
spec.abilities = {
    fireball = {
        key = "fireball", id = 42833, harmful = true, castTime = 3.5,
    },
    frostfire_bolt = {
        key = "frostfire_bolt", id = 47610, harmful = true, castTime = 3,
    },
    pyroblast = {
        key = "pyroblast", id = 42891, harmful = true, castTime = 5,
    },
    living_bomb = {
        key = "living_bomb", id = 55360, harmful = true, castTime = 0,
        applies = "living_bomb", appliesFor = 12, openerSkipIfUp = true,
    },
    scorch = {
        key = "scorch", id = 42859, harmful = true, castTime = 1.5,
    },
    fire_blast = {
        key = "fire_blast", id = 42873, harmful = true, cd = 8, castTime = 0,
        castableMoving = true,
    },
    blast_wave = {
        key = "blast_wave", id = 42945, harmful = true, cd = 30, castTime = 0,
    },
    dragons_breath = {
        key = "dragons_breath", id = 42950, harmful = true, cd = 20, castTime = 0,
    },
    flamestrike = {
        key = "flamestrike", id = 42926, harmful = true, castTime = 2,
    },
    blizzard = {
        key = "blizzard", id = 42940, harmful = true,
        channel = true, channelTime = 8,
    },
    combustion = {
        key = "combustion", id = 11129, cd = 120, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Combustion",
        applies = "combustion", appliesTo = "buff", appliesFor = 15,
    },
    icy_veins = {
        key = "icy_veins", id = 12472, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Icy Veins",
        applies = "icy_veins", appliesTo = "buff", appliesFor = 20,
    },
    mirror_image = {
        key = "mirror_image", id = 55342, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 20, cdLabel = "Mirror Image",
    },
    evocation = {
        key = "evocation", id = 12051, cd = 240,
        channel = true, channelTime = 8,
    },
    molten_armor = {
        key = "molten_armor", id = 43046, castableMoving = true,
        applies = "molten_armor", appliesTo = "buff", appliesFor = 1800,
            selfBuff = true,
    },
    counterspell = {
        key = "counterspell", id = 2139, harmful = true, cd = 24,
        castableMoving = true,
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

    spec.gcdProbeName = spec.abilities.fireball.name
    spec.hasteRefName = spec.abilities.fireball.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    -- Hot Streak makes the next Pyroblast instant. It is the only
    -- thing in the spec worth reacting to.
    state.hot_streak = state.buff.hot_streak.up

    state.mana_evocate = (state.manaPct or 100) < (ER:Setting("fireEvocationMana") or 30)
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "molten_armor", when = function(s) return not s.buff.molten_armor.up end },
}

spec.lists.single = {
    { key = "mirror_image" },
    { key = "combustion" },
    { key = "icy_veins" },

    { key = "living_bomb", when = function(s)
        return not s.dot.living_bomb.up and (s.ttd or 0) > 12
    end },

    -- Instant Pyroblast. Use it immediately: another crit while it is
    -- up is a wasted proc.
    { key = "pyroblast", when = function(s) return s.hot_streak end },

    { key = "evocation", when = function(s) return s.mana_evocate end },

    { key = "fire_blast", when = function(s) return s.moving end },

    { key = "frostfire_bolt", when = function(s)
        return ER:Setting("glyphFrostfire") == true
    end },

    { key = "fireball" },
}

spec.lists.aoe = {
    { key = "combustion" },
    { key = "living_bomb", when = function(s)
        return not s.dot.living_bomb.up and (s.ttd or 0) > 12
    end },
    { key = "pyroblast", when = function(s) return s.hot_streak end },
    { key = "blast_wave", when = function(s)
        return ER:Setting("fireMeleeAoe") == true
    end },
    { key = "dragons_breath", when = function(s)
        return ER:Setting("fireMeleeAoe") == true
    end },
    { key = "flamestrike", when = function(s)
        return s.buff.firestarter.up and not s.moving
    end },
    { key = "blizzard", when = function(s) return not s.moving end },
    { key = "fireball" },
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
    if class ~= "MAGE" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t2 > t1 and t2 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("MAGE", "fire", "Mage", "Fire", {
    { type = "check", key = "glyphFrostfire",
      label = "I have Glyph of Frostfire", onValue = true, offValue = false,
      tooltip = "Makes Frostfire Bolt beat Fireball as your filler." },
    { type = "check", key = "fireMeleeAoe",
      label = "Use Blast Wave and Dragon's Breath", onValue = true,
      offValue = false,
      tooltip = "Both need the pack close to you, and Dragon's Breath "
             .. "disorients. Off by default." },
    { type = "slider", key = "fireEvocationMana",
      label = "Evocate below", min = 5, max = 50, step = 5, fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. IMPROVED SCORCH upkeep is omitted. The debuff is usually kept up
     by whoever is assigned to it, and in most raids that is not the
     Fire mage's job by Wrath.

  2. MULTI-DOTTING Living Bomb, which the source does with
     cycle_targets up to a cap, is single-target only here.

  3. HOT STREAK is read from the buff (id 48108). There is also a
     separate Firestarter buff for instant Flamestrike; both are
     tracked but only Hot Streak drives the single-target list.

  4. FIRE AND ARCANE share a class but claim different talent tabs,
     so spec detection picks whichever tree you have more points in.
     That is the same mechanism as the two Death Knight specs.

  5. NO OPENER. The source has none for Fire beyond a pre-cast
     Pyroblast, which cannot be usefully prompted.
------------------------------------------------------------------]]
