--[[ ElvinRotation - Specs/WarriorArms.lua
     Arms Warrior, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/WarriorArms.simc

     First rage spec in the addon. Arms lives in Battle Stance for
     Overpower and dips into Berserker only for Recklessness, so the
     stance handling here is deliberately minimal - see NOTES.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Arms Warrior",
    class     = "WARRIOR",
    tab       = 1,             -- Arms tree
    school    = 1,             -- physical
    powerType = 1,             -- SPELL_POWER_RAGE
    usesStance = true,
    gcdProbe  = 47486,         -- Mortal Strike
}

--------------------------------------------------------------------
spec.auras = {
    battle_stance    = { id = 2457,  type = "buff" },
    berserker_stance = { id = 2458,  type = "buff" },
    taste_for_blood  = { id = 60503, type = "buff" },
    overpower_ready  = { id = 68051, type = "buff" },
    sudden_death     = { id = 52437, type = "buff" },
    recklessness     = { id = 1719,  type = "buff" },
    battle_shout     = { id = 47436, type = "buff" },
    bladestorm       = { id = 46924, type = "buff" },

    victorious   = { id = 32216, type = "buff" },

    rend         = { id = 47465, type = "debuff", mine = true, duration = 15 },
    sunder_armor = { id = 7386,  type = "debuff", mine = false, duration = 30 },
}

--------------------------------------------------------------------
spec.abilities = {
    mortal_strike = {
        key = "mortal_strike", id = 47486, harmful = true, cd = 6, power = 30,
    },
    rend = {
        key = "rend", id = 47465, harmful = true, power = 10,
        applies = "rend", appliesFor = 15, openerSkipIfUp = true,
    },
    overpower = {
        key = "overpower", id = 7384, harmful = true, cd = 5, power = 5,
    },
    slam = {
        key = "slam", id = 47475, harmful = true, castTime = 1.5, power = 15,
    },
    execute = {
        key = "execute", id = 47471, harmful = true, power = 15,
    },
    bladestorm = {
        key = "bladestorm", id = 46924, harmful = true, cd = 90, power = 25,
        majorCD = true, minTTD = 10, cdLabel = "Bladestorm",
        applies = "bladestorm", appliesTo = "buff", appliesFor = 6,
    },
    heroic_strike = {
        key = "heroic_strike", offGCD = true, id = 47450, harmful = true, power = 15,
    },
    cleave = {
        key = "cleave", offGCD = true, id = 47520, harmful = true, power = 20,
    },
    sweeping_strikes = {
        key = "sweeping_strikes", id = 12328, cd = 30, power = 30,
    },
    recklessness = {
        key = "recklessness", id = 1719, cd = 300, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Recklessness",
        applies = "recklessness", appliesTo = "buff", appliesFor = 12,
    },
    bloodrage = {
        key = "bloodrage", id = 2687, cd = 60, castableMoving = true,
        generatesPower = 20,
    },
    battle_shout = {
        key = "battle_shout", id = 47436, castableMoving = true,
        applies = "battle_shout", appliesTo = "buff", appliesFor = 120,
            selfBuff = true,
    },
    sunder_armor = {
        key = "sunder_armor", id = 7386, harmful = true, power = 15,
        applies = "sunder_armor", appliesFor = 30,
    },
    victory_rush = {
        key = "victory_rush", id = 34428, harmful = true,
    },
    battle_stance = {
        key = "battle_stance", id = 2457, castableMoving = true,
        applies = "battle_stance", appliesTo = "buff", appliesFor = 3600,
            selfBuff = true,
    },
    berserker_stance = {
        key = "berserker_stance", id = 2458, castableMoving = true,
        applies = "berserker_stance", appliesTo = "buff", appliesFor = 3600,
            selfBuff = true,
    },
    pummel = {
        key = "pummel", id = 6552, harmful = true, cd = 10, power = 10,
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

    spec.gcdProbeName = spec.abilities.mortal_strike.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    state.execute_phase = (state.targetHealthPct or 100) < 20
    state.rage = state.power or 0

    -- Overpower is usable after a dodge, or free from Taste for Blood
    -- (which Rend ticks grant). Both surface as buffs.
    state.overpower_now = state.buff.overpower_ready.up
                       or state.buff.taste_for_blood.up

    -- Rage to keep in reserve before queueing Heroic Strike, so the
    -- next Mortal Strike is always affordable.
    state.rage_to_queue = ER:Setting("heroicStrikeRage") or 60
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "battle_stance", when = function(s)
        return s.stance ~= "battle" and s.stance ~= "berserker"
    end },
    { key = "battle_shout", when = function(s) return not s.buff.battle_shout.up end },
}

spec.lists.single = {
    { key = "bloodrage", when = function(s)
        return (s.powerMax or 100) - s.rage > 20
    end },

    { key = "recklessness", when = function(s)
        return s.cooldown.bladestorm.remains < 1.5
    end },

    { key = "rend", when = function(s)
        return s.dot.rend.remains <= (ER:Setting("rendRefresh") or 3)
    end },

    { key = "overpower", when = function(s) return s.overpower_now end },

    { key = "bladestorm", when = function(s)
        return s.dot.rend.remains >= 7 and not s.execute_phase
    end },

    { key = "mortal_strike" },

    { key = "execute", when = function(s) return s.execute_phase end },

    -- Slam is only worth it with Sudden Death up; otherwise the cast
    -- time costs more than the hit is worth.
    { key = "slam", when = function(s)
        return s.buff.sudden_death.up and not s.moving
    end },

    -- Victory Rush only works after you kill something, signalled by
    -- the Victorious buff. Without this it was being recommended
    -- constantly on a target dummy, where nothing ever dies.
    { key = "victory_rush", when = function(s) return s.buff.victorious.up end },

    -- Rage dump. Held back so a Mortal Strike is always affordable.
    { key = "heroic_strike", when = function(s)
        return s.rage >= s.rage_to_queue and not s.buff.recklessness.up
    end },
}

spec.lists.aoe = {
    { key = "sweeping_strikes" },
    { key = "bladestorm", when = function(s) return s.dot.rend.remains >= 7 end },
    { key = "rend", when = function(s)
        return s.dot.rend.remains <= (ER:Setting("rendRefresh") or 3)
    end },
    { key = "overpower", when = function(s) return s.overpower_now end },
    { key = "mortal_strike" },
    { key = "cleave", when = function(s) return s.rage >= s.rage_to_queue end },
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
    if class ~= "WARRIOR" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("WARRIOR", "arms", "Warrior", "Arms", {
    { type = "slider", key = "heroicStrikeRage",
      label = "Queue Heroic Strike above", min = 20, max = 100, step = 5,
      fmt = "%d rage",
      tooltip = "Rage to keep in reserve so Mortal Strike is always "
             .. "affordable. Raise it if you find yourself rage starved." },
    { type = "slider", key = "rendRefresh",
      label = "Refresh Rend at", min = 0, max = 8, step = 0.5, fmt = "%.1fs" },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. STANCE DANCING IS NOT IMPLEMENTED. The source runs three separate
     lists, one per stance, and swaps into Berserker for Recklessness
     and Bladestorm before returning to Battle. That is a real part of
     high-end Arms play and it is deliberately left out: doing it
     badly is worse than not doing it. This assumes you stay in Battle
     Stance.

  2. HEROIC STRIKE is an off-GCD queued ability. The addon treats it
     as a normal recommendation, which is not quite right - it should
     be queued alongside your next global, not instead of it. The rage
     reserve slider is the crude version of that.

  3. SUNDER ARMOR upkeep is omitted. The source has an elaborate
     build-and-maintain plan for it; it is normally a tank's debuff.

  4. SLAM is gated on Sudden Death here. The source has a much more
     involved Slam-weaving model tied to swing timers, which 3.3.5
     exposes poorly.

  5. RAGE has no maximum worth modelling beyond the 100 cap, and
     Bloodrage is the only generator in the list.
------------------------------------------------------------------]]
