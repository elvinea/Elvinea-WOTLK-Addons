--[[ ElvinRotation - Specs/DruidBalance.lua
     Balance Druid, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs/DruidBalance.simc

     Built entirely around Eclipse. Two states:
       FISHING - no Eclipse up, cast whichever nuke can proc the one
                 you want next
       SPAMMING - an Eclipse is up, hammer the nuke it buffs
     The source calls these "fish" and "spam" and so does this file.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Balance Druid",
    class     = "DRUID",
    tab       = 1,             -- Balance tree
    school    = 6,             -- arcane/nature mix; arcane for Starfire
    powerType = 0,             -- mana
    gcdProbe  = 48461,         -- Wrath

    hasteRefBase = 2.5,        -- Wrath: 2s base... Starfire is 3.5s
}

--------------------------------------------------------------------
spec.auras = {
    moonkin_form   = { id = 24858, type = "buff" },
    eclipse_lunar  = { id = 48518, type = "buff" },   -- Starfire buffed
    eclipse_solar  = { id = 48517, type = "buff" },   -- Wrath buffed
    elunes_wrath   = { id = 64823, type = "buff" },   -- instant Starfire proc

    moonfire       = { id = 48463, type = "debuff", mine = true, duration = 12 },
    insect_swarm   = { id = 48468, type = "debuff", mine = true, duration = 12 },
    faerie_fire    = { id = 770,   type = "debuff", mine = false, duration = 300 },
}

--------------------------------------------------------------------
spec.abilities = {
    wrath = {
        key = "wrath", id = 48461, harmful = true, castTime = 2,
    },
    starfire = {
        key = "starfire", id = 48465, harmful = true, castTime = 3.5,
    },
    moonfire = {
        key = "moonfire", id = 48463, harmful = true, castTime = 0,
        applies = "moonfire", appliesFor = 12, openerSkipIfUp = true,
    },
    insect_swarm = {
        key = "insect_swarm", id = 48468, harmful = true, castTime = 0,
        applies = "insect_swarm", appliesFor = 12, openerSkipIfUp = true,
    },
    starfall = {
        key = "starfall", id = 53201, harmful = true, castTime = 0, cd = 90,
        majorCD = true, minTTD = 10, cdLabel = "Starfall",
    },
    force_of_nature = {
        key = "force_of_nature", id = 33831, castTime = 0, cd = 180,
        majorCD = true, minTTD = 20, cdLabel = "Force of Nature",
    },
    typhoon = {
        key = "typhoon", id = 61384, harmful = true, castTime = 0, cd = 20,
        castableMoving = true,
    },
    hurricane = {
        key = "hurricane", id = 48467, harmful = true,
        channel = true, channelTime = 10, cd = 60,
    },
    faerie_fire = {
        key = "faerie_fire", id = 770, harmful = true, castTime = 0,
        applies = "faerie_fire", appliesFor = 300,
    },
    moonkin_form = {
        key = "moonkin_form", id = 24858, castableMoving = true,
        applies = "moonkin_form", appliesTo = "buff", appliesFor = 3600,
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

    spec.gcdProbeName = spec.abilities.wrath.name
    spec.hasteRefName = spec.abilities.starfire.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    state.lunar_up = state.buff.eclipse_lunar.up      -- Starfire buffed
    state.solar_up = state.buff.eclipse_solar.up      -- Wrath buffed
    state.spam_now = state.lunar_up or state.solar_up
    state.fish_now = not state.spam_now

    -- Each Eclipse has its own 30s internal cooldown from when it last
    -- procced. sinceCast cannot see that, so track when each was last
    -- seen up and assume it can proc again 30s later.
    ER.eclipseSeen = ER.eclipseSeen or {}
    if state.lunar_up then ER.eclipseSeen.lunar = state.now end
    if state.solar_up then ER.eclipseSeen.solar = state.now end

    local ICD = 30
    local lunarLast = ER.eclipseSeen.lunar
    local solarLast = ER.eclipseSeen.solar
    state.lunar_can_proc = (not lunarLast) or (state.now - lunarLast) >= ICD
    state.solar_can_proc = (not solarLast) or (state.now - solarLast) >= ICD

    -- Which one are we fishing for? Wrath procs Lunar, Starfire procs
    -- Solar, so "fishing for Lunar" means casting Wrath.
    state.lunar_fish = state.fish_now and state.lunar_can_proc
    state.solar_fish = state.fish_now
                       and (state.solar_can_proc or not state.lunar_can_proc)
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "moonkin_form", when = function(s) return not s.buff.moonkin_form.up end },
}

-- No Eclipse up: keep DoTs rolling and cast whichever nuke procs the
-- Eclipse we want next.
spec.lists.fish = {
    { key = "starfire", when = function(s)
        -- Elune's Wrath makes the next Starfire instant. Spend it if
        -- we are not fishing for Lunar, or if it is about to expire.
        return s.buff.elunes_wrath.up
           and (not s.lunar_fish
                or s.buff.elunes_wrath.remains < 1.5
                or s.moving)
    end },

    { key = "moonfire", when = function(s)
        return not s.dot.moonfire.up and s.moving
    end },

    { key = "force_of_nature" },
    { key = "starfall" },

    { key = "faerie_fire", when = function(s)
        return ER:Setting("maintainFaerieFire") == true and not s.dot.faerie_fire.up
    end },

    { key = "insect_swarm", when = function(s) return not s.dot.insect_swarm.up end },

    { key = "typhoon", when = function(s)
        return s.moving and ER:Setting("glyphTyphoon") == true
    end },

    { key = "moonfire", when = function(s)
        return s.lunar_fish and s.dot.moonfire.remains < 3
    end },

    { key = "wrath",    when = function(s) return s.lunar_fish end },
    { key = "starfire", when = function(s) return s.solar_fish end },
}

-- An Eclipse is up: hammer the nuke it buffs before it falls off.
spec.lists.spam = {
    { key = "starfire", when = function(s) return s.buff.elunes_wrath.up end },

    -- Only re-DoT if the Eclipse has enough left to spare a global.
    { key = "insect_swarm", when = function(s)
        return not s.dot.insect_swarm.up
           and (not s.lunar_up or s.buff.eclipse_lunar.remains > 7)
    end },

    { key = "wrath",    when = function(s) return s.solar_up end },
    { key = "starfire", when = function(s) return s.lunar_up end },
}

spec.lists.aoe = {
    { key = "typhoon",   when = function(s) return ER:Setting("glyphTyphoon") == true end },
    { key = "starfall" },
    { key = "hurricane", when = function(s) return not s.moving end },
}

spec.lists.single = spec.lists.fish   -- required by the structural checks

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 3 end },
    { runList = "spam", terminal = true, when = function(s) return s.spam_now end },
    { runList = "fish", terminal = true, when = function(s) return true end },
}

--------------------------------------------------------------------
function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "DRUID" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("DRUID", "balance", "Druid", "Balance", {
    { type = "check", key = "glyphTyphoon",
      label = "I have Glyph of Typhoon", onValue = true, offValue = false,
      tooltip = "Removes the knockback, which makes Typhoon usable in a "
             .. "raid. Without it, do not cast it near a tank." },
    { type = "check", key = "maintainFaerieFire",
      label = "Maintain Faerie Fire", onValue = true, offValue = false,
      tooltip = "Usually another player's debuff. Costs you a global." },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. ECLIPSE INTERNAL COOLDOWN. Each Eclipse can only proc every 30
     seconds. The source reads the last-applied timestamp directly;
     3.3.5 does not expose that, so this tracks when each Eclipse was
     last seen up and assumes 30 seconds from there. It will be wrong
     for the first proc after a reload.

  2. WHICH NUKE PROCS WHICH. Wrath procs Lunar Eclipse (which buffs
     Starfire); Starfire procs Solar (which buffs Wrath). Fishing for
     Lunar therefore means casting Wrath. This reads backwards until
     you have it in your head.

  3. TYPHOON is off by default. Without the glyph it knocks back, which
     is a good way to annoy a tank.

  4. SINGLE-TARGET AND FISH are the same list. Balance has no separate
     single-target priority - "fish" IS the single-target rotation
     whenever no Eclipse is up.

  5. TREANTS AND STARFALL are treated as major cooldowns, so /er cd
     suppresses them.
------------------------------------------------------------------]]
