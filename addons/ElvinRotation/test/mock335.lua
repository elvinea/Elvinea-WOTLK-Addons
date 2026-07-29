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
    -- Rogue
    { name = "Mutilate",            id = 48666 },
    { name = "Envenom",             id = 57993 },
    { name = "Rupture",             id = 48672 },
    { name = "Slice and Dice",      id = 6774  },
    { name = "Expose Armor",        id = 48669 },
    { name = "Hunger for Blood",    id = 51662 },
    { name = "Garrote",             id = 48676 },
    { name = "Ambush",              id = 48691 },
    { name = "Fan of Knives",       id = 51723 },
    { name = "Cold Blood",          id = 14177 },
    { name = "Kick",                id = 1766  },
    { name = "Stealth",             id = 1787  },
    -- Paladin
    { name = "Crusader Strike",     id = 35395 },
    { name = "Divine Storm",        id = 53385 },
    { name = "Judgement of Wisdom", id = 53408 },
    { name = "Judgement of Light",  id = 20271 },
    { name = "Consecration",        id = 48819 },
    { name = "Exorcism",            id = 48801 },
    { name = "Hammer of Wrath",     id = 48806 },
    { name = "Holy Wrath",          id = 48817 },
    { name = "Avenging Wrath",      id = 31884 },
    { name = "Divine Plea",         id = 54428 },
    { name = "Seal of Vengeance",   id = 31801 },
    { name = "Seal of Command",     id = 20375 },
    -- Warlock
    { name = "Corruption",             id = 47813 },
    { name = "Unstable Affliction",    id = 47843 },
    { name = "Haunt",                  id = 59164 },
    { name = "Curse of Agony",         id = 47864 },
    { name = "Shadow Bolt",            id = 47809 },
    { name = "Drain Soul",             id = 47855 },
    { name = "Life Tap",               id = 57946 },
    { name = "Fel Armor",              id = 47893 },
    { name = "Shadowflame",            id = 61291 },
    { name = "Seed of Corruption",     id = 47836 },
    { name = "Drain Life",             id = 47857 },
    { name = "Death Coil",             id = 47860 },
    -- Mage
    { name = "Arcane Blast",           id = 42897 },
    { name = "Arcane Missiles",        id = 42846 },
    { name = "Arcane Barrage",         id = 44781 },
    { name = "Arcane Explosion",       id = 42921 },
    { name = "Blizzard",               id = 42940 },
    { name = "Flamestrike",            id = 42926 },
    { name = "Evocation",              id = 12051 },
    { name = "Arcane Power",           id = 12042 },
    { name = "Presence of Mind",       id = 12043 },
    { name = "Mirror Image",           id = 55342 },
    { name = "Icy Veins",              id = 12472 },
    { name = "Molten Armor",           id = 43046 },
    { name = "Counterspell",           id = 2139  },
    -- Druid
    { name = "Wrath",                  id = 48461 },
    { name = "Starfire",               id = 48465 },
    { name = "Moonfire",               id = 48463 },
    { name = "Insect Swarm",           id = 48468 },
    { name = "Starfall",               id = 53201 },
    { name = "Force of Nature",        id = 33831 },
    { name = "Typhoon",                id = 61384 },
    { name = "Hurricane",              id = 48467 },
    { name = "Faerie Fire",            id = 770   },
    { name = "Moonkin Form",           id = 24858 },
    -- Warrior
    { name = "Mortal Strike",          id = 47486 },
    { name = "Rend",                   id = 47465 },
    { name = "Overpower",              id = 7384  },
    { name = "Slam",                   id = 47475 },
    { name = "Execute",                id = 47471 },
    { name = "Bladestorm",             id = 46924 },
    { name = "Heroic Strike",          id = 47450 },
    { name = "Cleave",                 id = 47520 },
    { name = "Sweeping Strikes",       id = 12328 },
    { name = "Recklessness",           id = 1719  },
    { name = "Bloodrage",              id = 2687  },
    { name = "Battle Shout",           id = 47436 },
    { name = "Sunder Armor",           id = 7386  },
    { name = "Victory Rush",           id = 34428 },
    { name = "Battle Stance",          id = 2457  },
    { name = "Berserker Stance",       id = 2458  },
    { name = "Pummel",                 id = 6552  },
    -- Hunter
    { name = "Explosive Shot",         id = 60053 },
    { name = "Black Arrow",            id = 63672 },
    { name = "Aimed Shot",             id = 49050 },
    { name = "Steady Shot",            id = 49052 },
    { name = "Serpent Sting",          id = 49001 },
    { name = "Kill Shot",              id = 61006 },
    { name = "Multi-Shot",             id = 49048 },
    { name = "Volley",                 id = 58434 },
    { name = "Explosive Trap",         id = 49067 },
    { name = "Kill Command",           id = 34026 },
    { name = "Rapid Fire",             id = 3045  },
    { name = "Call of the Wild",       id = 53434 },
    { name = "Hunter's Mark",          id = 53338 },
    { name = "Aspect of the Dragonhawk", id = 61847 },
    -- Shaman
    { name = "Stormstrike",            id = 17364 },
    { name = "Lava Lash",              id = 60103 },
    { name = "Earth Shock",            id = 49231 },
    { name = "Flame Shock",            id = 49233 },
    { name = "Lightning Bolt",         id = 49238 },
    { name = "Chain Lightning",        id = 49271 },
    { name = "Fire Nova",              id = 61657 },
    { name = "Magma Totem",            id = 58734 },
    { name = "Lightning Shield",       id = 49281 },
    { name = "Feral Spirit",           id = 51533 },
    { name = "Fire Elemental Totem",   id = 2894  },
    { name = "Shamanistic Rage",       id = 30823 },
    { name = "Wind Shear",             id = 57994 },
    -- Fire Mage
    { name = "Fireball",               id = 42833 },
    { name = "Frostfire Bolt",         id = 47610 },
    { name = "Pyroblast",              id = 42891 },
    { name = "Living Bomb",            id = 55360 },
    { name = "Scorch",                 id = 42859 },
    { name = "Fire Blast",             id = 42873 },
    { name = "Blast Wave",             id = 42945 },
    { name = "Dragon's Breath",        id = 42950 },
    { name = "Combustion",             id = 11129 },
    -- Destruction Warlock
    { name = "Immolate",               id = 47811 },
    { name = "Conflagrate",            id = 17962 },
    { name = "Chaos Bolt",             id = 59172 },
    { name = "Incinerate",             id = 47838 },
    { name = "Curse of Doom",          id = 47867 },
    -- Frost Mage
    { name = "Frostbolt",              id = 42842 },
    { name = "Deep Freeze",            id = 44572 },
    { name = "Ice Lance",              id = 42914 },
    { name = "Cone of Cold",           id = 42931 },
    { name = "Cold Snap",              id = 11958 },
    { name = "Summon Water Elemental", id = 31687 },
    -- Marksmanship Hunter
    { name = "Chimera Shot",           id = 53209 },
    { name = "Arcane Shot",            id = 49045 },
    { name = "Readiness",              id = 23989 },
    { name = "Silencing Shot",         id = 34490 },
    { name = "Aspect of the Viper",    id = 34074 },
    -- Blood DK
    { name = "Heart Strike",           id = 55262 },
    { name = "Dancing Rune Weapon",    id = 49028 },
    { name = "Unholy Frenzy",          id = 49016 },
    -- Demonology
    { name = "Soul Fire",              id = 47825 },
    { name = "Metamorphosis",          id = 47241 },
    { name = "Demonic Empowerment",    id = 47193 },
    { name = "Immolation Aura",        id = 50589 },
    -- Beast Mastery
    { name = "Bestial Wrath",          id = 19574 },
    { name = "Intimidation",           id = 19577 },
    -- Fury
    { name = "Bloodthirst",            id = 23881 },
    { name = "Whirlwind",              id = 1680  },
    { name = "Death Wish",             id = 12292 },
    { name = "Victory Rush",           id = 34428 },
    -- Feral
    { name = "Shred",                  id = 48572 },
    { name = "Mangle (Cat)",           id = 48566 },
    { name = "Rake",                   id = 48574 },
    { name = "Rip",                    id = 49800 },
    { name = "Savage Roar",            id = 52610 },
    { name = "Ferocious Bite",         id = 48577 },
    { name = "Tiger's Fury",           id = 50213 },
    { name = "Berserk",                id = 50334 },
    { name = "Faerie Fire (Feral)",    id = 60401 },
    { name = "Cat Form",               id = 768   },
    -- Combat / Subtlety Rogue
    { name = "Sinister Strike",        id = 48638 },
    { name = "Eviscerate",             id = 48668 },
    { name = "Killing Spree",          id = 51690 },
    { name = "Adrenaline Rush",        id = 13750 },
    { name = "Blade Flurry",           id = 13877 },
    { name = "Hemorrhage",             id = 48660 },
    { name = "Backstab",               id = 48657 },
    { name = "Shadow Dance",           id = 51713 },
    { name = "Premeditation",          id = 14183 },
    -- Elemental Shaman
    { name = "Lava Burst",             id = 60043 },
    { name = "Thunderstorm",           id = 59159 },
    { name = "Elemental Mastery",      id = 16166 },
    { name = "Water Shield",           id = 57960 },
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
local actionPage, bonusOffset = 1, 0
function GetActionBarPage() return actionPage end
function GetBonusBarOffset() return bonusOffset end
function M.setActionPage(p, bonus)
    actionPage, bonusOffset = p or 1, bonus or 0
end

local shapeform = 0
function GetShapeshiftForm() return shapeform end
-- The shapeshift bar holds presences for a DK and stances for a
-- warrior, so the mock needs to be told which it is showing.
local formNames = { "Blood Presence", "Frost Presence", "Unholy Presence" }
function M.setFormNames(t) formNames = t end
function GetShapeshiftFormInfo(i)
    if not formNames[i] then return nil end
    return "icon", formNames[i], (i == shapeform), true
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
function M.addDebuff(name, id, remains, caster)
    table.insert(targetDebuffs, {
        name = name, id = id, count = 1,
        expires = clock + (remains or 15), duration = remains or 15,
        caster = caster,
    })
end
function M.clearDebuffs() for i = #targetDebuffs, 1, -1 do targetDebuffs[i] = nil end end

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
function M.clearBindings() for k in pairs(bindings) do bindings[k] = nil end end
RANGE_INDICATOR = "\226\128\162"

-- Simulate a bar addon (Bartender4-style names) having already drawn
-- its buttons with HotKey fontstrings. This is what Keybind reads.
local hotkeys = { "1", "2", "3", "SHIFT-4", "5", "CTRL-6" }
-- A paged bar: buttons report action = 1..12 and the PAGE lives on
-- the parent, so the real slot is (page-1)*12 + index.
-- A paged bar whose buttons also draw an icon, so the slot validation
-- has something to check against.
function M.buildPagedBar(prefix, page, keys, withIcons)
    local realPage = page
    local parent = { GetAttribute = function(self, k)
        if k == "actionpage" then return page end
    end }
    for i = 1, 12 do
        local slot = (realPage - 1) * 12 + i
        local btn = {
            IsVisible = function() return true end,
            GetParent = function() return parent end,
            GetAttribute = function(self, k)
                if k == "action" then return i end
            end,
        }
        if withIcons then
            btn.icon = { GetTexture = function() return GetActionTexture(slot) end }
        end
        _G[prefix .. i] = btn
        local txt = keys and keys[i]
        _G[prefix .. i .. "HotKey"] = { GetText = function() return txt or "" end }
    end
end

function M.buildBars(prefix, opts)
    prefix = prefix or "BT4Button"
    opts = opts or {}
    local keys = opts.keys or hotkeys
    local vis  = (opts.visible ~= false)
    local base = opts.slotBase or 0
    for i = 1, 12 do
        local btn = { IsVisible = function() return vis end }
        if opts.libStyle then
            btn._state_action = base + i      -- LibActionButton style
        else
            btn.action = base + i
        end
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

local combo = 0
function GetComboPoints(u, t) return combo end
function M.setComboPoints(n) combo = n end

local power = { [6] = 0, [3] = 100, [1] = 0, [0] = 0 }
function UnitPower(u, t) return power[t] or 0 end
function UnitPowerMax(u, t)
    if t == 6 then return 130 end
    if t == 3 then return 100 end
    if t == 1 then return 100 end
    return 0
end
function M.setPower(t, v) power[t] = v end
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
