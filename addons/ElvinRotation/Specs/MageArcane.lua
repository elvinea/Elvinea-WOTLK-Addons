--[[ ElvinRotation - Specs/MageArcane.lua
     Arcane Mage, WotLK 3.3.5a.

     Translated from Hekili's Wrath build:
       Wrath/APLs 2.0/MageArcane.simc
     which credits Icy Veins, September 2023.

     The shortest priority in the addon. Stack Arcane Blast to four,
     spend with Arcane Missiles, keep mana above water. Almost all the
     skill is in the mana management, not the button order.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name      = "Arcane Mage",
    class     = "MAGE",
    tab       = 1,             -- Arcane tree
    school    = 6,             -- arcane
    powerType = 0,             -- mana
    gcdProbe  = 42897,         -- Arcane Blast

    hasteRefBase = 2.5,        -- Arcane Blast: 2.5s base cast
}

--------------------------------------------------------------------
spec.auras = {
    -- Arcane Blast stacks on YOU, up to 4. Each stack raises the
    -- damage and the mana cost of the next one, which is the whole
    -- tension in the spec.
    arcane_blast     = { id = 36032, type = "buff" },
    missile_barrage  = { id = 44401, type = "buff" },
    clearcasting     = { id = 12536, type = "buff" },
    arcane_power     = { id = 12042, type = "buff" },
    presence_of_mind = { id = 12043, type = "buff" },
    molten_armor     = { id = 43046, type = "buff" },
    icy_veins        = { id = 12472, type = "buff" },
}

--------------------------------------------------------------------
spec.abilities = {
    arcane_blast = {
        key = "arcane_blast", id = 42897, harmful = true, castTime = 2.5,
        applies = "arcane_blast", appliesTo = "buff", appliesFor = 8,
    },
    arcane_missiles = {
        key = "arcane_missiles", id = 42846, harmful = true,
        channel = true, channelTime = 5,
    },
    arcane_barrage = {
        key = "arcane_barrage", id = 44781, harmful = true, cd = 3,
        castTime = 0, castableMoving = true,
    },
    arcane_explosion = {
        key = "arcane_explosion", id = 42921, harmful = true, castTime = 0,
    },
    blizzard = {
        key = "blizzard", id = 42940, harmful = true,
        channel = true, channelTime = 8,
    },
    flamestrike = {
        key = "flamestrike", id = 42926, harmful = true, castTime = 2,
    },
    evocation = {
        key = "evocation", id = 12051, cd = 240,
        channel = true, channelTime = 8,
    },
    arcane_power = {
        key = "arcane_power", id = 12042, cd = 120, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Arcane Power",
        applies = "arcane_power", appliesTo = "buff", appliesFor = 15,
    },
    presence_of_mind = {
        key = "presence_of_mind", id = 12043, cd = 120, castableMoving = true,
        majorCD = true, minTTD = 10, cdLabel = "Presence of Mind",
    },
    mirror_image = {
        key = "mirror_image", id = 55342, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 20, cdLabel = "Mirror Image",
    },
    icy_veins = {
        key = "icy_veins", id = 12472, cd = 180, castableMoving = true,
        majorCD = true, minTTD = 15, cdLabel = "Icy Veins",
        applies = "icy_veins", appliesTo = "buff", appliesFor = 20,
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

    spec.gcdProbeName = spec.abilities.arcane_blast.name
    spec.hasteRefName = spec.abilities.arcane_blast.name
end

--------------------------------------------------------------------
function spec.UpdateExtra(state)
    state.ab_stacks = state.buff.arcane_blast.stack or 0
    state.ab_capped = state.ab_stacks >= 4

    -- Two separate mana lines: one to start recovering, one to panic.
    state.mana_recover = (state.manaPct or 100) < (ER:Setting("arcaneManaFloor") or 70)
    state.mana_evocate = (state.manaPct or 100) < (ER:Setting("evocationMana") or 30)
end

--------------------------------------------------------------------
spec.lists = {}

spec.lists.precombat = {
    { key = "molten_armor", when = function(s) return not s.buff.molten_armor.up end },
}

spec.lists.single = {
    { key = "arcane_power" },
    { key = "icy_veins" },
    { key = "mirror_image" },

    -- At four stacks, spend. Missile Barrage makes Arcane Missiles
    -- instant-ish and much cheaper than another Arcane Blast.
    -- Missile Barrage: spend it. It does NOT require four Arcane Blast
    -- stacks - requiring that meant a proc could sit there unused
    -- while you kept stacking, which is a straight damage loss.
    { key = "arcane_missiles", when = function(s)
        return s.buff.missile_barrage.up
           and s.ab_stacks >= (ER:Setting("barrageMinStacks") or 1)
    end },

    -- Moving with four stacks and no proc: Barrage is the only
    -- instant that still spends them.
    { key = "arcane_barrage", when = function(s)
        return s.ab_capped and not s.buff.missile_barrage.up and s.moving
    end },

    { key = "evocation", when = function(s) return s.mana_evocate end },

    -- Below the recovery line, stop stacking and spend instead: each
    -- extra Arcane Blast stack costs progressively more mana.
    { key = "arcane_missiles", when = function(s)
        return s.mana_recover and s.ab_stacks >= 2
    end },

    { key = "arcane_blast" },
}

spec.lists.aoe = {
    { key = "arcane_power" },
    { key = "evocation", when = function(s) return s.mana_evocate end },
    { key = "arcane_explosion", when = function(s)
        return ER:Setting("arcaneExplosionInMelee") == true
    end },
    { key = "blizzard", when = function(s) return not s.moving end },
    { key = "flamestrike", when = function(s) return not s.moving end },
    { key = "arcane_blast" },
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
    return t1 > t2 and t1 > t3
end

ER:RegisterSpec(spec)

ER:RegisterSpecOptions("MAGE", "arcane", "Mage", "Arcane", {
    { type = "check", key = "arcaneExplosionInMelee",
      label = "Use Arcane Explosion", onValue = true, offValue = false,
      tooltip = "Only worth it standing in the pack. The addon cannot "
             .. "check your distance to the target, so it is off by "
             .. "default." },
    { type = "slider", key = "barrageMinStacks",
      label = "Missile Barrage at", min = 0, max = 4, step = 1,
      fmt = "%d Arcane Blast stacks",
      tooltip = "Spend a Missile Barrage proc once you have at least "
             .. "this many stacks. Set to 0 to always spend it." },
    { type = "slider", key = "arcaneManaFloor",
      label = "Stop stacking below", min = 20, max = 90, step = 5,
      fmt = "%d%% mana",
      tooltip = "Each Arcane Blast stack costs more mana than the last. "
             .. "Below this, spend the stacks rather than adding to them." },
    { type = "slider", key = "evocationMana",
      label = "Evocate below", min = 5, max = 50, step = 5, fmt = "%d%% mana" },
}, spec)

--[[ NOTES ---------------------------------------------------------

  1. ARCANE BLAST STACKS are read from the buff on you (id 36032).
     If the stack count reads zero while you are clearly stacked,
     that ID is the first thing to check with /er verify.

  2. THE SOURCE also has "arcane_missiles if prev_gcd.6.arcane_blast",
     meaning spend after six Arcane Blasts even without a proc. That
     needs cast history the addon does not keep; the mana floor covers
     the same ground less precisely.

  3. MANA GEMS, potions and Replenishment are omitted. The source uses
     best_mana_potion and replenish_mana; both are consumables.

  4. AOE fires above two targets, matching the source. Arcane
     Explosion is off by default because it needs you in melee range
     and 3.3.5 gives no reliable distance check.

  5. NO OPENER. The source has none for Arcane - the rotation is the
     opener.
------------------------------------------------------------------]]
