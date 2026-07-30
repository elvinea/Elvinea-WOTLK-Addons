-- ElvinKeybinds
-- Clears all action bar keybinds (including whatever ElvUI or anything else
-- had bound, since bindings are just Blizzard's global binding table) and
-- re-applies a fixed standard layout:
--   Bar 1 (ACTIONBUTTON1-12)          -> 1 2 3 4 5 6 7 8 9 0 - =
--   Bar 2 (MULTIACTIONBAR1BUTTON1-12) -> ALT-1 ... ALT-=
--   Bar 3 (MULTIACTIONBAR2BUTTON1-12) -> SHIFT-1 ... SHIFT-=

local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }

-- Bars we actually bind keys to
local BAR_DEFS = {
    { prefix = "ACTIONBUTTON",          modifier = "" },
    { prefix = "MULTIACTIONBAR1BUTTON", modifier = "ALT-" },
    { prefix = "MULTIACTIONBAR2BUTTON", modifier = "SHIFT-" },
}

-- All action-bar command prefixes we wipe clean before applying the layout
-- above. This covers every standard action bar slot regardless of which
-- addon (ElvUI, Bartender, Dominos, or plain Blizzard UI) originally bound
-- it, since all of them ultimately call the same SetBinding API.
local CLEAR_PREFIXES = {
    "ACTIONBUTTON",
    "MULTIACTIONBAR1BUTTON",
    "MULTIACTIONBAR2BUTTON",
    "MULTIACTIONBAR3BUTTON",
    "MULTIACTIONBAR4BUTTON",
    "BONUSACTIONBUTTON",
}

local function ClearCommandBindings(command)
    local key1, key2 = GetBindingKey(command)
    if key1 then SetBinding(key1) end
    if key2 then SetBinding(key2) end
end

local function ClearActionBarBindings()
    for _, prefix in ipairs(CLEAR_PREFIXES) do
        for i = 1, 12 do
            ClearCommandBindings(prefix .. i)
        end
    end
end

local function ApplyStandardBindings()
    for _, bar in ipairs(BAR_DEFS) do
        for i, key in ipairs(KEYS) do
            local command = bar.prefix .. i
            local bindKey = bar.modifier .. key
            SetBinding(bindKey, command)
        end
    end
end

local function StandardizeKeybinds()
    ClearActionBarBindings()
    ApplyStandardBindings()
    SaveBindings(2) -- 2 = save to this character's binding set
    print("|cff33ff99ElvinKeybinds|r: action bar keybinds standardized (1-=, ALT-1-=, SHIFT-1-=).")
end

local function ClearOnly()
    ClearActionBarBindings()
    SaveBindings(2)
    print("|cff33ff99ElvinKeybinds|r: action bar keybinds cleared.")
end

-- ============================ Config window ============================

local panel = CreateFrame("Frame", "ElvinKeybindsFrame", UIParent)
panel:SetSize(260, 150)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:SetFrameStrata("DIALOG")
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
panel:Hide()

tinsert(UISpecialFrames, "ElvinKeybindsFrame") -- lets Escape close it too

local closeButton = CreateFrame("Button", "ElvinKeybindsCloseButton", panel, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)

panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
panel.title:SetPoint("TOP", panel, "TOP", 0, -16)
panel.title:SetText("ElvinKeybinds")

local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
desc:SetPoint("TOP", panel.title, "BOTTOM", 0, -8)
desc:SetWidth(220)
desc:SetJustifyH("CENTER")
desc:SetText("Bars 1-3 -> 1-=, ALT-1-=, SHIFT-1-=")

local function SafeRun(label, func)
    if InCombatLockdown() then
        print("|cffff4444ElvinKeybinds|r: can't change keybinds in combat, try again out of combat.")
        return
    end
    local ok, err = pcall(func)
    if not ok then
        print("|cffff4444ElvinKeybinds|r: " .. label .. " failed - " .. tostring(err))
    end
end

local applyButton = CreateFrame("Button", "ElvinKeybindsApplyButton", panel, "UIPanelButtonTemplate")
applyButton:SetSize(200, 24)
applyButton:SetPoint("TOP", desc, "BOTTOM", 0, -16)
applyButton:SetText("Standardize Keybinds")
applyButton:RegisterForClicks("LeftButtonUp")
applyButton:SetScript("OnClick", function()
    SafeRun("Standardize", StandardizeKeybinds)
end)

local clearButton = CreateFrame("Button", "ElvinKeybindsClearButton", panel, "UIPanelButtonTemplate")
clearButton:SetSize(200, 24)
clearButton:SetPoint("TOP", applyButton, "BOTTOM", 0, -8)
clearButton:SetText("Clear Only")
clearButton:RegisterForClicks("LeftButtonUp")
clearButton:SetScript("OnClick", function()
    SafeRun("Clear", ClearOnly)
end)

SLASH_ELVINKEYBINDS1 = "/ekb"
SlashCmdList["ELVINKEYBINDS"] = function()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end
