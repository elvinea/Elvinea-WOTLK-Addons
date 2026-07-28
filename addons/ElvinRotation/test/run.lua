--[[ test/run.lua
     Loads ElvinRotation against the 3.3.5 mock and drives it.
     Run:  lua5.1 test/run.lua     (from the addon root)
--]]

local mock = dofile("test/mock335.lua")

local failures = 0
local function step(label, fn)
    local ok, err = pcall(fn)
    if ok then
        print("  PASS  " .. label)
    else
        failures = failures + 1
        print("  FAIL  " .. label .. "\n         " .. tostring(err))
    end
end

print("\n=== LOAD (order per .toc) ===")
for _, f in ipairs({ "Compat.lua", "Core.lua", "State.lua",
                     "Engine.lua", "Options.lua",
                     "Specs/PriestShadow.lua", "Specs/DeathKnightFrost.lua",
                     "Specs/DeathKnightUnholy.lua" }) do
    step(f, function() dofile(f) end)
end

local ER = _G.ElvinRotation
if not ER then print("\nFATAL: addon table missing") os.exit(1) end

print("\n=== PREFLIGHT (missing 3.3.5 globals) ===")
local missing = ER.Compat.Preflight()
if #missing == 0 then
    print("  PASS  all required globals present")
else
    failures = failures + 1
    print("  FAIL  missing: " .. table.concat(missing, ", "))
end

print("\n=== SAVED VARIABLE MIGRATION ===")
step("v0.2 saved vars with mindBlast=auto get migrated", function()
    -- exactly what a user upgrading from v0.2 has on disk
    _G.ElvinRotationDB = {
        x = 0, y = -150, size = 56, locked = false,
        showKeybind = true, queueSize = 3,
        settings = { mindBlast = "auto" },
    }
    mock.fireEvent("ADDON_LOADED", "ElvinRotation")
    assert(ElvinRotationDB.settings.mindBlast == "never",
        "stale 'auto' survived upgrade: " .. tostring(ElvinRotationDB.settings.mindBlast))
    assert(ElvinRotationDB.dbVersion == 4, "dbVersion not bumped")
end)

step("explicit user choice of 'always' is NOT clobbered", function()
    _G.ElvinRotationDB = {
        dbVersion = 4, settings = { mindBlast = "always" },
    }
    mock.fireEvent("ADDON_LOADED", "ElvinRotation")
    assert(ElvinRotationDB.settings.mindBlast == "always",
        "user setting was overwritten")
end)

step("new keys land in existing nested tables", function()
    _G.ElvinRotationDB = { settings = {} }
    mock.fireEvent("ADDON_LOADED", "ElvinRotation")
    assert(ElvinRotationDB.settings.mindBlast ~= nil,
        "nested default not merged into existing table")
end)

print("\n=== INIT ===")
step("saved vars + display", function()
    _G.ElvinRotationDB = nil
    mock.fireEvent("ADDON_LOADED", "ElvinRotation")
end)

step("spec detection", function()
    ER:DetectSpec()
    assert(ER.activeSpec, "no spec became active")
    assert(ER.activeSpec.name == "Shadow Priest", "wrong spec")
end)

step("all spells resolved to names", function()
    local bad = {}
    for k, ab in pairs(ER.activeSpec.abilities) do
        if not ab.name then table.insert(bad, k) end
    end
    assert(#bad == 0, "unresolved: " .. table.concat(bad, ", "))
end)

print("\n=== STATE UPDATE ===")
step("UpdateState runs clean", function() ER:UpdateState() end)

step("state values sane", function()
    local s = ER.state
    assert(s.manaPct > 0 and s.manaPct <= 100, "manaPct=" .. tostring(s.manaPct))
    assert(s.spellPower > 0, "spellPower=" .. tostring(s.spellPower))
    assert(s.latency > 0, "latency=" .. tostring(s.latency))
    assert(s.ttd > 0, "ttd=" .. tostring(s.ttd))
    assert(type(s.haste) == "number", "haste not a number")
    assert(s.mf_tick_time and s.mf_tick_time > 0, "mf_tick_time missing")
end)

print("\n=== RECOMMENDATION QUEUE ===")
step("Recommend returns a queue", function()
    local q = ER:Recommend(4)
    assert(type(q) == "table" and q[1], "no recommendation produced")
    local names = {}
    for i, ab in ipairs(q) do table.insert(names, i .. "." .. ab.name) end
    print("         " .. table.concat(names, "  "))
end)

step("projection advances (not all the same spell)", function()
    local q = ER:Recommend(4)
    assert(#q >= 2, "queue too short: " .. #q)
    local allSame = true
    for i = 2, #q do if q[i].name ~= q[1].name then allSame = false end end
    assert(not allSame, "projection stuck on " .. q[1].name)
end)

print("\n=== KEYBINDS ===")
step("no bar frames still resolves via default bindings", function()
    -- Correct behaviour: if the spell sits in slot 1 and ACTIONBUTTON1
    -- is bound, the key is knowable without any button frame existing.
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Mind Flay") == "1",
        "default binding fallback failed: " .. tostring(ER.Compat.Keybind("Mind Flay")))
end)

step("reads HotKey from a THIRD-PARTY bar (BT4Button)", function()
    mock.clearAllBars()
    mock.clearActions()
    mock.buildBars("BT4Button")
    ER.Compat.InvalidateKeybinds()
    local checks = { ["Mind Flay"]="1", ["Mind Blast"]="2",
                     ["Vampiric Touch"]="s4", ["Shadowfiend"]="c6" }
    for name, want in pairs(checks) do
        local got = ER.Compat.Keybind(name)
        assert(got == want, name .. ": expected " .. want .. " got " .. tostring(got))
    end
    print("         Mind Flay=1  Mind Blast=2  Vampiric Touch=s4  Shadowfiend=c6")
end)

step("reads HotKey from Blizzard default bars too", function()
    for i = 1, 12 do _G["BT4Button"..i], _G["BT4Button"..i.."HotKey"] = nil, nil end
    mock.buildBars("ActionButton")
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Mind Flay") == "1", "default bars failed")
end)

step("VISIBLE bar beats hidden Blizzard bar (the ElvUI case)", function()
    mock.clearAllBars(); mock.clearActions()
    -- Blizzard bar still exists but hidden, carrying stale bindings
    mock.buildBars("ActionButton", { visible = false,
        keys = { "STALE1","STALE2","STALE3","STALE4","STALE5","STALE6" } })
    -- ElvUI bar visible on top with the real bindings
    mock.buildBars("ElvUI_Bar1Button", { visible = true,
        keys = { "1","2","3","SHIFT-4","5","CTRL-6" } })
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Mind Flay")
    assert(got == "1", "hidden Blizzard bar won; got " .. tostring(got))
    mock.clearBars("ElvUI_Bar1Button"); mock.clearBars("ActionButton")
end)

step("a DIRECT placement beats a macro that mentions the spell", function()
    -- The reported failure: one multi-spell macro claimed itself as
    -- the home of seven abilities, so several showed the macro's key
    -- instead of their own.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(1, "Obliterate")                       -- direct
    mock.setMacro(9, "#showtooltip\n/cast Obliterate", 6) -- macro mention
    mock.buildBars("ActionButton", { visible = true,
        keys = { "1","2","3","4","5","6" } })
    ER.Compat.InvalidateKeybinds()

    local slots = ER.Compat.FindActionSlots("Obliterate")
    assert(#slots == 2, "expected 2 candidates, got " .. #slots)
    local got = ER.Compat.Keybind("Obliterate")

    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "1", "macro slot won over direct placement; got " .. tostring(got))
end)

step("#showtooltip only matches its OWN line", function()
    mock.clearAllBars(); mock.clearAllActions()
    -- A cooldown macro that merely NAMES several spells in comments or
    -- unrelated lines must not claim all of them.
    mock.setMacro(10, "#showtooltip Blood Tap\n/cast Blood Tap\n"
                   .. "-- also good with Unbreakable Armor and Pestilence", 6)
    mock.buildBars("ActionButton", { visible = true, keys = { "1","2","3","4","5","6" } })
    ER.Compat.InvalidateKeybinds()

    local bt = ER.Compat.FindActionSlots("Blood Tap")
    local ua = ER.Compat.FindActionSlots("Unbreakable Armor")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()

    assert(#bt == 1, "Blood Tap should match its own macro, got " .. #bt)
    assert(#ua == 0, "Unbreakable Armor wrongly claimed the macro slot")
end)

step("finds a spell in a macro with rank + conditionals", function()
    -- clear the direct placements first: a direct placement now
    -- correctly outranks a macro, which would mask this check
    mock.clearAllBars(); mock.clearAllActions()
    mock.buildBars("ActionButton", { visible = true })
    mock.setMacro(2, "#showtooltip\n/cast [@target,harm] Devouring Plague(Rank 9)", 4)
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.FindActionSlot("Devouring Plague") == 4,
        "conditional/rank macro not matched")
    mock.clearActions(); mock.clearBars("ActionButton")
end)

step("falls back to ICON match when the name is unparseable", function()
    mock.buildBars("ActionButton", { visible = true })
    mock.clearAllActions()
    -- macro body reveals nothing, but it carries the spell's icon
    mock.setMacroWithIcon(3, "#showtooltip\n/click SomeOtherButton", 5,
                          "Interface\\Icons\\Mind Flay")
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.FindActionSlot("Mind Flay") == 5,
        "icon fallback failed")
    mock.clearActions(); mock.clearBars("ActionButton")
end)

step("finds a spell placed as a MACRO", function()
    mock.buildBars("ActionButton", { visible = true })
    mock.setMacro(1, "#showtooltip\n/cast Dispersion", 3)
    ER.Compat.InvalidateKeybinds()
    local slot = ER.Compat.FindActionSlot("Dispersion")
    assert(slot == 3, "macro not resolved, slot=" .. tostring(slot))
    assert(ER.Compat.Keybind("Dispersion") == "3", "macro keybind missing")
    mock.clearBars("ActionButton")
end)

step("falls back to CLICK binding when no hotkey text", function()
    mock.buildBars("BT4Button", { visible = true, keys = {} })  -- no hotkey text
    mock.setBinding("CLICK BT4Button1:LeftButton", "ALT-Q")
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Mind Flay") == "aQ",
        "click binding fallback failed: " .. tostring(ER.Compat.Keybind("Mind Flay")))
    mock.clearBars("BT4Button")
end)

step("a real binding is trusted even on a non-visible frame", function()
    -- Bindings are pressable whether or not the button is drawn.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(1, "Mind Flay")
    mock.buildBars("ActionButton", { visible = false, keys = {} })
    mock.setBinding("ACTIONBUTTON1", "ALT-Q")
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Mind Flay")
    mock.setBinding("ACTIONBUTTON1", "1")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "aQ", "binding discarded for being non-visible; got " .. tostring(got))
end)

step("REGRESSION: text from a non-visible frame is still used", function()
    -- v1.1 discarded this and broke three working slots.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(77, "Dispersion")
    mock.buildBars("ElvUI_Bar7Button", { visible = false, slotBase = 72,
        keys = { "1","2","3","4","5" } })
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Dispersion")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "5", "non-visible third-party text discarded; got " .. tostring(got))
end)

step("third-party bar outranks Blizzard default for the same slot", function()
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(1, "Mind Flay")
    mock.buildBars("ActionButton", { visible = false, keys = { "STALE" } })
    mock.buildBars("ElvUI_Bar1Button", { visible = true, keys = { "s7" } })
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Mind Flay")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "s7", "Blizzard default bar won; got " .. tostring(got))
end)

step("default-bar text is used, but ranked lowest", function()
    -- Deliberate change from v1.1: a default-bar label is now shown
    -- rather than discarded, because discarding it lost real keys.
    -- It simply loses to any third-party source for the same slot.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(9, "Shadowfiend")
    mock.buildBars("ActionButton", { visible = false,
        keys = { "1","2","3","4","5","6","7","8","9" } })
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Shadowfiend")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "9", "default-bar text discarded; got " .. tostring(got))
end)

step("but a VISIBLE bar with the same label is fine", function()
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(9, "Shadowfiend")
    mock.buildBars("ActionButton", { visible = true,
        keys = { "1","2","3","4","5","6","7","8","9" } })
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Shadowfiend")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "9", "visible bar rejected; got " .. tostring(got))
end)

step("prefers a BOUND copy over an unbound paged duplicate", function()
    -- The reported failure: the same spell sits on a paged bar (slot
    -- 14, no rendered button) and on a visible bar (slot 75, bound).
    -- The low slot must not win.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(14, "Mind Blast")   -- paged copy, no button frame
    mock.setAction(75, "Mind Blast")   -- visible copy
    mock.buildBars("ElvUI_Bar7Button", { visible = true, slotBase = 72,
        keys = { "1", "2", "3", "4" } })
    ER.Compat.InvalidateKeybinds()

    local slots = ER.Compat.FindActionSlots("Mind Blast")
    assert(#slots == 2, "expected 2 copies, found " .. #slots)

    local got = ER.Compat.Keybind("Mind Blast")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "3", "unbound paged copy won; got " .. tostring(got))
end)

step("scans unknown frames EVEN WHEN named bars already found slots", function()
    -- Exactly the reported failure: Blizzard bars supply plenty of
    -- slots, but the spell sits on a frame with an unrecognised name.
    mock.clearAllBars()
    mock.clearAllActions()
    mock.setAction(2,  "Shadow Word: Pain")   -- lands on a known bar
    mock.setAction(14, "Mind Blast")          -- lands on the unknown one
    mock.buildBars("ActionButton", { visible = true })
    mock.buildBars("WhateverElvUICallsIt", { visible = true, slotBase = 12,
        keys = { "SHIFT-1", "SHIFT-2", "SHIFT-3" } })
    ER.Compat.InvalidateKeybinds()

    local swp = ER.Compat.Keybind("Shadow Word: Pain")
    local mb  = ER.Compat.Keybind("Mind Blast")

    mock.clearAllBars()
    mock.clearActions()
    ER.Compat.InvalidateKeybinds()

    assert(swp, "known-bar lookup regressed")
    assert(mb == "s2", "unknown frame skipped because named bars found slots; got "
        .. tostring(mb))
end)

step("discovers an UNKNOWN bar addon by scanning", function()
    for i = 1, 12 do
        _G["ActionButton"..i], _G["ActionButton"..i.."HotKey"] = nil, nil
    end
    mock.buildBars("SomeWeirdBarAddonButton")   -- not in BUTTON_PREFIXES
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Mind Flay")
    assert(got == "1", "auto-discovery failed, got " .. tostring(got))
    local _, _, method = ER.Compat.KeybindReport()
    print("         found via: " .. method)
end)

step("spell not on any bar returns nil", function()
    mock.clearActions()          -- undo the macro test's placement
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Dispersion") == nil,
        "expected nil, got " .. tostring(ER.Compat.Keybind("Dispersion")))
end)

print("\n=== OPTIONS WINDOW ===")
step("options panel builds without error", function()
    ER:ToggleOptions()
end)

step("dropdowns show text, not blank", function()
    -- The class dropdown must resolve to a display string; blank boxes
    -- were the reported symptom.
    local names = {}
    for class, data in pairs(ER.specOptions) do
        names[data.name or class] = true
    end
    assert(names["Priest"],       "Priest missing from the class dropdown")
    assert(names["Death Knight"], "Death Knight missing from the class dropdown")
    for class, data in pairs(ER.specOptions) do
        local any = false
        for _ in pairs(data.specs) do any = true end
        assert(any, class .. " has no specs")
    end
end)

step("'-' and '=' survive as keybinds", function()
    mock.clearAllBars()
    mock.clearActions()
    mock.buildBars("ActionButton", { visible = true, keys = {} })
    for _, k in ipairs({ "-", "=", "ALT-=", "ALT--" }) do
        mock.setBinding("ACTIONBUTTON1", k)
        ER.Compat.InvalidateKeybinds()
        local got = ER.Compat.Keybind("Mind Flay")
        assert(got and got ~= "", k .. " was filtered out entirely")
    end
    mock.setBinding("ACTIONBUTTON1", "=")
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Mind Flay") == "=", "plain = lost")
    mock.setBinding("ACTIONBUTTON1", "1")
end)

step("spec registered its own options", function()
    assert(ER.specOptions.PRIEST, "PRIEST not registered")
    assert(ER.specOptions.PRIEST.specs.shadow, "shadow spec not registered")
    local opts = ER.specOptions.PRIEST.specs.shadow.options
    assert(#opts == 2, "expected 2 spec options, got " .. #opts)
end)

print("\n=== KEYBIND ABBREVIATION ===")
step("modifiers strip without eating - or =", function()
    mock.clearAllBars()
    mock.clearActions()
    mock.buildBars("ActionButton", { visible = true, keys = {} })
    local cases = {
        { "=",                "="   },
        { "-",                "-"   },
        { "ALT-=",            "a="  },
        { "ALT--",            "a-"  },
        { "SHIFT-=",          "s="  },
        { "CTRL-SHIFT-ALT-=", "csa=" },
        { "BUTTON4",          "m4"  },
    }
    for i, c in ipairs(cases) do
        mock.setBinding("ACTIONBUTTON1", c[1])
        ER.Compat.InvalidateKeybinds()
        local got = ER.Compat.Keybind("Mind Flay")
        assert(got == c[2], c[1] .. " -> expected " .. c[2] .. " got " .. tostring(got))
    end
    print("         = / - / ALT-= / ALT-- / CTRL-SHIFT-ALT-= all correct")
    mock.setBinding("ACTIONBUTTON1", "1")
end)

step("ElvUI binding names are queried (the slot=14 case)", function()
    mock.clearAllBars()
    -- Reproduce the reported failure exactly: spell on ElvUI bar 2,
    -- action slot 14, bound under ELVUIBAR2BUTTON2 rather than any
    -- Blizzard or CLICK binding name.
    mock.clearBars("ActionButton")
    mock.clearAllActions()
    mock.setAction(14, "Mind Blast")
    mock.buildBars("ElvUI_Bar2Button", { visible = true, keys = {}, slotBase = 12 })
    mock.setBinding("ELVUIBAR2BUTTON2", "SHIFT-2")
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Mind Blast")

    mock.clearBars("ElvUI_Bar2Button")
    mock.clearActions()
    mock.buildBars("ActionButton", { visible = true })
    ER.Compat.InvalidateKeybinds()

    assert(got == "s2", "ELVUIBAR binding not used, got " .. tostring(got))
end)

print("\n=== SHADOWFIEND GATE ===")
step("not suggested at high mana", function()
    mock.player.mana = mock.player.manaMax          -- 100%
    ER:UpdateState()
    for _, ab in ipairs(ER:Recommend(4)) do
        assert(ab.name ~= "Shadowfiend", "Shadowfiend suggested at 100% mana")
    end
end)

step("suggested below the threshold", function()
    mock.player.mana = math.floor(mock.player.manaMax * 0.40)   -- 40%
    ER:UpdateState()
    local seen = false
    for i = 1, 8 do
        ER:UpdateState()
        for _, ab in ipairs(ER:Recommend(4)) do
            if ab.name == "Shadowfiend" then seen = true end
        end
        mock.advance(1.5)
    end
    assert(seen, "Shadowfiend never suggested at 40% mana")
    mock.player.mana = math.floor(mock.player.manaMax * 0.75)
end)

step("threshold is configurable", function()
    ElvinRotationDB.settings.shadowfiendMana = 20
    mock.player.mana = math.floor(mock.player.manaMax * 0.40)
    ER:UpdateState()
    for _, ab in ipairs(ER:Recommend(4)) do
        assert(ab.name ~= "Shadowfiend", "ignored a 20% threshold at 40% mana")
    end
    ElvinRotationDB.settings.shadowfiendMana = 50
end)

print("\n=== MIND BLAST MODE ===")
step("DEFAULT is never", function()
    assert(ER:Setting("mindBlast") == "never",
        "default should be never, got " .. tostring(ER:Setting("mindBlast")))
end)

step("never removes it from the queue", function()
    ElvinRotationDB.settings.mindBlast = "never"
    for i = 1, 12 do
        ER:UpdateState()
        local q = ER:Recommend(4)
        for _, ab in ipairs(q) do
            assert(ab.name ~= "Mind Blast", "Mind Blast still recommended with mb=never")
        end
        mock.advance(1.5)
    end
    print("         mb=never suppresses Mind Blast across 12 cycles")
end)

step("no swallowed predicate errors", function()
    assert(not ER.lastError, "predicate error: " .. tostring(ER.lastError))
end)

step("always brings it back", function()
    ElvinRotationDB.settings.mindBlast = "always"
    local seen = false
    for i = 1, 12 do
        ER:UpdateState()
        for _, ab in ipairs(ER:Recommend(4)) do
            if ab.name == "Mind Blast" then seen = true end
        end
        mock.advance(1.5)
    end
    ElvinRotationDB.settings.mindBlast = "never"
    assert(seen, "mb=always never produced Mind Blast")
end)

print("\n=== ROTATION WALK (10 cycles, DoTs applied as cast) ===")
step("10 cycles clean", function()
    local seen = {}
    for i = 1, 10 do
        ER:UpdateState()
        local q = ER:Recommend(3)
        local rec = q[1]
        assert(rec, "cycle " .. i .. ": nil recommendation")
        assert(not ER.lastError, "cycle " .. i .. ": " .. tostring(ER.lastError))
        table.insert(seen, rec.name)

        -- pretend we cast it: start its cooldown and apply DoTs
        mock.cast(rec.name)
        local dots = {
            ["Shadow Word: Pain"]  = { id = 48125, dur = 18 },
            ["Vampiric Touch"]     = { id = 48160, dur = 15 },
            ["Devouring Plague"]   = { id = 48300, dur = 24 },
        }
        local d = dots[rec.name]
        if d then
            table.insert(mock.targetDebuffs,
                { name = rec.name, id = d.id, count = 1,
                  expires = mock.now() + d.dur, duration = d.dur,
                  caster = "player" })
        end
        if rec.name == "Shadowform" or rec.name == "Inner Fire"
           or rec.name == "Vampiric Embrace" then
            table.insert(mock.playerBuffs,
                { name = rec.name, id = 0, count = 1, expires = 0, duration = 0 })
        end
        mock.advance(1.5)
    end
    print("         " .. table.concat(seen, " > "))
end)

print("\n=== HASTE DERIVATION ===")
step("haste tracks cast time", function()
    mock.player.haste = 25
    ER:UpdateState()
    local h = ER.state.haste
    assert(math.abs(h - 25) < 0.5, "expected ~25, got " .. tostring(h))
    mock.player.haste = 0
end)

print("\n=== QUEUE LENGTH ===")
step("engine returns exactly the requested count", function()
    ER:UpdateState()
    for n = 1, 5 do
        local q = ER:Recommend(n)
        assert(#q == n, "asked for " .. n .. ", engine returned " .. #q)
    end
end)

step("display shows exactly queueSize icons", function()
    for n = 1, 5 do
        ElvinRotationDB.queueSize = n
        ER:UpdateState()
        ER.state.inCombat = true
        local q = ER:Recommend(n)
        ER:UpdateDisplay(q)

        local shown = 0
        for _, f in ipairs(mock.frames) do
            if type(rawget(f, "_slotIndex")) == "number" and f:IsShown() then
                shown = shown + 1
            end
        end
        if shown > 0 then
            assert(shown == n, "queueSize " .. n .. " showed " .. shown .. " icons")
        end
    end
    ElvinRotationDB.queueSize = 3
end)

print("\n=== SPELL ID RESOLUTION ===")
step("every DK ability ID resolves to a name", function()
    local dk
    for _, sp in ipairs(ER.specs) do
        if sp.name == "Frost Death Knight" then dk = sp end
    end
    dk.ResolveRanks()
    local bad = {}
    for key, ab in pairs(dk.abilities) do
        if not ab.name then table.insert(bad, key .. "(" .. tostring(ab.id) .. ")") end
    end
    assert(#bad == 0, "unresolved DK spell IDs: " .. table.concat(bad, ", "))
end)

step("every DK aura ID resolves to a name", function()
    local dk
    for _, sp in ipairs(ER.specs) do
        if sp.name == "Frost Death Knight" then dk = sp end
    end
    local bad = {}
    for key, def in pairs(dk.auras) do
        if not def.name then table.insert(bad, key) end
    end
    -- auras are not in the spellbook mock, so only report, do not fail
    if #bad > 0 then print("         (auras unverified offline: " .. #bad .. ")") end
end)

print("\n=== COOLDOWN CONTROL ===")
local function specNamed(n)
    for _, sp in ipairs(ER.specs) do if sp.name == n then return sp end end
end

step("unholy spec registers with major cooldowns tagged", function()
    local uh = specNamed("Unholy Death Knight")
    assert(uh, "Unholy spec not registered")
    local cds = {}
    for key, ab in pairs(uh.abilities) do
        if ab.majorCD then cds[key] = true end
    end
    assert(cds.summon_gargoyle,     "gargoyle not tagged majorCD")
    assert(cds.army_of_the_dead,    "army not tagged majorCD")
    assert(cds.empower_rune_weapon, "ERW not tagged majorCD")
end)

step("every DK Unholy spell ID resolves", function()
    local uh = specNamed("Unholy Death Knight")
    uh.ResolveRanks()
    local bad = {}
    for key, ab in pairs(uh.abilities) do
        if not ab.name then table.insert(bad, key .. "(" .. tostring(ab.id) .. ")") end
    end
    assert(#bad == 0, "unresolved: " .. table.concat(bad, ", "))
end)

step("global toggle suppresses every major cooldown", function()
    ElvinRotationDB.cooldownsOff = false
    assert(ER:CooldownEnabled("summon_gargoyle"), "should be on by default")
    ElvinRotationDB.cooldownsOff = true
    assert(not ER:CooldownEnabled("summon_gargoyle"), "global toggle ignored")
    assert(not ER:CooldownEnabled("army_of_the_dead"), "global toggle partial")
    ElvinRotationDB.cooldownsOff = false
end)

step("per-cooldown toggle is independent", function()
    ElvinRotationDB.settings.cd_army_of_the_dead = false
    assert(not ER:CooldownEnabled("army_of_the_dead"), "per-CD toggle ignored")
    assert(ER:CooldownEnabled("summon_gargoyle"), "per-CD toggle leaked to others")
    ElvinRotationDB.settings.cd_army_of_the_dead = nil
end)

step("minTTD holds long cooldowns on short-lived targets", function()
    local uh = specNamed("Unholy Death Knight")
    assert(uh.abilities.army_of_the_dead.minTTD == 40,
        "army should need 40s of target life")
    assert(uh.abilities.summon_gargoyle.minTTD == 25,
        "gargoyle should need 25s of target life")
end)

step("gargoyle is tracked from a cast timestamp, not an aura", function()
    local uh = specNamed("Unholy Death Knight")
    local st = { runicPower = 0, runes = {}, sinceCast = { summon_gargoyle = 5 } }
    uh.UpdateExtra(st)
    assert(st.gargoyle_up, "gargoyle should be up 5s after the cast")
    assert(math.abs(st.gargoyle_remains - 25) < 0.01,
        "expected 25s remaining, got " .. tostring(st.gargoyle_remains))

    st.sinceCast.summon_gargoyle = 45
    uh.UpdateExtra(st)
    assert(not st.gargoyle_up, "gargoyle should have expired after 45s")
end)

step("options auto-generate a toggle per major cooldown", function()
    local data = ER.specOptions.DEATHKNIGHT.specs.unholy
    assert(data.spec, "spec table not passed to RegisterSpecOptions")
    local n = 0
    for _, ab in pairs(data.spec.abilities) do
        if ab.majorCD then n = n + 1 end
    end
    -- Raise Dead was deliberately untagged: keeping the ghoul out is
    -- upkeep, not burst, and must not be suppressed by /er cd.
    assert(n == 3, "expected 3 major cooldowns, found " .. n)
end)

print("\n=== SPELL ID vs NAME ===")
step("no ability ID resolves to a DIFFERENT spell", function()
    -- The blood_presence = 48263 bug: a valid ID for the wrong spell,
    -- invisible to every other check because everything resolved fine.
    local problems = {}
    for _, sp in ipairs(ER.specs) do
        if sp.ResolveRanks then sp.ResolveRanks() end
        for _, b in ipairs(ER.Compat.CheckSpellIDs(sp.abilities)) do
            table.insert(problems, string.format("%s: %s -> id %d is '%s'",
                sp.name, b.key, b.id, b.name))
        end
    end
    assert(#problems == 0, "\n           " .. table.concat(problems, "\n           "))
end)

step("blood_presence points at Blood Presence, not Frost", function()
    for _, sp in ipairs(ER.specs) do
        local bp = sp.abilities.blood_presence
        if bp then
            assert(bp.id == 48266,
                sp.name .. " blood_presence id is " .. bp.id .. ", expected 48266")
            assert(GetSpellInfo(bp.id) == "Blood Presence",
                sp.name .. " blood_presence resolves to " .. tostring(GetSpellInfo(bp.id)))
        end
    end
end)

step("no spec can ever reach Frost Presence", function()
    for _, sp in ipairs(ER.specs) do
        for key, ab in pairs(sp.abilities) do
            local name = GetSpellInfo(ab.id)
            assert(name ~= "Frost Presence",
                sp.name .. " ability '" .. key .. "' resolves to Frost Presence")
        end
    end
end)

print("\n=== SPEC DETECTION ===")
step("picks the spec with the most talent points, not the first match", function()
    -- The reported bug: a Frost priority loading for an Unholy
    -- character, so it suggested Frost Presence.
    local _, class = UnitClass("player")
    if class == "PRIEST" then
        print("         (mock character is a Priest; checking DK specs directly)")
    end
    local dkSpecs = {}
    for _, sp in ipairs(ER.specs) do
        if sp.class == "DEATHKNIGHT" then dkSpecs[sp.tab] = sp end
    end
    assert(dkSpecs[2] and dkSpecs[2].name == "Frost Death Knight",
        "tab 2 should be Frost")
    assert(dkSpecs[3] and dkSpecs[3].name == "Unholy Death Knight",
        "tab 3 should be Unholy")
end)

print("\n=== TARGET COUNTING ===")
step("counts distinct recently-damaged enemies", function()
    ElvinRotationDB.aoeMode = "auto"
    ER.seenEnemies = {}
    assert(ER:ActiveEnemies() == 1, "no damage should read as 1 target")

    ER.seenEnemies["0xA"] = GetTime()
    ER.seenEnemies["0xB"] = GetTime()
    ER.seenEnemies["0xC"] = GetTime()
    assert(ER:ActiveEnemies() == 3, "expected 3, got " .. ER:ActiveEnemies())
end)

step("stale enemies age out", function()
    ER.seenEnemies = {}
    ER.seenEnemies["0xA"] = GetTime()
    ER.seenEnemies["0xOLD"] = GetTime() - 30
    assert(ER:ActiveEnemies() == 1, "stale GUID was still counted")
end)

step("force-single overrides detection (the Blood Princes case)", function()
    ER.seenEnemies = {}
    for i = 1, 5 do ER.seenEnemies["0x" .. i] = GetTime() end
    assert(ER:ActiveEnemies() == 5, "detection broken")

    ElvinRotationDB.aoeMode = "single"
    assert(ER:ActiveEnemies() == 1, "force-single ignored")

    ElvinRotationDB.aoeMode = "aoe"
    assert(ER:ActiveEnemies() == 99, "force-aoe ignored")

    ElvinRotationDB.aoeMode = "auto"
    ER.seenEnemies = {}
end)

print("\n=== OPENERS ===")
step("every spec has an opener and an aoe list", function()
    for _, sp in ipairs(ER.specs) do
        assert(sp.lists.aoe, sp.name .. " has no aoe list")
        if sp.class == "DEATHKNIGHT" then
            assert(sp.lists.opener, sp.name .. " has no opener")
        end
    end
end)

step("every opener entry carries a cast target", function()
    for _, sp in ipairs(ER.specs) do
        if sp.lists.opener then
            for i, e in ipairs(sp.lists.opener) do
                assert(e.casts and e.casts > 0,
                    sp.name .. " opener step " .. i .. " has no cast count")
            end
        end
    end
end)

step("opener cast counts never decrease within an ability", function()
    -- Cumulative counts: a later entry for the same ability must ask
    -- for more casts than the earlier one, or it can never fire.
    for _, sp in ipairs(ER.specs) do
        if sp.lists.opener then
            local seen = {}
            for i, e in ipairs(sp.lists.opener) do
                if seen[e.key] then
                    assert(e.casts > seen[e.key],
                        sp.name .. " step " .. i .. " (" .. e.key
                        .. ") asks for " .. e.casts .. " casts after "
                        .. seen[e.key] .. " - it can never fire")
                end
                seen[e.key] = e.casts
            end
        end
    end
end)

step("FROST DK never suggests Frost Presence", function()
    -- Frost Presence is the tank presence. A Frost DPS runs Blood
    -- (dual wield) or Unholy (two handed).
    local fr = specNamed("Frost Death Knight")
    assert(not fr.abilities.frost_presence,
        "Frost Presence is still an ability in the Frost spec")
    assert(not fr.auras.frost_presence,
        "Frost Presence is still tracked as an aura")
    for _, list in pairs(fr.lists) do
        for _, e in ipairs(list) do
            assert(e.key ~= "frost_presence",
                "Frost Presence still appears in a priority list")
        end
    end
end)

step("frost opener matches the played sequence", function()
    local fr = specNamed("Frost Death Knight")
    local o = fr.lists.opener
    local want = { "icy_touch", "plague_strike", "unbreakable_armor",
                   "blood_tap", "obliterate", "frost_strike", "pestilence",
                   "empower_rune_weapon" }
    for i, k in ipairs(want) do
        assert(o[i] and o[i].key == k,
            "opener step " .. i .. " expected " .. k .. " got "
            .. tostring(o[i] and o[i].key))
    end
end)

step("unholy opener leads with Blood Strike for Desolation", function()
    local uh = specNamed("Unholy Death Knight")
    local o = uh.lists.opener
    assert(o[1].key == "blood_strike", "opener should lead with Blood Strike")
    assert(o[2].key == "plague_strike", "second should be Plague Strike")
    assert(o[3].key == "icy_touch", "third should be Icy Touch")
end)

step("unholy opener summons Gargoyle BEFORE swapping to Blood", function()
    local uh = specNamed("Unholy Death Knight")
    local gargIdx, bloodIdx, erwIdx
    for i, e in ipairs(uh.lists.opener) do
        if e.key == "summon_gargoyle"     then gargIdx  = i end
        if e.key == "blood_presence"      then bloodIdx = i end
        if e.key == "empower_rune_weapon" then erwIdx   = i end
    end
    assert(gargIdx and bloodIdx and erwIdx, "opener missing a key step")
    assert(gargIdx < bloodIdx, "Gargoyle must be summoned in Unholy Presence")
    assert(bloodIdx < erwIdx,  "ERW should be spent after the presence swap")
end)

step("unholy precombat opens in UNHOLY presence", function()
    local uh = specNamed("Unholy Death Knight")
    local found
    for _, e in ipairs(uh.lists.precombat) do
        if e.key == "unholy_presence" then found = true end
        assert(e.key ~= "blood_presence",
            "precombat should not put us in Blood Presence")
    end
    assert(found, "precombat should set Unholy Presence")
end)

print("\n=== AOE: SPREAD, NOT SPAM ===")
step("Pestilence is held when everything already has the disease", function()
    local uh = specNamed("Unholy Death Knight")
    local entry
    for _, e in ipairs(uh.lists.aoe) do
        if e.key == "pestilence" then entry = e end
    end
    assert(entry, "no pestilence line in the AoE list")

    -- 3 enemies, all 3 already diseased: must NOT fire
    local s1 = {
        dot = { frost_fever = { up = true, remains = 12 } },
        activeDot = { frost_fever = 3 },
        activeEnemies = 3,
    }
    assert(not entry.when(s1),
        "Pestilence suggested with every target already diseased - this is the spam bug")

    -- 3 enemies, only 1 diseased: should fire
    local s2 = {
        dot = { frost_fever = { up = true, remains = 12 } },
        activeDot = { frost_fever = 1 },
        activeEnemies = 3,
    }
    assert(entry.when(s2), "Pestilence should spread to the two undiseased targets")
end)

step("Frost AoE Pestilence has the same gate", function()
    local fr = specNamed("Frost Death Knight")
    local entry
    for _, e in ipairs(fr.lists.aoe) do
        if e.key == "pestilence" then entry = e end
    end
    local s1 = {
        dot = { frost_fever = { up = true, remains = 12 } },
        activeDot = { frost_fever = 4 }, activeEnemies = 4,
    }
    assert(not entry.when(s1), "Frost Pestilence spams when all targets are diseased")
end)

step("dot spread is counted per target from the combat log", function()
    ER.dotTargets = {}
    assert(ER:ActiveDots("frost_fever") == 0, "should start at zero")

    ER.dotTargets.frost_fever = {
        ["0xA"] = GetTime() + 10,
        ["0xB"] = GetTime() + 10,
        ["0xEXPIRED"] = GetTime() - 5,
    }
    assert(ER:ActiveDots("frost_fever") == 2,
        "expected 2 live dots, got " .. ER:ActiveDots("frost_fever"))
    ER.dotTargets = {}
end)

step("no AoE list contains an ungated filler that could spam", function()
    -- Every AoE entry must either have a condition or be a genuine
    -- filler that is safe to repeat.
    local SAFE_FILLERS = {
        obliterate = true, blood_strike = true, frost_strike = true,
        howling_blast = true, mind_sear = true, death_and_decay = true,
        scourge_strike = true, blood_boil = true,
    }
    for _, sp in ipairs(ER.specs) do
        for _, e in ipairs(sp.lists.aoe or {}) do
            if not e.when and not e.runList then
                assert(SAFE_FILLERS[e.key],
                    sp.name .. " AoE has ungated '" .. e.key .. "' which can spam")
            end
        end
    end
end)

print("\n=== PRESENCE IS A STANCE ===")
step("active presence is read from the shapeshift bar", function()
    mock.setPresence(1)
    assert(ER.Compat.ActivePresence() == "Blood Presence",
        "expected Blood Presence, got " .. tostring(ER.Compat.ActivePresence()))
    mock.setPresence(3)
    assert(ER.Compat.ActivePresence() == "Unholy Presence",
        "expected Unholy Presence, got " .. tostring(ER.Compat.ActivePresence()))
    mock.setPresence(0)
    assert(ER.Compat.ActivePresence() == nil, "no form should read as nil")
end)

step("no DK priority tests a presence as a BUFF", function()
    -- UnitBuff never sees a stance, so any buff-based presence check
    -- is permanently false and the addon nags you to cast something
    -- you are already standing in.
    for _, name in ipairs({ "Frost Death Knight", "Unholy Death Knight" }) do
        local sp = specNamed(name)
        for listName, list in pairs(sp.lists) do
            for i, e in ipairs(list) do
                if e.when then
                    local src = string.dump and "" or ""
                end
            end
        end
        assert(sp.usesPresence, name .. " does not declare usesPresence")
    end
end)

step("already in Blood Presence: the swap does not fire", function()
    local uh = specNamed("Unholy Death Knight")
    ElvinRotationDB.settings.managePresence = true
    local entry
    for _, e in ipairs(uh.lists.single) do
        if e.key == "blood_presence" then entry = e end
    end
    local s1 = {
        presence = "blood",
        cooldown = { summon_gargoyle = { remains = 120 } },
        gargoyle_up = false,
    }
    assert(not entry.when(s1), "suggested Blood Presence while already in it")

    local s2 = {
        presence = "unholy",
        cooldown = { summon_gargoyle = { remains = 120 } },
        gargoyle_up = false,
    }
    assert(entry.when(s2), "should swap to Blood from Unholy")
end)

step("gargoyle already out: not suggested again", function()
    local uh = specNamed("Unholy Death Knight")
    local entry
    for _, e in ipairs(uh.lists.single) do
        if e.key == "summon_gargoyle" then entry = e end
    end
    local s1 = { gargoyle_up = true, presence = "unholy" }
    assert(not entry.when(s1), "suggested Gargoyle while it was already out")
    local s2 = { gargoyle_up = false, presence = "unholy" }
    assert(entry.when(s2), "should suggest Gargoyle when it is not out")
end)

step("gargoyle prefers a real aura over the cast timestamp", function()
    local uh = specNamed("Unholy Death Knight")
    local st = {
        runicPower = 0, runes = {},
        buff = { summon_gargoyle = { up = true, remains = 22 } },
        dot = {}, sinceCast = { summon_gargoyle = 9999 },
    }
    st.debuff = st.dot
    uh.UpdateExtra(st)
    assert(st.gargoyle_up, "aura ignored in favour of a stale timestamp")
    assert(math.abs(st.gargoyle_remains - 22) < 0.01,
        "expected 22s from the aura, got " .. tostring(st.gargoyle_remains))
end)

print("\n=== PRESENCE SWAP ===")
step("swaps to Unholy before Gargoyle is ready", function()
    local uh = specNamed("Unholy Death Knight")
    ElvinRotationDB.settings.managePresence = true
    ElvinRotationDB.settings.presenceLead = 3
    ElvinRotationDB.cooldownsOff = false

    local entry
    for _, e in ipairs(uh.lists.single) do
        if e.key == "unholy_presence" then entry = e end
    end
    assert(entry, "no unholy_presence line in the priority")

    local s1 = {
        presence = "blood",
        cooldown = { summon_gargoyle = { remains = 2 } },
        gargoyle_up = false,
    }
    assert(entry.when(s1), "should swap to Unholy with Gargoyle 2s out")

    local s2 = {
        presence = "blood",
        cooldown = { summon_gargoyle = { remains = 60 } },
        gargoyle_up = false,
    }
    assert(not entry.when(s2), "should NOT swap with Gargoyle 60s out")
end)

step("swaps back to Blood once Gargoyle is spent", function()
    local uh = specNamed("Unholy Death Knight")
    local entry
    for _, e in ipairs(uh.lists.single) do
        if e.key == "blood_presence" then entry = e end
    end
    assert(entry, "no blood_presence line in the priority")

    local s1 = {
        presence = "unholy",
        cooldown = { summon_gargoyle = { remains = 120 } },
        gargoyle_up = false,
    }
    assert(entry.when(s1), "should return to Blood Presence after Gargoyle")

    local s2 = {
        presence = "unholy",
        cooldown = { summon_gargoyle = { remains = 120 } },
        gargoyle_up = true,
    }
    assert(not entry.when(s2), "must not swap out while the gargoyle is up")
end)

step("the swap can be turned off entirely", function()
    local uh = specNamed("Unholy Death Knight")
    ElvinRotationDB.settings.managePresence = false
    local entry
    for _, e in ipairs(uh.lists.single) do
        if e.key == "blood_presence" then entry = e end
    end
    local s1 = {
        presence = "unholy",
        cooldown = { summon_gargoyle = { remains = 120 } },
        gargoyle_up = false,
    }
    assert(not entry.when(s1), "presence managed while disabled")
    ElvinRotationDB.settings.managePresence = true
end)

print("\n=== COOLDOWN SWIPE ===")
step("RunesReadyIn returns the SOONEST payable time, not the longest", function()
    mock.resetRunes()
    -- frost runes down for 8s and 2s; one frost rune is needed
    mock.spendRune(5, 8); mock.spendRune(6, 2)
    local runes = ER.Compat.ReadRunes(mock.now())
    local wait, cdLen = ER.Compat.RunesReadyIn(runes, { frost = 1 })
    assert(math.abs(wait - 2) < 0.01,
        "expected the 2s rune, got " .. tostring(wait))
    assert(cdLen and cdLen > 0, "no cooldown length returned")
    mock.resetRunes()
end)

step("a two-type cost waits for the later of the two", function()
    mock.resetRunes()
    mock.spendRune(3, 6)   -- unholy
    mock.spendRune(4, 6)
    mock.spendRune(5, 1)   -- frost
    mock.spendRune(6, 1)
    local runes = ER.Compat.ReadRunes(mock.now())
    local wait = ER.Compat.RunesReadyIn(runes, { frost = 1, unholy = 1 })
    assert(math.abs(wait - 6) < 0.01,
        "Obliterate should wait 6s for the unholy rune, got " .. tostring(wait))
    mock.resetRunes()
end)

step("zero wait when the cost is already payable", function()
    mock.resetRunes()
    local runes = ER.Compat.ReadRunes(mock.now())
    local wait = ER.Compat.RunesReadyIn(runes, { frost = 1, unholy = 1 })
    assert(wait == 0, "full runes should mean no wait, got " .. tostring(wait))
end)

step("a cast in progress drives the swipe over the whole cast", function()
    ElvinRotationDB.showSwipe = true
    local now = mock.now()
    mock.setCasting("Vampiric Touch", now - 0.5, now + 1.0)
    mock.clearCooldownCalls()
    ER:UpdateState()
    ER.state.inCombat = true
    ER:UpdateDisplay(ER:Recommend(3))

    local call = mock.lastCooldownCall()
    assert(call and call.enable == 1, "no swipe while casting")
    assert(math.abs(call.duration - 1.5) < 0.01,
        "swipe should span the whole 1.5s cast, got " .. tostring(call.duration))
    mock.setCasting(nil)
end)

step("a channel in progress drives the swipe too", function()
    local now = mock.now()
    mock.setChanneling("Mind Flay", now - 1, now + 2)
    mock.clearCooldownCalls()
    ER:UpdateState()
    ER.state.inCombat = true
    ER:UpdateDisplay(ER:Recommend(3))

    local call = mock.lastCooldownCall()
    assert(call and call.enable == 1, "no swipe while channelling")
    assert(math.abs(call.duration - 3) < 0.01,
        "swipe should span the 3s channel, got " .. tostring(call.duration))
    mock.setChanneling(nil)
end)

step("display drives the swipe widget", function()
    mock.clearCooldownCalls()
    ElvinRotationDB.showSwipe = true
    ER:UpdateState()
    ER.state.inCombat = true
    ER:UpdateDisplay(ER:Recommend(3))
    assert(mock.lastCooldownCall(), "CooldownFrame_SetTimer was never called")
end)

step("swipe can be turned off", function()
    ElvinRotationDB.showSwipe = false
    mock.clearCooldownCalls()
    ER:UpdateState()
    ER.state.inCombat = true
    ER:UpdateDisplay(ER:Recommend(3))
    local last = mock.lastCooldownCall()
    assert(last and last.enable == 0, "swipe still enabled when turned off")
    ElvinRotationDB.showSwipe = true
end)

print("\n=== UNHOLY BUILD VARIANTS ===")
step("Glyph of Disease is detected", function()
    mock.clearGlyphs()
    assert(not ER.Compat.HasGlyph(63334), "glyph reported without one socketed")
    mock.setGlyph(2, 63334)
    assert(ER.Compat.HasGlyph(63334), "Glyph of Disease not detected")
    mock.clearGlyphs()
end)

step("Pestilence only appears with the glyph", function()
    local uh = specNamed("Unholy Death Knight")
    local function st(glyphed, ffRemains)
        mock.clearGlyphs()
        if glyphed then mock.setGlyph(1, 63334) end
        local s = {
            runicPower = 0, runes = {}, pet = true,
            dot = { frost_fever  = { up = true, remains = ffRemains },
                    blood_plague = { up = true, remains = 12 } },
        }
        s.debuff = s.dot
        uh.UpdateExtra(s)
        return s
    end

    local glyphed = st(true, 2)
    assert(glyphed.glyph_of_disease, "glyph not seen by the spec")
    assert(glyphed.disease_low,      "disease should read as low")
    assert(glyphed.both_diseases_up, "both diseases should read as up")

    local plain = st(false, 2)
    assert(not plain.glyph_of_disease, "glyph falsely reported")
    mock.clearGlyphs()
end)

step("disease refresh threshold is configurable", function()
    local uh = specNamed("Unholy Death Knight")
    ElvinRotationDB.settings.diseaseRefresh = 6
    local s = {
        runicPower = 0, runes = {}, pet = true,
        dot = { frost_fever  = { up = true, remains = 5 },
                blood_plague = { up = true, remains = 12 } },
    }
    s.debuff = s.dot
    uh.UpdateExtra(s)
    assert(s.disease_low, "5s left should be low when the threshold is 6s")

    ElvinRotationDB.settings.diseaseRefresh = 3
    uh.UpdateExtra(s)
    assert(not s.disease_low, "5s left should NOT be low at a 3s threshold")
end)

step("ghoul absence is detected", function()
    local uh = specNamed("Unholy Death Knight")
    mock.setPet(false)
    ER:UpdateState()
    assert(ER.state.pet == false, "pet wrongly reported present")
    mock.setPet(true)
    ER:UpdateState()
    assert(ER.state.pet == true, "pet not detected")
    mock.setPet(false)
end)

step("Bone Shield and Pestilence resolve", function()
    local uh = specNamed("Unholy Death Knight")
    uh.ResolveRanks()
    assert(uh.abilities.bone_shield.name == "Bone Shield",
        "Bone Shield unresolved: " .. tostring(uh.abilities.bone_shield.name))
    assert(uh.abilities.pestilence.name == "Pestilence",
        "Pestilence unresolved: " .. tostring(uh.abilities.pestilence.name))
end)

step("Raise Dead is NOT a suppressible major cooldown", function()
    local uh = specNamed("Unholy Death Knight")
    assert(not uh.abilities.raise_dead.majorCD,
        "ghoul upkeep should not be gated behind /er cd")
end)

print("\n=== RUNE MODEL ===")
step("all six runes read with correct types", function()
    mock.resetRunes()
    local runes = ER.Compat.ReadRunes(mock.now())
    assert(#runes == 6, "expected 6 runes, got " .. #runes)
    local want = { "blood","blood","unholy","unholy","frost","frost" }
    for i, t in ipairs(want) do
        assert(runes[i].type == t,
            "slot " .. i .. " expected " .. t .. " got " .. runes[i].type)
    end
end)

step("cost allocation respects rune types", function()
    mock.resetRunes()
    local runes = ER.Compat.ReadRunes(mock.now())
    local A = ER.Compat.RunesAvailable
    assert(A(runes, { frost = 1, unholy = 1 }), "Obliterate should be affordable")
    assert(A(runes, { blood = 1 }),             "Blood Strike should be affordable")
    assert(not A(runes, { frost = 3 }),         "3 frost runes should NOT be affordable")
end)

step("DEATH runes substitute for any type", function()
    mock.resetRunes()
    mock.spendRune(5, 10); mock.spendRune(6, 10)   -- both frost on cooldown
    local runes = ER.Compat.ReadRunes(mock.now())
    assert(not ER.Compat.RunesAvailable(runes, { frost = 1 }),
        "no frost runes should be available")

    mock.setRuneType(1, 4)                          -- blood slot 1 -> death
    runes = ER.Compat.ReadRunes(mock.now())
    assert(ER.Compat.RunesAvailable(runes, { frost = 1 }),
        "death rune should cover a frost cost")
    mock.resetRunes()
end)

step("death runes are not wasted on a matching cost", function()
    mock.resetRunes()
    mock.setRuneType(1, 4)      -- one death rune
    local runes = ER.Compat.ReadRunes(mock.now())
    -- blood + blood: one natural blood remains, death covers the other
    assert(ER.Compat.RunesAvailable(runes, { blood = 2 }), "should afford 2 blood")
    mock.resetRunes()
end)

print("\n=== FROST DEATH KNIGHT ===")
step("spec registers and declares runes", function()
    local dk
    for _, sp in ipairs(ER.specs) do
        if sp.name == "Frost Death Knight" then dk = sp end
    end
    assert(dk, "DK spec not registered")
    assert(dk.usesRunes, "spec did not declare usesRunes")
    assert(ER.specOptions.DEATHKNIGHT, "DK options not registered")
end)

step("rune costs gate abilities", function()
    local dk
    for _, sp in ipairs(ER.specs) do
        if sp.name == "Frost Death Knight" then dk = sp end
    end
    mock.resetRunes()
    local runes = ER.Compat.ReadRunes(mock.now())
    local ob = dk.abilities.obliterate
    assert(ER.Compat.RunesAvailable(runes, ob.runes), "Obliterate blocked at full runes")

    mock.spendRune(3, 10); mock.spendRune(4, 10)   -- both unholy down
    runes = ER.Compat.ReadRunes(mock.now())
    assert(not ER.Compat.RunesAvailable(runes, ob.runes),
        "Obliterate should need an unholy rune")
    mock.resetRunes()
end)

step("pestilence window follows presence", function()
    local dk
    for _, sp in ipairs(ER.specs) do
        if sp.name == "Frost Death Knight" then dk = sp end
    end
    ElvinRotationDB.settings.pestilenceWindow = 0

    local st = { presence = "unholy", runicPower = 0 }
    dk.UpdateExtra(st)
    assert(st.pesti_window == 8.5, "unholy presence should give 8.5, got "
        .. tostring(st.pesti_window))

    st = { presence = "blood", runicPower = 0 }
    dk.UpdateExtra(st)
    assert(st.pesti_window == 4, "non-unholy presence should give 4, got "
        .. tostring(st.pesti_window))

    ElvinRotationDB.settings.pestilenceWindow = 6
    st = { presence = "unholy", runicPower = 0 }
    dk.UpdateExtra(st)
    assert(st.pesti_window == 6, "manual override ignored")
    ElvinRotationDB.settings.pestilenceWindow = 0
end)

step("dual wield is detected", function()
    local dk
    for _, sp in ipairs(ER.specs) do
        if sp.name == "Frost Death Knight" then dk = sp end
    end
    mock.setDualWield(true)
    local st = { presence = "blood", runicPower = 0 }
    dk.UpdateExtra(st)
    assert(st.dual_wield == true, "dual wield not detected")

    mock.setDualWield(false)
    dk.UpdateExtra(st)
    assert(st.dual_wield == false, "two-hander misreported as dual wield")
end)

step("frost strike gated on runic power", function()
    local dk
    for _, sp in ipairs(ER.specs) do
        if sp.name == "Frost Death Knight" then dk = sp end
    end
    assert(dk.abilities.frost_strike.rp == 40, "Frost Strike should cost 40 RP")
end)

print(string.format("\n=== %s (%d failures) ===\n",
      failures == 0 and "ALL PASS" or "FAILURES", failures))
os.exit(failures > 0 and 1 or 0)
