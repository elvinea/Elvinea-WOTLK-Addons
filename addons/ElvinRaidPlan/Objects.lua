--[[
	ElvinRaidPlan - Objects.lua
	Everything about objects placed on the canvas: shapes, raid markers, class icons,
	and text labels. Handles drag-to-move, click-to-select (with resize/rotate
	handles), wheel-to-resize as a shortcut, right-click delete, shift+right-click
	recolor (shapes), and double-click text editing.

	v0.1 note: circle/wedge/arrow originally pointed at Blizzard texture paths
	that don't actually work pre-Legion (TempPortraitAlphaMask needs the
	CreateMaskTexture API added in 7.2, and the minimap-arrow path was just
	wrong) - both rendered nothing, which is why placed icons "disappeared".
	Fixed here by bundling our own plain white shapes that tint and rotate
	cleanly with the vanilla Texture API.
]]

local ERP = ElvinRaidPlan

ERP.liveObjects = ERP.liveObjects or {}

local DEFAULT_SIZE = 32
local MIN_SIZE = 14
local MAX_SIZE = 128
local ADDON_TEX_PATH = "Interface\\AddOns\\ElvinRaidPlan\\textures\\"

-- Bundled plain-white shapes (see textures/*.tga) recolor and rotate cleanly.
ERP.ShapeTextures = {
	square = "Interface\\Buttons\\WHITE8X8", -- built into the client, no masking needed
	circle = ADDON_TEX_PATH .. "circle.tga",
	wedge  = ADDON_TEX_PATH .. "triangle.tga",
	arrow  = ADDON_TEX_PATH .. "arrow.tga",
}

ERP.ShapeColors = {
	{ r = 0.90, g = 0.15, b = 0.15 }, -- red
	{ r = 0.20, g = 0.55, b = 0.95 }, -- blue
	{ r = 0.20, g = 0.80, b = 0.30 }, -- green
	{ r = 0.95, g = 0.85, b = 0.15 }, -- yellow
	{ r = 0.85, g = 0.45, b = 0.95 }, -- purple
	{ r = 0.95, g = 0.95, b = 0.95 }, -- white
	{ r = 0.10, g = 0.10, b = 0.10 }, -- black
	{ r = 0.95, g = 0.55, b = 0.10 }, -- orange
}

-- 1=Star 2=Circle 3=Diamond 4=Triangle 5=Moon 6=Square 7=Cross 8=Skull
ERP.RaidMarkerTexture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"

-- Class icons: use the client's real class-icon atlas (the genuine crests).
-- The correct WotLK atlas + per-class texcoords are below. If a given client
-- build can't supply it, set ERP.UseBundledClassIcons = true to fall back to
-- the bundled colored discs instead.
ERP.ClassAtlas = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
-- This client's atlas shows weapon icons, not class crests, so default to the
-- bundled emblems. Flip to false to try the real atlas.
ERP.UseBundledClassIcons = true
ERP.ClassCoords = {
	WARRIOR     = {0, 0.25, 0, 0.25},
	MAGE        = {0.25, 0.49609375, 0, 0.25},
	ROGUE       = {0.49609375, 0.7421875, 0, 0.25},
	DRUID       = {0.7421875, 0.98828125, 0, 0.25},
	HUNTER      = {0, 0.25, 0.25, 0.5},
	SHAMAN      = {0.25, 0.49609375, 0.25, 0.5},
	PRIEST      = {0.49609375, 0.7421875, 0.25, 0.5},
	WARLOCK     = {0.7421875, 0.98828125, 0.25, 0.5},
	PALADIN     = {0, 0.25, 0.5, 0.75},
	DEATHKNIGHT = {0.25, 0.49609375, 0.5, 0.75},
}
ERP.ClassBundledPath = "Interface\\AddOns\\ElvinRaidPlan\\textures\\class_%s.tga"
ERP.ClassTokens = {
	"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
	"DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

-- Apply the right class icon to a texture object: real atlas crest (default)
-- or bundled disc (fallback). Returns nothing; sets texture + texcoords.
local function ApplyClassIcon(tex, token)
	if ERP.UseBundledClassIcons then
		tex:SetTexture(string.format(ERP.ClassBundledPath, string.lower(token)))
		tex:SetTexCoord(0, 1, 0, 1)
	else
		tex:SetTexture(ERP.ClassAtlas)
		local c = ERP.ClassCoords[token]
		if c then tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
	end
end
ERP.ApplyClassIcon = ApplyClassIcon

-- Back-compat helper some call sites use for a plain path (bundled only).
local function ClassFile(token)
	return string.format(ERP.ClassBundledPath, string.lower(token))
end
ERP.ClassFile = ClassFile

-- Textures rotate fine via SetRotation; FontStrings don't support it pre-
-- Shadowlands, so text objects just skip rotation.
local function CanRotate(obj)
	return obj.texture ~= nil and obj.texture.SetRotation ~= nil
end

-- ------------------------------------------------------------
-- Popup for naming/editing text objects
-- ------------------------------------------------------------
StaticPopupDialogs["ELVINRAIDPLAN_TEXT_EDIT"] = {
	text = "Label text:",
	button1 = "Set",
	button2 = "Cancel",
	hasEditBox = true,
	maxLetters = 60,
	OnAccept = function(self)
		local obj = self.data
		local text = self.editBox:GetText()
		if obj and obj.fontString then
			obj.fontString:SetText(text ~= "" and text or "Text")
			obj.text = text
		end
	end,
	EditBoxOnEnterPressed = function(self)
		self:GetParent():Hide()
		StaticPopupDialogs["ELVINRAIDPLAN_TEXT_EDIT"].OnAccept(self:GetParent())
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- ------------------------------------------------------------
-- Object lifecycle
-- ------------------------------------------------------------

local function ApplyResize(obj, size)
	size = math.max(MIN_SIZE, math.min(MAX_SIZE, size))
	obj.size = size
	obj:SetSize(size, size)
	if obj.fontString and obj.kind == "text" then
		obj.fontString:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, size * 0.4), "OUTLINE")
	end
end

local function ApplyColor(obj, color)
	obj.color = color
	if obj.texture and obj.kind == "shape" then
		obj.texture:SetVertexColor(color.r, color.g, color.b, 1)
	end
end

local function ApplyRotation(obj, radians)
	obj.rotation = radians % (2 * math.pi)
	if CanRotate(obj) then
		obj.texture:SetRotation(obj.rotation)
	end
end

local function RefreshRelativePosition(obj)
	local x, y = obj:GetCenter()
	local cx, cy = ERP.canvas:GetCenter()
	obj.relX = (x - cx) / ERP.canvas:GetWidth()
	obj.relY = (y - cy) / ERP.canvas:GetHeight()
end

local function OnObjectDragStart(obj)
	if obj.locked then return end
	obj:StartMoving()
	obj.dragging = true
end

local function OnObjectDragStop(obj)
	if not obj.dragging then return end
	obj:StopMovingOrSizing()
	obj.dragging = false
	RefreshRelativePosition(obj)
	ERP:UpdateHandles()
end

local function OnObjectWheel(obj, delta)
	ApplyResize(obj, obj.size + delta * 4)
	RefreshRelativePosition(obj) -- center is unaffected by SetSize, but keep in sync
	ERP:UpdateHandles()
end

local function OnObjectClick(obj, button)
	if button == "RightButton" then
		if IsShiftKeyDown() and obj.kind == "shape" then
			obj.colorIndex = (obj.colorIndex % #ERP.ShapeColors) + 1
			ApplyColor(obj, ERP.ShapeColors[obj.colorIndex])
		else
			ERP:RemoveObject(obj)
		end
	elseif button == "LeftButton" then
		ERP:SelectObject(obj)
	end
end

local function OnObjectDoubleClick(obj)
	if obj.kind == "text" then
		StaticPopup_Show("ELVINRAIDPLAN_TEXT_EDIT", nil, nil, obj)
	end
end

-- placementInfo = { kind = "shape"/"marker"/"class"/"text", shapeType=, markerIndex=, classToken=, }
function ERP:CreateObject(placementInfo, relX, relY, size, color, rotation)
	local canvas = self.canvas
	-- Must be a Button, not a Frame: RegisterForClicks / RegisterForDrag /
	-- OnClick / OnDoubleClick are Button methods in 3.3.5. (A plain Frame has
	-- OnMouseDown/OnMouseUp only, which is why placing an object errored.)
	local obj = CreateFrame("Button", nil, canvas)
	obj:SetFrameLevel(canvas:GetFrameLevel() + 5)
	obj:EnableMouse(true)
	obj:SetMovable(true)
	obj:RegisterForDrag("LeftButton")
	obj:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	obj:SetClampedToScreen(false)

	obj.kind = placementInfo.kind
	obj.shapeType = placementInfo.shapeType
	obj.markerIndex = placementInfo.markerIndex
	obj.classToken = placementInfo.classToken
	obj.text = placementInfo.text
	obj.colorIndex = placementInfo.colorIndex or 1

	if obj.kind == "shape" or obj.kind == "marker" or obj.kind == "class" then
		local tex = obj:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints(obj)
		obj.texture = tex

		if obj.kind == "shape" then
			tex:SetTexture(ERP.ShapeTextures[obj.shapeType])
			ApplyColor(obj, color or ERP.ShapeColors[obj.colorIndex])
		elseif obj.kind == "marker" then
			tex:SetTexture(string.format(ERP.RaidMarkerTexture, obj.markerIndex))
		elseif obj.kind == "class" then
			ApplyClassIcon(tex, obj.classToken)
		end
	elseif obj.kind == "text" then
		local fs = obj:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fs:SetPoint("CENTER", obj, "CENTER", 0, 0)
		fs:SetText(obj.text or "Text")
		obj.fontString = fs

		-- translucent backdrop so text is legible over any background
		local bg = obj:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(obj)
		bg:SetTexture(0, 0, 0, 0.35)
		obj.bg = bg
	end

	ApplyResize(obj, size or DEFAULT_SIZE)
	ApplyRotation(obj, rotation or 0)

	obj:SetPoint("CENTER", canvas, "CENTER", (relX or 0) * canvas:GetWidth(), (relY or 0) * canvas:GetHeight())
	obj.relX, obj.relY = relX or 0, relY or 0

	obj:SetScript("OnDragStart", function(self) OnObjectDragStart(self) end)
	obj:SetScript("OnDragStop", function(self) OnObjectDragStop(self) end)
	obj:SetScript("OnMouseWheel", function(self, delta) OnObjectWheel(self, delta) end)
	obj:SetScript("OnClick", function(self, button) OnObjectClick(self, button) end)
	obj:SetScript("OnDoubleClick", function(self) OnObjectDoubleClick(self) end)

	-- Tooltip hint
	obj:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Click to select  |  drag to move  |  wheel to resize", 1, 1, 1)
		GameTooltip:AddLine("Right-click to delete" .. (self.kind == "shape" and "  |  shift+right-click to recolor" or ""), 0.8, 0.8, 0.8)
		if self.kind == "text" then
			GameTooltip:AddLine("Double-click to edit text", 0.8, 0.8, 0.8)
		end
		GameTooltip:Show()
	end)
	obj:SetScript("OnLeave", function() GameTooltip:Hide() end)

	table.insert(ERP.liveObjects, obj)
	return obj
end

function ERP:RemoveObject(obj)
	if self.selectedObject == obj then
		self:DeselectObject()
	end
	for i, o in ipairs(self.liveObjects) do
		if o == obj then
			table.remove(self.liveObjects, i)
			break
		end
	end
	obj:Hide()
	obj:SetParent(nil)
end

function ERP:ClearCanvas()
	self:DeselectObject()
	for _, obj in ipairs(self.liveObjects) do
		obj:Hide()
		obj:SetParent(nil)
	end
	wipe(self.liveObjects)
end

-- ------------------------------------------------------------
-- Selection + resize/rotate handles
-- ------------------------------------------------------------

local function MakeHandle(name, texturePath)
	local h = CreateFrame("Button", nil, ERP.canvas)
	h:SetSize(14, 14)
	h:SetFrameLevel(200)
	h:Hide()
	local tex = h:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints(h)
	tex:SetTexture(texturePath)
	h.texture = tex
	return h
end

function ERP:UpdateHandles()
	local obj = self.selectedObject
	if not obj or not obj:IsShown() then
		self:HideHandles()
		return
	end

	if not self.selectionBorder then
		local sb = CreateFrame("Frame", nil, self.canvas)
		sb:SetFrameLevel(150)
		sb:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
		sb:SetBackdropBorderColor(1, 0.82, 0, 0.9)
		self.selectionBorder = sb
	end
	self.selectionBorder:ClearAllPoints()
	self.selectionBorder:SetPoint("TOPLEFT", obj, "TOPLEFT", -3, 3)
	self.selectionBorder:SetPoint("BOTTOMRIGHT", obj, "BOTTOMRIGHT", 3, -3)
	self.selectionBorder:Show()

	if not self.resizeHandle then
		self.resizeHandle = MakeHandle("Resize", "Interface\\Buttons\\WHITE8X8")
		self.resizeHandle.texture:SetVertexColor(1, 0.82, 0, 1)
		self.resizeHandle:RegisterForDrag("LeftButton")
		self.resizeHandle:SetScript("OnDragStart", function(h) h.dragging = true end)
		self.resizeHandle:SetScript("OnDragStop", function(h) h.dragging = false end)
		self.resizeHandle:SetScript("OnUpdate", function(h)
			if not h.dragging or not ERP.selectedObject then return end
			local x, y = GetCursorPosition()
			local scale = ERP.canvas:GetEffectiveScale()
			x, y = x / scale, y / scale
			local cx, cy = ERP.selectedObject:GetCenter()
			local dist = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
			ApplyResize(ERP.selectedObject, dist * 1.4)
			ERP:UpdateHandles()
		end)
	end
	self.resizeHandle:ClearAllPoints()
	self.resizeHandle:SetPoint("CENTER", obj, "BOTTOMRIGHT", 0, 0)
	self.resizeHandle:Show()

	if CanRotate(obj) then
		if not self.rotateHandle then
			self.rotateHandle = MakeHandle("Rotate", "Interface\\Buttons\\WHITE8X8")
			self.rotateHandle.texture:SetVertexColor(0.3, 0.8, 1, 1)
			self.rotateHandle:RegisterForDrag("LeftButton")
			self.rotateHandle:SetScript("OnDragStart", function(h) h.dragging = true end)
			self.rotateHandle:SetScript("OnDragStop", function(h) h.dragging = false end)
			self.rotateHandle:SetScript("OnUpdate", function(h)
				if not h.dragging or not ERP.selectedObject then return end
				local x, y = GetCursorPosition()
				local scale = ERP.canvas:GetEffectiveScale()
				x, y = x / scale, y / scale
				local cx, cy = ERP.selectedObject:GetCenter()
				-- SetRotation is counter-clockwise-positive, but dragging the
				-- handle clockwise increases atan2(dx,dy); negate so the icon
				-- turns the same way the cursor moves.
				local angle = -math.atan2(x - cx, y - cy) -- 0 = pointing up
				ApplyRotation(ERP.selectedObject, angle)
			end)
		end
		self.rotateHandle:ClearAllPoints()
		self.rotateHandle:SetPoint("BOTTOM", obj, "TOP", 0, 18)
		self.rotateHandle:Show()
	elseif self.rotateHandle then
		self.rotateHandle:Hide()
	end
end

function ERP:HideHandles()
	if self.selectionBorder then self.selectionBorder:Hide() end
	if self.resizeHandle then self.resizeHandle:Hide() end
	if self.rotateHandle then self.rotateHandle:Hide() end
end

function ERP:SelectObject(obj)
	self.selectedObject = obj
	self:UpdateHandles()
end

function ERP:DeselectObject()
	self.selectedObject = nil
	self:HideHandles()
end

-- ------------------------------------------------------------
-- Serialization
-- ------------------------------------------------------------

function ERP:SerializeObject(obj)
	return {
		kind = obj.kind,
		shapeType = obj.shapeType,
		markerIndex = obj.markerIndex,
		classToken = obj.classToken,
		text = obj.text,
		relX = obj.relX,
		relY = obj.relY,
		size = obj.size,
		colorIndex = obj.colorIndex,
		rotation = obj.rotation,
	}
end

function ERP:DeserializeObject(data)
	local color = data.colorIndex and ERP.ShapeColors[data.colorIndex]
	self:CreateObject(data, data.relX, data.relY, data.size, color, data.rotation)
end
