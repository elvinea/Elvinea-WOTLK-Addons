--[[
	ElvinRaidPlan - Core.lua
	Drag-and-drop raid strategy planner for WotLK 3.3.5 (Warmane), inspired by raidplan.io.

	This file owns: SavedVariables, the main window frame, plan (save/load/new/delete)
	management, and the slash command. Canvas.lua builds the drawing surface,
	Palette.lua builds the left-hand tool strip, Objects.lua handles placed-object
	creation/drag/resize/delete/serialization.
]]

ElvinRaidPlan = CreateFrame("Frame", "ElvinRaidPlanFrameHandler", UIParent)
local ERP = ElvinRaidPlan

ERP.VERSION = "0.1"

-- ============================================================
-- SavedVariables
-- ============================================================

local DEFAULT_DB = {
	lastPlan = "Default",
	plans = {
		["Default"] = {
			background = { kind = "color", key = "dark" },
			objects = {},
		},
	},
}

local function CopyDefaults(src, dst)
	if type(dst) ~= "table" then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

local function Report(msg)
	if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffElvinRaidPlan:|r " .. tostring(msg))
	end
end
ERP.Report = Report

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
	if addonName ~= "ElvinRaidPlan" then return end
	self:UnregisterEvent("ADDON_LOADED")

	ElvinRaidPlanDB = CopyDefaults(DEFAULT_DB, ElvinRaidPlanDB)
	ERP.db = ElvinRaidPlanDB

	-- Confirm every module actually loaded and defined its entry points. If a
	-- file failed to load, its function will be nil here and we say which one.
	local missing = {}
	if not ERP.CreateMainFrame then table.insert(missing, "CreateMainFrame (Canvas.lua)") end
	if not ERP.BuildPalette   then table.insert(missing, "BuildPalette (Palette.lua)") end
	if not ERP.BuildMapPicker then table.insert(missing, "BuildMapPicker (MapBackgrounds.lua)") end
	if not ERP.CreateObject   then table.insert(missing, "CreateObject (Objects.lua)") end
	if #missing > 0 then
		ERP.initError = "modules missing: " .. table.concat(missing, ", ")
		Report("|cffff4444load incomplete|r - " .. ERP.initError .. ". A file above this one in the .toc errored; run /console scriptErrors 1 then /reload.")
		return
	end

	local ok, err = pcall(function()
		ERP:CreateMainFrame()
		ERP:LoadPlan(ERP.db.lastPlan or "Default")
	end)
	if ok then
		ERP.ready = true
		Report("loaded. Type /erp to open.")
	else
		ERP.initError = err
		Report("|cffff4444error building window:|r " .. tostring(err))
	end
end)

-- ============================================================
-- Plan management
-- ============================================================

-- The "live" plan currently shown on the canvas.
ERP.currentPlanName = nil

function ERP:GetPlanNames()
	local names = {}
	for name in pairs(self.db.plans) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ERP:NewPlan(name)
	if not name or name == "" then return end
	if self.db.plans[name] then
		print("|cff33ccffElvinRaidPlan|r: a plan named '" .. name .. "' already exists.")
		return
	end
	self.db.plans[name] = { background = { kind = "color", key = "dark" }, objects = {} }
	self:LoadPlan(name)
end

function ERP:SavePlan()
	if not self.currentPlanName then return end
	local plan = self.db.plans[self.currentPlanName]
	if not plan then return end

	plan.objects = {}
	for _, obj in ipairs(self.liveObjects or {}) do
		table.insert(plan.objects, self:SerializeObject(obj))
	end
	plan.background = self.currentBackground

	self.db.lastPlan = self.currentPlanName
	self:FlashSaved()
end

function ERP:LoadPlan(name)
	local plan = self.db.plans[name]
	if not plan then return end

	self:ClearCanvas()
	self.currentPlanName = name
	self.currentBackground = plan.background or "dark"
	self.db.lastPlan = name

	self:SetBackground(self.currentBackground)

	for _, data in ipairs(plan.objects or {}) do
		self:DeserializeObject(data)
	end

	if self.planNameBox then
		self.planNameBox:SetText(name)
	end
end

function ERP:DeletePlan(name)
	if not name or not self.db.plans[name] then return end
	if #self:GetPlanNames() <= 1 then
		print("|cff33ccffElvinRaidPlan|r: can't delete the only remaining plan.")
		return
	end
	self.db.plans[name] = nil
	if self.currentPlanName == name then
		local remaining = self:GetPlanNames()
		self:LoadPlan(remaining[1] or "Default")
	end
end

function ERP:RenamePlan(oldName, newName)
	if not oldName or not newName or newName == "" then return end
	if not self.db.plans[oldName] or self.db.plans[newName] then return end
	self.db.plans[newName] = self.db.plans[oldName]
	self.db.plans[oldName] = nil
	if self.currentPlanName == oldName then
		self.currentPlanName = newName
		self.db.lastPlan = newName
	end
end

-- ============================================================
-- Plan picker (Open button) — a scrollable list of saved plans
-- ============================================================

function ERP:BuildPlanPicker(parent)
	local picker = CreateFrame("Frame", "ElvinRaidPlanPlanPicker", parent)
	picker:SetSize(230, 340)
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
	title:SetText("Open a plan")

	local closeBtn = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -2, -2)
	closeBtn:SetScript("OnClick", function() picker:Hide() end)

	local scroll = CreateFrame("ScrollFrame", "ElvinRaidPlanPlanPickerScroll", picker, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -34)
	scroll:SetPoint("BOTTOMRIGHT", -30, 12)

	local list = CreateFrame("Frame", nil, scroll)
	list:SetSize(170, 10)
	scroll:SetScrollChild(list)
	picker.list = list

	self.planPicker = picker
end

local function GetPlanPickerButton(list, i)
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
		b:SetScript("OnLeave", function(self) self.text:SetTextColor(1, 1, 1) end)
		list.buttons[i] = b
	end
	return b
end

function ERP:RefreshPlanPicker()
	local list = self.planPicker.list
	for _, b in ipairs(list.buttons or {}) do b:Hide() end
	local y = -2
	local names = self:GetPlanNames()
	for i, name in ipairs(names) do
		local b = GetPlanPickerButton(list, i)
		b:SetPoint("TOPLEFT", 0, y)
		local mark = (name == self.currentPlanName) and "|cff33ff33> |r" or "  "
		b.text:SetText(mark .. name)
		b:SetScript("OnClick", function()
			ERP:LoadPlan(name)
			ERP.planPicker:Hide()
		end)
		b:Show()
		y = y - 22
	end
	list:SetHeight(-y + 4)
end

function ERP:TogglePlanPicker()
	if not self.planPicker then return end
	if self.planPicker:IsShown() then
		self.planPicker:Hide()
	else
		self:RefreshPlanPicker()
		self.planPicker:ClearAllPoints()
		self.planPicker:SetPoint("TOPLEFT", self.mainFrame, "TOPRIGHT", 6, 0)
		self.planPicker:Show()
	end
end

-- ============================================================
-- Slash command
-- ============================================================

SLASH_ELVINRAIDPLAN1 = "/erp"
SLASH_ELVINRAIDPLAN2 = "/raidplan"
SlashCmdList["ELVINRAIDPLAN"] = function(msg)
	if ERP.mainFrame then
		if ERP.mainFrame:IsShown() then
			ERP.mainFrame:Hide()
		else
			ERP.mainFrame:Show()
		end
	elseif ERP.initError then
		DEFAULT_CHAT_FRAME:AddMessage("|cffff4444ElvinRaidPlan didn't finish loading:|r " .. tostring(ERP.initError))
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff4444ElvinRaidPlan window isn't ready yet.|r If this persists, run |cffffff00/console scriptErrors 1|r then |cffffff00/reload|r and report the error.")
	end
end
