--[[ ElvinRotation - Core.lua
     Bootstrap, spec registry, queue display, slash commands.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

ER.specs   = {}
ER.enabled = true

-- Bump this with every release. Printed on load and via /er version so
-- "did the update actually install?" is a one-second question.
ER.VERSION = "5.0"

local DB_DEFAULTS = {
    dbVersion = 4,
    x = 0, y = -150, point = "CENTER", relPoint = "CENTER",
    size = 56, locked = false,
    showKeybind = true, keybindSize = 12, queueSize = 3,
    showSwipe = true, showGcdText = false,
    displayMode = "combat",       -- "combat" | "always"
    cooldownsOff = false,
    aoeMode = "auto",         -- auto | single | aoe
    collapsed = {}, rolledUp = false, optWidth = 380,
    -- DEFAULT IS "never": the imported flay_over_blast polynomial does
    -- not discriminate at 3.3.5 spellpower levels (see the MIND BLAST
    -- note in Specs/PriestShadow.lua), so "auto" behaves as "always".
    -- Defaulting to auto shipped a rotation that used Mind Blast
    -- unconditionally. /er mb auto|always|never to change.
    settings = {
        mindBlast = "never",
        shadowfiendMana = 50,     -- cast Shadowfiend at or below this mana %
        useCooldowns = true,
        kmFrostStrike = false,    -- not in the source priority; opt in
        howlingBlastRimeOnly = true,
        useBoneShield = true,
        keepGhoul = true,
        diseaseRefresh = 3,
        maintainExpose = false,
        rogueAoeThreshold = 5,
        useConsecration = true,
        useHolyWrath = false,
        aoeSealOfCommand = false,
        retManaFloor = 20,
        judgement = "wisdom",
        glyphLifeTap = false,
        useShadowflame = false,
        lifeTapMana = 30,
        seedThreshold = 3,
        arcaneExplosionInMelee = false,
        arcaneManaFloor = 70,
        evocationMana = 30,
        glyphTyphoon = false,
        maintainFaerieFire = false,
        heroicStrikeRage = 60,
        rendRefresh = 3,
        maintainHuntersMark = true,
        useExplosiveTrap = false,
        useMagmaTotem = true,
        maelstromFiller = 5,
        shamanRageMana = 25,
        glyphFrostfire = false,
        fireMeleeAoe = false,
        fireEvocationMana = 30,
        conflagrateFreely = false,
        destroLifeTapMana = 20,
        eternalWater = false,
        frostMeleeAoe = false,
        frostEvocationMana = 30,
        manageViper = true,
        viperMana = 25,
        useImmolationAura = false,
        demoLifeTapMana = 20,
        furyHeroicStrikeRage = 50,
        useFerociousBite = false, feralFaerieFire = false,
        combatRupture = false, bladeFlurrySingle = false,
        subUseBackstab = false,
        useWaterShield = false, lavaBurstAlways = false,
        eleEarthShock = false, useThunderstorm = false, eleManaFloor = 20,
        managePresence = true,
        presenceLead = 3,
        useOpener = true,
        openerWindow = 40,        -- these sequences run ~15-17 globals
        frostPresence = "blood",  -- blood | unholy. never frost: that is the tank presence
        pestilenceWindow = 0,     -- 0 = follow presence
    },
}

--------------------------------------------------------------------
function ER:Debug(msg)
    if self.debugMode then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffER|r " .. tostring(msg))
    end
end

function ER:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8080ffElvinRotation|r: " .. tostring(msg))
end

function ER:RegisterSpec(spec) table.insert(self.specs, spec) end

--------------------------------------------------------------------
-- COOLDOWN CONTROL
--
-- An ability marked majorCD in a spec file is gated three ways:
--   1. the global toggle          (/er cd, or the options checkbox)
--   2. its own per-ability toggle (auto-generated in the options)
--   3. a minimum time-to-die      (do not open a 10 minute cooldown
--                                  on something about to fall over)
-- Nothing here knows about any particular spell, so a new spec gets
-- the whole mechanism by tagging an ability.
--------------------------------------------------------------------
-- How many distinct enemies have we damaged in the last few seconds?
local ENEMY_WINDOW = 5

function ER:ActiveEnemies()
    self.seenEnemies = self.seenEnemies or {}
    local mode = ElvinRotationDB and ElvinRotationDB.aoeMode or "auto"
    if mode == "single" then return 1 end
    if mode == "aoe"    then return 99 end

    local now, n = GetTime(), 0
    for guid, seen in pairs(self.seenEnemies) do
        if now - seen > ENEMY_WINDOW then
            self.seenEnemies[guid] = nil
        else
            n = n + 1
        end
    end
    return n > 0 and n or 1
end

-- How many enemies currently have this debuff of ours?
function ER:ActiveDots(key)
    local t = self.dotTargets[key]
    if not t then return 0 end
    local now, n = GetTime(), 0
    for guid, expiry in pairs(t) do
        if expiry < now then t[guid] = nil else n = n + 1 end
    end
    return n
end

function ER:CooldownsEnabled()
    local db = ElvinRotationDB
    return not (db and db.cooldownsOff)
end

function ER:CooldownEnabled(key)
    if not self:CooldownsEnabled() then return false end
    local db = ElvinRotationDB
    local v = db and db.settings and db.settings["cd_" .. key]
    return v ~= false
end

-- Spec settings, read by priority predicates.
function ER:Setting(key)
    local db = ElvinRotationDB
    if db and db.settings and db.settings[key] ~= nil then return db.settings[key] end
    return DB_DEFAULTS.settings[key]
end

--------------------------------------------------------------------
-- Display: icon 1 is the recommendation, 2..N are the projection.
-- Later icons are dimmer because they are less certain.
--------------------------------------------------------------------
local frame, slots = nil, {}

local function buildSlot(parent, index, size)
    local s = {}
    s.frame = CreateFrame("Frame", nil, parent)
    s.frame._slotIndex = index
    s.frame:SetWidth(size)
    s.frame:SetHeight(size)

    s.icon = s.frame:CreateTexture(nil, "ARTWORK")
    s.icon:SetAllPoints(s.frame)
    s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Standard action-button cooldown swipe: the icon darkens and the
    -- shadow sweeps round as it becomes available. Same widget the
    -- default bars use, so it looks and behaves identically.
    s.cd = CreateFrame("Cooldown", nil, s.frame, "CooldownFrameTemplate")
    s.cd:SetAllPoints(s.frame)

    -- keybind text, top-right like a real action button
    s.key = s.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    s.key:SetPoint("TOPRIGHT", s.frame, "TOPRIGHT", -1, -1)
    s.key:SetTextColor(1, 1, 1)
    local fontPath = GameFontNormalSmall:GetFont()
    s.key:SetFont(fontPath, ElvinRotationDB.keybindSize or 12, "OUTLINE")

    if index == 1 then
        s.border = s.frame:CreateTexture(nil, "OVERLAY")
        s.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        s.border:SetBlendMode("ADD")
        s.border:SetPoint("CENTER", s.frame, "CENTER", 0, 0)
        s.border:SetWidth(size * 1.6)
        s.border:SetHeight(size * 1.6)
        s.border:SetVertexColor(0.5, 0.3, 0.9)

        s.gcd = s.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        s.gcd:SetPoint("CENTER", s.frame, "CENTER", 0, 0)
    end

    return s
end

function ER:BuildDisplay()
    if frame then return end          -- already built
    local db = ElvinRotationDB
    local size = db.size

    frame = CreateFrame("Frame", "ElvinRotationFrame", UIParent)
    frame:SetWidth(size)
    frame:SetHeight(size)
    frame:SetPoint(db.point or "CENTER", UIParent,
                   db.relPoint or "CENTER", db.x, db.y)
    frame:SetMovable(true)
    frame:EnableMouse(not db.locked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- StopMovingOrSizing re-anchors the frame to whichever corner
        -- of the screen it ended up nearest, so GetPoint no longer
        -- returns CENTER/CENTER. Saving only x,y and re-applying them
        -- as CENTER offsets put the frame somewhere else entirely on
        -- the next rebuild - which is why changing icon size appeared
        -- to reset the position. Save the whole anchor.
        local point, _, relPoint, x, y = self:GetPoint()
        ElvinRotationDB.point    = point
        ElvinRotationDB.relPoint = relPoint
        ElvinRotationDB.x, ElvinRotationDB.y = x, y
    end)

    slots = {}
    for i = 1, 5 do
        local sz = (i == 1) and size or (size * 0.6)
        local s = buildSlot(frame, i, sz)
        if i == 1 then
            s.frame:SetPoint("LEFT", frame, "LEFT", 0, 0)
        else
            s.frame:SetPoint("LEFT", slots[i-1].frame, "RIGHT", 5, 0)
            -- The old ramp (0.85 - i*0.1) put icon 4 at 45% and icon 5
            -- at 35% opacity, faint enough to look like they were not
            -- being drawn at all.
            s.frame:SetAlpha(({ [2] = 0.85, [3] = 0.75,
                                [4] = 0.68, [5] = 0.62 })[i] or 0.6)
        end
        slots[i] = s
    end

    frame:Hide()
end

-- Apply the current size and font settings.
--
-- This used to tear down and recreate the frames. WoW cannot destroy a
-- frame, so every nudge of the size slider leaked five more of them and
-- re-anchored the parent from defaults - which is the other half of why
-- the position appeared to reset. Resize in place instead.
function ER:RebuildDisplay()
    if not frame then self:BuildDisplay() return end

    local db = ElvinRotationDB
    frame:SetWidth(db.size)
    frame:SetHeight(db.size)

    local fontPath = GameFontNormalSmall:GetFont()

    for i, s in ipairs(slots) do
        local sz = (i == 1) and db.size or (db.size * 0.6)
        s.frame:SetWidth(sz)
        s.frame:SetHeight(sz)
        if s.key then
            s.key:SetFont(fontPath, db.keybindSize or 12, "OUTLINE")
        end
        if s.border then
            s.border:SetWidth(sz * 1.6)
            s.border:SetHeight(sz * 1.6)
        end
    end
end

function ER:SetLocked(v)
    ElvinRotationDB.locked = v and true or false
    if frame then frame:EnableMouse(not ElvinRotationDB.locked) end
end

-- When will this ability actually be castable, and over what window?
-- Returns start, duration in the form CooldownFrame_SetTimer wants.
-- Whatever gates it - its own cooldown, runes, or just the global -
-- gets drawn the same way.
local function readyWindow(ab, state)
    -- 0. Mid-cast or mid-channel. Nothing else can start until this
    --    finishes, so that is the honest thing to show. Scaled over
    --    the whole cast, so the sweep tracks the cast bar.
    local now = GetTime()

    if state.casting and state.castEnds and state.castEnds > now then
        local began = (state.castBegan and state.castBegan > 0)
                      and state.castBegan or (state.castEnds - 1.5)
        local duration = state.castEnds - began
        if duration > 0 then return began, duration end
    end

    if state.channeling and state.channelEnds and state.channelEnds > now then
        local began = (state.channelBegan and state.channelBegan > 0)
                      and state.channelBegan or (state.channelEnds - 3)
        local duration = state.channelEnds - began
        if duration > 0 then return began, duration end
    end

    -- 1. real spell cooldown, straight from the client
    if ab.name then
        local start, duration = GetSpellCooldown(ab.name)
        if start and start > 0 and duration and duration > 1.5 then
            return start, duration
        end
    end

    -- 2. waiting on runes
    if ab.runes and state.runes then
        local remains, cdLen = ER.Compat.RunesReadyIn(state.runes, ab.runes)
        if remains and remains > 0 and remains < 9000 then
            cdLen = (cdLen and cdLen > 0) and cdLen or 10
            return GetTime() - (cdLen - remains), cdLen
        end
    end

    -- 3. just the global cooldown
    if (state.gcd or 0) > 0.05 then
        local g = 1.5
        return GetTime() - (g - state.gcd), g
    end

    return nil
end

function ER:UpdateDisplay(queue)
    if not frame then return end

    local db = ElvinRotationDB
    local alwaysShow = (db.displayMode == "always")
    local show = queue and queue[1]
                 and (self.state.inCombat or alwaysShow or self.debugMode)

    if not show then frame:Hide() return end
    frame:Show()

    local n = math.min(db.queueSize or 3, 5)

    for i = 1, 5 do
        local s = slots[i]
        local ab = (i <= n) and queue[i] or nil

        if ab then
            local _, _, icon = GetSpellInfo(ab.id)
            s.icon:SetTexture(icon or "")
            s.frame:Show()

            if db.showKeybind then
                s.key:SetText(C.Keybind(ab.name) or "")
            else
                s.key:SetText("")
            end

            if s.cd then
                if db.showSwipe ~= false then
                    local start, duration = readyWindow(ab, self.state)
                    if start then
                        CooldownFrame_SetTimer(s.cd, start, duration, 1)
                    else
                        CooldownFrame_SetTimer(s.cd, 0, 0, 0)
                    end
                else
                    CooldownFrame_SetTimer(s.cd, 0, 0, 0)
                end
            end
        else
            s.frame:Hide()
        end
    end

    -- Dim the border when major cooldowns are suppressed, so the state
    -- is visible at a glance rather than needing a slash command.
    if slots[1].border then
        if ER:CooldownsEnabled() then
            slots[1].border:SetVertexColor(0.5, 0.3, 0.9)
        else
            slots[1].border:SetVertexColor(0.45, 0.45, 0.45)
        end
    end

    -- Numeric GCD readout. Off by default now that the swipe conveys
    -- the same thing more legibly.
    if slots[1].gcd then
        if db.showGcdText and self.state.gcd > 0.1 then
            slots[1].gcd:SetText(string.format("%.1f", self.state.gcd))
        else
            slots[1].gcd:SetText("")
        end
    end
end

--------------------------------------------------------------------
-- Spec activation
--------------------------------------------------------------------
function ER:DetectSpec()
    -- Pick the spec whose TALENT TAB has the most points, rather than
    -- the first one whose IsActive returns true. Registration order was
    -- deciding ties, which is how a Frost DK priority could load for an
    -- Unholy character and start suggesting Frost Presence.
    local _, class = UnitClass("player")
    local t = { C.TalentPoints() }

    local best, bestPoints
    for _, spec in ipairs(self.specs) do
        if spec.class == class and spec.tab then
            local points = t[spec.tab] or 0
            if not bestPoints or points > bestPoints then
                best, bestPoints = spec, points
            end
        end
    end

    if best and (bestPoints or 0) > 0 then
        if self.activeSpec ~= best then
            if best.ResolveRanks then
                local ok, err = pcall(best.ResolveRanks)
                if not ok then
                    self:Print("|cffff5555rank resolution failed:|r " .. tostring(err))
                    return
                end
            end
            local missing = {}
            for key, ab in pairs(best.abilities) do
                if not ab.name then table.insert(missing, key) end
            end
            if #missing > 0 then
                self:Print("|cffffaa00unresolved spells:|r " .. table.concat(missing, ", "))
            end

            -- Catch IDs that resolve to the WRONG spell.
            for _, tbl in ipairs({ best.abilities, best.auras }) do
                for _, b in ipairs(C.CheckSpellIDs(tbl)) do
                    self:Print(string.format(
                        "|cffff5555WRONG SPELL ID|r  %s -> id %d is '%s'",
                        b.key, b.id, b.name))
                end
            end

            self.activeSpec = best
            self:Print(best.name .. " priority loaded.  (tab " .. best.tab
                       .. ", " .. bestPoints .. " points)")
        end
        return
    end

    for _, spec in ipairs(self.specs) do
        if spec.IsActive() then
            if self.activeSpec ~= spec then
                if spec.ResolveRanks then
                    local ok, err = pcall(spec.ResolveRanks)
                    if not ok then
                        self:Print("|cffff5555rank resolution failed:|r " .. tostring(err))
                        return
                    end
                end

                local missing = {}
                for key, ab in pairs(spec.abilities) do
                    if not ab.name then table.insert(missing, key) end
                end
                if #missing > 0 then
                    self:Print("|cffffaa00unresolved spells:|r " .. table.concat(missing, ", "))
                end

                self.activeSpec = spec
                self:Print(spec.name .. " priority loaded.")
            end
            return
        end
    end

    if self.activeSpec then
        self.activeSpec = nil
        if frame then frame:Hide() end
    end
end

--------------------------------------------------------------------
-- Last successful cast, from the combat log. Needed by priorities
-- that reference prev_gcd / prev_off_gcd - e.g. Frost DK uses Blood
-- Tap immediately after Unbreakable Armor.
--------------------------------------------------------------------
ER.lastCast  = nil
ER.castTime  = {}     -- ability key -> GetTime() of its last successful cast
ER.castCount = {}     -- ability key -> casts since this fight started
ER.combatStart = 0

-- GUIDs we have damaged recently, for counting how many things we are
-- actually fighting. 3.3.5 has no nameplate API, so the combat log is
-- the only reliable source.
ER.seenEnemies = ER.seenEnemies or {}

-- Which enemies currently carry each of our debuffs.
--   dotTargets[spellName][destGUID] = expiry time
-- Needed so a spread effect like Pestilence is cast when it actually
-- has somewhere to spread TO, rather than every global.
ER.dotTargets = {}

local clog = CreateFrame("Frame")
clog:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
clog:SetScript("OnEvent", function(self, event, ...)
    if not ER.activeSpec then return end
    local e = C.ParseCombatLog(...)
    if e.sourceGUID ~= UnitGUID("player") then return end

    -- anything we damaged counts as an enemy we are engaged with
    if e.destGUID and string.find(e.event or "", "_DAMAGE", 1, true) then
        ER.seenEnemies[e.destGUID] = GetTime()
    end

    -- track our debuffs per target
    if e.spellName and e.destGUID then
        local ev = e.event
        if ev == "SPELL_AURA_APPLIED" or ev == "SPELL_AURA_REFRESH"
           or ev == "SPELL_AURA_APPLIED_DOSE" then
            for key, def in pairs(ER.activeSpec.auras) do
                if def.type == "debuff" and def.name == e.spellName then
                    ER.dotTargets[key] = ER.dotTargets[key] or {}
                    ER.dotTargets[key][e.destGUID] = GetTime() + (def.duration or 15)
                end
            end
        elseif ev == "SPELL_AURA_REMOVED" then
            for key, def in pairs(ER.activeSpec.auras) do
                if def.type == "debuff" and def.name == e.spellName
                   and ER.dotTargets[key] then
                    ER.dotTargets[key][e.destGUID] = nil
                end
            end
        end
    end

    if e.event ~= "SPELL_CAST_SUCCESS" then return end

    for key, ab in pairs(ER.activeSpec.abilities) do
        if ab.name and e.spellName == ab.name then
            ER.lastCast = key
            ER.castTime[key] = GetTime()
            ER.castCount[key] = (ER.castCount[key] or 0) + 1
            return
        end
    end
end)

--------------------------------------------------------------------
-- Events
--------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD",
                     "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
                     "LEARNED_SPELL_IN_TAB", "PLAYER_REGEN_ENABLED",
                     "PLAYER_REGEN_DISABLED",
                     "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED",
                     "ACTIONBAR_PAGE_CHANGED" }) do
    ev:RegisterEvent(e)
end

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "ElvinRotation" then
        ElvinRotationDB = ElvinRotationDB or {}

        -- BUG FIXED (v0.3): the old merge only filled keys that were
        -- entirely nil. ElvinRotationDB.settings already existed from a
        -- previous session, so changing a default INSIDE it had no
        -- effect - saved values silently won. Nested tables are now
        -- merged key by key.
        -- Read the stored version BEFORE merging defaults. The merge
        -- fills in dbVersion from DB_DEFAULTS, so checking afterwards
        -- always sees the current version and every migration is
        -- skipped. Ordering bug; caught by test/run.lua.
        local oldVersion = ElvinRotationDB.dbVersion or 0

        local function merge(dst, src)
            for k, v in pairs(src) do
                if type(v) == "table" then
                    dst[k] = dst[k] or {}
                    merge(dst[k], v)
                elseif dst[k] == nil then
                    dst[k] = v
                end
            end
        end
        merge(ElvinRotationDB, DB_DEFAULTS)

        -- One-shot migration: v0.2 shipped mindBlast="auto", which on
        -- 3.3.5 behaves as "always". Anyone carrying that saved value
        -- gets moved to the corrected default once.
        if oldVersion < 3 then
            if ElvinRotationDB.settings.mindBlast == "auto" then
                ElvinRotationDB.settings.mindBlast = "never"
            end
        end
        if oldVersion < 4 then
            ElvinRotationDB.dbVersion = 4
        end

        ER:BuildDisplay()
        ER:Print("v" .. ER.VERSION .. " loaded.  /er options")

        local missing = C.Preflight()
        if #missing > 0 then
            ER:Print("|cffff5555missing client API:|r " .. table.concat(missing, ", "))
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, function() ER:DetectSpec() end)
        -- bar addons finish setting up after us
        C_Timer.After(5, function() C.InvalidateKeybinds() end)

    elseif event == "PLAYER_TALENT_UPDATE"
        or event == "CHARACTER_POINTS_CHANGED"
        or event == "LEARNED_SPELL_IN_TAB" then
        C_Timer.After(1, function() ER:DetectSpec() end)

    elseif event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "ACTIONBAR_PAGE_CHANGED" then
        C.InvalidateKeybinds()

    elseif event == "PLAYER_REGEN_DISABLED" then
        ER.castCount = {}
        ER.combatStart = GetTime()
        ER.seenEnemies = {}
        ER.dotTargets = {}

    elseif event == "PLAYER_REGEN_ENABLED" then
        if frame and not ER.debugMode
           and ElvinRotationDB.displayMode ~= "always" then
            frame:Hide()
        end
    end
end)

--------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------
SLASH_ELVINROTATION1 = "/er"
SLASH_ELVINROTATION2 = "/elvinrotation"

SlashCmdList["ELVINROTATION"] = function(msg)
    msg = string.lower(msg or "")
    local cmd, arg = string.match(msg, "^(%S*)%s*(.-)$")
    local db = ElvinRotationDB

    if cmd == "toggle" then
        ER.enabled = not ER.enabled
        ER:Print(ER.enabled and "enabled" or "disabled")
        if not ER.enabled and frame then frame:Hide() end

    elseif cmd == "debug" then
        ER.debugMode = not ER.debugMode
        ER:Print("debug " .. (ER.debugMode and "on" or "off"))

    elseif cmd == "lock" then
        db.locked = not db.locked
        if frame then frame:EnableMouse(not db.locked) end
        ER:Print(db.locked and "locked" or "unlocked")

    elseif cmd == "keybind" then
        db.showKeybind = not db.showKeybind
        ER:Print("keybinds " .. (db.showKeybind and "shown" or "hidden"))

    elseif cmd == "queue" then
        local n = tonumber(arg)
        if n and n >= 1 and n <= 5 then
            db.queueSize = n
            ER:Print("queue size " .. n)
        else
            ER:Print("queue size must be 1-5 (currently " .. db.queueSize .. ")")
        end

    elseif cmd == "size" then
        local n = tonumber(arg)
        if n and n >= 20 and n <= 128 then
            db.size = n
            ER:Print("icon size " .. n .. " - /reload to apply")
        else
            ER:Print("size must be 20-128 (currently " .. db.size .. ")")
        end

    elseif cmd == "mb" then
        if arg == "auto" or arg == "always" or arg == "never" then
            db.settings.mindBlast = arg
            ER:Print("Mind Blast: " .. arg)
        else
            ER:Print("Mind Blast is '" .. tostring(db.settings.mindBlast)
                     .. "' - use: /er mb auto | always | never")
        end

    elseif cmd == "version" or cmd == "ver" then
        ER:Print("version " .. ER.VERSION)
        ER:Print("Options.lua loaded: " ..
            (ER.ToggleOptions and "|cff55ff55yes|r" or "|cffff5555NO - file missing|r"))
        ER:Print("dropdown options: " ..
            (ER.RegisterSpecOptions and "|cff55ff55yes|r" or "|cffff5555NO - old version|r"))
        local n = 0
        for _ in pairs(ER.specOptions or {}) do n = n + 1 end
        ER:Print("classes registered: " .. n)

    elseif cmd == "options" or cmd == "config" or cmd == "opt" then
        ER:ToggleOptions()

    elseif cmd == "sf" then
        local n = tonumber(arg)
        if n and n >= 0 and n <= 100 then
            db.settings.shadowfiendMana = n
            ER:Print("Shadowfiend at or below " .. n .. "% mana")
        else
            ER:Print("Shadowfiend mana threshold is "
                     .. tostring(db.settings.shadowfiendMana) .. "% - /er sf <0-100>")
        end

    elseif cmd == "aoe" then
        if arg == "auto" or arg == "single" or arg == "aoe" then
            db.aoeMode = arg
        else
            db.aoeMode = (db.aoeMode == "single") and "auto" or "single"
        end
        ER:Print("target mode: |cff55ff55" .. db.aoeMode .. "|r"
            .. "  (detected " .. ER:ActiveEnemies() .. " enemies)")

    elseif cmd == "dots" then
        if not UnitExists("target") then ER:Print("no target") return end
        local auras = C.DumpAuras("target")
        ER:Print("debuffs on target (" .. #auras .. "):")
        for _, a in ipairs(auras) do
            ER:Print(string.format("  %-22s id %-6s caster %-8s %.1fs",
                string.sub(a.name, 1, 22), tostring(a.id),
                tostring(a.caster), a.remains))
        end
        if ER.activeSpec then
            ER:Print("looking for:")
            for key, def in pairs(ER.activeSpec.auras) do
                if def.type == "debuff" then
                    local d = ER.state.debuff[key]
                    ER:Print(string.format("  %-22s id %-6s name '%s'  -> %s",
                        key, tostring(def.id), tostring(def.name),
                        (d and d.up) and string.format("FOUND %.1fs", d.remains)
                                      or "|cffff5555NOT FOUND|r"))
                end
            end
        end

    elseif cmd == "verify" then
        if not ER.activeSpec then ER:Print("no spec active") return end
        local total = 0
        for label, tbl in pairs({ abilities = ER.activeSpec.abilities,
                                  auras     = ER.activeSpec.auras }) do
            local bad = C.CheckSpellIDs(tbl)
            for _, b in ipairs(bad) do
                ER:Print(string.format("|cffff5555%s|r %s -> id %d resolves to '%s'",
                    label, b.key, b.id, b.name))
            end
            total = total + #bad
        end
        ER:Print(total == 0 and "|cff55ff55all spell IDs match their names|r"
                             or (total .. " mismatched ID(s)"))

    elseif cmd == "spec" then
        local _, class = UnitClass("player")
        local t1, t2, t3 = C.TalentPoints()
        ER:Print("class " .. tostring(class) .. "  talents " .. t1 .. "/" .. t2 .. "/" .. t3)
        ER:Print("active: " .. (ER.activeSpec and ER.activeSpec.name or "|cffff5555none|r"))
        for _, sp in ipairs(ER.specs) do
            if sp.class == class then
                ER:Print(string.format("  %-24s tab %d = %d points",
                    sp.name, sp.tab, ({ t1, t2, t3 })[sp.tab] or 0))
            end
        end

    elseif cmd == "cd" or cmd == "cds" then
        db.cooldownsOff = not db.cooldownsOff
        ER:Print("major cooldowns " ..
            (db.cooldownsOff and "|cffff5555OFF|r" or "|cff55ff55ON|r"))

    elseif cmd == "reset" then
        ElvinRotationDB = nil
        ER:Print("saved settings cleared - /reload to apply")

    elseif cmd == "bars" then
        -- /er bars <spell name>  = deep trace for one spell
        if arg and arg ~= "" then
            local target
            for _, ab in pairs(ER.activeSpec and ER.activeSpec.abilities or {}) do
                if ab.name and string.find(string.lower(ab.name), arg, 1, true) then
                    target = ab.name break
                end
            end
            if not target then ER:Print("no spell matching '" .. arg .. "'") return end
            ER:Print("trace: " .. target)
            for _, line in ipairs(C.KeybindTrace(target)) do ER:Print("  " .. line) end
            return
        end

        local bars, slots, method = C.KeybindReport()
        ER:Print("bar frames found: " ..
                 (#bars > 0 and table.concat(bars, ", ") or "|cffff5555NONE|r"))
        ER:Print("slots with a readable keybind: " .. slots .. "  (" .. method .. ")")
        local vis, total = C.VisibilityStats()
        ER:Print("buttons holding a slot: " .. total .. ", of which visible: " ..
                 (vis == 0 and "|cffff5555" or "|cff55ff55") .. vis .. "|r")
        ER:Print("showKeybind setting: " .. tostring(db.showKeybind))
        if ER.activeSpec then
            for _, key in ipairs({ "mind_flay", "mind_blast", "shadow_word_pain",
                                   "vampiric_touch", "devouring_plague" }) do
                local ab = ER.activeSpec.abilities[key]
                if ab and ab.name then
                    ER:Print(string.format("  %-18s slot=%s  key=%s", ab.name,
                        tostring(C.FindActionSlot(ab.name)),
                        tostring(C.Keybind(ab.name))))
                end
            end
        end

    elseif cmd == "keys" then
        -- Every ability: slot, raw binding, abbreviated result, source.
        -- Distinguishes "no binding found" from "abbreviation mangled it".
        if not ER.activeSpec then ER:Print("no spec active") return end
        ER:Print("spell | key | diagnosis")
        local bad = 0
        for key, ab in pairs(ER.activeSpec.abilities) do
            if not ab.name then
                bad = bad + 1
                ER:Print(string.format("  %-18s |cffff5555BAD SPELL ID|r id=%s",
                    key, tostring(ab.id)))
            else
                ER:Print(string.format("  %-18s %-6s | %s",
                    ab.name, tostring(C.Keybind(ab.name)),
                    C.KeybindDiagnosis(ab.name)))
            end
        end
        if bad > 0 then
            ER:Print("|cffff5555" .. bad .. " unresolved spell ID(s)|r - "
                     .. "these can never show a keybind or be recommended.")
        end

    elseif cmd == "state" then
        local s = ER.state
        ER:Print(string.format(
            "mana %.0f%% | gcd %.2f | haste %.1f%% | sp %d | lat %.0fms | ttd %.0f | moving %s",
            s.manaPct, s.gcd, s.haste, s.spellPower, s.latency * 1000, s.ttd,
            tostring(s.moving)))
        -- dots and pet, for debugging "it is not refreshing"
        local sp = ER.activeSpec
        if sp then
            local dots = {}
            for key, def in pairs(sp.auras) do
                if def.type == "debuff" then
                    local d = ER.state.debuff[key]
                    table.insert(dots, string.format("%s=%.1f%s", key,
                        d and d.remains or -1,
                        (d and d.inferred) and "|cffffaa00*|r" or ""))
                end
            end
            if #dots > 0 then
                ER:Print("dots: " .. table.concat(dots, "  ")
                    .. "   |cffffaa00*|r = from combat log, not UnitDebuff")
            end
            local spread = {}
            for key, def in pairs(sp.auras) do
                if def.type == "debuff" then
                    table.insert(spread, key .. " on " .. ER:ActiveDots(key))
                end
            end
            if #spread > 0 then ER:Print("spread: " .. table.concat(spread, "  ")) end
            if ER.state.comboPoints then
                ER:Print("combo points: " .. ER.state.comboPoints
                    .. "   power: " .. tostring(ER.state.power)
                    .. "/" .. tostring(ER.state.powerMax))
            end
            if ER.state.runes then
                local r = {}
                for _, rune in ipairs(ER.state.runes) do
                    table.insert(r, string.format("%s%s", string.sub(rune.type, 1, 1),
                        rune.ready and "+" or string.format("%.0f", rune.remains)))
                end
                ER:Print("runes: " .. table.concat(r, " ")
                    .. "   rp " .. tostring(ER.state.runicPower))
            end
            if ER.activeSpec.UpdateExtra and ER.state.glyph_of_disease ~= nil then
                ER:Print("glyph of disease: " .. tostring(ER.state.glyph_of_disease))
            end
            ER:Print("pet: " .. tostring(ER.state.pet)
                .. "   presence: " .. tostring(ER.state.presenceName)
                .. "   enemies: " .. tostring(ER.state.activeEnemies))
            local buffs = {}
            for key, def in pairs(sp.auras) do
                if def.type ~= "debuff" then
                    local b = ER.state.buff[key]
                    if b and b.up then table.insert(buffs, key) end
                end
            end
            ER:Print("buffs up: " ..
                (#buffs > 0 and table.concat(buffs, ", ") or "(none)"))
        end

        ER:Print(string.format("combat %.0fs   opener %s",
            ER.state.combatTime or -1,
            (ER.state.inCombat
             and (ER.state.combatTime or 0) < (ER:Setting("openerWindow") or 40)
             and ER:Setting("useOpener") ~= false) and "|cff55ff55ACTIVE|r" or "off"))

        local q = {}
        for i, ab in ipairs(ER.queue or {}) do table.insert(q, i .. "." .. ab.name) end
        ER:Print(string.format("queue: asked for %d, engine returned %d",
            db.queueSize or 3, #q))
        if #q > 0 then ER:Print("  " .. table.concat(q, "  ")) end
        if ER.lastError then ER:Print("|cffff5555last error:|r " .. ER.lastError) end

    else
        ER:Print("version | spec | verify | dots | options | cd | aoe <auto|single|aoe> | keys | toggle | debug | lock | keybind | bars [spell] | queue <1-5> | size <n> | mb <auto|always|never> | sf <0-100> | state | reset")
    end
end
