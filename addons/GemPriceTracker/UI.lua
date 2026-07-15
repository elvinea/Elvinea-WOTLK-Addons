GPT = GPT or {}

local FRAME_W = 470
local CONTENT_W = 430
local ROW_H = 20
local HEADER_H = 22

GPT.widgets = {
    materials = {},
    cutgems   = {},
    kit       = { rows = {} },
    smallkit  = { rows = {} },
}

-- ------------------------------------------------------------
-- small helpers
-- ------------------------------------------------------------
local function CreateLabel(parent, text, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if size then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, "")
    end
    if color then
        fs:SetTextColor(color[1], color[2], color[3])
    end
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

local function CreateNumberEditBox(parent, width, initial, onCommit)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(width, ROW_H)
    eb:SetAutoFocus(false)
    eb:SetNumeric(false)
    eb:SetJustifyH("CENTER")
    eb:SetMaxLetters(8)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetTextInsets(2, 2, 2, 2)
    eb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    eb:SetBackdropColor(0, 0, 0, 0.55)
    eb:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
    eb:SetText(tostring(initial or 0))
    eb.commit = onCommit
    eb:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local v = tonumber(self:GetText())
        if v then
            self.commit(v)
            GPT_Recalc()
        else
            self:SetText(tostring(initial or 0))
        end
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

local function CreateCheck(parent, checked, onClick)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
        GPT_Recalc()
    end)
    return cb
end

-- ------------------------------------------------------------
-- Main frame + scroll content
-- ------------------------------------------------------------
local mainFrame, content
local sectionList = {} -- { key, title, header, content, build }

local function ToggleSection(key)
    local db = GPT.db
    db.sections[key] = not db.sections[key]
    GPT.Layout()
end

local function CreateSectionHeader(parentContent, key, title)
    local header = CreateFrame("Button", nil, parentContent)
    header:SetSize(CONTENT_W, HEADER_H)
    local fs = CreateLabel(header, "", 13)
    fs:SetPoint("LEFT", 2, 0)
    header.fs = fs
    header:SetScript("OnClick", function() ToggleSection(key) end)
    header:SetScript("OnEnter", function(self) self.fs:SetTextColor(1, 1, 1) end)
    header:SetScript("OnLeave", function(self) self.fs:SetTextColor(1, 0.82, 0) end)

    local function updateText()
        local open = GPT.db.sections[key]
        fs:SetText((open and "|cffffd200[-]|r " or "|cffffd200[+]|r ") .. title)
    end
    header.updateText = updateText

    return header
end

-- ------------------------------------------------------------
-- Raw Materials section
-- ------------------------------------------------------------
local function BuildMaterialsSection(c)
    local y = -4
    for i, m in ipairs(GPT.Materials) do
        local row = CreateFrame("Frame", nil, c)
        row:SetSize(CONTENT_W, ROW_H)
        row:SetPoint("TOPLEFT", 4, y)

        local nameFS = CreateLabel(row, m.name)
        nameFS:SetPoint("LEFT", 0, 0)
        nameFS:SetWidth(220)

        local eb = CreateNumberEditBox(row, 50, GPT.db.materialPrice[m.key], function(v)
            GPT.db.materialPrice[m.key] = v
        end)
        eb:SetPoint("LEFT", 230, 0)

        local gLabel = CreateLabel(row, "g", 12)
        gLabel:SetPoint("LEFT", eb, "RIGHT", 4, 0)

        GPT.widgets.materials[m.key] = { eb = eb }
        y = y - ROW_H
    end
    return -y + 6
end

-- ------------------------------------------------------------
-- Cut Gems section
-- ------------------------------------------------------------
local function BuildCutGemsSection(c)
    local y = -4

    local hdr = CreateFrame("Frame", nil, c)
    hdr:SetSize(CONTENT_W, ROW_H)
    hdr:SetPoint("TOPLEFT", 4, y)
    local h1 = CreateLabel(hdr, "Gem", 11, {0.7,0.7,0.7}); h1:SetPoint("LEFT", 0, 0)
    local h2 = CreateLabel(hdr, "Sell", 11, {0.7,0.7,0.7}); h2:SetPoint("LEFT", 150, 0)
    local h3 = CreateLabel(hdr, "Mat Cost", 11, {0.7,0.7,0.7}); h3:SetPoint("LEFT", 230, 0)
    local h4 = CreateLabel(hdr, "Profit", 11, {0.7,0.7,0.7}); h4:SetPoint("LEFT", 320, 0)
    y = y - ROW_H

    for _, g in ipairs(GPT.CutGems) do
        local row = CreateFrame("Frame", nil, c)
        row:SetSize(CONTENT_W, ROW_H)
        row:SetPoint("TOPLEFT", 4, y)

        local nameFS = CreateLabel(row, g.name)
        nameFS:SetWidth(150)
        nameFS:SetPoint("LEFT", 0, 0)

        local sellEB = CreateNumberEditBox(row, 45, GPT.db.gemSell[g.key], function(v)
            GPT.db.gemSell[g.key] = v
        end)
        sellEB:SetPoint("LEFT", 150, 0)

        local matCostFS = CreateLabel(row, "")
        matCostFS:SetPoint("LEFT", 230, 0)
        matCostFS:SetWidth(70)

        local profitFS = CreateLabel(row, "")
        profitFS:SetPoint("LEFT", 320, 0)
        profitFS:SetWidth(80)

        GPT.widgets.cutgems[g.key] = { sellEB = sellEB, matCostFS = matCostFS, profitFS = profitFS }
        y = y - ROW_H
    end
    return -y + 6
end

-- ------------------------------------------------------------
-- Gem Kit Calculator section
-- ------------------------------------------------------------
local function BuildKitSection(c)
    local y = -4

    local budgetRow = CreateFrame("Frame", nil, c)
    budgetRow:SetSize(CONTENT_W, ROW_H)
    budgetRow:SetPoint("TOPLEFT", 4, y)
    local bLabel = CreateLabel(budgetRow, "Gold Budget:")
    bLabel:SetPoint("LEFT", 0, 0)
    local budgetEB = CreateNumberEditBox(budgetRow, 65, GPT.db.budget, function(v)
        GPT.db.budget = v
    end)
    budgetEB:SetPoint("LEFT", 110, 0)
    GPT.widgets.kit.budgetEB = budgetEB
    y = y - ROW_H - 4

    local note = CreateLabel(c, "Check = include. Manual Qty > 0 locks that gem; 0 = auto-distribute.", 10, {0.6,0.6,0.6})
    note:SetPoint("TOPLEFT", 4, y)
    note:SetWidth(CONTENT_W - 8)
    y = y - 16

    local hdr = CreateFrame("Frame", nil, c)
    hdr:SetSize(CONTENT_W, ROW_H)
    hdr:SetPoint("TOPLEFT", 4, y)
    local h = {}
    h[1] = CreateLabel(hdr, "Gem", 10, {0.7,0.7,0.7}); h[1]:SetPoint("LEFT", 0, 0)
    h[2] = CreateLabel(hdr, "In", 10, {0.7,0.7,0.7}); h[2]:SetPoint("LEFT", 108, 0)
    h[3] = CreateLabel(hdr, "Manual", 10, {0.7,0.7,0.7}); h[3]:SetPoint("LEFT", 132, 0)
    h[4] = CreateLabel(hdr, "Qty", 10, {0.7,0.7,0.7}); h[4]:SetPoint("LEFT", 190, 0)
    h[5] = CreateLabel(hdr, "Stk", 10, {0.7,0.7,0.7}); h[5]:SetPoint("LEFT", 230, 0)
    h[6] = CreateLabel(hdr, "Price", 10, {0.7,0.7,0.7}); h[6]:SetPoint("LEFT", 265, 0)
    h[7] = CreateLabel(hdr, "Value", 10, {0.7,0.7,0.7}); h[7]:SetPoint("LEFT", 320, 0)
    y = y - ROW_H

    for _, g in ipairs(GPT.CutGems) do
        local row = CreateFrame("Frame", nil, c)
        row:SetSize(CONTENT_W, ROW_H)
        row:SetPoint("TOPLEFT", 4, y)

        local nameFS = CreateLabel(row, g.name)
        nameFS:SetWidth(105)
        nameFS:SetPoint("LEFT", 0, 0)

        local kitRow = GPT.db.kit[g.key]
        local cb = CreateCheck(row, kitRow.include, function(checked)
            GPT.db.kit[g.key].include = checked
        end)
        cb:SetPoint("LEFT", 100, 0)

        local manualEB = CreateNumberEditBox(row, 40, kitRow.manualQty, function(v)
            GPT.db.kit[g.key].manualQty = v
        end)
        manualEB:SetPoint("LEFT", 132, 0)

        local qtyFS = CreateLabel(row, "")
        qtyFS:SetWidth(35)
        qtyFS:SetPoint("LEFT", 192, 0)

        local stacksFS = CreateLabel(row, "")
        stacksFS:SetWidth(30)
        stacksFS:SetPoint("LEFT", 230, 0)

        local priceFS = CreateLabel(row, "")
        priceFS:SetWidth(50)
        priceFS:SetPoint("LEFT", 265, 0)

        local valueFS = CreateLabel(row, "")
        valueFS:SetWidth(80)
        valueFS:SetPoint("LEFT", 320, 0)

        GPT.widgets.kit.rows[g.key] = {
            cb = cb, manualEB = manualEB, qtyFS = qtyFS,
            stacksFS = stacksFS, priceFS = priceFS, valueFS = valueFS,
        }
        y = y - ROW_H
    end

    y = y - 4
    local totalsRow = CreateFrame("Frame", nil, c)
    totalsRow:SetSize(CONTENT_W, ROW_H)
    totalsRow:SetPoint("TOPLEFT", 4, y)
    local totalLabel = CreateLabel(totalsRow, "Total Value:")
    totalLabel:SetPoint("LEFT", 230, 0)
    local totalFS = CreateLabel(totalsRow, "")
    totalFS:SetPoint("LEFT", 320, 0)
    GPT.widgets.kit.totalValueFS = totalFS
    y = y - ROW_H

    local statusFS = CreateLabel(c, "", 11)
    statusFS:SetPoint("TOPLEFT", 4, y)
    statusFS:SetWidth(CONTENT_W - 8)
    GPT.widgets.kit.statusFS = statusFS
    y = y - ROW_H

    return -y + 6
end

-- ------------------------------------------------------------
-- Small Gem Kit section
-- ------------------------------------------------------------
local function BuildSmallKitSection(c)
    local y = -4

    local hdr = CreateFrame("Frame", nil, c)
    hdr:SetSize(CONTENT_W, ROW_H)
    hdr:SetPoint("TOPLEFT", 4, y)
    local h1 = CreateLabel(hdr, "Gem", 10, {0.7,0.7,0.7}); h1:SetPoint("LEFT", 0, 0)
    local h2 = CreateLabel(hdr, "In", 10, {0.7,0.7,0.7}); h2:SetPoint("LEFT", 128, 0)
    local h3 = CreateLabel(hdr, "Qty", 10, {0.7,0.7,0.7}); h3:SetPoint("LEFT", 152, 0)
    local h4 = CreateLabel(hdr, "Stk", 10, {0.7,0.7,0.7}); h4:SetPoint("LEFT", 210, 0)
    local h5 = CreateLabel(hdr, "Price", 10, {0.7,0.7,0.7}); h5:SetPoint("LEFT", 250, 0)
    local h6 = CreateLabel(hdr, "Value", 10, {0.7,0.7,0.7}); h6:SetPoint("LEFT", 320, 0)
    y = y - ROW_H

    for _, s in ipairs(GPT.SmallKit) do
        local row = CreateFrame("Frame", nil, c)
        row:SetSize(CONTENT_W, ROW_H)
        row:SetPoint("TOPLEFT", 4, y)

        local nameFS = CreateLabel(row, s.name)
        nameFS:SetWidth(125)
        nameFS:SetPoint("LEFT", 0, 0)

        local skRow = GPT.db.smallKit[s.key]
        local cb = CreateCheck(row, skRow.include, function(checked)
            GPT.db.smallKit[s.key].include = checked
        end)
        cb:SetPoint("LEFT", 120, 0)

        local qtyEB = CreateNumberEditBox(row, 45, skRow.qty, function(v)
            GPT.db.smallKit[s.key].qty = v
        end)
        qtyEB:SetPoint("LEFT", 150, 0)

        local stacksFS = CreateLabel(row, "")
        stacksFS:SetWidth(35)
        stacksFS:SetPoint("LEFT", 210, 0)

        local priceFS = CreateLabel(row, "")
        priceFS:SetWidth(60)
        priceFS:SetPoint("LEFT", 250, 0)

        local valueFS = CreateLabel(row, "")
        valueFS:SetWidth(80)
        valueFS:SetPoint("LEFT", 320, 0)

        GPT.widgets.smallkit.rows[s.key] = {
            cb = cb, qtyEB = qtyEB, stacksFS = stacksFS, priceFS = priceFS, valueFS = valueFS,
        }
        y = y - ROW_H
    end

    y = y - 4
    local totalsRow = CreateFrame("Frame", nil, c)
    totalsRow:SetSize(CONTENT_W, ROW_H)
    totalsRow:SetPoint("TOPLEFT", 4, y)
    local totalLabel = CreateLabel(totalsRow, "Total Value:")
    totalLabel:SetPoint("LEFT", 210, 0)
    local totalFS = CreateLabel(totalsRow, "")
    totalFS:SetPoint("LEFT", 320, 0)
    GPT.widgets.smallkit.totalValueFS = totalFS
    y = y - ROW_H

    return -y + 6
end

-- ------------------------------------------------------------
-- Layout: position headers/content based on collapse state
-- ------------------------------------------------------------
function GPT.Layout()
    local y = -4
    for _, sec in ipairs(sectionList) do
        sec.header:ClearAllPoints()
        sec.header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        sec.header.updateText()
        y = y - HEADER_H

        local open = GPT.db.sections[sec.key]
        if open then
            sec.content:ClearAllPoints()
            sec.content:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            sec.content:Show()
            y = y - sec.height - 6
        else
            sec.content:Hide()
        end
    end
    content:SetHeight(math.max(-y, 10))
end

-- ------------------------------------------------------------
-- Refresh: push calculated values into the widgets
-- ------------------------------------------------------------
function GPT.RefreshUI()
    if not content then return end

    for _, g in ipairs(GPT.CutGems) do
        local w = GPT.widgets.cutgems[g.key]
        local calc = GPT.calc.cutGems[g.key]
        if w and calc then
            w.matCostFS:SetText(string.format("%.0fg", calc.matCost))
            if calc.profit >= 0 then
                w.profitFS:SetTextColor(0.2, 1, 0.2)
            else
                w.profitFS:SetTextColor(1, 0.3, 0.3)
            end
            w.profitFS:SetText(string.format("%.0fg", calc.profit))
        end
    end

    for _, g in ipairs(GPT.CutGems) do
        local w = GPT.widgets.kit.rows[g.key]
        local calc = GPT.calc.kit[g.key]
        if w and calc then
            w.qtyFS:SetText(tostring(calc.qty))
            w.stacksFS:SetText(tostring(calc.stacks))
            w.priceFS:SetText(string.format("%.0fg", GPT.db.gemSell[g.key]))
            w.valueFS:SetText(string.format("%.0fg", calc.value))
        end
    end
    if GPT.widgets.kit.totalValueFS then
        GPT.widgets.kit.totalValueFS:SetText(string.format("%.0fg", GPT.calc.kitTotalValue))
    end
    if GPT.widgets.kit.statusFS then
        local budget = tonumber(GPT.db.budget) or 0
        if GPT.calc.kitOverBudget then
            GPT.widgets.kit.statusFS:SetTextColor(1, 0.3, 0.3)
            GPT.widgets.kit.statusFS:SetText(string.format("Over budget by %.0fg", GPT.calc.kitTotalValue - budget))
        else
            GPT.widgets.kit.statusFS:SetTextColor(0.2, 1, 0.2)
            GPT.widgets.kit.statusFS:SetText(string.format("Under budget - %.0fg remaining", budget - GPT.calc.kitTotalValue))
        end
    end

    for _, s in ipairs(GPT.SmallKit) do
        local w = GPT.widgets.smallkit.rows[s.key]
        local calc = GPT.calc.smallKit[s.key]
        if w and calc then
            w.stacksFS:SetText(tostring(calc.stacks))
            w.priceFS:SetText(string.format("%.0fg", calc.price))
            w.valueFS:SetText(string.format("%.0fg", calc.value))
        end
    end
    if GPT.widgets.smallkit.totalValueFS then
        GPT.widgets.smallkit.totalValueFS:SetText(string.format("%.0fg", GPT.calc.smallKitTotalValue))
    end
end

-- ------------------------------------------------------------
-- Build the frame
-- ------------------------------------------------------------
function GPT.BuildUI()
    if mainFrame then return end

    mainFrame = CreateFrame("Frame", "GemPriceTrackerFrame", UIParent)
    local savedSize = GPT.db.frameSize or { w = FRAME_W, h = 560 }
    mainFrame:SetSize(savedSize.w, savedSize.h)
    mainFrame:SetResizable(true)
    mainFrame:SetMinResize(FRAME_W, 300)
    mainFrame:SetMaxResize(900, 1000)
    local pos = GPT.db.framePos
    mainFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        GPT.db.framePos = { point = point, x = x, y = y }
    end)
    mainFrame:SetClampedToScreen(true)
    mainFrame:Hide()
    tinsert(UISpecialFrames, "GemPriceTrackerFrame")

    local title = CreateLabel(mainFrame, "Gem & Material Price Tracker", 14)
    title:SetPoint("TOP", 0, -18)

    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -4, -4)

    local resizeGrip = CreateFrame("Button", nil, mainFrame)
    resizeGrip:SetSize(16, 16)
    resizeGrip:SetPoint("BOTTOMRIGHT", -6, 7)
    resizeGrip:SetNormalTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Up")
    resizeGrip:SetHighlightTexture("Interface\\Buttons\\UI-Panel-ExpandButton-Down")
    resizeGrip:SetScript("OnMouseDown", function()
        mainFrame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        GPT.db.frameSize = { w = mainFrame:GetWidth(), h = mainFrame:GetHeight() }
    end)

    local hint = CreateLabel(mainFrame, "Click a section header to collapse/expand it.", 10, {0.6,0.6,0.6})
    hint:SetPoint("TOP", 0, -34)

    local scroll = CreateFrame("ScrollFrame", "GemPriceTrackerScroll", mainFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -52)
    scroll:SetPoint("BOTTOMRIGHT", -34, 16)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_W, 10)
    scroll:SetScrollChild(content)

    local defs = {
        { key = "materials", title = "Raw Materials",      build = BuildMaterialsSection },
        { key = "cutgems",   title = "Cut Gems",            build = BuildCutGemsSection },
        { key = "kit",       title = "Gem Kit Calculator",  build = BuildKitSection },
        { key = "smallkit",  title = "Small Gem Kit",       build = BuildSmallKitSection },
    }

    for _, d in ipairs(defs) do
        local header = CreateSectionHeader(content, d.key, d.title)
        local secContent = CreateFrame("Frame", nil, content)
        secContent:SetSize(CONTENT_W, 10)
        local h = d.build(secContent)
        secContent:SetHeight(h)
        table.insert(sectionList, { key = d.key, header = header, content = secContent, height = h })
    end

    GPT.Layout()
    GPT.RefreshUI()
end

function GPT.ToggleFrame()
    if not mainFrame then
        GPT.BuildUI()
    end
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        GPT.RefreshUI()
    end
end
