--[[ ElvinRotation - State.lua
     Minimal state model.

     Hekili's State.lua is 7,447 lines because it simulates the game
     forward several GCDs. This does NOT do that - it snapshots the
     present moment only. That is enough for a correct next-ability
     recommendation, which is the whole v1 goal.

     Forward projection is the upgrade path, not the starting point.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local state = {
    -- resources
    mana = 0, manaMax = 1, manaPct = 0,

    -- timing
    now = 0, gcd = 0, latency = 0, haste = 0, spellPower = 0,

    -- casting
    casting = nil, castEnds = 0,
    channeling = nil, channelEnds = 0,

    -- context
    inCombat = false, moving = false,
    targetExists = false, targetHealthPct = 100, ttd = 300,

    buff = {}, debuff = {}, cooldown = {}, talent = {}, glyph = {}, setBonus = {},
}
ER.state = state

--------------------------------------------------------------------
-- Aura wrapper objects. Accessing state.buff.shadowform.up etc.
--------------------------------------------------------------------
local function emptyAura()
    return { up = false, down = true, remains = 0, stack = 0, stacks = 0, expires = 0 }
end

local function readAura(unit, def, isDebuff, mineOnly, key)
    local count, expires, duration
    if isDebuff then
        count, expires, duration = C.FindDebuff(unit, def.name, def.id, mineOnly)

        -- FALLBACK: believe the combat log.
        --
        -- If UnitDebuff cannot see a debuff we KNOW we applied - wrong
        -- rank, a caster the client will not name, a server quirk -
        -- then trusting the scan means the addon decides the disease is
        -- missing and tells you to reapply it forever. The combat log
        -- already tells us we landed it and when, so use that.
        if not count and key and unit == "target" and UnitGUID then
            local guid = UnitGUID("target")
            local seen = guid and ER.dotTargets and ER.dotTargets[key]
                         and ER.dotTargets[key][guid]
            if seen and seen > state.now then
                return {
                    up = true, down = false,
                    remains = seen - state.now,
                    stack = 1, stacks = 1, expires = seen,
                    duration = def.duration or 15,
                    inferred = true,
                }
            end
        end
    else
        count, expires, duration = C.FindBuff(unit, def.name, def.id)
    end

    if not count then return emptyAura() end

    local remains = expires - state.now
    if expires == 0 then remains = 3600 end     -- permanent aura
    if remains < 0 then remains = 0 end

    return {
        up = true, down = false,
        remains = remains,
        stack = count, stacks = count,
        expires = expires,
        duration = duration or 0,
    }
end

--------------------------------------------------------------------
-- Movement detection.
--
-- GetUnitSpeed EXISTS in 3.3.5 and returns current speed directly.
-- Use it. An earlier version of this file diffed GetPlayerMapPosition
-- instead, which was wrong three ways:
--   - it reports 0,0 inside instances, i.e. in raids
--   - map coords are coarse and lag behind actual movement
--   - the first call always compared against 0,0 and so always
--     reported "moving", which fired the movement branch of the
--     priority list on every login
--------------------------------------------------------------------
local lastMoveCheck, movingFlag = 0, false

local function updateMoving()
    if state.now - lastMoveCheck < 0.1 then return movingFlag end
    lastMoveCheck = state.now
    movingFlag = (GetUnitSpeed("player") or 0) > 0
    return movingFlag
end

--------------------------------------------------------------------
-- Time to die. Simple linear extrapolation from a rolling sample.
--------------------------------------------------------------------
local ttdGUID, ttdSamples = nil, {}

local function updateTTD()
    if not UnitExists("target") or UnitIsDead("target") then
        state.ttd = 0
        return
    end

    local guid = UnitGUID("target")
    if guid ~= ttdGUID then
        ttdGUID, ttdSamples = guid, {}
    end

    local hp = UnitHealth("target")
    local hpMax = UnitHealthMax("target")
    if hpMax == 0 then state.ttd = 300 return end

    table.insert(ttdSamples, { t = state.now, hp = hp })
    while #ttdSamples > 20 do table.remove(ttdSamples, 1) end

    -- Training dummies never die; the APL special-cases this.
    if UnitName("target") and string.find(UnitName("target"), "Dummy") then
        state.ttd = 300
        return
    end

    if #ttdSamples < 2 then state.ttd = 300 return end

    local first, last = ttdSamples[1], ttdSamples[#ttdSamples]
    local dt, dhp = last.t - first.t, first.hp - last.hp

    if dt <= 0 or dhp <= 0 then
        state.ttd = 300
    else
        state.ttd = math.min(300, (last.hp / (dhp / dt)))
    end
end

--------------------------------------------------------------------
-- Main refresh
--------------------------------------------------------------------
function ER:UpdateState()
    local spec = ER.activeSpec
    if not spec then return end

    state.now      = GetTime()
    state.latency  = C.Latency()
    state.inCombat = UnitAffectingCombat("player")
    state.moving   = updateMoving()

    -- Generic power. A spec declares powerType (0 mana, 1 rage,
    -- 3 energy, 6 runic power) and gets it as state.power, plus a
    -- readable alias. Saves every new spec inventing its own.
    if spec.powerType then
        state.power    = UnitPower("player", spec.powerType) or 0
        state.powerMax = UnitPowerMax("player", spec.powerType) or 100
        state.powerPct = state.powerMax > 0
                         and (state.power / state.powerMax * 100) or 0
        if spec.powerType == 3 then state.energy = state.power end
        if spec.powerType == 1 then state.rage   = state.power end
    end

    -- Combo points live on the TARGET in 3.3.5, not on the player.
    if spec.usesComboPoints then
        state.comboPoints = (GetComboPoints and GetComboPoints("player", "target")) or 0
    end

    -- resources
    state.mana    = UnitMana("player")
    state.manaMax = UnitManaMax("player")
    state.manaPct = state.manaMax > 0 and (state.mana / state.manaMax * 100) or 0

    -- Runes and runic power, only for specs that declare them. Keeps
    -- the cost of this out of every other spec's update loop.
    if spec.usesRunes then
        state.runes = C.ReadRunes(state.now)

        local counts = { blood = 0, frost = 0, unholy = 0, death = 0 }
        for _, r in ipairs(state.runes) do
            if r.ready then counts[r.type] = counts[r.type] + 1 end
        end
        state.rune = counts
        state.runesReady = counts.blood + counts.frost + counts.unholy + counts.death

        -- SPELL_POWER_RUNIC_POWER is 6 on 3.3.5
        state.runicPower = UnitPower("player", 6) or 0
        state.runicPowerMax = UnitPowerMax("player", 6) or 130
    end

    -- caster stats
    -- haste derived from a reference spell's cast time (see Compat)
    state.haste = C.SpellHaste(spec.hasteRefName, spec.hasteRefBase)
    state.spellPower = GetSpellBonusDamage(spec.school or 6) or 0

    -- gcd
    state.gcd = C.GCDRemaining(spec.gcdProbeName)

    -- cast / channel
    -- startTime is index 5, endTime index 6, both in milliseconds.
    -- The start is needed as well as the end so a cast swipe can be
    -- drawn over the whole cast rather than guessed at.
    local castName, _, _, _, castStart, castEnd = UnitCastingInfo("player")
    state.casting    = castName
    state.castBegan  = castStart and (castStart / 1000) or 0
    state.castEnds   = castEnd and (castEnd / 1000) or 0

    local chanName, _, _, _, chanStart, chanEnd = UnitChannelInfo("player")
    state.channeling   = chanName
    state.channelBegan = chanStart and (chanStart / 1000) or 0
    state.channelEnds  = chanEnd and (chanEnd / 1000) or 0

    -- target
    state.targetExists = UnitExists("target") and UnitCanAttack("player", "target")
                         and not UnitIsDead("target")
    if state.targetExists then
        local hpMax = UnitHealthMax("target")
        state.targetHealthPct = hpMax > 0 and (UnitHealth("target") / hpMax * 100) or 100
    else
        state.targetHealthPct = 100
    end
    updateTTD()

    -- auras
    for key, def in pairs(spec.auras) do
        if def.type == "debuff" then
            state.debuff[key] = readAura("target", def, true, def.mine ~= false, key)
        else
            state.buff[key] = readAura("player", def, false)
        end
    end
    -- DoTs are just our debuffs; alias for APL readability
    state.dot = state.debuff

    -- cooldowns
    for key, ab in pairs(spec.abilities) do
        -- by NAME, not ID - see ResolveRanks comment in the spec file
        local start, duration, enabled = GetSpellCooldown(ab.name or ab.id)
        local remains = 0
        if start and start > 0 and duration and duration > 1.5 then
            remains = start + duration - state.now
            if remains < 0 then remains = 0 end
            -- Self-calibrating: remember the real duration so forward
            -- projection uses the talented value, not the base one.
            ab.observedCD = duration
        end
        state.cooldown[key] = {
            remains = remains,
            up = remains == 0,
            ready = remains == 0,
        }
    end

    -- talents
    if spec.talents then
        for key, t in pairs(spec.talents) do
            state.talent[key] = { rank = C.TalentRank(t[1], t[2]) }
            state.talent[key].enabled = state.talent[key].rank > 0
        end
    end

    state.pet = C.HasPet()

    -- Presences are stances. Expose them as plain booleans so a
    -- priority never has to care which mechanism backs them.
    if spec.usesPresence then
        local pname = C.ActivePresence()
        state.presenceName = pname
        state.presence = pname and string.lower(string.gsub(pname, "%s*Presence", ""))
                         or nil
    end
    state.activeEnemies = ER:ActiveEnemies()

    -- how many enemies carry each of our debuffs
    state.activeDot = state.activeDot or {}
    for key, def in pairs(spec.auras) do
        if def.type == "debuff" then
            state.activeDot[key] = ER:ActiveDots(key)
        end
    end
    state.combatTime = state.inCombat and (state.now - (ER.combatStart or 0)) or 0
    state.castCount = ER.castCount
    state.lastCast = ER.lastCast

    -- Seconds since each ability was last cast. Lets a priority model
    -- an effect that has no trackable aura - Summon Gargoyle being the
    -- obvious one: the gargoyle is a pet, not a buff on you.
    state.sinceCast = state.sinceCast or {}
    for key in pairs(spec.abilities) do
        local t = ER.castTime[key]
        state.sinceCast[key] = t and (state.now - t) or 9999
    end
    if spec.UpdateExtra then spec.UpdateExtra(state) end
end

return state
