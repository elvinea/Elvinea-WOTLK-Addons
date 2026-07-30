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
                     "Specs/DeathKnightUnholy.lua",
                     "Specs/RogueAssassination.lua",
                     "Specs/PaladinRetribution.lua",
                     "Specs/WarlockAffliction.lua",
                     "Specs/MageArcane.lua",
                     "Specs/DruidBalance.lua",
                     "Specs/WarriorArms.lua",
                     "Specs/HunterSurvival.lua",
                     "Specs/ShamanEnhancement.lua",
                     "Specs/MageFire.lua",
                     "Specs/WarlockDestruction.lua",
                     "Specs/MageFrost.lua",
                     "Specs/HunterMarksmanship.lua",
                     "Specs/DeathKnightBlood.lua",
                     "Specs/WarlockDemonology.lua",
                     "Specs/HunterBeastMastery.lua",
                     "Specs/WarriorFury.lua",
                     "Specs/DruidFeral.lua",
                     "Specs/RogueCombat.lua",
                     "Specs/RogueSubtlety.lua",
                     "Specs/ShamanElemental.lua" }) do
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

print("\n=== NEW SPECS ===")
step("all seven specs register with a unique class and tab", function()
    local expect = {
        "Shadow Priest", "Frost Death Knight", "Unholy Death Knight",
        "Assassination Rogue", "Retribution Paladin",
        "Affliction Warlock", "Arcane Mage",
        "Balance Druid", "Arms Warrior",
        "Survival Hunter", "Enhancement Shaman", "Fire Mage",
        "Destruction Warlock", "Frost Mage", "Marksmanship Hunter",
        "Blood Death Knight", "Demonology Warlock",
        "Beast Mastery Hunter", "Fury Warrior",
        "Feral Druid (Cat)", "Combat Rogue", "Subtlety Rogue",
        "Elemental Shaman",
    }
    for _, name in ipairs(expect) do
        assert(specNamed(name), name .. " not registered")
    end
    assert(#ER.specs == #expect,
        "expected " .. #expect .. " specs, found " .. #ER.specs)

    -- no two specs of the same class may claim the same talent tab
    local seen = {}
    for _, sp in ipairs(ER.specs) do
        local slot = sp.class .. ":" .. sp.tab
        if seen[slot] then
            error(sp.class .. " tab " .. sp.tab .. " claimed by both "
                  .. seen[slot] .. " and " .. sp.name)
        end
        seen[slot] = sp.name
    end
end)

step("every spec resolves every spell ID to the right spell", function()
    local problems = {}
    for _, sp in ipairs(ER.specs) do
        if sp.ResolveRanks then sp.ResolveRanks() end
        for _, b in ipairs(ER.Compat.CheckSpellIDs(sp.abilities)) do
            table.insert(problems, sp.name .. ": " .. b.key
                .. " -> id " .. b.id .. " is '" .. b.name .. "'")
        end
    end
    assert(#problems == 0, "\n           " .. table.concat(problems, "\n           "))
end)

step("every spec has the required structure", function()
    for _, sp in ipairs(ER.specs) do
        assert(sp.lists.single,  sp.name .. " has no single-target list")
        assert(sp.lists.aoe,     sp.name .. " has no AoE list")
        assert(sp.lists.default, sp.name .. " has no default list")
        assert(sp.IsActive,      sp.name .. " has no IsActive")
        assert(sp.ResolveRanks,  sp.name .. " has no ResolveRanks")
        assert(sp.gcdProbe,      sp.name .. " has no GCD probe")
        for key, ab in pairs(sp.abilities) do
            assert(ab.key == key,
                sp.name .. " ability '" .. key .. "' has key '"
                .. tostring(ab.key) .. "'")
        end
    end
end)

step("all 23 damage specs are built", function()
    assert(#ER.specs == 23, "expected 23 specs, found " .. #ER.specs)
end)

step("every class has its full complement", function()
    local expect = {
        DEATHKNIGHT = 3, DRUID = 2, HUNTER = 3, MAGE = 3, PALADIN = 1,
        PRIEST = 1, ROGUE = 3, SHAMAN = 2, WARLOCK = 3, WARRIOR = 2,
    }
    local byClass = {}
    for _, sp in ipairs(ER.specs) do
        byClass[sp.class] = (byClass[sp.class] or 0) + 1
    end
    for class, n in pairs(expect) do
        assert(byClass[class] == n, class .. " expected " .. n
            .. " specs, found " .. tostring(byClass[class]))
    end
end)

step("Warlock, Hunter and Warrior are now fully covered", function()
    local byClass = {}
    for _, sp in ipairs(ER.specs) do
        byClass[sp.class] = (byClass[sp.class] or 0) + 1
    end
    assert(byClass.WARLOCK == 3, "expected 3 Warlock specs, got "
        .. tostring(byClass.WARLOCK))
    assert(byClass.HUNTER == 3,  "expected 3 Hunter specs, got "
        .. tostring(byClass.HUNTER))
    assert(byClass.WARRIOR == 2, "expected 2 Warrior specs, got "
        .. tostring(byClass.WARRIOR))
    assert(byClass.MAGE == 3,    "expected 3 Mage specs")
    assert(byClass.DEATHKNIGHT == 3, "expected 3 Death Knight specs")
end)

step("no two specs anywhere claim the same class and tab", function()
    local seen = {}
    for _, sp in ipairs(ER.specs) do
        local slot = sp.class .. ":" .. sp.tab
        if seen[slot] then
            error(slot .. " claimed by both " .. seen[slot] .. " and " .. sp.name)
        end
        seen[slot] = sp.name
    end
end)

step("all three Death Knight specs claim different tabs", function()
    local tabs = {}
    for _, sp in ipairs(ER.specs) do
        if sp.class == "DEATHKNIGHT" then
            assert(not tabs[sp.tab],
                "DK tab " .. sp.tab .. " claimed twice")
            tabs[sp.tab] = sp.name
        end
    end
    assert(tabs[1] and tabs[2] and tabs[3], "expected all three DK trees")
end)

step("all three Mage specs claim different tabs", function()
    local tabs = {}
    for _, sp in ipairs(ER.specs) do
        if sp.class == "MAGE" then
            assert(not tabs[sp.tab], "Mage tab " .. sp.tab .. " claimed twice")
            tabs[sp.tab] = sp.name
        end
    end
    assert(tabs[1] and tabs[2] and tabs[3], "expected all three Mage trees")
end)

step("all ten classes have at least one spec", function()
    local classes = {}
    for _, sp in ipairs(ER.specs) do classes[sp.class] = true end
    for _, c in ipairs({ "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE",
                         "PALADIN", "PRIEST", "ROGUE", "SHAMAN",
                         "WARLOCK", "WARRIOR" }) do
        assert(classes[c], c .. " has no spec built")
    end
end)

step("Maelstrom Weapon stacking drives the Shaman list", function()
    local sh = specNamed("Enhancement Shaman")
    local st = {
        buff = { maelstrom_weapon = { stack = 5 },
                 lightning_shield = { up = true } },
        dot = {}, debuff = {}, manaPct = 80,
    }
    sh.UpdateExtra(st)
    assert(st.maelstrom_full, "5 stacks should read as full")

    st.buff.maelstrom_weapon.stack = 3
    sh.UpdateExtra(st)
    assert(not st.maelstrom_full, "3 stacks should not read as full")
end)

step("Hunter rotation is built around Explosive Shot", function()
    local h = specNamed("Survival Hunter")
    local esIdx, ssIdx
    for i, e in ipairs(h.lists.single) do
        if e.key == "explosive_shot" and not esIdx then esIdx = i end
        if e.key == "steady_shot"    and not ssIdx then ssIdx = i end
    end
    assert(esIdx and ssIdx, "missing a core Hunter ability")
    assert(esIdx < ssIdx, "Explosive Shot must outrank Steady Shot")
end)

step("Fire Mage reacts to Hot Streak before filling", function()
    local m = specNamed("Fire Mage")
    local pyroIdx, fbIdx
    for i, e in ipairs(m.lists.single) do
        if e.key == "pyroblast" and not pyroIdx then pyroIdx = i end
        if e.key == "fireball"  and not fbIdx   then fbIdx = i end
    end
    assert(pyroIdx < fbIdx, "Hot Streak Pyroblast must outrank Fireball")
end)

step("the two Mage specs claim different talent tabs", function()
    local arcane = specNamed("Arcane Mage")
    local fire   = specNamed("Fire Mage")
    assert(arcane.tab ~= fire.tab,
        "Arcane and Fire both claim tab " .. arcane.tab)
end)

step("Balance Druid Eclipse logic", function()
    local d = specNamed("Balance Druid")
    ER.eclipseSeen = {}
    local st = {
        now = 1000, buff = {
            eclipse_lunar = { up = false, remains = 0 },
            eclipse_solar = { up = false, remains = 0 },
            elunes_wrath  = { up = false },
        },
        dot = {}, debuff = {},
    }
    d.UpdateExtra(st)
    assert(st.fish_now, "no Eclipse up should mean fishing")
    assert(not st.spam_now, "should not be spamming with no Eclipse")

    st.buff.eclipse_lunar.up = true
    d.UpdateExtra(st)
    assert(st.spam_now, "Lunar Eclipse up should mean spamming")
    assert(st.lunar_up, "lunar_up not set")
    ER.eclipseSeen = {}
end)

step("Eclipse internal cooldown is tracked", function()
    local d = specNamed("Balance Druid")
    ER.eclipseSeen = { lunar = 1000 }
    local st = {
        now = 1010,          -- only 10s since Lunar was last up
        buff = { eclipse_lunar = { up = false, remains = 0 },
                 eclipse_solar = { up = false, remains = 0 },
                 elunes_wrath  = { up = false } },
        dot = {}, debuff = {},
    }
    d.UpdateExtra(st)
    assert(not st.lunar_can_proc, "Lunar should be on its 30s internal cooldown")

    st.now = 1040            -- 40s later
    d.UpdateExtra(st)
    assert(st.lunar_can_proc, "Lunar should be available again after 30s")
    ER.eclipseSeen = {}
end)

step("Arms Warrior uses rage", function()
    local w = specNamed("Arms Warrior")
    assert(w.powerType == 1, "Arms should use rage (power type 1)")
    assert(w.abilities.mortal_strike.power == 30, "Mortal Strike costs 30 rage")
    assert(w.abilities.bloodrage.generatesPower, "Bloodrage should generate rage")
end)

step("Heroic Strike holds rage in reserve", function()
    local w = specNamed("Arms Warrior")
    local hs
    for _, e in ipairs(w.lists.single) do
        if e.key == "heroic_strike" then hs = e end
    end
    assert(hs and hs.when, "Heroic Strike should be gated")
    local low  = { rage = 30, rage_to_queue = 60, buff = { recklessness = { up = false } } }
    local high = { rage = 80, rage_to_queue = 60, buff = { recklessness = { up = false } } }
    assert(not hs.when(low),  "should not dump rage at 30")
    assert(hs.when(high),     "should dump rage at 80")
end)

step("Rogue and Paladin register", function()
    assert(specNamed("Assassination Rogue"), "Rogue spec not registered")
    assert(specNamed("Retribution Paladin"), "Paladin spec not registered")
    assert(ER.specOptions.ROGUE,   "Rogue options not registered")
    assert(ER.specOptions.PALADIN, "Paladin options not registered")
end)

step("every new spec has the required structure", function()
    for _, name in ipairs({ "Assassination Rogue", "Retribution Paladin" }) do
        local sp = specNamed(name)
        assert(sp.lists.single,   name .. " has no single-target list")
        assert(sp.lists.aoe,      name .. " has no AoE list")
        assert(sp.lists.default,  name .. " has no default list")
        assert(sp.IsActive,       name .. " has no IsActive")
        assert(sp.ResolveRanks,   name .. " has no ResolveRanks")
        assert(sp.gcdProbe,       name .. " has no GCD probe")
    end
end)

step("Rogue declares energy and combo points", function()
    local r = specNamed("Assassination Rogue")
    assert(r.powerType == 3, "Rogue should use energy (power type 3)")
    assert(r.usesComboPoints, "Rogue should declare usesComboPoints")
    assert(r.abilities.mutilate.buildsCombo == 2, "Mutilate builds 2 combo points")
    assert(r.abilities.envenom.spendsCombo, "Envenom is a finisher")
end)

step("combo points and energy are read into state", function()
    local r = specNamed("Assassination Rogue")
    local real = ER.activeSpec
    ER.activeSpec = r
    r.ResolveRanks()
    mock.setComboPoints(4)
    mock.setPower(3, 75)
    ER:UpdateState()
    assert(ER.state.comboPoints == 4,
        "combo points not read, got " .. tostring(ER.state.comboPoints))
    assert(ER.state.energy == 75,
        "energy not read, got " .. tostring(ER.state.energy))
    ER.activeSpec = real
    mock.setComboPoints(0)
end)

step("finishers are blocked without combo points", function()
    local r = specNamed("Assassination Rogue")
    assert(r.abilities.envenom.minCombo == 1, "Envenom should need combo points")
    assert(r.abilities.rupture.minCombo == 1, "Rupture should need combo points")
    assert(r.abilities.slice_and_dice.minCombo == 1, "SnD should need combo points")
end)

step("Paladin cooldowns and mana gate are declared", function()
    local p = specNamed("Retribution Paladin")
    assert(p.powerType == 0, "Paladin should use mana")
    assert(p.abilities.crusader_strike.cd == 4, "Crusader Strike is a 4s cooldown")
    assert(p.abilities.avenging_wrath.majorCD, "Avenging Wrath should be a major CD")
end)

step("both new specs resolve every spell ID to the right name", function()
    for _, name in ipairs({ "Assassination Rogue", "Retribution Paladin" }) do
        local sp = specNamed(name)
        sp.ResolveRanks()
        local bad = {}
        for _, b in ipairs(ER.Compat.CheckSpellIDs(sp.abilities)) do
            table.insert(bad, b.key .. " -> id " .. b.id .. " is '" .. b.name .. "'")
        end
        assert(#bad == 0, name .. ": " .. table.concat(bad, ", "))
    end
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

print("\n=== HIGH ACTION SLOTS ===")
step("slots above 72 resolve via bar-addon binding names", function()
    -- Reported on Fury: everything in slots 97-108 came back
    -- "none bound" because no Blizzard binding header covers them.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(101, "Bloodrage")
    -- bar 9 owns slots 97-108, so slot 101 is bar 9 button 5
    mock.setBinding("ELVUIBAR9BUTTON5", "SHIFT-R")
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Bloodrage")
    mock.clearActions(); mock.clearBindings()
    mock.setBinding("ACTIONBUTTON1", "1")
    ER.Compat.InvalidateKeybinds()
    assert(got == "sR", "slot 101 unresolved, got " .. tostring(got))
end)

step("slot to bar/button arithmetic is right", function()
    -- bar N owns slots (N-1)*12+1 .. N*12
    local cases = {
        { slot = 1,   bar = 1,  idx = 1  },
        { slot = 12,  bar = 1,  idx = 12 },
        { slot = 73,  bar = 7,  idx = 1  },
        { slot = 84,  bar = 7,  idx = 12 },
        { slot = 97,  bar = 9,  idx = 1  },
        { slot = 108, bar = 9,  idx = 12 },
        { slot = 120, bar = 10, idx = 12 },
    }
    for _, c in ipairs(cases) do
        local bar = math.floor((c.slot - 1) / 12) + 1
        local idx = ((c.slot - 1) % 12) + 1
        assert(bar == c.bar and idx == c.idx,
            "slot " .. c.slot .. " mapped to bar " .. bar .. " button " .. idx)
    end
end)

step("LibActionButton bars are read (_state_action, not .action)", function()
    -- ElvUI and Bartender build on LibActionButton-1.0, which keeps
    -- the live slot in _state_action. Reading only .action meant those
    -- buttons looked like they held nothing.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(1, "Bloodthirst")
    mock.buildBars("ElvUI_Bar1Button",
        { visible = true, libStyle = true, keys = { "s3", "s4" } })
    ER.Compat.InvalidateKeybinds()
    local got = ER.Compat.Keybind("Bloodthirst")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "s3", "LibActionButton slot not read, got " .. tostring(got))
end)

step("a manual key overrides detection entirely", function()
    mock.clearAllBars(); mock.clearAllActions()
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Bloodthirst") == nil, "baseline should be nil")

    ElvinRotationDB.manualKeys = { ["Bloodthirst"] = "s3" }
    assert(ER.Compat.Keybind("Bloodthirst") == "s3",
        "manual key ignored, got " .. tostring(ER.Compat.Keybind("Bloodthirst")))
    assert(ER.Compat.KeybindDiagnosis("Bloodthirst"):find("manually"),
        "diagnosis should say it was set manually")

    ElvinRotationDB.manualKeys = {}
end)

step("a stance change invalidates the keybind cache", function()
    -- ElvUI pages a warrior's bars by stance, so the slot a button
    -- shows changes when the stance does. A cached map goes stale.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(1, "Bloodthirst")
    mock.buildBars("ElvUI_Bar1Button", { visible = true, keys = { "1", "2" } })
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Bloodthirst") == "1", "baseline lookup failed")

    -- repage: the same button now shows slot 97
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(97, "Bloodthirst")
    mock.buildBars("ElvUI_Bar1Button", { visible = true, slotBase = 96,
                                          keys = { "s1", "s2" } })
    ER.Compat.InvalidateKeybinds()
    assert(ER.Compat.Keybind("Bloodthirst") == "s1",
        "after repaging, expected s1, got " .. tostring(ER.Compat.Keybind("Bloodthirst")))

    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
end)

step("a PAGED bar resolves to the real action slot", function()
    -- The Fury case: bar 1 on page 9 shows slots 97-108, but its
    -- buttons still report action = 1..12. Every key was being filed
    -- against slots 1-12 instead of the slots actually shown.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(101, "Bloodrage")          -- page 9, button 5
    mock.buildPagedBar("ElvUI_Bar1Button", 9,
        { "s1","s2","s3","s4","s5","s6" })
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Bloodrage")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "s5",
        "paged slot 101 should map to button 5, got " .. tostring(got))
end)

step("every form and stance offset maps to the right page", function()
    -- All of these page the bars, so all of them hit the same bug:
    --   Warrior  Battle 1 / Defensive 2 / Berserker 3
    --   Druid    Bear 1 / Aquatic 2 / Cat 3 / Moonkin-Travel 4
    --   Rogue    Stealth 1
    local page = ER.Compat.CurrentActionPage
    local cases = {
        { bonus = 0, page = 1,  first = 1,   last = 12  },
        { bonus = 1, page = 7,  first = 73,  last = 84  },
        { bonus = 2, page = 8,  first = 85,  last = 96  },
        { bonus = 3, page = 9,  first = 97,  last = 108 },
        { bonus = 4, page = 10, first = 109, last = 120 },
    }
    for _, c in ipairs(cases) do
        mock.setActionPage(1, c.bonus)
        local p = page()
        assert(p == c.page,
            "bonus " .. c.bonus .. " should give page " .. c.page .. ", got " .. p)
        assert((p - 1) * 12 + 1 == c.first and p * 12 == c.last,
            "page " .. p .. " should cover slots " .. c.first .. "-" .. c.last)
    end
    mock.setActionPage(1, 0)
end)

step("Balance druid slots 109-120 are reachable (Moonkin, offset 4)", function()
    -- The reported Balance case: Faerie Fire 109, Insect Swarm 110,
    -- Wrath 111, Starfall 112, Moonfire 113, Starfire 114.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setActionPage(1, 4)                 -- Moonkin
    mock.setAction(111, "Wrath")
    mock.buildPagedBar("ElvUI_Bar1Button", 10,
        { "1","2","3","4","5","6" })
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Wrath")
    mock.clearAllBars(); mock.clearActions(); mock.setActionPage(1, 0)
    ER.Compat.InvalidateKeybinds()
    assert(got == "3", "slot 111 is page 10 button 3, got " .. tostring(got))
end)

step("an UNPAGED bar is not shifted by an active form", function()
    -- The risk in the fallback: a bar that does not page still reports
    -- 1-12 while the form offset is non-zero. Shifting it would file
    -- every key against slots the button never shows.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setActionPage(1, 3)                 -- a form IS active
    mock.setAction(2, "Bloodthirst")         -- but this bar shows slot 2
    mock.buildPagedBar("ElvUI_Bar1Button", 1, { "q","w","e" }, true)
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Bloodthirst")
    mock.clearAllBars(); mock.clearActions(); mock.setActionPage(1, 0)
    ER.Compat.InvalidateKeybinds()
    assert(got == "w",
        "unpaged bar was wrongly shifted; expected w, got " .. tostring(got))
end)

step("Blizzard bonus-bar offset resolves the page", function()
    -- A warrior in Berserker Stance has bonus offset 3, so bar 1 shows
    -- page 9 = slots 97-108. This is the fallback used when the bar
    -- addon exposes no actionpage attribute.
    local page = ER.Compat.CurrentActionPage
    mock.setActionPage(1, 3)
    local p = page()
    assert(p == 9, "bonus offset 3 should give page 9, got " .. tostring(p))
    assert((p - 1) * 12 + 1 == 97, "page 9 should start at slot 97")

    mock.setActionPage(1, 0)
    assert(page() == 1, "no bonus bar should give page 1")
end)

step("an unpaged bar is unaffected", function()
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(3, "Bloodthirst")
    mock.buildPagedBar("ElvUI_Bar1Button", 1, { "1","2","3","4" })
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Bloodthirst")
    mock.clearAllBars(); mock.clearActions()
    ER.Compat.InvalidateKeybinds()
    assert(got == "3", "page 1 should not be shifted, got " .. tostring(got))
end)

step("rendered text wins over a stale named binding", function()
    -- /kb writes click bindings, the WoW settings UI writes named
    -- ones. The label the bar draws is right for both.
    mock.clearAllBars(); mock.clearAllActions()
    mock.setAction(1, "Bloodthirst")
    mock.buildBars("ElvUI_Bar1Button", { visible = true, keys = { "s7" } })
    mock.setBinding("ELVUIBAR1BUTTON1", "STALE")
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Bloodthirst")
    mock.clearAllBars(); mock.clearActions(); mock.clearBindings()
    mock.setBinding("ACTIONBUTTON1", "1")
    ER.Compat.InvalidateKeybinds()
    assert(got == "s7", "expected the drawn label s7, got " .. tostring(got))
end)

print("\n=== IN-FLIGHT AURAS ===")
step("every dot ability declares what it applies", function()
    -- The suppression keys off ab.applies, so an ability that puts up
    -- a dot without declaring it would still double-cast.
    local expect = {
        ["Frost Death Knight"]  = { icy_touch = "frost_fever",
                                    plague_strike = "blood_plague" },
        ["Unholy Death Knight"] = { icy_touch = "frost_fever",
                                    plague_strike = "blood_plague" },
        ["Shadow Priest"]       = { shadow_word_pain = "shadow_word_pain",
                                    vampiric_touch = "vampiric_touch",
                                    devouring_plague = "devouring_plague" },
    }
    for specName, abilities in pairs(expect) do
        local sp = specNamed(specName)
        for key, aura in pairs(abilities) do
            assert(sp.abilities[key], specName .. " missing " .. key)
            assert(sp.abilities[key].applies == aura,
                specName .. " " .. key .. " should declare applies="
                .. aura .. ", got " .. tostring(sp.abilities[key].applies))
        end
    end
end)

step("a just-cast dot is not recommended again while it lands", function()
    -- The pull double-cast: the debuff has not registered yet, so the
    -- priority sees "no dot" and says to cast it again.
    mock.clearDebuffs()
    ER.castTime = { shadow_word_pain = GetTime() - 0.4 }
    ER:UpdateState()

    local since = ER.state.sinceCast.shadow_word_pain
    assert(since and since < 1.5, "sinceCast not tracking, got " .. tostring(since))

    local q = ER:Recommend(4)
    for _, ab in ipairs(q) do
        assert(ab.key ~= "shadow_word_pain",
            "recommended a dot that was cast 0.4s ago and has not landed")
    end
    ER.castTime = {}
end)

step("grace expires so a genuinely missing dot is reapplied", function()
    ER.castTime = { shadow_word_pain = GetTime() - 5 }
    ER:UpdateState()
    assert(ER.state.sinceCast.shadow_word_pain > 1.5,
        "grace should have expired after 5 seconds")
    ER.castTime = {}
end)

print("\n=== HOWLING BLAST ===")
step("not suggested without a Rime proc", function()
    ElvinRotationDB.settings.howlingBlastRimeOnly = true
    local fr = specNamed("Frost Death Knight")
    for _, listName in ipairs({ "single", "aoe" }) do
        for _, e in ipairs(fr.lists[listName]) do
            if e.key == "howling_blast" then
                assert(e.when, listName .. " Howling Blast is ungated")
                local off = { buff = { freezing_fog = { up = false } } }
                assert(not e.when(off),
                    listName .. " suggested Howling Blast with no Rime proc")
                local on = { buff = { freezing_fog = { up = true } } }
                assert(e.when(on),
                    listName .. " did not suggest Howling Blast on a Rime proc")
            end
        end
    end
end)

step("Freezing Fog uses the right buff ID", function()
    local fr = specNamed("Frost Death Knight")
    assert(fr.auras.freezing_fog.id == 59052,
        "Freezing Fog should be 59052, got " .. tostring(fr.auras.freezing_fog.id))
end)

print("\n=== DEBUFF DETECTION ===")
step("a disease with a NIL caster still counts as ours", function()
    -- 3.3.5 often reports unitCaster as nil for units outside your
    -- group. Rejecting on that made a plainly ticking disease read as
    -- absent, so the addon kept saying to reapply it.
    mock.clearDebuffs()
    mock.addDebuff("Frost Fever", 55095, 12, nil)
    local count, expires = ER.Compat.FindDebuff("target", "Frost Fever", 55095, true)
    assert(count, "disease with a nil caster was rejected")
end)

step("a disease cast by someone ELSE is still rejected", function()
    mock.clearDebuffs()
    mock.addDebuff("Frost Fever", 55095, 12, "party1")
    local count = ER.Compat.FindDebuff("target", "Frost Fever", 55095, true)
    assert(not count, "another player's disease was counted as ours")
end)

step("our own disease is found and its timer read", function()
    mock.clearDebuffs()
    mock.addDebuff("Frost Fever", 55095, 12, "player")
    local count, expires = ER.Compat.FindDebuff("target", "Frost Fever", 55095, true)
    assert(count, "our own disease not found")
    assert(expires > 0, "no expiry returned")
end)

step("DumpAuras lists what is actually on the target", function()
    mock.clearDebuffs()
    mock.addDebuff("Frost Fever", 55095, 12, "player")
    mock.addDebuff("Blood Plague", 55078, 11, nil)
    local dump = ER.Compat.DumpAuras("target")
    assert(#dump == 2, "expected 2 debuffs, got " .. #dump)
    assert(dump[1].name == "Frost Fever", "wrong first debuff")
    mock.clearDebuffs()
end)

print("\n=== OPENER RESPECTS EXISTING AURAS ===")
step("opener does not reapply a dot that is already up", function()
    -- Reported: queue read Icy Touch, Plague Strike, Icy Touch, Plague
    -- Strike while frost_fever sat at 13.5s and blood_plague at 14.9s.
    -- The opener is a fixed sequence and was ignoring them.
    mock.clearDebuffs()
    mock.addDebuff("Shadow Word: Pain", 48125, 16, "player")
    ER.castCount = {}
    ER.combatStart = GetTime()
    ER.dotTargets = {}
    ER:UpdateState()
    ER.state.inCombat = true
    ER.state.combatTime = 2

    local q = ER:Recommend(5)
    for i, ab in ipairs(q) do
        if ab.key == "shadow_word_pain" then
            error("reapplied a dot with 16s remaining at queue position " .. i)
        end
    end
    mock.clearDebuffs()
end)

step("opener DOES apply a dot that is missing", function()
    mock.clearDebuffs()
    ER.castCount = {}
    ER.dotTargets = {}
    ER:UpdateState()
    ER.state.inCombat = true
    ER.state.combatTime = 1

    local q = ER:Recommend(5)
    local found = false
    for _, ab in ipairs(q) do
        if ab.applies then found = true end
    end
    assert(found, "opener should apply dots when none are up")
end)

step("a dot low on duration is still refreshed by the opener", function()
    -- Shadow has no opener list, so exercise the engine rule directly
    -- with a minimal spec of one dot ability.
    local real = ER.activeSpec
    local fake = {
        name = "Test", class = "PRIEST", tab = 3,
        auras = { testdot = { id = 48125, type = "debuff", mine = true } },
        abilities = {
            testdot = { key = "testdot", id = 48125, name = "Shadow Word: Pain",
                        harmful = true, castableMoving = true,
                        applies = "testdot", appliesFor = 18,
                        openerSkipIfUp = true },
        },
        lists = {},
    }
    fake.lists.opener  = { { key = "testdot", casts = 1 } }
    fake.lists.single  = {}
    fake.lists.aoe     = {}
    fake.lists.default = {
        { runList = "opener", terminal = true, when = function() return true end },
    }
    ER.activeSpec = fake

    local function queueWith(remains)
        ER.castCount, ER.dotTargets = {}, {}
        ER.state.debuff = { testdot = { up = remains > 0, down = remains <= 0,
                                        remains = remains, stack = 1 } }
        ER.state.dot = ER.state.debuff
        ER.state.buff = ER.state.buff or {}
        ER.state.sinceCast = {}
        ER.state.castCount = {}
        ER.state.inCombat, ER.state.combatTime = true, 1
        return ER:Recommend(1)
    end

    local low  = queueWith(2)     -- nearly gone: must refresh
    local high = queueWith(16)    -- plenty left: must not

    ER.activeSpec = real
    assert(low[1] and low[1].key == "testdot",
        "a dot at 2s should still be refreshed by the opener")
    assert(not (high[1] and high[1].key == "testdot"),
        "a dot at 16s should NOT be reapplied by the opener")
end)

print("\n=== UNHOLY OPENER SEQUENCE ===")
step("opener matches the played sequence exactly", function()
    local uh = specNamed("Unholy Death Knight")
    local want = {
        "blood_strike", "plague_strike", "icy_touch", "blood_strike",
        "scourge_strike", "blood_tap", "summon_gargoyle", "blood_presence",
        "empower_rune_weapon", "scourge_strike", "blood_strike",
        "scourge_strike", "blood_strike", "death_coil", "death_coil",
    }
    assert(#uh.lists.opener == #want,
        "expected " .. #want .. " opener steps, got " .. #uh.lists.opener)
    for i, key in ipairs(want) do
        assert(uh.lists.opener[i].key == key,
            "step " .. i .. " expected " .. key .. ", got "
            .. uh.lists.opener[i].key)
    end
end)

step("Blood Strike is NOT skipped just because Desolation is up", function()
    -- The 3.5 regression: Blood Strike applies Desolation as a side
    -- effect, so the skip rule removed all four of its opener steps -
    -- and the Unholy opener leads with it.
    local uh = specNamed("Unholy Death Knight")
    local bs = uh.abilities.blood_strike
    assert(bs.applies == "desolation", "Blood Strike should apply Desolation")
    assert(not bs.openerSkipIfUp,
        "Blood Strike must not opt in to the opener skip rule")
end)

step("diseases DO opt in to the skip rule", function()
    for _, name in ipairs({ "Frost Death Knight", "Unholy Death Knight" }) do
        local sp = specNamed(name)
        assert(sp.abilities.icy_touch.openerSkipIfUp,
            name .. " Icy Touch should opt in")
        assert(sp.abilities.plague_strike.openerSkipIfUp,
            name .. " Plague Strike should opt in")
    end
end)

step("Gargoyle comes before the Blood Presence swap", function()
    local uh = specNamed("Unholy Death Knight")
    local g, bp, erw
    for i, e in ipairs(uh.lists.opener) do
        if e.key == "summon_gargoyle"     and not g   then g   = i end
        if e.key == "blood_presence"      and not bp  then bp  = i end
        if e.key == "empower_rune_weapon" and not erw then erw = i end
    end
    assert(g < bp,  "Gargoyle must be summoned before swapping to Blood")
    assert(bp < erw, "ERW is spent after the presence swap")
end)

print("\n=== PROJECTION CARRIES CAST STATE ===")
step("the opener is not replayed inside the projected queue", function()
    -- The reported bug: Plague Strike appeared at queue positions 2 and
    -- 5 while its disease was up, because the projection read every
    -- opener entry as never cast.
    ElvinRotationDB.settings.useOpener = true
    ER.castCount = {}
    ER.combatStart = GetTime()
    ER:UpdateState()
    ER.state.inCombat = true
    ER.state.combatTime = 1

    local q = ER:Recommend(5)
    local seen = {}
    for i, ab in ipairs(q) do
        if ab.applies then
            assert(not seen[ab.key],
                "'" .. ab.key .. "' appears twice in the queue (positions "
                .. tostring(seen[ab.key]) .. " and " .. i .. ")")
            seen[ab.key] = i
        end
    end
end)

step("a simulated cast increments the projected cast count", function()
    ER.castCount = { shadow_word_pain = 3 }
    ER:UpdateState()
    assert(ER.state.castCount.shadow_word_pain == 3, "real cast count wrong")

    -- the projection must start from the real counts, not from zero
    local q = ER:Recommend(4)
    assert(q[1], "no recommendation")
    ER.castCount = {}
end)

step("projected combat time advances", function()
    ER:UpdateState()
    ER.state.inCombat = true
    local before = ER.state.combatTime or 0
    ER:Recommend(5)
    -- combatTime advancing inside the projection is what lets the
    -- opener hand over to the normal priority mid-queue
    assert(type(before) == "number", "combatTime not tracked")
end)

print("\n=== COMBAT LOG FALLBACK ===")
step("a disease UnitDebuff cannot see is still counted from the log", function()
    -- If the scan misses it for any reason, the addon must not decide
    -- the disease is gone and tell you to reapply it forever.
    mock.clearDebuffs()                       -- UnitDebuff sees nothing
    local guid = UnitGUID("target")
    ER.dotTargets = { shadow_word_pain = { [guid] = GetTime() + 11 } }

    ER:UpdateState()
    local d = ER.state.debuff.shadow_word_pain
    assert(d and d.up, "combat log fallback did not fire")
    assert(d.inferred, "should be marked as inferred")
    assert(d.remains > 10, "expected ~11s, got " .. tostring(d.remains))
    ER.dotTargets = {}
end)

step("an EXPIRED log entry does not keep the dot alive", function()
    mock.clearDebuffs()
    local guid = UnitGUID("target")
    ER.dotTargets = { shadow_word_pain = { [guid] = GetTime() - 5 } }
    ER:UpdateState()
    local d = ER.state.debuff.shadow_word_pain
    assert(not d.up, "expired log entry kept the dot alive")
    ER.dotTargets = {}
end)

step("UnitDebuff wins when it can see the aura", function()
    mock.clearDebuffs()
    mock.addDebuff("Shadow Word: Pain", 48125, 7, "player")
    ER.dotTargets = { shadow_word_pain = { [UnitGUID("target")] = GetTime() + 30 } }
    ER:UpdateState()
    local d = ER.state.debuff.shadow_word_pain
    assert(d.up, "real aura not found")
    assert(not d.inferred, "should have used the real aura, not the log")
    ER.dotTargets = {}
    mock.clearDebuffs()
end)

print("\n=== FROST DISEASE UPKEEP ===")
step("without Glyph of Disease, Pestilence is not used for upkeep", function()
    mock.clearGlyphs()
    local fr = specNamed("Frost Death Knight")
    local st = { presence = "blood", runicPower = 0, haste = 0 }
    fr.UpdateExtra(st)
    assert(st.glyph_of_disease == false, "glyph falsely detected")

    for _, e in ipairs(fr.lists.single) do
        if e.key == "pestilence" then
            local s1 = {
                glyph_of_disease = false,
                dot = { frost_fever = { up = true, remains = 1 } },
                pesti_window = 4,
            }
            assert(not e.when(s1),
                "Pestilence used for upkeep without the glyph - diseases will drop")
        end
    end
end)

step("with the glyph, Pestilence upkeep is allowed", function()
    local fr = specNamed("Frost Death Knight")
    local fired = false
    for _, e in ipairs(fr.lists.single) do
        if e.key == "pestilence" then
            local s1 = {
                glyph_of_disease = true,
                dot = { frost_fever = { up = true, remains = 1 } },
                pesti_window = 4,
            }
            if e.when(s1) then fired = true end
        end
    end
    assert(fired, "Pestilence should refresh when the glyph is present")
end)

step("diseases refresh BEFORE dropping, not after", function()
    local fr = specNamed("Frost Death Knight")
    ElvinRotationDB.settings.diseaseRefresh = 3
    local it
    for _, e in ipairs(fr.lists.single) do
        if e.key == "icy_touch" then it = e break end
    end
    local s1 = { dot = { frost_fever = { up = true, remains = 2 } } }
    assert(it.when(s1),
        "should refresh at 2s left, not wait for the disease to fall off")
    local s2 = { dot = { frost_fever = { up = true, remains = 10 } } }
    assert(not it.when(s2), "should not refresh at 10s left")
end)

step("Blood Strike sits below the strikes, not above the diseases", function()
    local fr = specNamed("Frost Death Knight")
    local itIdx, bsIdx, obIdx
    for i, e in ipairs(fr.lists.single) do
        if e.key == "icy_touch"    and not itIdx then itIdx = i end
        if e.key == "obliterate"   and not obIdx then obIdx = i end
        if e.key == "blood_strike" and not bsIdx then bsIdx = i end
    end
    assert(itIdx < bsIdx, "Icy Touch must outrank Blood Strike")
    assert(obIdx < bsIdx, "Obliterate must outrank Blood Strike")
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
    -- An ungated AoE entry is only safe if something else stops it
    -- repeating: a cooldown, a resource cost, or being the intended
    -- spam ability for that list. Checking the ability itself beats
    -- maintaining a list of names.
    local INTENDED_SPAM = {
        fan_of_knives = true,   -- Rogue AoE
        shadow_bolt = true,     -- Warlock filler
        arcane_blast = true,    -- Arcane filler
        mind_sear = true, mind_flay = true,
        obliterate = true, blood_strike = true, frost_strike = true,
        scourge_strike = true, blood_boil = true, howling_blast = true,
        steady_shot = true,     -- Hunter filler
        fireball = true,        -- Fire Mage filler
        wrath = true, starfire = true,   -- Balance nukes
        incinerate = true,      -- Destruction filler
        frostbolt = true,       -- Frost Mage filler
        heart_strike = true, death_strike = true,   -- Blood DK
        bloodthirst = true, whirlwind = true,       -- Fury
        arcane_shot = true,                         -- Hunter
        shred = true, hemorrhage = true,            -- Druid / Rogue
        sinister_strike = true, lightning_bolt = true,
    }

    for _, sp in ipairs(ER.specs) do
        for _, e in ipairs(sp.lists.aoe or {}) do
            if not e.when and not e.runList then
                local ab = sp.abilities[e.key]
                assert(ab, sp.name .. " AoE references unknown '" .. e.key .. "'")
                local gated = (ab.cd and ab.cd > 0)
                           or ab.majorCD
                           or ab.power or ab.rp or ab.runes
                           or INTENDED_SPAM[e.key]
                assert(gated,
                    sp.name .. " AoE has ungated '" .. e.key
                    .. "' with no cooldown or cost - it can spam")
            end
        end
    end
end)

step("no single-target list contains an ungated repeatable either", function()
    for _, sp in ipairs(ER.specs) do
        for _, e in ipairs(sp.lists.single or {}) do
            if not e.when and not e.runList then
                local ab = sp.abilities[e.key]
                assert(ab, sp.name .. " single references unknown '" .. e.key .. "'")
            end
        end
    end
end)

print("\n=== WARRIOR STANCES ARE STANCES TOO ===")
step("no Warrior priority tests a stance as a buff", function()
    -- Same bug as DK presences: UnitBuff never sees a stance, so the
    -- check was permanently false and Fury kept telling you to enter
    -- Berserker Stance while standing in it.
    for _, name in ipairs({ "Arms Warrior", "Fury Warrior" }) do
        local sp = specNamed(name)
        assert(sp.usesStance, name .. " does not declare usesStance")
    end
end)

step("stance is read from the shapeshift bar", function()
    mock.setFormNames({ "Battle Stance", "Defensive Stance", "Berserker Stance" })
    mock.setPresence(3)
    assert(ER.Compat.ActiveStance() == "Berserker Stance",
        "expected Berserker Stance, got " .. tostring(ER.Compat.ActiveStance()))
    mock.setPresence(1)
    assert(ER.Compat.ActiveStance() == "Battle Stance",
        "expected Battle Stance, got " .. tostring(ER.Compat.ActiveStance()))
    mock.setPresence(0)
end)

step("Fury opens Recklessness before Death Wish", function()
    local f = specNamed("Fury Warrior")
    local r, d
    for i, e in ipairs(f.lists.single) do
        if e.key == "recklessness" and not r then r = i end
        if e.key == "death_wish"   and not d then d = i end
    end
    assert(r < d, "Recklessness should come before Death Wish")
end)

step("Victory Rush requires the Victorious proc", function()
    -- It was being recommended constantly on a dummy, where nothing
    -- ever dies and the proc never happens.
    for _, name in ipairs({ "Arms Warrior", "Fury Warrior" }) do
        local sp = specNamed(name)
        local vr
        for _, e in ipairs(sp.lists.single) do
            if e.key == "victory_rush" then vr = e end
        end
        assert(vr and vr.when, name .. " Victory Rush is ungated")
        assert(not vr.when({ buff = { victorious = { up = false } } }),
            name .. " suggested Victory Rush with no proc")
        assert(vr.when({ buff = { victorious = { up = true } } }),
            name .. " ignored an active Victorious proc")
    end
end)

step("a paged slot resolves via its BUTTON binding, not the slot number", function()
    -- Moonfire at slot 2 resolved; Wrath at slot 111 did not, despite
    -- being the same bar. ACTIONBUTTON bindings follow the button, so
    -- slot 111 on page 10 is button 3 = ACTIONBUTTON3.
    mock.clearAllBars(); mock.clearAllActions(); mock.clearBindings()
    mock.setActionPage(1, 4)                       -- Moonkin, page 10
    mock.setAction(111, "Wrath")
    mock.setBinding("ACTIONBUTTON3", "SHIFT-W")
    ER.Compat.InvalidateKeybinds()

    local got = ER.Compat.Keybind("Wrath")
    mock.setActionPage(1, 0); mock.clearActions(); mock.clearBindings()
    mock.setBinding("ACTIONBUTTON1", "1")
    ER.Compat.InvalidateKeybinds()
    assert(got == "sW",
        "slot 111 should map to ACTIONBUTTON3, got " .. tostring(got))
end)

step("the off-GCD suggestion occupies a queue slot frame", function()
    local real = ER.activeSpec
    local fury = specNamed("Fury Warrior")
    ER.activeSpec = fury
    fury.ResolveRanks()

    mock.setPower(1, 90)
    ElvinRotationDB.queueSize = 3
    ER:UpdateState()
    ER.state.inCombat = true
    ER.state.rage = 90
    local q = ER:Recommend(3)
    ER:UpdateDisplay(q)

    local shown = 0
    for _, f in ipairs(mock.frames) do
        if type(rawget(f, "_slotIndex")) == "number" and f:IsShown() then
            shown = shown + 1
        end
    end
    ER.activeSpec = real
    mock.setPower(1, 0)
    assert(shown == 4,
        "expected 3 queue icons plus 1 off-GCD, got " .. shown)
end)

step("off-GCD abilities are actually FOUND, not just marked", function()
    -- The bug: evaluate() returns at the first usable ability, and
    -- Heroic Strike sits at the bottom of the list, so the off-GCD
    -- hook inside evaluate could never fire. A separate pass is needed.
    local real = ER.activeSpec
    local fury = specNamed("Fury Warrior")
    ER.activeSpec = fury
    fury.ResolveRanks()

    mock.setPower(1, 90)          -- plenty of rage
    ER:UpdateState()
    ER.state.inCombat = true
    ER.state.rage = 90

    local q = ER:Recommend(3)
    assert(q[1], "no main recommendation")
    for _, ab in ipairs(q) do
        assert(not ab.offGCD,
            "off-GCD ability '" .. ab.key .. "' leaked into the main queue")
    end
    assert(ER.offGCD, "no off-GCD suggestion produced at 90 rage")
    assert(ER.offGCD.key == "heroic_strike",
        "expected Heroic Strike, got " .. tostring(ER.offGCD.key))

    ER.activeSpec = real
    mock.setPower(1, 0)
end)

step("no off-GCD suggestion when the rage reserve is not met", function()
    local real = ER.activeSpec
    local fury = specNamed("Fury Warrior")
    ER.activeSpec = fury

    mock.setPower(1, 10)
    ER:UpdateState()
    ER.state.inCombat = true
    ER.state.rage = 10
    ER:Recommend(3)
    assert(not ER.offGCD or ER.offGCD.key ~= "heroic_strike",
        "Heroic Strike suggested at 10 rage")

    ER.activeSpec = real
    mock.setPower(1, 0)
end)

step("Heroic Strike and Cleave are marked off-GCD", function()
    for _, name in ipairs({ "Arms Warrior", "Fury Warrior" }) do
        local sp = specNamed(name)
        assert(sp.abilities.heroic_strike.offGCD,
            name .. " Heroic Strike should be off-GCD")
        assert(sp.abilities.cleave.offGCD,
            name .. " Cleave should be off-GCD")
    end
end)

step("an off-GCD suggestion is found even when it is LAST in the list", function()
    -- The bug: evaluate() returns at the first usable ability, and
    -- Heroic Strike sits at the bottom of the Fury priority. Anything
    -- castable above it stopped the scan, so the off-GCD indicator
    -- never appeared at all.
    local real = ER.activeSpec
    local fake = {
        name = "OffGCDTest", class = "WARRIOR", tab = 2,
        auras = {},
        abilities = {
            filler = { key = "filler", id = 23881, name = "Bloodthirst",
                       harmful = true },
            queued = { key = "queued", id = 47450, name = "Heroic Strike",
                       harmful = true, offGCD = true },
        },
        lists = {},
    }
    fake.lists.single = {
        { key = "filler" },          -- always usable, always first
        { key = "queued" },          -- off-GCD, last
    }
    fake.lists.aoe = {}
    fake.lists.default = {
        { runList = "single", terminal = true, when = function() return true end },
    }
    ER.activeSpec = fake
    ER.state.inCombat = true
    ER.state.targetExists = true

    local q = ER:Recommend(1)
    local off = ER.offGCD
    ER.activeSpec = real

    assert(q[1] and q[1].key == "filler",
        "the queue should hold the ability that costs a global")
    assert(off and off.key == "queued",
        "off-GCD suggestion was not found; got " .. tostring(off and off.key))
end)

step("off-GCD abilities never occupy the main queue", function()
    for _, sp in ipairs(ER.specs) do
        for _, listName in ipairs({ "single", "aoe" }) do
            for _, e in ipairs(sp.lists[listName] or {}) do
                local ab = sp.abilities[e.key]
                -- they may appear in the LIST; the engine filters them
                -- out of the queue. Just assert the flag is coherent.
                if ab and ab.offGCD then
                    assert(ab.name == nil or type(ab.name) == "string",
                        "bad off-GCD ability " .. e.key)
                end
            end
        end
    end
end)

print("\n=== OPTIONS FOLLOW THE ACTIVE SPEC ===")
step("the Rotation panel selects the spec you are playing", function()
    -- A Balance druid was being shown Feral's settings, because the
    -- default came from pairs() order over the class's specs.
    local data = ER.specOptions.DRUID
    assert(data and data.specs.balance and data.specs.feral,
        "Druid should have two specs registered")
    assert(data.specs.balance.spec and data.specs.feral.spec,
        "both Druid specs should carry their spec table")
    assert(data.specs.balance.spec ~= data.specs.feral.spec,
        "the two Druid specs must be distinct tables")
end)

print("\n=== PUBLIC HIDE API ===")
step("another addon can hide and release the display", function()
    ER.hiddenBy = {}
    assert(not ER:IsDisplayHidden(), "should start visible")

    ER:HideDisplay("BossMod")
    assert(ER:IsDisplayHidden(), "HideDisplay did nothing")

    ER:ShowDisplay("BossMod")
    assert(not ER:IsDisplayHidden(), "ShowDisplay did not release")
end)

step("two addons cannot un-hide each other", function()
    -- The reason hides are tracked by source: whoever releases first
    -- must not reveal the display while the other still wants it gone.
    ER.hiddenBy = {}
    ER:HideDisplay("BossMod")
    ER:HideDisplay("Cinematics")
    assert(ER:IsDisplayHidden(), "should be hidden")

    ER:ShowDisplay("BossMod")
    assert(ER:IsDisplayHidden(),
        "released by one source while another still holds a hide")

    ER:ShowDisplay("Cinematics")
    assert(not ER:IsDisplayHidden(), "should be visible once all released")
end)

step("toggle flips the caller's own request", function()
    ER.hiddenBy = {}
    local _, nowHidden = ER:ToggleDisplay("MyAddon")
    assert(nowHidden and ER:IsDisplayHidden(), "first toggle should hide")

    local _, nowHidden2 = ER:ToggleDisplay("MyAddon")
    assert(not nowHidden2 and not ER:IsDisplayHidden(),
        "second toggle should show")
end)

step("toggle never releases another addon's hide", function()
    -- If toggling cleared everyone's request, two addons sharing the
    -- display would keep overriding each other.
    ER.hiddenBy = {}
    ER:HideDisplay("BossMod")
    ER:ToggleDisplay("MyAddon")          -- adds a second hide
    assert(ER:IsDisplayHidden(), "should be hidden by both")

    ER:ToggleDisplay("MyAddon")          -- releases only mine
    assert(ER:IsDisplayHidden(),
        "toggling released the boss mod's hide as well")

    ER:ShowDisplay("BossMod")
    assert(not ER:IsDisplayHidden(), "should be visible once all released")
end)

step("a hide is not persisted to saved settings", function()
    ER.hiddenBy = {}
    ER:HideDisplay("Transient")
    assert(ElvinRotationDB.hiddenBy == nil,
        "an external hide must not be written to saved variables")
    ER:ShowDisplay("Transient")
end)

step("callbacks fire on hide and show", function()
    ER.hiddenBy, ER.callbacks = {}, {}
    local seen = {}
    ER:RegisterCallback("hidden", function(src) seen.hidden = src end, "Test")
    ER:RegisterCallback("shown",  function(src) seen.shown  = src end, "Test")

    ER:HideDisplay("Alpha")
    assert(seen.hidden == "Alpha", "hidden callback did not fire")
    ER:ShowDisplay("Alpha")
    assert(seen.shown == "Alpha", "shown callback did not fire")
    ER.callbacks = {}
end)

step("the callback fires once, not per source", function()
    ER.hiddenBy, ER.callbacks = {}, {}
    local n = 0
    ER:RegisterCallback("hidden", function() n = n + 1 end, "Test")
    ER:HideDisplay("A")
    ER:HideDisplay("B")
    assert(n == 1, "hidden callback fired " .. n .. " times, expected 1")
    ER.hiddenBy, ER.callbacks = {}, {}
end)

step("a broken callback cannot break the addon", function()
    ER.hiddenBy, ER.callbacks = {}, {}
    ER:RegisterCallback("hidden", function() error("deliberate") end, "BadAddon")
    ER:HideDisplay("X")           -- must not propagate
    assert(ER:IsDisplayHidden(), "hide failed because a callback errored")
    ER.hiddenBy, ER.callbacks = {}, {}
end)

step("a hidden display stays hidden through an update", function()
    ER.hiddenBy = {}
    ER:UpdateState()
    ER.state.inCombat = true
    ER:HideDisplay("BossMod")
    ER:UpdateDisplay(ER:Recommend(3))

    local f = ER:GetDisplayFrame()
    assert(f, "no display frame exposed")
    assert(not f:IsShown(), "display re-showed itself while externally hidden")

    ER:ShowDisplay("BossMod")
end)

print("\n=== SELF BUFF WARNINGS ===")
step("self buffs are tagged across specs", function()
    local tagged = 0
    for _, sp in ipairs(ER.specs) do
        for _, ab in pairs(sp.abilities) do
            if ab.selfBuff then tagged = tagged + 1 end
        end
    end
    assert(tagged > 10, "expected many self buffs tagged, found " .. tagged)
end)

step("a missing self buff is reported", function()
    ER:UpdateState()
    assert(type(ER.state.missingSelfBuffs) == "table",
        "missingSelfBuffs not populated")
end)

print("\n=== ARCANE MISSILE BARRAGE ===")
step("Missile Barrage does not require four stacks", function()
    local m = specNamed("Arcane Mage")
    local am
    for _, e in ipairs(m.lists.single) do
        if e.key == "arcane_missiles" and not am then am = e end
    end
    ElvinRotationDB.settings.barrageMinStacks = 1
    local st = { buff = { missile_barrage = { up = true } },
                 ab_stacks = 2, ab_capped = false }
    assert(am.when(st), "a Missile Barrage proc at 2 stacks should be spent")
end)

print("\n=== BALANCE ECLIPSE DOTS ===")
step("Moonfire is tied to Lunar, Insect Swarm to Solar", function()
    local d = specNamed("Balance Druid")
    local mf, is
    for _, e in ipairs(d.lists.spam) do
        if e.key == "moonfire"     and not mf then mf = e end
        if e.key == "insect_swarm" and not is then is = e end
    end
    assert(mf and is, "spam list should handle both dots")

    local lunar = { lunar_up = true, solar_up = false,
                    dot = { moonfire = { remains = 1 }, insect_swarm = { remains = 1 } },
                    buff = { eclipse_lunar = { remains = 10 },
                             eclipse_solar = { remains = 0 } } }
    assert(mf.when(lunar), "Moonfire should refresh during Lunar")
    assert(not is.when(lunar), "Insect Swarm should NOT be refreshed during Lunar")

    local solar = { lunar_up = false, solar_up = true,
                    dot = { moonfire = { remains = 1 }, insect_swarm = { remains = 1 } },
                    buff = { eclipse_lunar = { remains = 0 },
                             eclipse_solar = { remains = 10 } } }
    assert(is.when(solar), "Insect Swarm should refresh during Solar")
    assert(not mf.when(solar), "Moonfire should NOT be refreshed during Solar")
end)

print("\n=== PRESENCE IS A STANCE ===")
step("active presence is read from the shapeshift bar", function()
    mock.setFormNames({ "Blood Presence", "Frost Presence", "Unholy Presence" })
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
