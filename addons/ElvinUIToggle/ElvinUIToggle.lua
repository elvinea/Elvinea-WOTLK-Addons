local ADDON_NAME = "ElvinUIToggle"

-- ============================================================
-- CONFIG — element key -> global frame name + display label
--
-- Verify these frame names in-game with /fstack if a toggle
-- doesn't do anything. Frame names can shift between ElvUI /
-- addon versions.
-- ============================================================
local ELEMENTS = {
    bar1    = { frames = {"ElvUI_Bar1"},         label = "Bar 1" },
    bar2    = { frames = {"ElvUI_Bar2"},         label = "Bar 2" },
    bar3    = { frames = {"ElvUI_Bar3"},         label = "Bar 3" },
    bar4    = { frames = {"ElvUI_Bar4"},         label = "Bar 4" },
    bar5    = { frames = {"ElvUI_Bar5"},         label = "Bar 5" },
    bar6    = { frames = {"ElvUI_Bar6"},         label = "Bar 6" },
    stance  = { frames = {"ElvUI_StanceBar"},    label = "Stance Bar" },
    pet     = { frames = {"ElvUI_BarPet"},       label = "Pet Bar" },
    micro   = { frames = {"ElvUI_MicroBar"},     label = "Micro Bar" },
    chat    = { frames = {"ChatFrame1", "CU_ChatFrameTabButton", "ChatFrame1Tab", "ChatFrame2Tab", "ChatFrame3Tab", "ChatFrame4Tab", "ChatFrame5Tab", "LeftChatPanel", "RightChatPanel"}, label = "Chat" },
    details = { frames = {"DetailsUpFrameInstance1", "Details_SwitchButtonFrame1", "Details_GumpFrame1", "Details_WindowFrame1", "DetailsBaseFrame1", "DetailsRowFrame1"}, label = "Details" },
    cd      = { showCmd = "/ecd show", hideCmd = "/ecd hide", label = "ElvinCDs" },
    petfr   = { frames = {"ElvUF_Pet"},          label = "Pet Frame" },
    playerfr = { frames = {"ElvUF_Player"},      label = "Player Frame" },
    targetfr = { frames = {"ElvUF_Target"},      label = "Target Frame" },
    minimap = { frames = {"MinimapCluster"},     label = "Minimap" },
    pallypower = { frames = {"PallyPowerAnchor", "PallyPowerAuto", "PallyPowerAura"}, label = "PallyPower" },
    cdused  = { showCmd = "/cu show", hideCmd = "/cu hide", label = "CD Used" },
    rotation = { showCmd = "/er show", hideCmd = "/er hide", label = "ElvinRotation" },
    playerbuffs = { frames = {"ElvUIPlayerBuffs"}, label = "Player Buffs" },
    playerdebuffs = { frames = {"ElvUIPlayerDebuffs"}, label = "Player Debuffs" },
    vuhdo   = { frames = {"VdAc1"},              label = "VuhDo" },
}

-- Order to display element toggle buttons in the UI
local ELEMENT_ORDER = {
    "bar1", "bar2", "bar3", "bar4", "bar5", "bar6",
    "stance", "pet", "micro", "chat", "details", "cd",
    "petfr", "playerfr", "targetfr", "minimap",
    "pallypower", "cdused", "rotation", "playerbuffs", "playerdebuffs", "vuhdo",
}

-- Elements where keybinds must keep working while "hidden".
-- These use SetAlpha(0) + EnableMouse(false) instead of :Hide(),
-- since a real :Hide() can break secure click-through for
-- keybound actions. Alpha+mouse-disable keeps the frame alive
-- and bindable, just invisible and unclickable by mouse.
local USE_ALPHA_HIDE = {
    bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = true, bar6 = true,
    stance = true, pet = true, micro = true,
}

local DEFAULT_SLASH = "/uit"

local DEFAULT_TEMPLATES = {
    raiding = {
        bar1 = false, bar2 = false, bar3 = false, bar4 = true, bar5 = false,
        bar6 = false, stance = true, pet = true, micro = true,
        chat = false, details = true, cd = true, rotation = true, cdused = true,
        petfr = true, playerfr = true, targetfr = true, minimap = true,
        pallypower = true, playerbuffs = true, playerdebuffs = true, vuhdo = true,
    },
    everything = {
        bar1 = true, bar2 = true, bar3 = true, bar4 = true, bar5 = true,
        bar6 = true, stance = true, pet = true, micro = true,
        chat = true, details = true, cd = true, rotation = true, cdused = true,
        petfr = true, playerfr = true, targetfr = true, minimap = true,
        pallypower = true, playerbuffs = true, playerdebuffs = true, vuhdo = true,
    },
}

-- ============================================================
-- CORE
-- ============================================================
-- Fires a slash command programmatically (used for elements like CD Used
-- that only expose an on/off toggle command, no directly hideable frame).
local function TriggerSlashCommand(cmdText)
    local editBox = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
    if not editBox then
        print("|cffff8800ElvinUIToggle:|r couldn't access the chat edit box")
        return false
    end
    editBox:SetText(cmdText)
    ChatEdit_SendText(editBox, 0)
    return true
end

-- Returns the list of frame objects that actually exist for this element.
-- (An element can map to more than one underlying frame, e.g. chat also
-- has a separate tab-button frame that needs hiding.)
local function GetFrames(key)
    local def = ELEMENTS[key]
    if not def or not def.frames then return {} end
    local found = {}
    for _, name in ipairs(def.frames) do
        local f = _G[name]
        if f then tinsert(found, f) end
    end
    return found
end

local function IsElementVisible(key)
    local v = ElvinUIToggleDB.state[key]
    if v ~= nil then return v end
    local def = ELEMENTS[key]
    if def and def.showCmd then return true end -- default assumption before first toggle
    local frames = GetFrames(key)
    return frames[1] and frames[1]:IsShown() or false
end

local RefreshUI -- forward declare

-- Some frames (chat, Details, etc.) get re-shown by their own addon's
-- internal logic right after we hide them - e.g. chat frames popping
-- back open when a new message arrives. This hook forces the frame
-- back down immediately if we still consider it "hidden", so other
-- addons can't silently undo our toggle.
local hookedFrames = {}
local function EnsureReHideHook(f, key)
    if hookedFrames[f] then return end
    hookedFrames[f] = true
    f:HookScript("OnShow", function(self)
        if ElvinUIToggleDB.state[key] == false then
            self:Hide()
        end
    end)
end

local function SetElementVisible(key, visible)
    local def = ELEMENTS[key]

    -- Elements with explicit show/hide commands (e.g. ElvinCDs, ElvinRotation)
    -- go through their own addon's command instead of touching any frame -
    -- we know the exact resulting state since we chose which command to fire.
    if def and def.showCmd and def.hideCmd then
        TriggerSlashCommand(visible and def.showCmd or def.hideCmd)
        ElvinUIToggleDB.state[key] = visible
        if RefreshUI then RefreshUI() end
        return
    end

    local frames = GetFrames(key)
    if #frames == 0 then
        print("|cffff8800ElvinUIToggle:|r couldn't find any frame for '" .. key .. "' (tried: " .. table.concat(def and def.frames or {}, ", ") .. ")")
        return
    end

    -- Must be set BEFORE Show()/Hide() below - the anti-flicker hook
    -- fires synchronously inside Show() and needs to see the new value,
    -- not the previous one, or it immediately undoes the change.
    ElvinUIToggleDB.state[key] = visible

    for _, f in ipairs(frames) do
        if USE_ALPHA_HIDE[key] then
            if visible then
                f:SetAlpha(1)
                f:EnableMouse(true)
            else
                f:SetAlpha(0)
                f:EnableMouse(false)
            end
        else
            EnsureReHideHook(f, key)
            if visible then f:Show() else f:Hide() end
        end
    end

    if RefreshUI then RefreshUI() end
end

local function ToggleElement(key)
    if not ELEMENTS[key] then
        print("|cffff8800ElvinUIToggle:|r unknown element '" .. key .. "'")
        return
    end
    SetElementVisible(key, not IsElementVisible(key))
end

local function ApplyTemplate(name)
    local tpl = ElvinUIToggleDB.templates[name]
    if not tpl then
        print("|cffff8800ElvinUIToggle:|r no template named '" .. name .. "'")
        return
    end
    for key, visible in pairs(tpl) do
        if not (ELEMENTS[key] and ELEMENTS[key].command) then
            SetElementVisible(key, visible)
        end
    end
    ElvinUIToggleDB.lastTemplate = name
    print("|cff00ff00ElvinUIToggle:|r applied template '" .. name .. "'")
end

local function SaveTemplate(name)
    if not name or name == "" then return end
    local tpl = {}
    for key, def in pairs(ELEMENTS) do
        if not def.command then
            tpl[key] = IsElementVisible(key)
        end
    end
    ElvinUIToggleDB.templates[name] = tpl
    print("|cff00ff00ElvinUIToggle:|r saved current visibility as template '" .. name .. "'")
    if RefreshUI then RefreshUI() end
end

local function DeleteTemplate(name)
    ElvinUIToggleDB.templates[name] = nil
    print("|cff00ff00ElvinUIToggle:|r deleted template '" .. name .. "'")
    if RefreshUI then RefreshUI() end
end

local function HideAll()
    for key, def in pairs(ELEMENTS) do
        if not def.command then
            SetElementVisible(key, false)
        end
    end
    print("|cff00ff00ElvinUIToggle:|r hid everything")
end

local function ShowAll()
    for key, def in pairs(ELEMENTS) do
        if not def.command then
            SetElementVisible(key, true)
        end
    end
    print("|cff00ff00ElvinUIToggle:|r showed everything")
end

-- ============================================================
-- SLASH COMMAND (changeable)
-- ============================================================
local function SetSlashCommand(newCmd)
    newCmd = newCmd:lower():gsub("%s+", "")
    if newCmd == "" then return end
    if newCmd:sub(1, 1) ~= "/" then newCmd = "/" .. newCmd end

    -- unregister old
    local old = ElvinUIToggleDB.slashCommand
    if old and hash_SlashCmdList then
        hash_SlashCmdList[old:upper()] = nil
    end

    SLASH_ELVINUITOGGLE1 = newCmd
    hash_SlashCmdList[newCmd:upper()] = "ELVINUITOGGLE"
    ElvinUIToggleDB.slashCommand = newCmd
    print("|cff00ff00ElvinUIToggle:|r command is now " .. newCmd .. " (safety fallback /elvinuit always works too)")
    if RefreshUI then RefreshUI() end
end

local function HandleCommand(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" then
        if ElvinUIToggleFrame:IsShown() then
            ElvinUIToggleFrame:Hide()
        else
            ElvinUIToggleFrame:Show()
        end
    elseif cmd == "template" and arg ~= "" then
        ApplyTemplate(arg)
    elseif cmd == "save" and arg ~= "" then
        SaveTemplate(arg)
    elseif cmd == "toggle" and arg ~= "" then
        ToggleElement(arg:lower())
    elseif cmd == "hideall" then
        HideAll()
    elseif cmd == "showall" then
        ShowAll()
    elseif cmd == "list" then
        print("|cff00ff00ElvinUIToggle|r templates:")
        for name in pairs(ElvinUIToggleDB.templates) do print("  - " .. name) end
    elseif cmd == "cmd" and arg ~= "" then
        SetSlashCommand(arg)
    else
        print("|cff00ff00ElvinUIToggle|r commands (or just type the command with no args to open the UI):")
        print("  template <name> | save <name> | toggle <element> | hideall | showall | list | cmd <newcmd>")
    end
end

-- Fixed fallback command so you can never lock yourself out - runs the
-- exact same handler as the customizable command, not just a window toggle.
SLASH_ELVINUITOGGLEFALLBACK1 = "/elvinuit"
SlashCmdList["ELVINUITOGGLEFALLBACK"] = function(msg)
    HandleCommand(msg)
end

SlashCmdList["ELVINUITOGGLE"] = function(msg)
    HandleCommand(msg)
end

-- ============================================================
-- UI
-- ============================================================
local elementButtons = {}
local templateRows = {}

local function StyleToggleButton(btn, key)
    if ELEMENTS[key] and ELEMENTS[key].command then return end -- leave neutral color, state unknown
    local visible = IsElementVisible(key)
    if visible then
        btn:SetNormalFontObject("GameFontNormal")
        btn.bg:SetVertexColor(0.15, 0.5, 0.15, 0.9)
    else
        btn:SetNormalFontObject("GameFontDisable")
        btn.bg:SetVertexColor(0.5, 0.15, 0.15, 0.9)
    end
end

local function BuildMainFrame()
    local f = CreateFrame("Frame", "ElvinUIToggleFrame", UIParent)
    f:SetSize(460, 658)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
        edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    f:SetFrameStrata("DIALOG")
    f:Hide()
    tinsert(UISpecialFrames, "ElvinUIToggleFrame") -- lets ESC close it

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    title:SetText("ElvinUIToggle")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- ---------- Element toggle grid ----------
    local gridLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gridLabel:SetPoint("TOPLEFT", 20, -45)
    gridLabel:SetText("Elements (click to toggle):")

    local cols, rows = 4, 6
    local btnW, btnH = 99, 28
    local startX, startY = 20, -65
    for i, key in ipairs(ELEMENT_ORDER) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local btn = CreateFrame("Button", "ElvinUIToggleBtn" .. key, f)
        btn:SetSize(btnW, btnH)
        btn:SetPoint("TOPLEFT", startX + col * (btnW + 8), startY - row * (btnH + 6))
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetAllPoints()
        btn.bg:SetTexture("Interface/Buttons/WHITE8x8")
        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER")
        text:SetText(ELEMENTS[key].label)
        btn.text = text
        local cmd = ELEMENTS[key].command
        if cmd then
            btn.bg:SetVertexColor(0.35, 0.35, 0.15, 0.9) -- neutral: state unknown, just fires the command
            btn:SetScript("OnClick", function() TriggerSlashCommand(cmd) end)
        else
            btn:SetScript("OnClick", function() ToggleElement(key) end)
        end
        elementButtons[key] = btn
    end

    -- ---------- Hide all / show all ----------
    local hideAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    hideAllBtn:SetSize(120, 22)
    hideAllBtn:SetPoint("TOPLEFT", 20, -263)
    hideAllBtn:SetText("Hide All")
    hideAllBtn:SetScript("OnClick", HideAll)

    local showAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    showAllBtn:SetSize(120, 22)
    showAllBtn:SetPoint("LEFT", hideAllBtn, "RIGHT", 8, 0)
    showAllBtn:SetText("Show All")
    showAllBtn:SetScript("OnClick", ShowAll)

    -- ---------- Slash command changer ----------
    local cmdLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cmdLabel:SetPoint("TOPLEFT", 20, -298)
    cmdLabel:SetText("Command:")

    local cmdBox = CreateFrame("EditBox", "ElvinUIToggleCmdBox", f, "InputBoxTemplate")
    cmdBox:SetSize(140, 20)
    cmdBox:SetPoint("LEFT", cmdLabel, "RIGHT", 10, 0)
    cmdBox:SetAutoFocus(false)
    cmdBox:SetScript("OnEnterPressed", function(self)
        SetSlashCommand(self:GetText())
        self:ClearFocus()
    end)
    f.cmdBox = cmdBox

    local cmdSetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cmdSetBtn:SetSize(50, 20)
    cmdSetBtn:SetPoint("LEFT", cmdBox, "RIGHT", 8, 0)
    cmdSetBtn:SetText("Set")
    cmdSetBtn:SetScript("OnClick", function() SetSlashCommand(cmdBox:GetText()) end)

    -- ---------- Save template ----------
    local saveLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saveLabel:SetPoint("TOPLEFT", 20, -330)
    saveLabel:SetText("Save current as:")

    local saveBox = CreateFrame("EditBox", "ElvinUIToggleSaveBox", f, "InputBoxTemplate")
    saveBox:SetSize(140, 20)
    saveBox:SetPoint("LEFT", saveLabel, "RIGHT", 10, 0)
    saveBox:SetAutoFocus(false)
    saveBox:SetScript("OnEnterPressed", function(self)
        SaveTemplate(self:GetText())
        self:SetText("")
        self:ClearFocus()
    end)
    f.saveBox = saveBox

    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(50, 20)
    saveBtn:SetPoint("LEFT", saveBox, "RIGHT", 8, 0)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        SaveTemplate(saveBox:GetText())
        saveBox:SetText("")
    end)

    -- ---------- Template list ----------
    local listLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", 20, -363)
    listLabel:SetText("Saved templates:")

    local listContainer = CreateFrame("Frame", nil, f)
    listContainer:SetPoint("TOPLEFT", 20, -383)
    listContainer:SetSize(420, 250)
    f.listContainer = listContainer

    return f
end

local function RebuildTemplateRows()
    local f = ElvinUIToggleFrame
    for _, row in ipairs(templateRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(templateRows)

    local names = {}
    for name in pairs(ElvinUIToggleDB.templates) do tinsert(names, name) end
    table.sort(names)

    local y = 0
    for _, name in ipairs(names) do
        local row = CreateFrame("Frame", nil, f.listContainer)
        row:SetSize(380, 24)
        row:SetPoint("TOPLEFT", 0, y)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT", 0, 0)
        text:SetWidth(180)
        text:SetJustifyH("LEFT")
        text:SetText(name)

        local applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        applyBtn:SetSize(70, 20)
        applyBtn:SetPoint("LEFT", text, "RIGHT", 10, 0)
        applyBtn:SetText("Apply")
        applyBtn:SetScript("OnClick", function() ApplyTemplate(name) end)

        local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        delBtn:SetSize(70, 20)
        delBtn:SetPoint("LEFT", applyBtn, "RIGHT", 6, 0)
        delBtn:SetText("Delete")
        delBtn:SetScript("OnClick", function() DeleteTemplate(name) end)

        tinsert(templateRows, row)
        y = y - 26
    end
end

RefreshUI = function()
    if not ElvinUIToggleFrame then return end
    for key, btn in pairs(elementButtons) do
        StyleToggleButton(btn, key)
    end
    if ElvinUIToggleFrame.cmdBox then
        ElvinUIToggleFrame.cmdBox:SetText(ElvinUIToggleDB.slashCommand or DEFAULT_SLASH)
    end
    RebuildTemplateRows()
end

-- ============================================================
-- INIT
-- ============================================================
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    ElvinUIToggleDB = ElvinUIToggleDB or {}
    ElvinUIToggleDB.templates = ElvinUIToggleDB.templates or {}
    ElvinUIToggleDB.state = ElvinUIToggleDB.state or {}
    ElvinUIToggleDB.slashCommand = ElvinUIToggleDB.slashCommand or DEFAULT_SLASH

    for name, tpl in pairs(DEFAULT_TEMPLATES) do
        if not ElvinUIToggleDB.templates[name] then
            ElvinUIToggleDB.templates[name] = tpl
        end
    end

    BuildMainFrame()
    SetSlashCommand(ElvinUIToggleDB.slashCommand)
    RefreshUI()

    print("|cff00ff00ElvinUIToggle|r loaded. Type " .. ElvinUIToggleDB.slashCommand .. " to open the panel.")
end)
