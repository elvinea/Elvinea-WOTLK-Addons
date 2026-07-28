--[[ ElvinRotation - Engine.lua
     Priority evaluator + forward projection.

     Priorities are plain Lua predicates hand-translated from
     PriestShadow.simc rather than parsed at runtime. See the spec file.
--]]

local ER = _G.ElvinRotation

ER.queue     = {}
ER.lastError = nil

--------------------------------------------------------------------
-- Usability
--------------------------------------------------------------------
local function isUsable(ab, state, virtual)
    if not ab.name then return false end

    -- On a projected step we can't ask the client, so trust the
    -- simulated cooldown instead.
    if not virtual then
        if not IsUsableSpell(ab.name) then return false end
    end

    local cd = state.cooldown[ab.key]
    if cd and cd.remains > (state.gcd + state.latency) then return false end

    -- rune / runic power cost
    if ab.runes and state.runes then
        if not ER.Compat.RunesAvailable(state.runes, ab.runes) then return false end
    end
    if ab.rp and (state.runicPower or 0) < ab.rp then return false end

    if ab.harmful and not state.targetExists then return false end

    -- major cooldown gating
    if ab.majorCD then
        if not ER:CooldownEnabled(ab.key) then return false end
        if ab.minTTD and (state.ttd or 0) < ab.minTTD then return false end
    end

    if ab.castTime and ab.castTime > 0 and state.moving and not ab.castableMoving then
        return false
    end

    return true
end

--------------------------------------------------------------------
-- Evaluate a priority list
--------------------------------------------------------------------
local function evaluate(list, spec, state, depth, virtual)
    depth = depth or 0
    if depth > 5 then return nil end

    for _, entry in ipairs(list) do

        if entry.runList then
            local ok = true
            if entry.when then
                local success, result = pcall(entry.when, state)
                ok = success and result and true or false
            end
            if ok then
                local sub = spec.lists[entry.runList]
                if sub then
                    local rec = evaluate(sub, spec, state, depth + 1, virtual)
                    if rec then return rec end
                    if entry.terminal then return nil end
                end
            end

        else
            local ab = spec.abilities[entry.key]
            if ab then
                local passed = true

                -- Opener entries: "cast this until it has been cast N
                -- times this fight". Cast counts come from the combat
                -- log and reset when combat starts.
                if entry.casts then
                    local done = (state.castCount and state.castCount[entry.key]) or 0
                    if done >= entry.casts then passed = false end
                end
                if entry.when then
                    local ok, result = pcall(entry.when, state)
                    if not ok then
                        ER.lastError = entry.key .. ": " .. tostring(result)
                        passed = false
                    else
                        passed = result and true or false
                    end
                end
                if passed and isUsable(ab, state, virtual) then
                    return ab
                end
            end
        end
    end

    return nil
end

--------------------------------------------------------------------
-- FORWARD PROJECTION
--
-- To show "and then this", you have to pretend you cast the first
-- recommendation and re-evaluate. Hekili does this with a full
-- resource/aura simulation (State.lua, 7,447 lines). This is a much
-- cheaper approximation:
--
--   advance the clock by the ability's cast time or the GCD,
--   decay every aura and cooldown by that amount,
--   apply what the ability does (its DoT, its own cooldown),
--   re-run the priority list.
--
-- ACCURACY WARNING: this ignores procs, latency drift, target death,
-- Shadow Weaving stacking and anything reactive. Step 1 is reliable;
-- steps 2+ are a plan, not a promise, and will change as the fight
-- does. That is true of Hekili too, just less so.
--------------------------------------------------------------------
local function cloneState(s)
    local v = {}
    for k, val in pairs(s) do
        if type(val) ~= "table" then v[k] = val end
    end

    v.buff, v.debuff, v.cooldown = {}, {}, {}
    for k, a in pairs(s.buff) do
        v.buff[k] = { up = a.up, down = a.down, remains = a.remains,
                      stack = a.stack, stacks = a.stacks, expires = a.expires }
    end
    for k, a in pairs(s.debuff) do
        v.debuff[k] = { up = a.up, down = a.down, remains = a.remains,
                        stack = a.stack, stacks = a.stacks, expires = a.expires }
    end
    for k, c in pairs(s.cooldown) do
        v.cooldown[k] = { remains = c.remains, up = c.up, ready = c.ready }
    end
    v.dot = v.debuff
    v.talent, v.glyph, v.setBonus = s.talent, s.glyph, s.setBonus

    if s.runes then
        v.runes = {}
        for i, r in ipairs(s.runes) do
            v.runes[i] = { slot = r.slot, type = r.type,
                           ready = r.ready, remains = r.remains }
        end
        v.rune = { blood = s.rune.blood, frost = s.rune.frost,
                   unholy = s.rune.unholy, death = s.rune.death }
    end
    return v
end

local function decay(tbl, dt)
    for _, a in pairs(tbl) do
        a.remains = a.remains - dt
        if a.remains <= 0 then
            a.remains, a.up, a.down = 0, false, true
            a.stack, a.stacks = 0, 0
        end
    end
end

local function advance(v, ab, spec)
    local hasteMod = 1 + (v.haste or 0) / 100
    local gcd = math.max(1.0, 1.5 / hasteMod)
    local dt  = gcd

    if ab.castTime and ab.castTime > 0 then
        dt = math.max(gcd, ab.castTime / hasteMod)
    elseif ab.channel and ab.channelTime then
        dt = ab.channelTime / hasteMod
    end

    decay(v.buff, dt)
    decay(v.debuff, dt)
    for _, c in pairs(v.cooldown) do
        c.remains = math.max(0, c.remains - dt)
        c.up, c.ready = c.remains == 0, c.remains == 0
    end

    if v.runes then
        for _, r in ipairs(v.runes) do
            if not r.ready then
                r.remains = r.remains - dt
                if r.remains <= 0 then r.ready, r.remains = true, 0 end
            end
        end
    end

    -- what the ability does
    if ab.applies then
        local target = (ab.appliesTo == "buff") and v.buff or v.debuff
        local a = target[ab.applies] or {}
        a.remains = ab.appliesFor or 0
        a.up, a.down = true, false
        a.stack = math.max(1, a.stack or 1)
        a.stacks = a.stack
        target[ab.applies] = a
    end

    local cd = ab.observedCD or ab.cd
    if cd and cd > 0 then
        v.cooldown[ab.key] = { remains = cd, up = false, ready = false }
    end

    if ab.cost then v.mana = math.max(0, (v.mana or 0) - ab.cost) end

    -- Spend runes in the projection so the next step sees them gone.
    if ab.runes and v.runes then
        local used = {}
        local function take(kind)
            for i, r in ipairs(v.runes) do
                if not used[i] and r.ready and r.type == kind then used[i] = true return r end
            end
            for i, r in ipairs(v.runes) do
                if not used[i] and r.ready and r.type == "death" then used[i] = true return r end
            end
        end
        for _, kind in ipairs({ "blood", "frost", "unholy" }) do
            for _ = 1, (ab.runes[kind] or 0) do
                local r = take(kind)
                if r then r.ready, r.remains = false, 10 / hasteMod end
            end
        end
        v.rune = { blood = 0, frost = 0, unholy = 0, death = 0 }
        for _, r in ipairs(v.runes) do
            if r.ready then v.rune[r.type] = v.rune[r.type] + 1 end
        end
    end

    if ab.rp then v.runicPower = math.max(0, (v.runicPower or 0) - ab.rp) end
    if ab.generatesRP then
        v.runicPower = math.min(v.runicPowerMax or 130,
                                (v.runicPower or 0) + ab.generatesRP)
    end
    v.manaPct = (v.manaMax or 0) > 0 and (v.mana / v.manaMax * 100) or 0
    v.now = (v.now or 0) + dt
    v.gcd = 0

    v.lastCast = ab.key
    if spec.UpdateExtra then spec.UpdateExtra(v) end
    return dt
end

--------------------------------------------------------------------
-- Public: build a queue of N recommendations
--------------------------------------------------------------------
function ER:Recommend(count)
    local spec = self.activeSpec
    if not spec then return {} end
    count = count or (ElvinRotationDB and ElvinRotationDB.queueSize) or 3

    local state = self.state

    -- Mid-cast, the current suggestion is already committed.
    if state.casting and (state.castEnds - state.now) > state.latency then
        return self.queue
    end

    local out = {}

    local first = evaluate(spec.lists.default, spec, state, 0, false)
    if not first then self.queue = out return out end
    out[1] = first

    if count > 1 then
        local v = cloneState(state)
        advance(v, first, spec)
        for i = 2, count do
            local nxt = evaluate(spec.lists.default, spec, v, 0, true)
            if not nxt then break end
            out[i] = nxt
            advance(v, nxt, spec)
        end
    end

    self.queue = out
    return out
end

--------------------------------------------------------------------
-- Update loop. Throttled: this is the biggest performance lever.
--------------------------------------------------------------------
local accum = 0
local UPDATE_INTERVAL = 0.1

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(self, elapsed)
    accum = accum + elapsed
    if accum < UPDATE_INTERVAL then return end
    accum = 0

    if not ER.enabled or not ER.activeSpec then return end

    ER:UpdateState()
    ER:UpdateDisplay(ER:Recommend())
end)

function ER:SetUpdateInterval(seconds)
    UPDATE_INTERVAL = math.max(0.05, math.min(0.5, seconds or 0.1))
end
