--[[
	ElvinRaidPlan - Palette.lua
	The left-hand strip of draggable tools: basic shapes + text, then a scrollable
	icon library (raid target markers and class icons). Press and drag any button
	onto the canvas to place it there (release over the canvas to drop it).
]]

local ERP = ElvinRaidPlan

local PALETTE_WIDTH = 68
local BTN_SIZE = 40
local BTN_PAD = 6

local function MakeToolButton(parent, texture, texCoords, tooltip, onPress)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(BTN_SIZE, BTN_SIZE)
	b:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 8,
	})
	b:SetBackdropColor(0, 0, 0, 0.3)
	b:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

	local tex = b:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("CENTER")
	tex:SetSize(BTN_SIZE - 12, BTN_SIZE - 12)
	tex:SetTexture(texture)
	if texCoords then
		tex:SetTexCoord(texCoords[1], texCoords[2], texCoords[3], texCoords[4])
	end

	b:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			onPress()
		end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltip, 1, 1, 1)
		GameTooltip:AddLine("Press and drag onto the canvas", 0.8, 0.8, 0.8)
		GameTooltip:Show()
		self:SetBackdropBorderColor(0.7, 0.7, 0.2, 1)
	end)
	b:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		self:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
	end)

	return b
end

function ERP:BuildPalette(mainFrame, canvas, nameBox)
	local palette = CreateFrame("Frame", nil, mainFrame)
	palette:SetWidth(PALETTE_WIDTH)
	palette:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -14)
	palette:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 12, 20)
	palette:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
	})
	palette:SetBackdropColor(0, 0, 0, 0.25)
	self.palette = palette

	-- Scroll frame so the marker/class icon library doesn't overflow the window.
	local scroll = CreateFrame("ScrollFrame", "ElvinRaidPlanPaletteScroll", palette, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 4, -6)
	scroll:SetPoint("BOTTOMRIGHT", -24, 6)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(PALETTE_WIDTH - 30, 10) -- height grows below
	scroll:SetScrollChild(content)

	local y = 0
	local function NextRow(h)
		y = y - h
	end

	local function SectionLabel(text)
		local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		fs:SetPoint("TOPLEFT", 0, y)
		fs:SetText(text)
		NextRow(14)
	end

	local function PlaceButtonRow(btn)
		btn:SetParent(content)
		btn:SetPoint("TOPLEFT", 0, y)
		NextRow(BTN_SIZE + BTN_PAD)
	end

	-- Shapes
	SectionLabel("Shapes")
	local shapeOrder = { "square", "circle", "wedge", "arrow" }
	local shapeLabels = { square = "Square", circle = "Circle", wedge = "Wedge / cone", arrow = "Arrow" }
	for _, shapeType in ipairs(shapeOrder) do
		local btn = MakeToolButton(content, ERP.ShapeTextures[shapeType], nil, shapeLabels[shapeType], function()
			ERP:BeginPlacement({ kind = "shape", shapeType = shapeType })
		end)
		PlaceButtonRow(btn)
	end

	-- Text
	local textBtn = MakeToolButton(content, "Interface\\AddOns\\ElvinRaidPlan\\textures\\text_tool.tga", nil, "Text label", function()
		ERP:BeginPlacement({ kind = "text", text = "Text" })
	end)
	PlaceButtonRow(textBtn)

	NextRow(8)

	-- Raid markers
	SectionLabel("Raid markers")
	for i = 1, 8 do
		local btn = MakeToolButton(content, string.format(ERP.RaidMarkerTexture, i), nil, "Raid marker " .. i, function()
			ERP:BeginPlacement({ kind = "marker", markerIndex = i })
		end)
		PlaceButtonRow(btn)
	end

	NextRow(8)

	-- Class icons (bundled per-class textures)
	SectionLabel("Classes")
	for _, classToken in ipairs(ERP.ClassTokens) do
		local label = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or classToken
		local btn = MakeToolButton(content, ERP.ClassFile(classToken), nil, label, function()
			ERP:BeginPlacement({ kind = "class", classToken = classToken })
		end)
		PlaceButtonRow(btn)
	end

	content:SetHeight(-y + 10)
end
