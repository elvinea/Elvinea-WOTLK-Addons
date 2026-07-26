--[[
	ElvinRaidPlan - MapBackgrounds.lua

	Backgrounds come in two kinds:
	  "color" - flat panel colors
	  "arena" - a bundled boss-arena image we ship in maps\<file>.tga

	The client's own world/zone maps are intentionally NOT used - they're the
	wrong art for boss strategy and tile badly. Boss arenas are supplied as
	bundled images instead.

	Adding a real map: drop a 512x512 (or any power-of-two) uncompressed TGA in
	the maps\ folder, then set its `file` in ERP.BossArenas below. Entries whose
	file isn't present yet just fall back to a flat color, so the picker still
	works while maps are being added.
]]

local ERP = ElvinRaidPlan

local ARENA_PATH = "Interface\\AddOns\\ElvinRaidPlan\\maps\\"

ERP.FlatColors = {
	{ key = "dark",      label = "Dark",      r = 0.08, g = 0.08, b = 0.09 },
	{ key = "slate",     label = "Slate",     r = 0.16, g = 0.17, b = 0.21 },
	{ key = "green",     label = "Green",     r = 0.09, g = 0.16, b = 0.10 },
	{ key = "parchment", label = "Parchment", r = 0.55, g = 0.47, b = 0.35 },
}

-- Boss-arena registry, grouped by raid. `file` is the TGA stem in maps\.
ERP.BossArenas = {
	{
		raid = "Icecrown Citadel",
		bosses = {
			{ name = "Lord Marrowgar",        file = "icc_marrowgar" },
			{ name = "Lady Deathwhisper",     file = "icc_deathwhisper" },
			{ name = "Gunship Battle",        file = "icc_gunship" },
			{ name = "Deathbringer Saurfang",  file = "icc_saurfang" },
			{ name = "Festergut",             file = "icc_festergut" },
			{ name = "Rotface",               file = "icc_rotface" },
			{ name = "Professor Putricide",   file = "icc_putricide" },
			{ name = "Blood Prince Council",  file = "icc_bloodprinces" },
			{ name = "Blood-Queen Lana'thel", file = "icc_bloodqueen" },
			{ name = "Valithria Dreamwalker", file = "icc_valithria" },
			{ name = "Sindragosa",            file = "icc_sindragosa" },
			{ name = "The Lich King",         file = "icc_lichking" },
		},
	},
}

local function GetFlatColor(key)
	for _, c in ipairs(ERP.FlatColors) do
		if c.key == key then return c end
	end
	return ERP.FlatColors[1]
end

-- ------------------------------------------------------------
-- Rendering
-- ------------------------------------------------------------

function ERP:ClearMapTiles()
	self.mapTiles = self.mapTiles or {}
	for _, tex in ipairs(self.mapTiles) do
		tex:Hide()
	end
end

function ERP:RenderFlatColor(key)
	self:ClearMapTiles()
	local c = GetFlatColor(key)
	self.canvasTexture:SetTexture(c.r, c.g, c.b, 1)
	self.currentBackground = { kind = "color", key = c.key }
	if self.bgLabel then self.bgLabel:SetText(c.label) end
end

-- A boss arena is one full-canvas bundled image.
function ERP:RenderArena(file, displayName)
	self:ClearMapTiles()
	self.mapTiles = self.mapTiles or {}
	local tex = self.mapTiles[1]
	if not tex then
		tex = self.canvas:CreateTexture(nil, "BACKGROUND")
		self.mapTiles[1] = tex
	end
	-- Dim base so a missing texture reads as dark rather than a solid block.
	self.canvasTexture:SetTexture(0.08, 0.08, 0.09, 1)
	tex:ClearAllPoints()
	tex:SetAllPoints(self.canvas)
	tex:SetTexCoord(0, 1, 0, 1)
	tex:SetTexture(ARENA_PATH .. file .. ".tga")
	tex:Show()
	self.currentBackground = { kind = "arena", file = file, name = displayName }
	if self.bgLabel then self.bgLabel:SetText(displayName or file) end
end

-- Save/load entry point. Accepts the table shapes above, or an old bare
-- color-key string from early versions.
function ERP:SetBackground(bg)
	if type(bg) == "string" then
		self:RenderFlatColor(bg)
	elseif type(bg) == "table" and bg.kind == "arena" and bg.file then
		self:RenderArena(bg.file, bg.name)
	elseif type(bg) == "table" and bg.kind == "color" then
		self:RenderFlatColor(bg.key)
	else
		self:RenderFlatColor("dark")
	end
end

function ERP:CycleFlatColor()
	local idx = 1
	local curKey = (self.currentBackground and self.currentBackground.kind == "color") and self.currentBackground.key or nil
	for i, c in ipairs(self.FlatColors) do
		if c.key == curKey then idx = i break end
	end
	local nextColor = self.FlatColors[(idx % #self.FlatColors) + 1]
	self:RenderFlatColor(nextColor.key)
end

-- ------------------------------------------------------------
-- Picker UI: a plain scroll list of raids -> bosses, plus flat colors.
-- ------------------------------------------------------------

local function ClearListButtons(list)
	for _, b in ipairs(list.buttons or {}) do
		b:Hide()
	end
end

local function GetListButton(list, i)
	list.buttons = list.buttons or {}
	local b = list.buttons[i]
	if not b then
		b = CreateFrame("Button", nil, list)
		b:SetHeight(20)
		b:SetPoint("LEFT", 4, 0)
		b:SetPoint("RIGHT", -4, 0)
		local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		fs:SetPoint("LEFT", 4, 0)
		fs:SetJustifyH("LEFT")
		b.text = fs
		b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.82, 0) end)
		b:SetScript("OnLeave", function(self) self.text:SetTextColor(self.baseColor and self.baseColor[1] or 1, self.baseColor and self.baseColor[2] or 1, self.baseColor and self.baseColor[3] or 1) end)
		list.buttons[i] = b
	end
	return b
end

local function BuildTopLevel(list)
	ClearListButtons(list)
	local y = -2
	local idx = 0
	local function Row(text, onClick)
		idx = idx + 1
		local b = GetListButton(list, idx)
		b:SetPoint("TOPLEFT", 0, y)
		b.text:SetText(text)
		b.baseColor = { 1, 1, 1 }
		b.text:SetTextColor(1, 1, 1)
		b:SetScript("OnClick", onClick)
		b:Show()
		y = y - 22
	end
	local function Gap(px) y = y - (px or 6) end

	for ri, group in ipairs(ERP.BossArenas) do
		Row("|cffffd200" .. group.raid .. "|r", function() ERP:ShowBossList(ri, group) end)
	end
	Gap(8)
	Row("Flat color (cycle)", function()
		ERP:CycleFlatColor(); ERP.mapPicker:Hide()
	end)

	list:SetHeight(-y + 4)
end

function ERP:ShowBossList(raidIndex, group)
	local list = self.mapPicker.list
	ClearListButtons(list)
	local y = -2
	local idx = 0
	local function Row(text, onClick)
		idx = idx + 1
		local b = GetListButton(list, idx)
		b:SetPoint("TOPLEFT", 0, y)
		b.text:SetText(text)
		b.baseColor = { 1, 1, 1 }
		b.text:SetTextColor(1, 1, 1)
		b:SetScript("OnClick", onClick)
		b:Show()
		y = y - 22
	end

	Row("< Back", function() BuildTopLevel(list) end)
	Row("|cffffd200" .. group.raid .. "|r", function() end)
	for _, boss in ipairs(group.bosses) do
		Row("  " .. boss.name, function()
			ERP:RenderArena(boss.file, boss.name)
			ERP.mapPicker:Hide()
		end)
	end
	list:SetHeight(-y + 4)
end

function ERP:BuildMapPicker(parent)
	local picker = CreateFrame("Frame", "ElvinRaidPlanMapPicker", parent)
	picker:SetSize(230, 360)
	picker:SetFrameStrata("DIALOG")
	picker:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 11, top = 11, bottom = 11 },
	})
	picker:Hide()
	picker:EnableMouse(true)

	local title = picker:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Choose a map")

	local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -2, -2)
	closeBtn:SetScript("OnClick", function() picker:Hide() end)

	local scroll = CreateFrame("ScrollFrame", "ElvinRaidPlanMapPickerScroll", picker, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -34)
	scroll:SetPoint("BOTTOMRIGHT", -30, 12)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(170, 10)
	scroll:SetScrollChild(list)

	self.mapPicker = picker
	picker.list = list
	-- built lazily on first open
end

function ERP:ToggleMapPicker()
	if self.mapPicker:IsShown() then
		self.mapPicker:Hide()
	else
		BuildTopLevel(self.mapPicker.list)
		self.mapPicker:ClearAllPoints()
		self.mapPicker:SetPoint("TOPLEFT", self.mainFrame, "TOPRIGHT", 6, 0)
		self.mapPicker:Show()
	end
end
