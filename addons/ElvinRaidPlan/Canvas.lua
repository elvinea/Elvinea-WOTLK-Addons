--[[
	ElvinRaidPlan - Canvas.lua
	Builds the main window and the canvas surface objects get placed on, handles
	background selection, and runs the "drag palette icon onto canvas" placement
	flow (a mouse-follow ghost, finalized on left-button release).
]]

local ERP = ElvinRaidPlan

local GHOST_SIZE = 32

function ERP:FlashSaved()
	if not self.savedText then return end
	self.savedText:SetText("Saved!")
	self.savedText:SetAlpha(1)
	self.savedFade = 1.2
end

-- ============================================================
-- Placement (drag a palette tool onto the canvas)
-- ============================================================

local function BuildGhostVisual(ghost, info)
	for _, child in ipairs({ ghost:GetRegions() }) do
		child:Hide()
		child:SetParent(nil)
	end

	if info.kind == "shape" then
		local tex = ghost:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints(ghost)
		tex:SetTexture(ERP.ShapeTextures[info.shapeType])
		tex:SetVertexColor(1, 1, 1, 0.7)
	elseif info.kind == "marker" then
		local tex = ghost:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints(ghost)
		tex:SetTexture(string.format(ERP.RaidMarkerTexture, info.markerIndex))
		tex:SetAlpha(0.75)
	elseif info.kind == "class" then
		local tex = ghost:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints(ghost)
		tex:SetTexture(ERP.ClassFile(info.classToken))
		tex:SetAlpha(0.75)
	elseif info.kind == "text" then
		local fs = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fs:SetPoint("CENTER")
		fs:SetText("Text")
		fs:SetAlpha(0.75)
	end
end

function ERP:BeginPlacement(info)
	if self.ghost then
		self.ghost:Hide()
		self.ghost:SetScript("OnUpdate", nil)
		self.ghost:SetParent(nil)
		self.ghost = nil
	end

	local ghost = CreateFrame("Frame", nil, UIParent)
	ghost:SetSize(GHOST_SIZE, GHOST_SIZE)
	ghost:SetFrameStrata("TOOLTIP")
	BuildGhostVisual(ghost, info)
	self.ghost = ghost
	self.pendingInfo = info
	self.placementActive = true

	ghost:SetScript("OnUpdate", function(selfGhost)
		local x, y = GetCursorPosition()
		local scale = UIParent:GetEffectiveScale()
		selfGhost:ClearAllPoints()
		selfGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)

		if IsMouseButtonDown("RightButton") then
			ERP:CancelPlacement()
		elseif not IsMouseButtonDown("LeftButton") then
			ERP:FinalizePlacement()
		end
	end)
end

function ERP:CancelPlacement()
	if self.ghost then
		self.ghost:Hide()
		self.ghost:SetScript("OnUpdate", nil)
	end
	self.placementActive = false
	self.pendingInfo = nil
end

function ERP:FinalizePlacement()
	local ghost = self.ghost
	local info = self.pendingInfo
	self.placementActive = false

	if not ghost or not info then return end
	ghost:Hide()
	ghost:SetScript("OnUpdate", nil)

	local cx, cy = ghost:GetCenter()
	local left, right = self.canvas:GetLeft(), self.canvas:GetRight()
	local top, bottom = self.canvas:GetTop(), self.canvas:GetBottom()

	if cx and left and cx >= left and cx <= right and cy >= bottom and cy <= top then
		local canvasCx, canvasCy = self.canvas:GetCenter()
		local relX = (cx - canvasCx) / self.canvas:GetWidth()
		local relY = (cy - canvasCy) / self.canvas:GetHeight()
		self:CreateObject(info, relX, relY)
	end

	self.pendingInfo = nil
end

-- ============================================================
-- Main frame
-- ============================================================

function ERP:CreateMainFrame()
	local f = CreateFrame("Frame", "ElvinRaidPlanMainFrame", UIParent)
	f:SetSize(760, 560)
	f:SetPoint("CENTER")
	f:SetFrameStrata("HIGH")
	f:SetMovable(true)
	f:SetResizable(true)
	if f.SetMinResize then f:SetMinResize(560, 420) end
	if f.SetMaxResize then f:SetMaxResize(1400, 1000) end
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetClampedToScreen(true)
	f:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 11, top = 11, bottom = 11 },
	})
	f:Hide()
	tinsert(UISpecialFrames, "ElvinRaidPlanMainFrame") -- allows Esc to close
	self.mainFrame = f

	-- Title bar / drag region
	local title = CreateFrame("Frame", nil, f)
	title:SetPoint("TOPLEFT", 12, -12)
	title:SetPoint("TOPRIGHT", -12, -12)
	title:SetHeight(24)
	title:EnableMouse(true)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", function() f:StartMoving() end)
	title:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

	local titleText = title:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titleText:SetPoint("LEFT", 4, 0)
	titleText:SetText("ElvinRaidPlan")

	local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	closeBtn:SetScript("OnClick", function() f:Hide() end)

	-- Resize grip, bottom-right corner
	local sizer = CreateFrame("Button", nil, f)
	sizer:SetSize(16, 16)
	sizer:SetPoint("BOTTOMRIGHT", -6, 6)
	sizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	sizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	sizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	sizer:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
	sizer:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		ERP:LayoutAfterResize()
	end)

	-- Plan controls row
	local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
	nameBox:SetSize(150, 20)
	nameBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 6, -10)
	nameBox:SetAutoFocus(false)
	nameBox:SetScript("OnEnterPressed", function(self)
		local newName = self:GetText()
		if newName ~= "" and newName ~= ERP.currentPlanName then
			ERP:RenamePlan(ERP.currentPlanName, newName)
		end
		self:ClearFocus()
	end)
	self.planNameBox = nameBox

	local function MakeSmallButton(label, width, anchorTo, xoff)
		local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		b:SetSize(width, 22)
		b:SetPoint("LEFT", anchorTo, "RIGHT", xoff, 0)
		b:SetText(label)
		return b
	end

	local openBtn = MakeSmallButton("Open", 48, nameBox, 8)
	openBtn:SetScript("OnClick", function() ERP:TogglePlanPicker() end)

	local newBtn = MakeSmallButton("New", 46, openBtn, 4)
	newBtn:SetScript("OnClick", function()
		StaticPopup_Show("ELVINRAIDPLAN_NEW_PLAN")
	end)

	local saveBtn = MakeSmallButton("Save", 50, newBtn, 4)
	saveBtn:SetScript("OnClick", function() ERP:SavePlan() end)

	local deleteBtn = MakeSmallButton("Delete", 56, saveBtn, 4)
	deleteBtn:SetScript("OnClick", function()
		if ERP.currentPlanName then
			StaticPopupDialogs["ELVINRAIDPLAN_CONFIRM_DELETE"].text =
				"Delete plan '" .. ERP.currentPlanName .. "'?"
			StaticPopup_Show("ELVINRAIDPLAN_CONFIRM_DELETE")
		end
	end)

	local colorBtn = MakeSmallButton("Color", 50, deleteBtn, 4)
	colorBtn:SetScript("OnClick", function() ERP:CycleFlatColor() end)

	local mapBtn = MakeSmallButton("Map...", 56, colorBtn, 2)
	mapBtn:SetScript("OnClick", function() ERP:ToggleMapPicker() end)

	local bgLabel = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	bgLabel:SetPoint("LEFT", mapBtn, "RIGHT", 8, 0)
	bgLabel:SetWidth(90)
	bgLabel:SetJustifyH("LEFT")
	self.bgLabel = bgLabel

	local savedText = f:CreateFontString(nil, "ARTWORK", "GameFontGreen")
	savedText:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -4)
	savedText:SetAlpha(0)
	self.savedText = savedText

	f:SetScript("OnUpdate", function(self, elapsed)
		if ERP.savedFade and ERP.savedFade > 0 then
			ERP.savedFade = ERP.savedFade - elapsed
			savedText:SetAlpha(math.max(0, ERP.savedFade))
		end
	end)

	-- Canvas surface. Its left edge is anchored to the palette (built below)
	-- rather than the other way around, to avoid a circular anchor dependency.
	local canvas = CreateFrame("Frame", nil, f)
	canvas:EnableMouse(true) -- so empty-canvas clicks can deselect
	canvas:SetBackdrop({
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
	})
	canvas:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	local canvasTex = canvas:CreateTexture(nil, "BACKGROUND")
	canvasTex:SetAllPoints(canvas)
	canvasTex:SetTexture(0.08, 0.08, 0.09, 1)
	canvas:SetScript("OnMouseDown", function() ERP:DeselectObject() end)
	self.canvas = canvas
	self.canvasTexture = canvasTex

	self:BuildPalette(f, canvas, nameBox)

	canvas:SetPoint("TOPLEFT", self.palette, "TOPRIGHT", 10, 0)
	canvas:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)

	self:BuildMapPicker(f)
	self:BuildPlanPicker(f)
	self:RenderFlatColor("dark")

	-- Popups
	StaticPopupDialogs["ELVINRAIDPLAN_NEW_PLAN"] = {
		text = "New plan name:",
		button1 = "Create",
		button2 = "Cancel",
		hasEditBox = true,
		OnAccept = function(self)
			ERP:NewPlan(self.editBox:GetText())
		end,
		EditBoxOnEnterPressed = function(self)
			ERP:NewPlan(self:GetText())
			self:GetParent():Hide()
		end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	StaticPopupDialogs["ELVINRAIDPLAN_CONFIRM_DELETE"] = {
		text = "Delete this plan?",
		button1 = "Delete",
		button2 = "Cancel",
		OnAccept = function() ERP:DeletePlan(ERP.currentPlanName) end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
end

-- Re-run anything that depends on the canvas' pixel size (zone map tiles;
-- selection handle positions) after the window has been resized.
function ERP:LayoutAfterResize()
	if self.currentBackground then
		self:SetBackground(self.currentBackground)
	end
	self:UpdateHandles()
end
