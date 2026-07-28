--[[ ElvinRotation - Options.lua
     Settings window: collapsible sections, class/spec dropdowns,
     resizable, and a live keybind diagnostic pane.

     Layout is computed by relayout() rather than hardcoded offsets, so
     collapsing a section reflows everything below it.
--]]

local ER = _G.ElvinRotation
local C  = ER.Compat

local panel, sections, widgets, specRows = nil, {}, {}, {}
local selectedClass, selectedSpec
local rolledUp = false

local HEADER_H, ROW_H, SLIDER_H, PAD = 24, 28, 46, 10

--------------------------------------------------------------------
-- Widgets. None of these position themselves; relayout() does that.
--------------------------------------------------------------------
local function makeCheck(label, tooltip, get, set)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetWidth(24); cb:SetHeight(24)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    cb:SetChecked(get())
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)

    if tooltip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    cb.Refresh = function() cb:SetChecked(get()) end
    return cb
end

local sliderN = 0
local function makeSlider(label, minV, maxV, stepV, get, set, fmt)
    sliderN = sliderN + 1
    local name = "ElvinRotationSlider" .. sliderN
    local sl = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
    sl:SetHeight(16)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(stepV)
    sl:SetValue(get())

    if _G[name .. "Low"]  then _G[name .. "Low"]:SetText(tostring(minV))  end
    if _G[name .. "High"] then _G[name .. "High"]:SetText(tostring(maxV)) end

    local function setText(v)
        if _G[name .. "Text"] then
            _G[name .. "Text"]:SetText(label .. ": " .. string.format(fmt or "%d", v))
        end
    end
    setText(get())

    sl:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / stepV + 0.5) * stepV
        setText(value); set(value)
    end)

    sl.Refresh = function() sl:SetValue(get()); setText(get()) end
    return sl
end

local dropN = 0
local function makeDropdown(label, width, itemsFn, get, set)
    dropN = dropN + 1
    local dd = CreateFrame("Frame", "ElvinRotationDrop" .. dropN, panel,
                           "UIDropDownMenuTemplate")

    -- Parent the caption to the DROPDOWN, not the panel. As a child of
    -- the panel it stayed on screen after the Rotation section was
    -- collapsed, leaving "Class" and "Spec" floating with no controls.
    local fs = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 20, 2)
    fs:SetText(label)
    dd.labelFS = fs

    local function onClick(self)
        set(self.value)
        if ER.RefreshOptions then ER:RefreshOptions() end
    end

    UIDropDownMenu_Initialize(dd, function()
        for _, item in ipairs(itemsFn()) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.func = item.text, item.value, onClick
            info.checked = (item.value == get())
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(dd, width or 130)

    -- SetSelectedValue sets the value but NOT the shown text, which is
    -- why these rendered blank.
    dd.Refresh = function()
        local v = get()
        UIDropDownMenu_SetSelectedValue(dd, v)
        local shown = "(none)"
        for _, item in ipairs(itemsFn()) do
            if item.value == v then shown = item.text break end
        end
        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(dd, shown) end
    end
    dd.Refresh()
    return dd
end

--------------------------------------------------------------------
-- Sections
--------------------------------------------------------------------
local function relayout() end   -- forward declaration

local function addSection(key, title)
    local sec = { key = key, title = title, rows = {} }

    sec.header = CreateFrame("Button", nil, panel)
    sec.header:SetHeight(HEADER_H)

    sec.text = sec.header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sec.text:SetPoint("LEFT", sec.header, "LEFT", 0, 0)
    sec.text:SetTextColor(0.6, 0.4, 1)

    sec.header:SetScript("OnClick", function()
        ElvinRotationDB.collapsed = ElvinRotationDB.collapsed or {}
        ElvinRotationDB.collapsed[key] = not ElvinRotationDB.collapsed[key]
        relayout()
    end)
    sec.header:SetScript("OnEnter", function() sec.text:SetTextColor(0.8, 0.6, 1) end)
    sec.header:SetScript("OnLeave", function() sec.text:SetTextColor(0.6, 0.4, 1) end)

    table.insert(sections, sec)
    return sec
end

local function addRow(sec, widget, height, indent, extra, dy)
    table.insert(sec.rows, { w = widget, h = height or ROW_H,
                             x = indent or 24, extra = extra, dy = dy or 0 })
end

local function isCollapsed(key)
    return ElvinRotationDB.collapsed and ElvinRotationDB.collapsed[key]
end

--------------------------------------------------------------------
relayout = function()
    if not panel then return end

    if rolledUp then
        for _, sec in ipairs(sections) do
            sec.header:Hide()
            for _, r in ipairs(sec.rows) do
                r.w:Hide(); if r.extra then r.extra:Hide() end
            end
        end
        panel:SetHeight(44)
        if widgets.grip then widgets.grip:Hide() end
        return
    end

    if widgets.grip then widgets.grip:Show() end

    local y = -44
    for _, sec in ipairs(sections) do
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
        sec.header:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
        sec.header:Show()

        local collapsed = isCollapsed(sec.key)
        sec.text:SetText((collapsed and "+ " or "- ") .. sec.title)
        y = y - HEADER_H

        if collapsed then
            for _, r in ipairs(sec.rows) do
                r.w:Hide(); if r.extra then r.extra:Hide() end
            end
        else
            for _, r in ipairs(sec.rows) do
                r.w:ClearAllPoints()
                r.w:SetPoint("TOPLEFT", panel, "TOPLEFT", r.x, y + (r.dy or 0))
                r.w:Show()
                if r.extra then r.extra:Show() end
                y = y - r.h
            end
        end
        y = y - PAD
    end

    local needed = -y + 24
    local minH = 120
    panel:SetHeight(math.max(minH, needed))
end

--------------------------------------------------------------------
-- Spec option registry
--------------------------------------------------------------------
ER.specOptions = ER.specOptions or {}

function ER:RegisterSpecOptions(class, spec, className, specName, opts, specTable)
    self.specOptions[class] = self.specOptions[class] or { name = className, specs = {} }
    self.specOptions[class].name = className or self.specOptions[class].name
    self.specOptions[class].specs[spec] = { name = specName, options = opts,
                                            spec = specTable }
end

local function classList()
    local out = {}
    for class, data in pairs(ER.specOptions) do
        table.insert(out, { text = data.name or class, value = class })
    end
    table.sort(out, function(a, b) return a.text < b.text end)
    if #out == 0 then out[1] = { text = "(none loaded)", value = "" } end
    return out
end

local function specList()
    local out = {}
    local data = ER.specOptions[selectedClass]
    if data then
        for spec, d in pairs(data.specs) do
            table.insert(out, { text = d.name or spec, value = spec })
        end
    end
    table.sort(out, function(a, b) return a.text < b.text end)
    if #out == 0 then out[1] = { text = "(none)", value = "" } end
    return out
end

local rotationSec

local function buildSpecOptions()
    for _, w in ipairs(specRows) do w:Hide() end
    specRows = {}

    -- drop everything after the two dropdown rows
    while #rotationSec.rows > 1 do table.remove(rotationSec.rows) end

    local data = ER.specOptions[selectedClass]
    local specData = data and data.specs[selectedSpec]
    if not specData then return end

    -- Auto-generate a toggle for every ability the spec tagged
    -- majorCD. Options.lua does not know what any of them are.
    local opts = {}
    for _, o in ipairs(specData.options) do table.insert(opts, o) end

    if specData.spec then
        local cds = {}
        for key, ab in pairs(specData.spec.abilities) do
            if ab.majorCD then table.insert(cds, { key = key, ab = ab }) end
        end
        table.sort(cds, function(a, b) return a.key < b.key end)
        for _, c in ipairs(cds) do
            table.insert(opts, {
                type = "check", key = "cd_" .. c.key,
                label = "Use " .. (c.ab.cdLabel or c.key),
                onValue = true, offValue = false,
                tooltip = "Also requires major cooldowns to be on (/er cd)."
                       .. (c.ab.minTTD and ("  Held unless the target has at least "
                          .. c.ab.minTTD .. "s to live.") or ""),
            })
        end
    end

    for _, opt in ipairs(opts) do
        local w
        if opt.type == "check" then
            w = makeCheck(opt.label, opt.tooltip,
                function() return ElvinRotationDB.settings[opt.key] ~= opt.offValue end,
                function(v) ElvinRotationDB.settings[opt.key] = v and opt.onValue or opt.offValue end)
            addRow(rotationSec, w, ROW_H)
        else
            w = makeSlider(opt.label, opt.min or 0, opt.max or 100, opt.step or 1,
                function() return ElvinRotationDB.settings[opt.key] or opt.min or 0 end,
                function(v) ElvinRotationDB.settings[opt.key] = v end, opt.fmt)
            w:SetWidth(190)
            addRow(rotationSec, w, SLIDER_H, 30)
        end
        table.insert(specRows, w)
    end
end

--------------------------------------------------------------------
-- Keybind diagnostic pane
--------------------------------------------------------------------
local keyLines = {}

local function refreshKeyPane()
    if not ER.activeSpec then return end

    -- Was hardcoded to Priest spell keys, so the pane was blank for
    -- every other spec. Walk the ACTIVE spec's abilities instead.
    local keys = {}
    for key in pairs(ER.activeSpec.abilities) do table.insert(keys, key) end
    table.sort(keys)

    local i = 1
    for _, key in ipairs(keys) do
        local ab = ER.activeSpec.abilities[key]
        local fs = keyLines[i]
        if ab and fs then
            if not ab.name then
                -- The spell ID in the spec file did not resolve to any
                -- spell. Nothing downstream can work without a name, so
                -- flag it loudly - this is the fastest way to catch a
                -- wrong ID in a newly written spec module.
                fs:SetText(string.format(
                    "|cffcccccc%-18s|r |cffff5555BAD SPELL ID|r  id=%s",
                    string.sub(key, 1, 18), tostring(ab.id)))
            else
                local shown = C.Keybind(ab.name)
                local colour = shown and "|cff55ff55" or "|cffff5555"
                fs:SetText(string.format("|cffcccccc%-16s|r %s%-5s|r %s",
                    string.sub(ab.name, 1, 16), colour, tostring(shown),
                    C.KeybindDiagnosis(ab.name)))
            end
            i = i + 1
        end
        if i > #keyLines then break end
    end
    for j = i, #keyLines do keyLines[j]:SetText("") end
end

--------------------------------------------------------------------
local function build()
    local db = ElvinRotationDB
    sections, widgets, specRows = {}, {}, {}

    panel = CreateFrame("Frame", "ElvinRotationOptions", UIParent)
    panel:SetWidth(db.optWidth or 380)
    panel:SetHeight(560)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:SetResizable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        ElvinRotationDB.optWidth = self:GetWidth()
    end)
    if panel.SetMinResize then panel:SetMinResize(340, 100) end
    if panel.SetMaxResize then panel:SetMaxResize(760, 900) end

    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -16)
    title:SetText("ElvinRotation")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() panel:Hide() end)

    -- roll the whole window up to its title bar
    local roll = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    roll:SetWidth(22); roll:SetHeight(20)
    roll:SetPoint("RIGHT", close, "LEFT", -2, 0)
    roll:SetText("_")
    roll:SetScript("OnClick", function(self)
        rolledUp = not rolledUp
        ElvinRotationDB.rolledUp = rolledUp
        self:SetText(rolledUp and "+" or "_")
        relayout()
    end)
    widgets.roll = roll

    local grip = CreateFrame("Button", nil, panel)
    grip:SetWidth(16); grip:SetHeight(16)
    grip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing()
        ElvinRotationDB.optWidth = panel:GetWidth()
        relayout()
    end)
    widgets.grip = grip

    ---------------- Display ----------------
    local disp = addSection("display", "Display")
    widgets.always = makeCheck("Show out of combat",
        "Keep the icons visible at all times. Off = combat only.",
        function() return ElvinRotationDB.displayMode == "always" end,
        function(v) ElvinRotationDB.displayMode = v and "always" or "combat" end)
    addRow(disp, widgets.always)

    widgets.locked = makeCheck("Lock position",
        "When unlocked, drag the icons with the left mouse button.",
        function() return ElvinRotationDB.locked end,
        function(v) ER:SetLocked(v) end)
    addRow(disp, widgets.locked)

    widgets.aoe = makeCheck("Force single target",
        "Ignore how many enemies are detected and always use the "
        .. "single-target priority. For fights with several targets "
        .. "where you still want to focus one, like Blood Princes.",
        function() return ElvinRotationDB.aoeMode == "single" end,
        function(v) ElvinRotationDB.aoeMode = v and "single" or "auto" end)
    addRow(disp, widgets.aoe)

    widgets.cds = makeCheck("Use major cooldowns",
        "Master switch for everything tagged as a major cooldown. "
        .. "Same as /er cd. The icon border greys out when off.",
        function() return not ElvinRotationDB.cooldownsOff end,
        function(v) ElvinRotationDB.cooldownsOff = not v end)
    addRow(disp, widgets.cds)

    widgets.swipe = makeCheck("Cooldown swipe on icons",
        "Darkens the icon and sweeps round as it becomes available, "
        .. "exactly like a normal action button.",
        function() return ElvinRotationDB.showSwipe ~= false end,
        function(v) ElvinRotationDB.showSwipe = v end)
    addRow(disp, widgets.swipe)

    widgets.gcdText = makeCheck("Numeric countdown too",
        "Also print the remaining time as a number on the main icon.",
        function() return ElvinRotationDB.showGcdText == true end,
        function(v) ElvinRotationDB.showGcdText = v end)
    addRow(disp, widgets.gcdText)

    widgets.keybind = makeCheck("Show keybinds",
        "Display the bound key in the corner of each icon.",
        function() return ElvinRotationDB.showKeybind end,
        function(v) ElvinRotationDB.showKeybind = v end)
    addRow(disp, widgets.keybind)

    ---------------- Sizing ----------------
    local size = addSection("sizing", "Sizing")
    widgets.size = makeSlider("Icon size", 24, 128, 2,
        function() return ElvinRotationDB.size end,
        function(v) ElvinRotationDB.size = v; ER:RebuildDisplay() end)
    widgets.size:SetWidth(190); addRow(size, widgets.size, SLIDER_H, 30)

    widgets.keySize = makeSlider("Keybind text size", 6, 24, 1,
        function() return ElvinRotationDB.keybindSize end,
        function(v) ElvinRotationDB.keybindSize = v; ER:RebuildDisplay() end)
    widgets.keySize:SetWidth(190); addRow(size, widgets.keySize, SLIDER_H, 30)

    widgets.queue = makeSlider("Icons shown", 1, 5, 1,
        function() return ElvinRotationDB.queueSize end,
        function(v) ElvinRotationDB.queueSize = v end)
    widgets.queue:SetWidth(190); addRow(size, widgets.queue, SLIDER_H, 30)

    ---------------- Rotation ----------------
    -- Pick the default selection BEFORE building the dropdowns; they
    -- read it during construction.
    do
        local _, class = UnitClass("player")
        selectedClass = ER.specOptions[class] and class or (classList()[1] or {}).value
        local d = ER.specOptions[selectedClass]
        selectedSpec = nil
        if d then for spec in pairs(d.specs) do selectedSpec = spec break end end
    end

    rotationSec = addSection("rotation", "Rotation")

    widgets.classDrop = makeDropdown("Class", 120, classList,
        function() return selectedClass end,
        function(v)
            selectedClass = v
            local d = ER.specOptions[v]
            selectedSpec = nil
            if d then for spec in pairs(d.specs) do selectedSpec = spec break end end
            buildSpecOptions()
        end)

    widgets.specDrop = makeDropdown("Spec", 120, specList,
        function() return selectedSpec end,
        function(v) selectedSpec = v; buildSpecOptions() end)

    widgets.specDrop:ClearAllPoints()
    widgets.specDrop:SetPoint("LEFT", widgets.classDrop, "RIGHT", 10, 0)
    -- The "Class"/"Spec" captions are anchored ABOVE their dropdowns,
    -- so the row needs to start lower or they overlap the section
    -- header. dy pushes the widget down; h reserves the caption space.
    addRow(rotationSec, widgets.classDrop, 62, 8, widgets.specDrop, -16)

    buildSpecOptions()

    ---------------- Keybinds (diagnostic) ----------------
    local keys = addSection("keys", "Keybinds")
    for i = 1, 18 do
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        -- FontStrings cannot be positioned by addRow directly, so wrap
        local holder = CreateFrame("Frame", nil, panel)
        holder:SetHeight(14); holder:SetWidth(330)
        fs:SetPoint("LEFT", holder, "LEFT", 0, 0)
        holder.Refresh = function() end
        keyLines[i] = fs
        addRow(keys, holder, 15, 24)
    end
    ElvinRotationDB.collapsed = ElvinRotationDB.collapsed or {}
    if ElvinRotationDB.collapsed.keys == nil then
        ElvinRotationDB.collapsed.keys = true   -- diagnostics folded by default
    end

    rolledUp = ElvinRotationDB.rolledUp or false
    roll:SetText(rolledUp and "+" or "_")

    relayout()
    panel:Hide()
end

--------------------------------------------------------------------
function ER:RefreshOptions()
    if not panel then return end
    for _, w in pairs(widgets) do if w.Refresh then w.Refresh() end end
    for _, w in ipairs(specRows) do if w.Refresh then w.Refresh() end end
    refreshKeyPane()
    relayout()
end

function ER:ToggleOptions()
    if not panel then build() end
    if panel:IsShown() then
        panel:Hide()
    else
        ER:RefreshOptions()
        panel:Show()
    end
end
