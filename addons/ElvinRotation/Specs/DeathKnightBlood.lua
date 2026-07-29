--[[ ElvinRotation - Specs/DeathKnightBlood.lua
     Blood Death Knight (DPS), WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs 2.0/DeathKnight-BloodPesti.simc

     Third Death Knight spec, so it inherits the rune model for free.
     Everything orbits Dancing Rune Weapon: the burst cooldowns are
     all held for it, and Death Coil is only spent while it is down.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Blood Death Knight",
    class     = "DEATHKNIGHT",
    tab       = 1,             -- Blood tree
    school    = 1,
    gcdProbe  = 49909,         -- Icy Touch

    usesRunes    = true,
    usesPresence = true,
}

spec.auras = {
    frost_fever   = { id = 55095, type = "debuff", mine = true, duration = 15 },
    blood_plague  = { id = 55078, type = "debuff", mine = true, duration = 15 },

    horn_of_winter      = { id = 57623, type = "buff" },
    unholy_frenzy       = { id = 49016, type = "buff" },
    dancing_rune_weapon = { id = 49028, type = "buff" },
    bone_shield         = { id = 49222, type = "buff" },
}

spec.abilities = {
    icy_touch = {
        key = "icy_touch", id = 49909, harmful = true, castableMoving = true,
        runes = { frost = 1 }, generatesRP = 10,
        applies = "frost_fever", appliesFor = 15, openerSkipIfUp = true,
    },
    plague_strike = {
        key = "plague_strike", id = 49921, harmful = true, castableMoving = true,
        runes = { unholy = 1 }, generatesRP = 10,
        applies = "blood_plague", appliesFor = 15, openerSkipIfUp = true,
    },
    heart_strike = {
        key = "heart_strike", id = 55262, harmful = true, castableMoving = true,
        runes = { blood = 1 }, generatesRP = 10,
    },
    death_strike = {
        key = "death_strike", id = 49924, harmful = true, castableMoving = true,
        runes = { frost = 1, unholy = 1 }, generatesRP = 15,
    },
    pestilence = {
        key = "pestilence", id = 50842, harmful = true, castableMoving = true,
        runes = { blood = 1 },
    },
    death_coil = {
        key = "death_coil", id = 49895, harmful = true, castableMoving = true,
        rp = 40,
    },
    dancing_rune_weapon = {
        key = "dancing_rune_weapon", id = 49028, castableMoving = true, cd = 90,
        rp = 60, majorCD = true, minTTD = 20, cdLabel = "Dancing Rune Weapon",
        applies = "dancing_rune_weapon", appliesTo = "buff", appliesFor = 12,
    },
    unholy_frenzy = {
        key = "unholy_frenzy", id = 49016, castableMoving = true, cd = 180,
        majorCD = true, minTTD = 20, cdLabel = "Unholy Frenzy",
        applies = "unholy_frenzy", appliesTo = "buff", appliesFor = 30,
    },
    empower_rune_weapon = {
        key = "empower_rune_weapon", id = 47568, castableMoving = true, cd = 300,
        majorCD = true, minTTD = 20, cdLabel = "Empower Rune Weapon",
    },
    army_of_the_dead = {
        key = "army_of_the_dead", id = 42650, castableMoving = true, cd = 600,
        runes = { blood = 1, frost = 1, unholy = 1 },
        majorCD = true, minTTD = 40, cdLabel = "Army of the Dead",
    },
    raise_dead = {
        key = "raise_dead", id = 46584, castableMoving = true, cd = 180,
    },
    blood_tap = {
        key = "blood_tap", id = 45529, castableMoving = true, cd = 60,
    },
    horn_of_winter = {
        key = "horn_of_winter", id = 57623, castableMoving = true, cd = 20,
        generatesRP = 10,
        applies = "horn_of_winter", appliesTo = "buff", appliesFor = 120,
    },
    mind_freeze = {
        key = "mind_freeze", id = 47528, harmful = true, castableMoving = true,
        cd = 10, rp = 20,
    },
    blood_presence = {
        key = "blood_presence", id = 48266, castableMoving = true,
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
    spec.gcdProbeName = spec.abilities.icy_touch.name
end

function spec.UpdateExtra(state)
    state.rp = state.runicPower or 0
    state.drw_ready = state.cooldown.dancing_rune_weapon
                      and state.cooldown.dancing_rune_weapon.remains <= 0
    state.drw_up = state.buff.dancing_rune_weapon.up
end

spec.lists = {}

spec.lists.precombat = {
    { key = "blood_presence", when = function(s) return s.presence ~= "blood" end },
    { key = "horn_of_winter", when = function(s)
        return not s.buff.horn_of_winter.up
    end },
}

-- Opener, transcribed from the source's actions.opener list.
spec.lists.opener = {
    { key = "icy_touch",           casts = 1 },
    { key = "plague_strike",       casts = 1 },
    { key = "death_strike",        casts = 1 },
    { key = "heart_strike",        casts = 2 },
    { key = "raise_dead",          casts = 1 },
    { key = "empower_rune_weapon", casts = 1 },
    { key = "dancing_rune_weapon", casts = 1 },
    { key = "death_strike",        casts = 2 },
    { key = "heart_strike",        casts = 3 },
    { key = "blood_tap",           casts = 1 },
    { key = "heart_strike",        casts = 4 },
}

spec.lists.single = {
    { key = "icy_touch",     when = function(s) return not s.dot.frost_fever.up end },
    { key = "plague_strike", when = function(s) return not s.dot.blood_plague.up end },

    { key = "pestilence", when = function(s)
        return s.dot.frost_fever.up and s.dot.frost_fever.remains < 1.5
    end },

    -- Burst cooldowns are all held for Dancing Rune Weapon.
    { key = "unholy_frenzy", when = function(s) return s.drw_ready end },
    { key = "raise_dead",    when = function(s) return s.drw_ready end },
    { key = "dancing_rune_weapon" },

    { key = "heart_strike" },
    { key = "death_strike" },

    -- Runic power is saved while Dancing Rune Weapon is available,
    -- because the ability itself costs 60.
    { key = "death_coil", when = function(s) return not s.drw_ready end },

    { key = "horn_of_winter", when = function(s)
        return not s.buff.horn_of_winter.up
    end },
}

spec.lists.aoe = {
    { key = "icy_touch",     when = function(s) return not s.dot.frost_fever.up end },
    { key = "plague_strike", when = function(s) return not s.dot.blood_plague.up end },
    { key = "pestilence", when = function(s)
        return s.dot.frost_fever.up
           and (s.activeDot.frost_fever or 0) < (s.activeEnemies or 1)
    end },
    { key = "dancing_rune_weapon" },
    { key = "heart_strike" },
    { key = "death_strike" },
    { key = "death_coil", when = function(s) return not s.drw_ready end },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "opener", terminal = false,
      when = function(s)
          return s.inCombat
             and s.combatTime < (ER:Setting("openerWindow") or 40)
             and ER:Setting("useOpener") ~= false
      end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 1 end },
    { runList = "single", terminal = true, when = function(s) return true end },
}

function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "DEATHKNIGHT" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("DEATHKNIGHT", "blood", "Death Knight", "Blood (DPS)", {
    { type = "check", key = "useOpener",
      label = "Use the scripted opener", onValue = true, offValue = false },
}, spec)

--[[ NOTES ---------------------------------------------------------
  1. THIS IS THE DPS BLOOD SPEC, not the tank one. Blood was the DPS
     tree before 3.2 and remained viable after; the source list is a
     damage list, not a threat list.
  2. UNHOLY FRENZY is usually cast on someone else in a raid. Here it
     is treated as a self cooldown held for Dancing Rune Weapon.
  3. THREE DK SPECS now share the class, one per talent tab.
  4. DEATH COIL is held while Dancing Rune Weapon is off cooldown,
     because DRW itself costs 60 runic power.
------------------------------------------------------------------]]
