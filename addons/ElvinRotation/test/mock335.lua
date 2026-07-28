--[[ test/mock335.lua
     A stub of the 3.3.5a client API - and ONLY the 3.3.5a API.

     Any function the addon calls that isn't defined here will fail
     exactly the way it does in-game ("attempt to call global 'X'").
     That is the point: this catches Cataclysm+ API leakage offline
     instead of one /reload at a time.

     Deliberately ABSENT (added after 3.3.5), do not add these:
       UnitSpellHaste            4.0.1
       GetSpellBookItemName      4.0.1
       CombatLogGetCurrentEventInfo  8.0
       C_Timer / C_Spell / C_Container / C_AddOns   (various)
       GetSpellCharges           5.0
       UnitAura filter tuples with raid flags       4.2
--]]

local M = {}

-- ---------- state the mock pretends to have ----------
local clock = 10000
local player = {
    class = "PRIEST",
    mana = 18000, manaMax = 24000,
    talents = { 0, 5, 66 },          -- shadow-specced
    haste = 0,
    spellPower = 1800,
    combat = true,
}
local spellbook = {
    { name = "Shadow Word: Pain",  id = 48125, cast = 0,    cd = 0   },
    { name = "Mind Blast",         id = 48127, cast = 1500, cd = 8   },
    { name = "Mind Flay",          id = 48156, cast = 0,    cd = 0   },
    { name = "Vampiric Touch",     id = 48160, cast = 1500, cd = 0   },
    { name = "Devouring Plague",   id = 48300, cast = 0,    cd = 0   },
    { name = "Shadow Word: Death", id = 48158, cast = 0,    cd = 12  },
    { name = "Shadowfiend",        id = 34433, cast = 0,    cd = 300 },
    { name = "Inner Focus",        id = 14751, cast = 0,    cd = 180 },
    { name = "Inner Fire",         id = 48168, cast = 0,    cd = 0   },
    { name = "Vampiric Embrace",   id = 15286, cast = 0,    cd = 0   },
    { name = "Shadowform",         id = 15473, cast = 0,    cd = 0   },
    { name = "Dispersion",         id = 47585, cast = 0,    cd = 180 },
}
-- Frost DK spells, so the DK module's IDs can be checked offline.
for _, e in ipairs({
    { name = "Icy Touch",           id = 49909 },
    { name = "Plague Strike",       id = 49921 },
    { name = "Obliterate",          id = 51425 },
    { name = "Blood Strike",        id = 49930 },
    { name = "Frost Strike",        id = 55268 },
    { name = "Howling Blast",       id = 51411 },
    { name = "Pestilence",          id = 50842 },
    { name = "Blood Tap",           id = 45529 },
    { name = "Unbreakable Armor",   id = 51271 },
    { name = "Empower Rune Weapon", id = 47568 },
    { name = "Horn of Winter",      id = 57623 },
    { name = "Raise Dead",          id = 46584 },
    { name = "Death Strike",        id = 49924 },
    { name = "Mind Freeze",         id = 47528 },
    { name = "Frost Presence",      id = 48263 },
    { name = "Blood Presence",      id = 48266 },
    { name = "Summon Gargoyle",     id = 49206 },
    -- Unholy
    { name = "Scourge Strike",      id = 55271 },
    { name = "Death Coil",          id = 49895 },
    { name = "Summon Gargoyle",     id = 49206 },
    { name = "Ghoul Frenzy",        id = 63560 },
    { name = "Army of the Dead",    id = 42650 },
    { name = "Blood Boil",          id = 49941 },
    { name = "Death and Decay",     id = 49938 },
    { name = "Unholy Presence",     id = 48265 },
    { name = "Pestilence",          id = 50842 },
    { name = "Bone Shield",         id = 49222 },
    { name = "Mind Sear",           id = 53023 },
}) do
    table.insert(spellbook, { name = e.name, id = e.id, cast = 0, cd = 0 })
end

local byName, byID = {}, {}
for _, s in ipairs(spellbook) do byName[s.name] = s ; byID[s.id] = s end

local playerBuffs  = { { name = "Shadowform", id = 15473, count = 1, expires = 0, duration = 0 } }
local targetDebuffs = {}

M.player, M.playerBuffs, M.targetDebuffs, M.spellbook = player, playerBuffs, targetDebuffs, spellbook
-- Fire an event at every frame that has a handler, over a SNAPSHOT of
-- the list: handlers create frames, and iterating the live list made
-- init run more than once.
function M.fireEvent(event, arg1)
    local snapshot = {}
    for i, f in ipairs(M.frames or {}) do snapshot[i] = f end
    for _, f in ipairs(snapshot) do
        local h = f.GetScript and f:GetScript("OnEvent")
        if h then h(f, event, arg1) end
    end
end

function M.advance(dt) clock = clock + dt end

-- simulate casting a spell: start its cooldown
function M.cast(name)
    local s = byName[name]
    if s and s.cd and s.cd > 0 then
        s.cdStart, s.cdDuration = clock, s.cd
    end
end
function M.now() return clock end

-- ---------- widget stubs ----------
local function newRegion()
    local r = {}
    local noop = function() return r end
    r.GetObjectType = function() return "Texture" end
    r.GetRegions = function() return end
    r.IsShown = function() return true end
    r.IsVisible = function() return true end
    r.GetChecked = function() return false end
    r.GetValue = function() return 0 end
    r.GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end
    setmetatable(r, { __index = function(t, k)
        t[k] = noop
        return noop
    end })
    return r
end

local frames = {}
function CreateFrame(kind, name, parent, template)
    local f = newRegion()
    f.CreateTexture    = function() return newRegion() end
    f.CreateFontString = function() return newRegion() end
    f.SetScript = function(self, ev, fn) self["_" .. ev] = fn ; return self end
    f.GetScript = function(self, ev) return self["_" .. ev] end
    f.RegisterEvent = function() end
    f.UnregisterEvent = function() end
    f.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
    -- Track shown state so display logic can actually be asserted.
    f._shown = true
    f.Show    = function(self) (self or f)._shown = true  end
    f.Hide    = function(self) (self or f)._shown = false end
    f.IsShown = function(self) return ((self or f)._shown) and true or false end
    f.IsVisible = function(self) return ((self or f)._shown) and true or false end
    f.SetMinMaxValues = function() end
    f.SetValueStep = function() end
    f.SetValue = function() end
    f.SetChecked = function() end
    f.GetChecked = function() return false end
    f.SetBackdrop = function() end
    f.SetFrameStrata = function() end
    table.insert(frames, f)
    if name then
        _G[name] = f
        -- OptionsSliderTemplate creates these named children
        for _, suffix in ipairs({ "Low", "High", "Text" }) do
            _G[name .. suffix] = newRegion()
        end
    end
    return f
end
M.frames = frames

-- Cooldown widget
local cdCalls = {}
function CooldownFrame_SetTimer(frame, start, duration, enable)
    frame._cd = { start = start, duration = duration, enable = enable }
    table.insert(cdCalls, frame._cd)
end
function M.lastCooldownCall() return cdCalls[#cdCalls] end
function M.clearCooldownCalls() cdCalls = {} end

UIParent = newRegion()
function UIDropDownMenu_Initialize(f, fn) f._init = fn ; if fn then pcall(fn) end end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) end
function UIDropDownMenu_SetWidth(f, w) end
function UIDropDownMenu_SetSelectedValue(f, v) f._value = v end
GameTooltip = newRegion()
GameFontNormalSmall = newRegion()
GameFontNormal = newRegion()
DEFAULT_CHAT_FRAME = { AddMessage = function(self, m) print("  [chat] " .. m) end }
SlashCmdList = {}
BOOKTYPE_SPELL = "spell"
CR_HASTE_SPELL = 20

-- ---------- 3.3.5 API ----------
function GetTime() return clock end

function GetSpellInfo(idOrName)
    local s = byID[idOrName] or byName[idOrName]
    if not s then return nil end
    local cast = s.cast
    if cast > 0 then cast = cast / (1 + player.haste / 100) end
    return s.name, "Rank 1", "Interface\\Icons\\" .. s.name, cast, 0, 30, s.id
end

function GetSpellName(index, bookType)
    local s = spellbook[index]
    if not s then return nil end
    return s.name, "Rank 1"
end

function GetSpellLink(index, bookType)
    local s = spellbook[index]
    if not s then return nil end
    return "|cff71d5ff|Hspell:" .. s.id .. "|h[" .. s.name .. "]|h|r"
end

function GetSpellCooldown(nameOrIndex)
    local s = byName[nameOrIndex] or byID[nameOrIndex]
    if not s then return 0, 0, 1 end
    return s.cdStart or 0, s.cdDuration or 0, 1
end

function IsUsableSpell(name)
    if not byName[name] then return nil, nil end
    return true, false
end

function GetSpellBonusDamage(school) return player.spellPower end
function GetCombatRatingBonus(rating) return 0 end
function GetNetStats() return 0, 0, 120 end   -- NOTE: only 3 returns
function GetItemCooldown(id) return 0, 0, 1 end

function UnitClass(u) return "Priest", player.class end
function UnitMana(u) return player.mana end
function UnitManaMax(u) return player.manaMax end
function UnitAffectingCombat(u) return player.combat end
local shapeform = 0
function GetShapeshiftForm() return shapeform end
function GetShapeshiftFormInfo(i)
    local names = { "Blood Presence", "Frost Presence", "Unholy Presence" }
    if not names[i] then return nil end
    return "icon", names[i], (i == shapeform), true
end
function M.setPresence(i) shapeform = i or 0 end

local hasPet = false
function M.setPet(v) hasPet = v and true or false end
function UnitExists(u)
    if u == "pet" then return hasPet end
    return u == "player" or u == "target"
end
function UnitCanAttack(a, b) return true end
function UnitIsDead(u) return false end
function UnitHealth(u) return 500000 end
function UnitHealthMax(u) return 1000000 end
function UnitGUID(u) return "0xTEST" .. u end
function UnitName(u) return u == "target" and "Training Dummy" or "Tester" end
function UnitIsUnit(a, b) return a == b end
function UnitLevel(u) return 80 end
local playerSpeed = 0
function GetUnitSpeed(u) return playerSpeed end
function M.setMoving(v) playerSpeed = v and 7 or 0 end
function GetPlayerMapPosition(u) return 0.5, 0.5 end

local casting, channeling = nil, nil
function M.setCasting(name, startS, endS)
    casting = name and { name, nil, nil, nil, startS * 1000, endS * 1000 } or nil
end
function M.setChanneling(name, startS, endS)
    channeling = name and { name, nil, nil, nil, startS * 1000, endS * 1000 } or nil
end
function UnitCastingInfo(u)
    if not casting then return nil end
    return casting[1], casting[2], casting[3], casting[4], casting[5], casting[6]
end
function UnitChannelInfo(u)
    if not channeling then return nil end
    return channeling[1], channeling[2], channeling[3], channeling[4],
           channeling[5], channeling[6]
end

local function auraAt(list, i)
    local a = list[i]
    if not a then return nil end
    return a.name, "", "icon", a.count, nil, a.duration, a.expires,
           a.caster or "player", false, false, a.id
end
function UnitBuff(u, i)   return auraAt(playerBuffs, i) end
function UnitDebuff(u, i) return auraAt(targetDebuffs, i) end

-- action bars: put a few spells on slots 1..12
local actions = { [1]="Mind Flay", [2]="Mind Blast", [3]="Shadow Word: Pain", [14]="Mind Blast",
                  [4]="Vampiric Touch", [5]="Devouring Plague", [6]="Shadowfiend" }
function GetActionInfo(slot)
    local n = actions[slot]
    if not n then return nil end
    if type(n) == "table" and n.macro then return "macro", n.macro end
    return "spell", byName[n].id
end
local bindings = { ACTIONBUTTON1="1", ACTIONBUTTON2="2", ACTIONBUTTON3="3",
                   ACTIONBUTTON4="SHIFT-4", ACTIONBUTTON5="5", ACTIONBUTTON6="CTRL-6" }
function GetBindingKey(b) return bindings[b] end
function M.setBinding(b, k) bindings[b] = k end
RANGE_INDICATOR = "\226\128\162"

-- Simulate a bar addon (Bartender4-style names) having already drawn
-- its buttons with HotKey fontstrings. This is what Keybind reads.
local hotkeys = { "1", "2", "3", "SHIFT-4", "5", "CTRL-6" }
function M.buildBars(prefix, opts)
    prefix = prefix or "BT4Button"
    opts = opts or {}
    local keys = opts.keys or hotkeys
    local vis  = (opts.visible ~= false)
    local base = opts.slotBase or 0
    for i = 1, 12 do
        local btn = { action = base + i, IsVisible = function() return vis end }
        _G[prefix .. i] = btn
        local txt = keys[i]
        _G[prefix .. i .. "HotKey"] = { GetText = function() return txt or "" end }
    end
end

-- Every prefix any test creates, so a test can start from clean.
local ALL_TEST_PREFIXES = {
    "ActionButton", "BT4Button", "ElvUI_Bar1Button", "ElvUI_Bar2Button",
    "SomeWeirdBarAddonButton", "WhateverElvUICallsIt",
    "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
}

function M.clearAllBars()
    for _, p in ipairs(ALL_TEST_PREFIXES) do
        for i = 1, 12 do
            _G[p .. i], _G[p .. i .. "HotKey"] = nil, nil
        end
    end
end

function M.clearBars(prefix)
    for i = 1, 12 do
        _G[prefix .. i], _G[prefix .. i .. "HotKey"] = nil, nil
    end
end

-- macros
local macros = {}
function M.setMacro(index, body, slot)
    macros[index] = body
    actions[slot] = { macro = index }
end
function M.setAction(slot, spellName) actions[slot] = spellName end
function M.clearAllActions() for k in pairs(actions) do actions[k] = nil end end
function M.clearActions()
    for k in pairs(actions) do actions[k] = nil end
    actions[1]="Mind Flay"; actions[2]="Mind Blast"; actions[3]="Shadow Word: Pain"
    actions[4]="Vampiric Touch"; actions[5]="Devouring Plague"; actions[6]="Shadowfiend"; actions[14]="Mind Blast"
end
function GetMacroBody(i) return macros[i] end
function GetActionTexture(slot)
    local n = actions[slot]
    if not n then return nil end
    if type(n) == "table" and n.macro then return n.tex end
    return "Interface\\Icons\\" .. n
end
function M.setMacroWithIcon(index, body, slot, tex)
    macros[index] = body
    actions[slot] = { macro = index, tex = tex }
end

-- Runes: slots 1-2 blood, 3-4 unholy, 5-6 frost. Type 4 = death.
local runes = {}
for i = 1, 6 do
    runes[i] = { rtype = (i <= 2 and 1) or (i <= 4 and 2) or 3, start = 0, dur = 0 }
end
function GetRuneCooldown(i)
    local r = runes[i]
    if not r then return 0, 0, true end
    local ready = (r.start == 0) or (clock >= r.start + r.dur)
    return r.start, r.dur, ready
end
function GetRuneType(i) return runes[i] and runes[i].rtype or 1 end
local offhand = false
function OffhandHasWeapon() return offhand and 1 or nil end
function M.setDualWield(v) offhand = v and true or false end
function M.spendRune(i, dur)
    runes[i].start, runes[i].dur = clock, dur or 10
end
function M.setRuneType(i, t) runes[i].rtype = t end
function M.resetRunes()
    for i = 1, 6 do
        runes[i].start, runes[i].dur = 0, 0
        runes[i].rtype = (i <= 2 and 1) or (i <= 4 and 2) or 3
    end
end

local power = { [6] = 0 }
function UnitPower(u, t) return power[t] or 0 end
function UnitPowerMax(u, t) return t == 6 and 130 or 0 end
function M.setRunicPower(v) power[6] = v end

-- glyphs
local glyphs = {}
function GetGlyphSocketInfo(i)
    local g = glyphs[i]
    if not g then return nil end
    return true, 1, 1, g
end
function M.setGlyph(i, spellID) glyphs[i] = spellID end
function M.clearGlyphs() for i = 1, 6 do glyphs[i] = nil end end

function GetTalentTabInfo(tab)
    return "Tab" .. tab, "icon", player.talents[tab] or 0
end
function GetTalentInfo(tab, index)
    return "Talent", "icon", 1, 1, (index <= 3 and 3 or 0), 5
end

return M
