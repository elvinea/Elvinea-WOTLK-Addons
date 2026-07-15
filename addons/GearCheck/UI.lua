-- GearCheck :: UI.lua
-- Pop-up window: one line per player (collapsed), click to drop down per-slot detail.

GearCheck = GearCheck or {}
local GC = GearCheck
GC.lines = {}
GC.expandedItem = {}   -- ["Player\0Slot"] = true

local WIN_W, WIN_H = 600, 470
local ROW_H, DET_H = 16, 14

-------------------------------------------------------------------------------
-- Build the frame once
-------------------------------------------------------------------------------
local function makeButton(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetHeight(20); b:SetWidth(w or 90); b:SetText(text)
    return b
end

function GC:BuildUI()
    if self.win then return end
    local f = CreateFrame("Frame", "GearCheckWindow", UIParent)
    f:SetWidth(WIN_W); f:SetHeight(WIN_H)
    f:SetPoint("TOPLEFT", UIParent, "CENTER", -WIN_W/2, WIN_H/2)  -- anchored by top-left so resizing is stable
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetResizable(true)
    if f.SetMinResize then f:SetMinResize(500, 220) end
    if f.SetMaxResize then f:SetMaxResize(1200, 1100) end
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -16)
    title:SetText("GearCheck  |cff888888v2.8|r")
    f.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    -- action buttons
    local bSelf   = makeButton(f, "Scan Self",   78); bSelf:SetPoint("TOPLEFT", 14, -36)
    local bTarget = makeButton(f, "Scan Target", 82); bTarget:SetPoint("LEFT", bSelf, "RIGHT", 4, 0)
    local bRaid   = makeButton(f, "Scan Raid",   74); bRaid:SetPoint("LEFT", bTarget, "RIGHT", 4, 0)
    local bCheck  = makeButton(f, "Check",       56); bCheck:SetPoint("LEFT", bRaid, "RIGHT", 4, 0)
    local bExpand = makeButton(f, "Expand All",  78); bExpand:SetPoint("LEFT", bCheck, "RIGHT", 4, 0)
    local bClear  = makeButton(f, "Clear",       56); bClear:SetPoint("LEFT", bExpand, "RIGHT", 4, 0)
    bSelf:SetScript("OnClick",   function() GC:ScanSelf()  end)
    bTarget:SetScript("OnClick", function() GC:ScanTarget() end)
    bRaid:SetScript("OnClick",   function() GC:ScanRaid()  end)
    bCheck:SetScript("OnClick",  function() GC:Check()     end)
    bExpand:SetScript("OnClick", function() GC:ToggleAll() end)
    bClear:SetScript("OnClick",  function() GC:ClearResults() end)

    -- scroll area
    local sf = CreateFrame("ScrollFrame", "GearCheckScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -64)
    sf:SetPoint("BOTTOMRIGHT", -34, 20)
    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(WIN_W - 60)
    child:SetHeight(1)
    sf:SetScrollChild(child)

    self.win, self.child, self.scroll = f, child, sf

    -- resize grip (bottom-right). Only re-flow the list once, on release, to avoid
    -- the per-frame re-render bug during dragging.
    local grip = CreateFrame("Button", nil, f)
    grip:SetWidth(16); grip:SetHeight(16)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    grip:SetPoint("BOTTOMRIGHT", -6, 6)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() GC.resizing = true; f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing(); GC.resizing = false
        if GC.scroll then GC.child:SetWidth(GC.scroll:GetWidth()) end
        GC:Render()
    end)

    -- during drag: just keep the scroll child width in sync (cheap); render on release
    f:SetScript("OnSizeChanged", function()
        if GC.child and GC.scroll then GC.child:SetWidth(GC.scroll:GetWidth()) end
    end)
end

function GC:Show() self:BuildUI(); self.win:Show(); self:Render() end
function GC:Hide() if self.win then self.win:Hide() end end

-------------------------------------------------------------------------------
-- Line pool
-------------------------------------------------------------------------------
function GC:GetLine(i)
    local ln = self.lines[i]
    if not ln then
        ln = CreateFrame("Button", nil, self.child)
        ln:SetHeight(ROW_H)
        ln:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        ln.text = ln:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ln.text:SetPoint("LEFT", 2, 0)
        ln.text:SetJustifyH("LEFT")
        ln:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        ln:SetScript("OnClick", function(self2, button)
            if self2.kind == "player" then
                if button == "RightButton" then GC:CycleRole(self2.pname)
                else GC:ToggleExpand(self2.pname) end
            elseif self2.kind == "item" and self2.itemKey then
                GC.expandedItem[self2.itemKey] = not GC.expandedItem[self2.itemKey]
                GC:Render()
            end
        end)
        self.lines[i] = ln
    end
    return ln
end

function GC:ToggleExpand(name)
    self.expanded[name] = not self.expanded[name]
    self:Render()
end

function GC:ToggleAll()
    local anyCollapsed = false
    for n in pairs(self.results) do if not self.expanded[n] then anyCollapsed = true break end end
    for n in pairs(self.results) do self.expanded[n] = anyCollapsed end
    self:Render()
end

-------------------------------------------------------------------------------
-- Collapsed item header line: "! Slot: Item   (N)"
-------------------------------------------------------------------------------
-- Talents dropdown: header line + per-talent right/wrong list
function GC:TalentHeader(d, expanded)
    local t = d.talents
    local arrow = expanded and "|cffffcc00-|r" or "|cffffcc00+|r"
    local spec = (t and t.spec) and (" |cffaaaaaa[" .. t.spec .. "]|r") or ""
    local mark, status
    if not t or t.noref then
        mark = "|cff888888.|r"; status = "|cff888888no reference|r"
    elseif t.ok then
        mark = "|cff55dd55.|r"; status = "|cff33ff33correct|r"
    else
        mark = "|cffff4040!|r"; status = "|cffff4040" .. t.wrong .. " wrong|r"
    end
    return string.format("%s %s |cffffffffTalents:|r%s   %s", arrow, mark, spec, status)
end

function GC:TalentDetails(d)
    local out = {}
    local t = d.talents
    if not t or t.noref then
        out[#out+1] = "|cff888888no reference build for this spec (add it to the Talent Builds tab)|r"
        return out
    end
    for _, ln in ipairs(t.lines) do
        if ln.status == "ok" then
            out[#out+1] = string.format("|cff55dd55v %s %d/%d|r", ln.name, ln.got, ln.need)
        elseif ln.status == "extra" then
            out[#out+1] = string.format("|cffff4040x %s %d (not in build)|r", ln.name, ln.got)
        else
            out[#out+1] = string.format("|cffff4040x %s %d/%d|r", ln.name, ln.got, ln.need)
        end
    end
    if #out == 0 then out[#out+1] = "|cff55dd55- ok|r" end
    return out
end

-- Talents dropdown: header line + per-talent right/wrong list  (renderers above)
function GC:ItemHeader(sd, expanded)
    local np = sd.problems and #sd.problems or 0
    local arrow = expanded and "|cffffcc00-|r" or "|cffffcc00+|r"
    local mark, status
    if np > 0 then mark = "|cffff4040!|r"; status = "|cffff4040(" .. np .. ")|r"
    elseif sd.preBis then mark = "|cffff8800~|r"; status = "|cffff8800pre-BiS|r"
    elseif sd.notBis then mark = "|cffffcc00~|r"; status = "|cffffcc00off-BiS|r"
    else mark = "|cff55dd55.|r"; status = "" end
    local il = sd.ilvl and (" |cff707070i" .. sd.ilvl .. "|r") or ""
    return string.format("%s %s |cffffffff%s:|r %s%s   %s", arrow, mark, sd.slot, (sd.item or "?"), il, status)
end

-- Detail lines shown when an item is expanded
function GC:ItemDetails(sd)
    local out = {}
    if sd.gems and #sd.gems > 0 then
        out[#out+1] = "|cff88ccffGems:|r " .. table.concat(sd.gems, ", ")
    else
        out[#out+1] = "|cff888888Gems:|r none socketed"
    end
    if sd.id == 6 then
        out[#out+1] = "|cff88ff88Belt Buckle:|r " .. (sd.hasBuckle and "present" or "|cffff4040missing|r")
    elseif sd.enchanted then
        local e
        if sd.enchName then e = sd.enchName .. (sd.enchStats and ("  |cffffd200" .. sd.enchStats .. "|r") or "")
        elseif sd.enchEffect then e = sd.enchEffect
        else e = "enchanted" end
        out[#out+1] = "|cff88ff88Enchant:|r " .. e
    else
        out[#out+1] = "|cff888888Enchant:|r none"
    end
    if sd.problems then
        for _, p in ipairs(sd.problems) do out[#out+1] = "|cffff4040- " .. p .. "|r" end
    end
    if sd.preBis then out[#out+1] = "|cffff8800- pre-BiS: Normal/base version — get the Heroic one|r" end
    if sd.notBis then out[#out+1] = "|cffffcc00- not on the BiS list for this profile|r" end
    if (not sd.problems or #sd.problems == 0) and not sd.notBis and not sd.preBis then
        out[#out+1] = "|cff55dd55- ok|r"
    end
    return out
end

-------------------------------------------------------------------------------
-- Render everything
-------------------------------------------------------------------------------
function GC:Render()
    if not self.win then return end
    local child = self.child
    if self.scroll then child:SetWidth(self.scroll:GetWidth()) end
    local names = {}
    for n in pairs(self.results) do names[#names+1] = n end
    table.sort(names, function(a, b)
        local ia = (self.results[a].issues or 0) > 0 and 0 or 1
        local ib = (self.results[b].issues or 0) > 0 and 0 or 1
        if ia ~= ib then return ia < ib end
        return a < b
    end)

    local li, y = 0, -2
    local width = child:GetWidth()

    local function put(kind, x, h, text, pname, itemKey)
        li = li + 1
        local ln = self:GetLine(li)
        ln:ClearAllPoints()
        ln:SetPoint("TOPLEFT", child, "TOPLEFT", x, y)
        ln:SetWidth(width - x - 2); ln:SetHeight(h)
        ln.kind, ln.pname, ln.itemKey = kind, pname, itemKey
        ln.text:SetText(text)
        ln:Show()
        y = y - h
    end

    for _, name in ipairs(names) do
        local d = self.results[name]
        -- player header
        local cc = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.class or ""]) or { r=1, g=1, b=1 }
        local arrow = self.expanded[name] and "-" or "+"
        local status
        if d.outOfRange then status = "|cff888888out of range|r"
        elseif d.note then status = "|cffaaaaaa" .. d.note .. "|r"
        elseif not d.validated then status = ""
        else
            local parts = {}
            if (d.issues or 0) > 0 then parts[#parts+1] = "|cffff4040" .. d.issues .. " issue(s)|r" end
            if d.talents and not d.talents.noref and (d.talents.wrong or 0) > 0 then
                parts[#parts+1] = "|cffff7d0a" .. d.talents.wrong .. " talent|r"
            end
            if (d.offbis or 0) > 0 then parts[#parts+1] = "|cffffcc00" .. d.offbis .. " off-BiS|r" end
            if (d.prebis or 0) > 0 then parts[#parts+1] = "|cffff8800" .. d.prebis .. " pre-BiS|r" end
            if #parts == 0 then status = "|cff33ff33OK|r" else status = table.concat(parts, "  ") end
        end
        local role = d.role and ("|cffaaaaaa[" .. d.role .. "]|r") or "|cff888888[?]|r"
        local gs = d.gearScore and d.gearScore > 0 and ("|cff70b8ffGS: " .. d.gearScore .. "|r") or ""
        local header = string.format("|cffffcc00%s|r |cff%02x%02x%02x%s|r  %s  %s   %s",
            arrow, cc.r*255, cc.g*255, cc.b*255, name, role, gs, status)
        put("player", 2, ROW_H, header, name)

        if self.expanded[name] and d.slots then
            for _, sd in ipairs(d.slots) do
                if sd.item then
                    local key = name .. "\0" .. sd.slot
                    local iexp = self.expandedItem[key]
                    put("item", 16, DET_H, self:ItemHeader(sd, iexp), nil, key)
                    if iexp then
                        for _, dl in ipairs(self:ItemDetails(sd)) do
                            put("detail", 34, DET_H, dl)
                        end
                    end
                end
            end
            -- Talents dropdown (guarded: a render error must never silently drop the line)
            local tkey = name .. "\0__talents"
            local texp = self.expandedItem[tkey]
            local okH, hdr = pcall(function() return self:TalentHeader(d, texp) end)
            put("item", 16, DET_H, (okH and hdr) or "|cffffcc00+|r |cffff4040!|r |cffffffffTalents:|r |cffff4040render error|r", nil, tkey)
            if texp then
                local okD, lines = pcall(function() return self:TalentDetails(d) end)
                if okD and lines then
                    for _, dl in ipairs(lines) do put("detail", 34, DET_H, dl) end
                else
                    put("detail", 34, DET_H, "|cffff4040talent detail error: " .. tostring(lines) .. "|r")
                end
            end
            y = y - 4
        end
    end

    for i = li + 1, #self.lines do self.lines[i]:Hide() end
    child:SetHeight(math.max(1, -y + 6))
end
