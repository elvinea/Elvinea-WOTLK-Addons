--[[
	AggroDone
	WotLK 3.3.5 (Warmane-compatible) rewrite of the "Trick or Treat" concept.

	What it does:
	  - Watches for Tricks of the Trade (Rogue) and Misdirection (Hunter) being
	    cast on someone.
	  - Judges whether it was used near the start of combat ("good timing") or
	    later into the pull.
	  - Tallies the caster's damage for the next few seconds (the window the
	    cooldown is actually active for) so you can see the payoff.
	  - If YOU are the caster or the target of the cooldown, it whispers the
	    other person a short report. This only ever fires when you're actually
	    part of the exchange - i.e. you're playing Rogue/Hunter and cast it, or
	    you're the one who got tricked/MD'd (the tank).
	  - Every event (including ones you're not part of) also gets logged to a
	    small popup window, so if you're on a class that never casts or
	    receives these cooldowns you can still open the window and see who in
	    the raid is using them, and when.

	Slash commands: /aggrodone or /ad
	    /ad            - toggle the tracking window
	    /ad show       - show it
	    /ad hide       - hide it
	    /ad clear      - wipe the log
	    /ad config     - open the options panel (Interface Options > AddOns > AggroDone)

	    /ad whisper status               - show current whisper settings (chat-only alternative to /ad config)
	    /ad whisper mode full            - full report (timing + damage)
	    /ad whisper mode damage          - bonus damage only, no timing text
	    /ad whisper mode off             - no whispers at all (window log only)
	    /ad whisper totonme on|off       - someone used Tricks on you
	    /ad whisper totbyme on|off       - you cast Tricks on someone
	    /ad whisper mdonme  on|off       - someone used MD on you
	    /ad whisper mdbyme  on|off       - you cast MD on someone

	    Note: mode and the per-scenario toggles stack. Mode controls what the
	    whisper says; the scenario toggles control whether it's sent at all
	    for that particular case. Everything still gets logged to the popup
	    window either way, whisper or not.

	Notes on the 3.3.5 combat log:
	  Pre-Cataclysm COMBAT_LOG_EVENT_UNFILTERED does NOT have the "hideCaster"
	  or the extra raid-flag arguments retail addons are written against.
	  The layout on this client is:
	    timestamp, subevent, sourceGUID, sourceName, sourceFlags,
	    destGUID, destName, destFlags, <event-specific args...>
--]]

local ADDON_NAME = "AggroDone"

-- ---------------------------------------------------------------------
-- Spell data
-- ---------------------------------------------------------------------
-- Both cooldowns actually proc their real damage/redirect buff on the
-- *next* damaging attack, but for a whisper-friendly summary we just use
-- a fixed window starting at the moment the ability is cast. 6s covers the
-- Tricks of the Trade buff duration; it's a bit generous for Misdirection
-- (whose own proc buff is 4s) but that's fine for "how much damage did you
-- do right after using this" purposes.
local TRACKED_SPELLS = {
	[57934] = { name = "Tricks of the Trade", short = "Tricks", key = "tot", window = 6 },
	[34477] = { name = "Misdirection",        short = "MD",     key = "md",  window = 6 },
}

-- Anything cast within this many seconds of combat starting counts as
-- "good timing" (i.e. used at the pull, which is the whole point of these
-- cooldowns). Tweak to taste.
local GOOD_TIMING_THRESHOLD = 3

-- ---------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------
local playerGUID = UnitGUID("player")
local combatStartTime = nil

-- pending[casterGUID] = { spellId, info, casterGUID, casterName,
--                          targetGUID, targetName, startTime, delta,
--                          damage, expires }
local pending = {}

-- whisper.mode: "full" (timing + damage), "damage" (bonus damage only), or "off" (no whispers at all)
-- whisper.scenarios: per spell/per direction toggle - lets you mute just "Tricks on you" etc.
--   while leaving the others on, regardless of mode.
local WHISPER_DEFAULTS = {
	mode = "full",
	scenarios = {
		totbyme = true, -- you cast Tricks on someone
		totonme = true, -- someone used Tricks on you
		mdbyme  = true, -- you cast MD on someone
		mdonme  = true, -- someone used MD on you
	},
}

AggroDoneDB = AggroDoneDB or { shown = false, point = nil, whisper = WHISPER_DEFAULTS }

-- Fill in any missing whisper settings (covers upgrades from before this existed,
-- or new scenario keys added later).
AggroDoneDB.whisper = AggroDoneDB.whisper or {}
AggroDoneDB.whisper.mode = AggroDoneDB.whisper.mode or WHISPER_DEFAULTS.mode
AggroDoneDB.whisper.scenarios = AggroDoneDB.whisper.scenarios or {}
for key, default in pairs(WHISPER_DEFAULTS.scenarios) do
	if AggroDoneDB.whisper.scenarios[key] == nil then
		AggroDoneDB.whisper.scenarios[key] = default
	end
end

-- ---------------------------------------------------------------------
-- Popup window
-- ---------------------------------------------------------------------
local window = CreateFrame("Frame", "AggroDoneWindow", UIParent)
window:SetSize(360, 220)
window:SetPoint("CENTER", 0, 150)
window:SetMovable(true)
window:EnableMouse(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, _, x, y = self:GetPoint()
	AggroDoneDB.point = { point = point, x = x, y = y }
end)
window:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 11, top = 11, bottom = 11 },
})
window:Hide()

local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -14)
title:SetText("AggroDone - Tricks / MD Log")

local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -4, -4)
closeButton:SetScript("OnClick", function()
	window:Hide()
	AggroDoneDB.shown = false
end)

local msgFrame = CreateFrame("ScrollingMessageFrame", "AggroDoneMsgFrame", window)
msgFrame:SetPoint("TOPLEFT", 20, -36)
msgFrame:SetPoint("BOTTOMRIGHT", -30, 16)
msgFrame:SetFontObject(GameFontHighlightSmall)
msgFrame:SetJustifyH("LEFT")
msgFrame:SetFading(false)
msgFrame:SetMaxLines(200)
msgFrame:EnableMouseWheel(true)
msgFrame:SetScript("OnMouseWheel", function(self, delta)
	if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end)

local scrollBar = CreateFrame("Slider", "AggroDoneScrollBar", window, "UIPanelScrollBarTemplate")
scrollBar:SetPoint("TOPRIGHT", -12, -36)
scrollBar:SetPoint("BOTTOMRIGHT", -12, 16)
scrollBar:SetMinMaxValues(0, 0)
scrollBar:SetValueStep(1)
scrollBar:SetScript("OnValueChanged", function(self, value)
	msgFrame:SetScrollOffset(value)
end)
msgFrame:SetScript("OnMessageScrollChanged", function(self)
	scrollBar:SetMinMaxValues(0, self:GetNumMessages() - 1 > 0 and self:GetNumMessages() - 1 or 0)
end)

local function LogToWindow(text)
	msgFrame:AddMessage(text)
end

local function ShowWindow()
	if AggroDoneDB.point then
		window:ClearAllPoints()
		window:SetPoint(AggroDoneDB.point.point, UIParent, AggroDoneDB.point.point, AggroDoneDB.point.x, AggroDoneDB.point.y)
	end
	window:Show()
	AggroDoneDB.shown = true
end

local function HideWindow()
	window:Hide()
	AggroDoneDB.shown = false
end

-- ---------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------
local function FinishEntry(entry)
	local timingText
	if entry.delta == nil then
		timingText = "no active pull timer"
	elseif entry.delta <= GOOD_TIMING_THRESHOLD then
		timingText = string.format("%.1fs after pull (good timing)", entry.delta)
	else
		timingText = string.format("%.1fs after pull (late)", entry.delta)
	end

	local logLine = string.format(
		"|cff33ff99%s|r -> |cffffffff%s|r: %s, %s, %d dmg in %ds",
		entry.casterName, entry.targetName, entry.info.short, timingText, entry.damage, entry.info.window
	)
	LogToWindow(logLine)

	local iAmCaster = entry.casterGUID == playerGUID
	local iAmTarget = entry.targetGUID == playerGUID

	if iAmCaster or iAmTarget then
		local scenarioKey
		if entry.info.key == "tot" then
			scenarioKey = iAmCaster and "totbyme" or "totonme"
		else
			scenarioKey = iAmCaster and "mdbyme" or "mdonme"
		end

		local whisper = AggroDoneDB.whisper
		local scenarioOn = whisper.scenarios[scenarioKey]

		if whisper.mode ~= "off" and scenarioOn then
			local whisperTarget, whisperMsg

			if whisper.mode == "damage" then
				-- Bonus-damage-only: skip the timing readout entirely.
				whisperMsg = string.format(
					"[AggroDone] %s bonus damage: %d dmg in %ds.",
					entry.info.name, entry.damage, entry.info.window
				)
			else
				if iAmCaster then
					whisperMsg = string.format(
						"[AggroDone] Used %s on you, %s - you did %d dmg in the %ds window.",
						entry.info.name, timingText, entry.damage, entry.info.window
					)
				else
					whisperMsg = string.format(
						"[AggroDone] Got your %s, %s - I did %d dmg in the %ds window.",
						entry.info.name, timingText, entry.damage, entry.info.window
					)
				end
			end

			whisperTarget = iAmCaster and entry.targetName or entry.casterName

			if whisperTarget and whisperTarget ~= UnitName("player") then
				SendChatMessage(whisperMsg, "WHISPER", nil, whisperTarget)
			end
		end

		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AggroDone:|r " .. logLine)
	end
end

-- ---------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local elapsedSinceCheck = 0
frame:SetScript("OnUpdate", function(self, elapsed)
	elapsedSinceCheck = elapsedSinceCheck + elapsed
	if elapsedSinceCheck < 0.5 then return end
	elapsedSinceCheck = 0

	local now = GetTime()
	for guid, entry in pairs(pending) do
		if now >= entry.expires then
			FinishEntry(entry)
			pending[guid] = nil
		end
	end
end)

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		playerGUID = UnitGUID("player")
		if AggroDoneDB.shown then
			ShowWindow()
		end
		return
	end

	if event == "PLAYER_REGEN_DISABLED" then
		combatStartTime = GetTime()
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		combatStartTime = nil
		return
	end

	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local timestamp, subevent, sourceGUID, sourceName, sourceFlags,
			destGUID, destName, destFlags = ...

		if subevent == "SPELL_CAST_SUCCESS" then
			local spellId = select(9, ...)
			local info = TRACKED_SPELLS[spellId]
			if info and sourceName and destName then
				local castTime = GetTime()
				local delta = combatStartTime and (castTime - combatStartTime) or nil
				pending[sourceGUID] = {
					spellId = spellId,
					info = info,
					casterGUID = sourceGUID,
					casterName = sourceName,
					targetGUID = destGUID,
					targetName = destName,
					startTime = castTime,
					delta = delta,
					damage = 0,
					expires = castTime + info.window,
				}
			end
			return
		end

		if subevent == "SWING_DAMAGE" or subevent == "SPELL_DAMAGE" or subevent == "RANGE_DAMAGE" then
			local entry = pending[sourceGUID]
			if entry then
				local amount
				if subevent == "SWING_DAMAGE" then
					amount = select(9, ...)
				else
					-- SPELL_DAMAGE / RANGE_DAMAGE: spellId, spellName, spellSchool, amount, ...
					amount = select(12, ...)
				end
				if amount then
					entry.damage = entry.damage + amount
				end
			end
			return
		end
	end
end)

-- ---------------------------------------------------------------------
-- Options panel (Interface Options > AddOns > AggroDone)
-- ---------------------------------------------------------------------
local SCENARIO_LABELS = {
	totbyme = "Tricks by you",
	totonme = "Tricks on you",
	mdbyme  = "MD by you",
	mdonme  = "MD on you",
}

local optionsPanel = CreateFrame("Frame", "AggroDoneOptionsPanel", UIParent)
optionsPanel.name = "AggroDone"
optionsPanel:Hide()

local panelTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", 16, -16)
panelTitle:SetText("AggroDone")

local panelSubtitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
panelSubtitle:SetPoint("TOPLEFT", panelTitle, "BOTTOMLEFT", 0, -8)
panelSubtitle:SetWidth(500)
panelSubtitle:SetJustifyH("LEFT")
panelSubtitle:SetText("Controls when AggroDone whispers you or the other person about Tricks of the Trade / Misdirection usage. The popup window log (/ad show) always records everything regardless of these settings.")

local modeLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
modeLabel:SetPoint("TOPLEFT", panelSubtitle, "BOTTOMLEFT", 0, -20)
modeLabel:SetText("Whisper content")

local MODE_OPTIONS = {
	{ text = "Full report (timing + damage)", value = "full" },
	{ text = "Bonus damage only", value = "damage" },
	{ text = "Off (no whispers at all)", value = "off" },
}

local modeDropdown = CreateFrame("Frame", "AggroDoneModeDropdown", optionsPanel, "UIDropDownMenuTemplate")
modeDropdown:SetPoint("TOPLEFT", modeLabel, "BOTTOMLEFT", -16, -4)
UIDropDownMenu_SetWidth(modeDropdown, 220)

UIDropDownMenu_Initialize(modeDropdown, function(self, level)
	for _, opt in ipairs(MODE_OPTIONS) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = opt.text
		info.value = opt.value
		info.func = function(btn)
			AggroDoneDB.whisper.mode = btn.value
			UIDropDownMenu_SetSelectedValue(modeDropdown, btn.value)
		end
		UIDropDownMenu_AddButton(info, level)
	end
end)

local scenarioLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
scenarioLabel:SetPoint("TOPLEFT", modeDropdown, "BOTTOMLEFT", 16, -12)
scenarioLabel:SetText("Send a whisper for...")

-- Order matters here for layout below.
local SCENARIO_ORDER = { "totonme", "totbyme", "mdonme", "mdbyme" }

local scenarioChecks = {}
local prevAnchor = scenarioLabel
for _, key in ipairs(SCENARIO_ORDER) do
	local check = CreateFrame("CheckButton", "AggroDoneCheck" .. key, optionsPanel, "UICheckButtonTemplate")
	check:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -6)
	_G[check:GetName() .. "Text"]:SetText(SCENARIO_LABELS[key])
	check:SetScript("OnClick", function(self)
		AggroDoneDB.whisper.scenarios[key] = self:GetChecked() and true or false
	end)
	scenarioChecks[key] = check
	prevAnchor = check
end

optionsPanel:SetScript("OnShow", function(self)
	UIDropDownMenu_SetSelectedValue(modeDropdown, AggroDoneDB.whisper.mode)
	for _, opt in ipairs(MODE_OPTIONS) do
		if opt.value == AggroDoneDB.whisper.mode then
			UIDropDownMenu_SetText(modeDropdown, opt.text)
		end
	end
	for key, check in pairs(scenarioChecks) do
		check:SetChecked(AggroDoneDB.whisper.scenarios[key])
	end
end)

if InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(optionsPanel)
end

local function OpenOptions()
	if InterfaceOptionsFrame_OpenToCategory then
		-- Known Blizzard quirk on this client: the first call sometimes opens
		-- to the wrong category the very first time it's used in a session.
		-- Calling it twice is the standard workaround.
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
		InterfaceOptionsFrame_OpenToCategory(optionsPanel)
	end
end

-- ---------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------
local function PrintWhisperStatus()
	local whisper = AggroDoneDB.whisper
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AggroDone|r whisper mode: " .. whisper.mode)
	for _, key in ipairs({ "totbyme", "totonme", "mdbyme", "mdonme" }) do
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"  %s: %s", SCENARIO_LABELS[key], whisper.scenarios[key] and "on" or "off"
		))
	end
end

local function OnOff(word)
	if word == "on" then return true end
	if word == "off" then return false end
	return nil
end

local function SlashHandler(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")

	if cmd == "show" then
		ShowWindow()
	elseif cmd == "hide" then
		HideWindow()
	elseif cmd == "clear" then
		msgFrame:Clear()
	elseif cmd == "config" or cmd == "options" then
		OpenOptions()
	elseif cmd == "whisper" then
		local sub, arg = rest:match("^(%S*)%s*(.-)$")

		if sub == "mode" then
			if arg == "full" or arg == "damage" or arg == "off" then
				AggroDoneDB.whisper.mode = arg
				DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AggroDone|r whisper mode set to: " .. arg)
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AggroDone|r usage: /ad whisper mode full|damage|off")
			end
		elseif AggroDoneDB.whisper.scenarios[sub] ~= nil then
			local value = OnOff(arg)
			if value == nil then
				DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AggroDone|r usage: /ad whisper " .. sub .. " on|off")
			else
				AggroDoneDB.whisper.scenarios[sub] = value
				DEFAULT_CHAT_FRAME:AddMessage(string.format(
					"|cff33ff99AggroDone|r %s: %s", SCENARIO_LABELS[sub], value and "on" or "off"
				))
			end
		elseif sub == "status" or sub == "" then
			PrintWhisperStatus()
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AggroDone|r unknown whisper option: " .. sub)
		end
	else
		if window:IsShown() then
			HideWindow()
		else
			ShowWindow()
		end
	end
end

SLASH_AGGRODONE1 = "/aggrodone"
SLASH_AGGRODONE2 = "/ad"
SlashCmdList["AGGRODONE"] = SlashHandler
