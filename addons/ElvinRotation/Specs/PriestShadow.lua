--[[ ElvinRotation - Specs/PriestShadow.lua
     Shadow Priest, WotLK 3.3.5a.

     Priority translated from Hekili's Wrath build:
       Wrath/APLs/PriestShadow.simc  (single-target list)
       Wrath/Priest.lua              (flay_over_blast expression)

     v1 SCOPE: single target only. Cleave/Mind Sear and the multi-dot
     cycle_targets logic are deliberately omitted - see NOTES at bottom.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local spec = {
    name     = "Shadow Priest",
    class    = "PRIEST",
    tab      = 3,              -- Shadow talent tree
    school   = 6,              -- shadow, for GetSpellBonusDamage
    gcdProbe = 48125,          -- Shadow Word: Pain - no CD, safe GCD probe

    -- Haste reference: Vampiric Touch, 1.5s base, not modified by any
    -- Shadow talent. Comparing its live cast time to base gives total
    -- haste including raid buffs, which no 3.3.5 API exposes directly.
    hasteRefBase = 1.5,
}

--------------------------------------------------------------------
-- Auras
--------------------------------------------------------------------
spec.auras = {
    -- player buffs
    shadowform        = { id = 15473, type = "buff" },
    inner_fire        = { id = 48168, type = "buff" },
    inner_focus       = { id = 14751, type = "buff" },
    vampiric_embrace  = { id = 15286, type = "buff" },
    shadow_weaving    = { id = 15258, type = "buff" },
    replenishment     = { id = 57669, type = "buff" },
    dispersion        = { id = 47585, type = "buff" },

    -- our debuffs on target
    shadow_word_pain  = { id = 48125, type = "debuff", mine = true, duration = 18 },
    vampiric_touch    = { id = 48160, type = "debuff", mine = true, duration = 15 },
    devouring_plague  = { id = 48300, type = "debuff", mine = true, duration = 24 },
}

--------------------------------------------------------------------
-- Abilities
-- Mana costs are max-rank level-80 approximations; they only gate
-- "can I afford this", so small error is harmless. Talents such as
-- Shadow Focus reduce actual cost, making us conservative.
--------------------------------------------------------------------
spec.abilities = {
    -- cd / applies / appliesFor drive FORWARD PROJECTION only.
    -- Live cooldowns still come from GetSpellCooldown; observedCD
    -- (captured in State.lua) overrides cd once seen, so talented
    -- reductions like Improved Mind Blast self-calibrate.
    mind_blast = {
        key = "mind_blast", id = 48127, cost = 682,
        castTime = 1.5, harmful = true, cd = 8,
    },
    mind_flay = {
        key = "mind_flay", id = 48156, cost = 361,
        channel = true, channelTime = 3, harmful = true,
    },
    mind_sear = {
        key = "mind_sear", id = 53023, cost = 1041,
        channel = true, channelTime = 5, harmful = true,
    },
    shadow_word_pain = {
        key = "shadow_word_pain", id = 48125, cost = 575,
        castTime = 0, harmful = true,
        applies = "shadow_word_pain", appliesFor = 18,
    },
    vampiric_touch = {
        key = "vampiric_touch", id = 48160, cost = 678,
        castTime = 1.5, harmful = true,
        applies = "vampiric_touch", appliesFor = 15,
    },
    devouring_plague = {
        key = "devouring_plague", id = 48300, cost = 819,
        castTime = 0, harmful = true, castableMoving = true,
        applies = "devouring_plague", appliesFor = 24,
    },
    shadow_word_death = {
        key = "shadow_word_death", id = 48158, cost = 468,
        castTime = 0, harmful = true, castableMoving = true, cd = 12,
    },
    shadowfiend = {
        key = "shadowfiend", id = 34433, cost = 663,
        castTime = 0, harmful = true, castableMoving = true, cd = 300,
        majorCD = true, minTTD = 20, cdLabel = "Shadowfiend",
    },
    inner_focus = {
        key = "inner_focus", id = 14751, cost = 0,
        castTime = 0, castableMoving = true, cd = 180,
        applies = "inner_focus", appliesTo = "buff", appliesFor = 30,
    },
    inner_fire = {
        key = "inner_fire", id = 48168, cost = 141,
        castTime = 0, castableMoving = true,
        applies = "inner_fire", appliesTo = "buff", appliesFor = 600,
    },
    vampiric_embrace = {
        key = "vampiric_embrace", id = 15286, cost = 158,
        castTime = 0, harmful = true, castableMoving = true,
        applies = "vampiric_embrace", appliesTo = "buff", appliesFor = 1800,
    },
    shadowform = {
        key = "shadowform", id = 15473, cost = 0,
        castTime = 0, castableMoving = true,
        applies = "shadowform", appliesTo = "buff", appliesFor = 3600,
    },
    dispersion = {
        key = "dispersion", id = 47585, cost = 0,
        castTime = 0, castableMoving = true, cd = 180,
    },
}

--------------------------------------------------------------------
-- Rank resolution.
--
-- WotLK spells have ranks; modern WoW dropped them entirely, so Hekili
-- never has to deal with this. Two consequences on 3.3.5:
--
--   1. GetSpellBookItemName does NOT exist (added 4.0.1). The 3.3.5
--      equivalent is GetSpellName(index, bookType).
--
--   2. GetSpellCooldown / IsUsableSpell are unreliable when passed a
--      global spell ID on this client - they expect a NAME or a
--      spellbook index. Querying by name is also self-correcting:
--      it resolves to your highest known rank automatically.
--
-- So: we keep global IDs as the canonical "which spell do I mean",
-- but resolve a NAME for each one at load and query by name at runtime.
--------------------------------------------------------------------
function spec.ResolveRanks()
    -- name for each ability, from its canonical global ID
    for _, ab in pairs(spec.abilities) do
        ab.name = GetSpellInfo(ab.id)
    end

    -- name for each aura, so aura matching survives rank differences
    for _, def in pairs(spec.auras) do
        def.name = GetSpellInfo(def.id)
    end

    -- Walk the spellbook to find the highest known rank ID for each
    -- ability. Used for icon display and GetSpellInfo cast times.
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
            if id then
                -- spellbook is ordered low->high rank, so the last
                -- match wins and we end on the highest known rank
                for _, ab in ipairs(entries) do
                    ab.id = id
                end
            end
        end
        i = i + 1
    end

    -- gcd probe and haste reference must both be names on this client
    spec.gcdProbeName  = spec.abilities.shadow_word_pain.name
    spec.hasteRefName  = spec.abilities.vampiric_touch.name
end

--------------------------------------------------------------------
-- Derived values
--------------------------------------------------------------------
local function hasteMult(state)
    return 1 + (state.haste / 100)
end

function spec.UpdateExtra(state)
    local hm = hasteMult(state)

    -- Mind Flay: 3 ticks over 3s base, haste-scaled in WotLK.
    state.mf_duration  = 3 / hm
    state.mf_tick_time = 1 / hm

    state.mb_cast_time = 1.5 / hm
    state.vt_cast_time = 1.5 / hm

    state.execute_phase = state.targetHealthPct < 20
end

--------------------------------------------------------------------
-- flay_over_blast
-- Direct port of Hekili's Wrath/Priest.lua StateExpr. Decides whether
-- continuing Mind Flay beats clipping for Mind Blast, as a function of
-- spellpower, haste and latency ("Linelo maths").
--
-- PORT BUG FIXED: the original uses select(4, GetNetStats()), which is
-- nil on 3.3.5 (only 3 return values before 4.0.1). That would make
-- every latency term nil and error the whole expression. We use
-- Compat.Latency(), which reads index 3.
--------------------------------------------------------------------
local function flay_over_blast(state)
    local sp = state.spellPower or 0

    -- state.haste is already derived from VT cast time vs 1.5s base
    -- (see Compat.SpellHaste) - the same trick the original used
    -- inline. Single source of truth now.
    local currHaste = state.haste or 0

    if state.setBonus.tier10_4pc then
        if (currHaste > 102.68 and sp > 1500)
        or (sp > 5493.3 and currHaste < 50)
        or (sp > 5.0219e-04*currHaste^4 - 1.7950e-01*currHaste^3
                + 2.4578e+01*currHaste^2 - 1.5651e+03*currHaste + 4.1580e+04) then
            return false
        end
    else
        local lat = state.latency        -- seconds, from Compat.Latency()
        if sp >= (-1.0038e-02*lat^2 + 1.7241e-03*lat + 1.1564e-04)*currHaste^4
               + ( 4.928100*lat^2 - 0.908961*lat - 0.063893)*currHaste^3
               + (-878.800*lat^2  + 177.068*lat  + 13.641)*currHaste^2
               + ( 6.6990e+04*lat^2 - 1.5253e+04*lat - 1.3489e+03)*currHaste
               + (-1.8099e+06*lat^2 + 5.0044e+05*lat + 5.3978e+04) then
            return false
        end
    end

    return true
end

--------------------------------------------------------------------
-- Priority lists
--------------------------------------------------------------------
spec.lists = {}

-- Out of combat / setup
spec.lists.precombat = {
    { key = "shadowform",       when = function(s) return not s.buff.shadowform.up end },
    { key = "inner_fire",       when = function(s) return not s.buff.inner_fire.up end },
    { key = "vampiric_embrace", when = function(s) return not s.buff.vampiric_embrace.up end },
}

-- Single target. Order matches PriestShadow.simc actions.single
spec.lists.single = {

    -- Refresh DP if the fight is ending, or if moving with no DP up
    { key = "devouring_plague", when = function(s)
        return s.ttd <= s.mf_duration
            or (s.moving and s.dot.devouring_plague.remains <= 0)
    end },

    -- Inner Focus'd flay, or a tight SW:P clip window
    { key = "mind_flay", when = function(s)
        return s.buff.inner_focus.up
            or (s.dot.shadow_word_pain.remains < 1.5
                and s.dot.shadow_word_pain.remains >= s.mf_tick_time + s.latency)
    end },

    -- SHADOWFIEND
    -- The .simc has plain "shadowfiend,if=time_to_die>0", i.e. on
    -- cooldown. That is a sim assumption: the robot never runs dry, so
    -- it treats the fiend as pure damage. In practice you hold it until
    -- mana actually needs the return. Threshold is a setting.
    { key = "shadowfiend", when = function(s)
        return s.inCombat
           and s.ttd > 0
           and s.manaPct <= (ER:Setting("shadowfiendMana") or 50)
    end },

    -- SW:P only once Shadow Weaving is stacked, so the DoT snapshots it
    { key = "shadow_word_pain", when = function(s)
        if s.dot.shadow_word_pain.up then return false end
        local sw = s.buff.shadow_weaving.stack
        return (sw == 5 and s.ttd >= 75) or (sw >= 3 and s.ttd < 75)
    end },

    { key = "vampiric_touch", when = function(s)
        return s.dot.vampiric_touch.remains + s.latency < s.vt_cast_time
           and s.ttd >= 3
    end },

    { key = "devouring_plague", when = function(s)
        return s.dot.devouring_plague.remains <= 0
    end },

    -- MIND BLAST
    -- Mode is a setting, because the imported polynomial does not
    -- discriminate at 3.3.5 gear levels - see the MIND BLAST note at
    -- the bottom of this file. /er mb auto|always|never
    { key = "mind_blast", when = function(s)
        if s.ttd < s.mb_cast_time then return false end
        local mode = ER:Setting("mindBlast")
        if mode == "never"  then return false end
        if mode == "always" then return true end
        return flay_over_blast(s) or s.buff.replenishment.remains < 3
    end },

    { key = "inner_focus", when = function(s)
        return s.buff.shadow_weaving.stack == 5
    end },

    { key = "inner_fire", when = function(s)
        return not s.buff.inner_fire.up and s.ttd >= 10
    end },

    { key = "vampiric_embrace", when = function(s)
        return not s.buff.vampiric_embrace.up and s.ttd >= 10
    end },

    -- Filler
    { key = "mind_flay", when = function(s) return not s.moving end },

    -- Movement fallbacks
    { key = "shadow_word_death", when = function(s) return s.moving end },
    { key = "devouring_plague",  when = function(s) return s.moving end },

    { key = "dispersion", when = function(s) return s.manaPct <= 60 end },
}

-- Multi-target. The source cleave list multi-dots with cycle_targets,
-- which 3.3.5 cannot express; this is the single-target priority with
-- Mind Sear as the filler instead of Mind Flay.
spec.lists.aoe = {
    { key = "devouring_plague", when = function(s)
        return s.dot.devouring_plague.remains <= 0
    end },
    { key = "vampiric_touch", when = function(s)
        return s.dot.vampiric_touch.remains + s.latency < s.vt_cast_time
    end },
    { key = "shadow_word_pain", when = function(s)
        return not s.dot.shadow_word_pain.up and s.buff.shadow_weaving.stack >= 3
    end },
    { key = "mind_sear", when = function(s) return not s.moving end },
    { key = "shadow_word_death", when = function(s) return s.moving end },
}

spec.lists.default = {
    { runList = "precombat", terminal = false,
      when = function(s) return not s.inCombat end },
    { runList = "aoe", terminal = true,
      when = function(s) return (s.activeEnemies or 1) > 1 end },
    { runList = "single", terminal = true,
      when = function(s) return true end },
}

--------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------
function spec.IsActive()
    local _, class = UnitClass("player")
    if class ~= "PRIEST" then return false end
    local t1, t2, t3 = C.TalentPoints()
    return t3 > t1 and t3 > t2      -- Shadow is tab 3
end

ER:RegisterSpec(spec)

-- Options shown under Rotation > Priest > Shadow.
ER:RegisterSpecOptions("PRIEST", "shadow", "Priest", "Shadow", {
    { type = "slider", key = "shadowfiendMana",
      label = "Shadowfiend at mana %", min = 0, max = 100, step = 5, fmt = "%d%%" },
    { type = "check",  key = "mindBlast",
      label = "Use Mind Blast", onValue = "always", offValue = "never",
      tooltip = "Off by default. The imported Mind Blast vs Mind Flay "
             .. "formula produces thresholds far above any 3.3.5 "
             .. "spellpower, so it always answered yes." },
}, spec)

--[[ NOTES / DELIBERATE OMISSIONS ---------------------------------

  1. CLEAVE. The .simc cleave list uses cycle_targets with
     max_cycle_targets=7 for multi-dotting. 3.3.5 has no reliable way
     to enumerate nameplates or scan arbitrary units, so multi-dot
     tracking needs a GUID-keyed combat-log cache. Real work; not v1.

  2. WAIT ACTIONS. Two `wait` entries (pooling for DP tick and VT
     refresh during Mind Flay) are omitted. They are sub-GCD
     optimisations worth maybe a fraction of a percent.

  3. CHANNEL CLIPPING. `interrupt_if=!buff.inner_focus.up&ticks>=2`
     on Mind Flay is not implemented. We recommend the next ability
     but do not tell you WHEN to clip the channel. This is the single
     biggest remaining accuracy gap for Shadow and the most valuable
     next feature. It needs tick counting off the combat log
     (SPELL_PERIODIC_DAMAGE from Mind Flay on our GUID).

  4. TIER BONUSES. state.setBonus.tier10_4pc is never populated, so
     flay_over_blast always takes the non-4pc branch. Wire this up by
     scanning equipped item IDs if you raid in T10.

  5. MIND BLAST / flay_over_blast. The imported polynomial compares
     spellpower against a threshold that, at 3.3.5 gear, is never
     reached - measured thresholds run 85,923 SP at 0% haste down to
     7,629 SP at 80% haste, against a realistic ceiling of roughly
     2,400 SP. So it returns "use Mind Blast" unconditionally on this
     client and never actually discriminates. It was presumably fitted
     against Wrath Classic tuning or different input units.
     Hence the explicit mode setting. Default is "auto" (polynomial,
     i.e. always). Set "never" to drop Mind Blast from the rotation.

  6. SHADOWFORM is intentionally not in the combat list. The .simc
     comments note that having it in-rotation "bugs out".
------------------------------------------------------------------]]
