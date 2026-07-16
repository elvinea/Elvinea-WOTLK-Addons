-- GearCheck :: Core.lua
-- Scanning (gear/gems/enchants), role detection, raid inspection queue, validation.

GearCheck = GearCheck or {}
local GC = GearCheck
GC.results = {}          -- name -> scan data
GC.expanded = {}         -- name -> bool (UI drop-down state)

-------------------------------------------------------------------------------
-- Hidden tooltip for reading enchant effect text
-------------------------------------------------------------------------------
local scanTip = CreateFrame("GameTooltip", "GearCheckScanTip", nil, "GameTooltipTemplate")
scanTip:SetOwner(UIParent, "ANCHOR_NONE")

-- One tooltip pass per item: returns (enchantText, emptySocketCount, isHeroic, gemNames).
-- gemNames is a fallback list built by matching plain tooltip lines against GC.ALL_GEMS,
-- since on Warmane the inspected item link sometimes has its gem IDs stripped, which
-- makes GetItemGem/the link regex return nothing even though the gem is really socketed.
local function ScanItemTooltip(unit, slotId)
    scanTip:ClearLines()
    if not scanTip:SetInventoryItem(unit, slotId) then return nil, 0, false, {}, false end
    local plainEnch, procEnch, runeEnch, nameEnch = nil, nil, nil, nil
    local empty, isHeroic, hasProfReq = 0, false, false
    local gemNames = {}
    for i = 2, scanTip:NumLines() do
        local fs = _G["GearCheckScanTipTextLeft"..i]
        local txt = fs and fs:GetText()
        if txt then
            local low = txt:lower()
            local trimmed = low:match("^%s*(.-)%s*$")
            local r, g, b = fs:GetTextColor()
            if txt:find("EmptySocket") then
                empty = empty + 1
            elseif low == "heroic" then
                isHeroic = true
            elseif GC.ENCH_BYNAME and GC.ENCH_BYNAME[trimmed] then
                -- a profession enchant named directly in the tooltip (embroidery, tinker, ...)
                nameEnch = nameEnch or GC.ENCH_BYNAME[trimmed]
            elseif low:find("enchantment requires") then
                hasProfReq = true
            elseif GC.ALL_GEMS and GC.ALL_GEMS[txt] then
                gemNames[#gemNames + 1] = txt
            else
                local stat = txt:gsub("|T.-|t", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
                if txt:find("|T") and GC.GEM_BY_STAT and GC.GEM_BY_STAT[stat] then
                    gemNames[#gemNames + 1] = GC.GEM_BY_STAT[stat]
                else
                    local isProcLine = low:find("^equip:") or low:find("^use:") or low:find("^chance")
                    local hasDuration = low:find("cooldown") or low:find(" sec")
                    local isBareArmor = low:find("^%d+ armor$")
                    local excluded = low:find("socket") or low:find("shift") or low:find("click")
                        or low:find("^requires") or low:find("^classes:") or low:find("^races:")
                        or low:find("set:") or txt:find("^%(%d") or txt:find("/%d")
                        or low:find("^%d+ set") or low == "normal" or low == "mythic"
                        or low:find("made by") or isBareArmor
                    if r and r > 0.8 and g < 0.3 and b < 0.3 and low:find("^rune of") then
                        runeEnch = runeEnch or txt
                    elseif isProcLine and hasDuration and not excluded then
                        procEnch = procEnch or txt
                    elseif g and g > 0.9 and r < 0.2 and b < 0.2 and not isProcLine and not excluded then
                        plainEnch = plainEnch or txt
                    end
                end
            end
        end
    end
    local enchText = runeEnch or plainEnch or procEnch
    -- special = named profession enchant / proc / runeforge: exempt from the role-keyword check
    local specialEnch = (nameEnch ~= nil) or
        ((enchText ~= nil) and (enchText == runeEnch or enchText == procEnch or hasProfReq))
    return enchText, empty, isHeroic, gemNames, specialEnch, nameEnch
end

-------------------------------------------------------------------------------
-- Role from primary talent tree
-------------------------------------------------------------------------------
function GC:GetPrimaryTree(inspect)
    -- Explicitly resolve which talent group (spec 1 or 2) is actually ACTIVE and pass
    -- it through to every talent call. For self this is usually implicit, but for an
    -- INSPECTED unit the default appears unreliable on this server — we were seeing
    -- plausible-looking but wrong numbers that matched the character's off-spec
    -- instead of their active one (e.g. reading a Resto off-spec on a Balance main).
    local group = GetActiveTalentGroup and GetActiveTalentGroup(inspect) or nil
    local best, bestPts = 1, -1
    for tab = 1, 3 do
        local _, _, pts = GetTalentTabInfo(tab, inspect, nil, group)
        -- GetTalentTabInfo is unreliable on Warmane (often 0) -> sum talents instead
        if not pts or pts == 0 then
            pts = 0
            local n = GetNumTalents(tab, inspect, nil, group) or 0
            for i = 1, n do
                local _, _, _, _, rank = GetTalentInfo(tab, i, inspect, nil, group)
                pts = pts + (rank or 0)
            end
        end
        if pts > bestPts then bestPts = pts; best = tab end
    end
    return best, bestPts
end

function GC:RoleForUnit(unit, class, inspect)
    local tree = self:GetPrimaryTree(inspect)
    local map = self.TREE_ROLE[class]
    local role = map and map[tree] or nil
    -- Feral: bear vs cat. If in Dire Bear/Bear form treat as Tank (best effort, self only).
    if class == "DRUID" and role == "Melee" and unit == "player" then
        local form = GetShapeshiftForm and GetShapeshiftForm()
        if form == 1 then role = "Tank" end
    end
    return role, tree
end

function GC:ProfileForUnit(class, tree, role)
    local m = self.TREE_PROFILE[class]
    local p = m and m[tree] or nil
    if class == "DRUID" and role == "Tank" then p = "Leather Tank" end
    return p
end

-- Which spec's talent build to grade against (from primary tree, with a couple of
-- role-based tie-breaks where one tree covers two specs).
function GC:SpecForTalents(class, tree, role)
    local m = self.TREE_SPEC and self.TREE_SPEC[class]
    local spec = m and m[tree] or nil
    if class == "DRUID" and spec == "Feral (Cat)" and role == "Tank" then spec = "Feral (Bear)" end
    return spec
end

-- Read a unit's full talent build as { [talentName] = rank } for rank > 0.
function GC:ReadTalents(inspect)
    local group = GetActiveTalentGroup and GetActiveTalentGroup(inspect) or nil
    local out = {}
    for tab = 1, 3 do
        local n = GetNumTalents(tab, inspect, nil, group) or 0
        for i = 1, n do
            local name, _, _, _, rank = GetTalentInfo(tab, i, inspect, nil, group)
            if name and rank and rank > 0 then out[name] = rank end
        end
    end
    return out
end

-- Grade a unit's talents against its spec's reference build.
function GC:GradeTalents(data, inspect, have)
    local build = self.TALENT_BUILD and self.TALENT_BUILD[data.class] and data.talentSpec
                  and self.TALENT_BUILD[data.class][data.talentSpec]
    local t = { spec = data.talentSpec, lines = {}, wrong = 0 }
    if not build then t.noref = true; data.talents = t; return end
    have = have or self:ReadTalents(inspect)
    -- reference talents: check each is at the wanted rank
    local names = {}
    for name in pairs(build) do names[#names+1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local need, got = build[name], have[name] or 0
        local status = (got == need) and "ok" or "low"
        if status ~= "ok" then t.wrong = t.wrong + 1 end
        t.lines[#t.lines+1] = { name = name, got = got, need = need, status = status }
    end
    -- points spent where the build wants none (extra / off-build)
    local extras = {}
    for name, got in pairs(have) do
        if not build[name] then extras[#extras+1] = name end
    end
    table.sort(extras)
    for _, name in ipairs(extras) do
        t.wrong = t.wrong + 1
        t.lines[#t.lines+1] = { name = name, got = have[name], need = 0, status = "extra" }
    end
    t.ok = (t.wrong == 0)
    data.talents = t
end

-- Resolve a friendly enchant name + stats from the effect text + slot.
function GC:EnchantName(slot, effect)
    if not effect then return nil, nil end
    local low = effect:lower()
    local list = self.ENCH_NAME[slot]
    if list then
        for _, e in ipairs(list) do
            local keys = e[1]
            local all = true
            for _, k in ipairs(keys) do
                if not low:find(k, 1, true) then all = false break end
            end
            if all then return e[2], e[3] end
        end
    end
    return nil, nil
end

-------------------------------------------------------------------------------
-- Scan one unit's equipped gear/gems/enchants
-------------------------------------------------------------------------------
function GC:ScanUnit(unit, inspect)
    local name = UnitName(unit) or "?"
    local _, class = UnitClass(unit)
    local role, tree = self:RoleForUnit(unit, class, inspect)
    -- Read talents once; use them to split Feral Bear vs Cat (they share the Feral
    -- tree, so tree/form can't tell them apart on inspected units). "Protector of the
    -- Pack" is a bear/tank-only talent — its presence means Bear.
    local talents = self:ReadTalents(inspect)
    if class == "DRUID" and tree == 2 then
        role = ((talents["Protector of the Pack"] or 0) > 0) and "Tank" or "Melee"
    end
    local data = { name = name, class = class, role = role, tree = tree,
                   type = self:TypeFor(role, class), profile = self:ProfileForUnit(class, tree, role),
                   talentSpec = self:SpecForTalents(class, tree, role),
                   slots = {}, issues = 0, offbis = 0, prebis = 0, scanned = true }
    local ok = pcall(function() self:GradeTalents(data, inspect, talents) end)
    if not ok and not data.talents then
        data.talents = { spec = data.talentSpec, noref = true }
    end

    for _, s in ipairs(self.SLOTS) do
        local link = GetInventoryItemLink(unit, s.id)
        local sd = { slot = s.name, id = s.id, ench = s.ench }
        if link then
            local iname, _, irarity, ilvl, _, _, _, _, iequiploc = GetItemInfo(link)
            sd.item = iname; sd.ilvl = ilvl; sd.link = link
            sd.rarity = irarity; sd.equipLoc = iequiploc
            -- enchant id, kept only as a hint for ENCHANT_ID_NAME lookups — it is NOT used
            -- to decide "is this item enchanted" any more, because that field is unreliable
            -- for some items on this server (it was flagging items as enchanted when the
            -- green line found was really just the item's own baseline itemization stat).
            local enchantId = link:match("item:%d+:(%d*)")
            sd.enchantId = enchantId
            -- gems: pull the gem IDs from the item link, resolve to names now, and remember
            -- the IDs so we can re-resolve once the client finishes caching them.
            local _, _, gid1, gid2, gid3, gid4 = link:match("item:(%d+):(%d*):(%d*):(%d*):(%d*):(%d*)")
            local gids = { gid1, gid2, gid3, gid4 }
            sd.gems = {}
            sd.gemIds = {}
            sd.gemsPending = false
            for i = 1, 4 do
                -- GetItemGem reads the socketed gem from inspect data even when the link
                -- string has no gem ids; use its gem link to recover the id when needed.
                local gname, glink = GetItemGem(link, i)
                local gid = gids[i]
                if (not gid or gid == "" or gid == "0") and glink then
                    gid = glink:match("item:(%d+)")
                end
                -- GetItemGem sometimes resolves to a name that isn't a gem at all on this
                -- server (seen returning a completely unrelated equipped item's name,
                -- e.g. a Hands item while scanning Head gems — a corrupted/misaligned
                -- lookup). Only trust it if it's a name we actually recognize as a gem;
                -- otherwise fall through to the numeric-ID path below, which is honest
                -- about not knowing the name rather than confidently showing a wrong one.
                if gname and not self.ALL_GEMS[gname] then
                    gname = nil
                end
                if gname then
                    sd.gems[#sd.gems + 1] = gname
                    if gid and gid ~= "0" then sd.gemIds[i] = gid end
                elseif gid and gid ~= "" and gid ~= "0" then
                    sd.gemIds[i] = gid
                    local n = GetItemInfo(tonumber(gid))
                    if n then
                        sd.gems[#sd.gems + 1] = n
                    else
                        sd.gems[#sd.gems + 1] = "gem #" .. gid
                        sd.gemsPending = true
                        GetItemInfo(tonumber(gid))   -- prime the item cache
                    end
                end
            end
            local enchTxt, empty, isHeroic, tipGems, specialEnch, nameEnch = ScanItemTooltip(unit, s.id)
            sd.emptySockets = empty
            sd.isHeroic = isHeroic
            sd.specialEnch = specialEnch
            -- fallback: if the link/GetItemGem path found no gems, or only unresolved
            -- "gem #id" placeholders (common on inspected units where Warmane puts enchant-ids
            -- in the link), use the gem names read straight off the tooltip instead.
            local allPending = #sd.gems > 0
            for _, g in ipairs(sd.gems) do if not g:find("^gem #") then allPending = false break end end
            if (#sd.gems == 0 or allPending) and #tipGems > 0 then
                sd.gems = tipGems
                sd.gemsPending = false
                sd.gemsFromTooltip = true
            end
            -- belts are never enchantable (the buckle is a socket, not an enchant). Otherwise,
            -- trust the tooltip scan: it now correctly separates a real applied enchant from
            -- the item's own baseline stats, which the link's enchant-id field could not.
            local idName = self.ENCHANT_ID_NAME and self.ENCHANT_ID_NAME[enchantId]
            sd.enchanted = (s.id ~= 6) and (nameEnch ~= nil or enchTxt ~= nil or idName ~= nil)
            if sd.enchanted then
                if nameEnch then
                    sd.enchName, sd.enchStats = nameEnch[1], nameEnch[2]
                    sd.enchEffect, sd.enchRaw = nameEnch[1], nameEnch[1]
                else
                    sd.enchEffect = idName or enchTxt
                    sd.enchRaw = enchTxt
                    sd.enchName, sd.enchStats = self:EnchantName(s.name, enchTxt)
                end
            end
            -- belt buckle: the waist has a socket only if the Eternal Belt Buckle is on
            -- (belts have no native socket). Detect via any gem, empty socket (tooltip),
            -- or GetItemStats' empty-socket count.
            if s.id == 6 then
                local stats = GetItemStats(link)
                local statEmpty = 0
                if stats then
                    statEmpty = (stats.EMPTY_SOCKET_RED or 0) + (stats.EMPTY_SOCKET_YELLOW or 0)
                              + (stats.EMPTY_SOCKET_BLUE or 0) + (stats.EMPTY_SOCKET_PRISMATIC or 0)
                              + (stats.EMPTY_SOCKET_META or 0)
                end
                sd.hasBuckle = (#sd.gems > 0) or (empty and empty > 0) or (statEmpty > 0)
            end
        end
        table.insert(data.slots, sd)
    end

    -- GearScore total (GearScoreLite/GearScoreRecorder formula) + average ilvl.
    -- Titan's Grip: if either Main Hand or Off Hand is a 2H weapon (only possible
    -- with both hands filled under that talent), both hands' scores halve — the
    -- 2.0 vs 1.0 SlotMOD weighting itself comes automatically from ItemGearScore's
    -- equip-location lookup now, including for a Titan's Grip off-hand 2H weapon.
    do
        local mh, oh
        for _, sd in ipairs(data.slots) do
            if sd.id == 16 then mh = sd elseif sd.id == 17 then oh = sd end
        end
        local titanGrip = 1
        if mh and oh and ((mh.equipLoc == "INVTYPE_2HWEAPON") or (oh.equipLoc == "INVTYPE_2HWEAPON")) then
            titanGrip = 0.5
        end
        local total, ilvlSum, ilvlCount = 0, 0, 0
        for _, sd in ipairs(data.slots) do
            if sd.item and sd.ilvl and sd.ilvl > 0 then
                local extra = 1
                if sd.id == 16 then
                    extra = titanGrip
                    if class == "HUNTER" then extra = extra * 0.3164 end
                elseif sd.id == 17 then
                    extra = titanGrip
                elseif sd.id == 18 and class == "HUNTER" then
                    -- Hunters' ranged weapon IS effectively their main weapon in this
                    -- formula, weighted far above a normal relic/idol slot.
                    extra = 5.3224
                end
                local isEnchanted = sd.enchantId and sd.enchantId ~= "" and sd.enchantId ~= "0"
                total = total + self:ItemGearScore(sd.ilvl, sd.rarity, sd.equipLoc, isEnchanted, extra)
                ilvlSum = ilvlSum + sd.ilvl
                ilvlCount = ilvlCount + 1
            end
        end
        data.gearScore = total
        data.avgIlvl = ilvlCount > 0 and math.floor(ilvlSum / ilvlCount) or 0
    end
    return data
end

-------------------------------------------------------------------------------
-- Validate gems & enchants for a scanned unit
-------------------------------------------------------------------------------
function GC:Validate(data)
    data.issues = 0
    data.offbis = 0
    data.prebis = 0
    local bis = data.profile and self.ITEM_BIS and self.ITEM_BIS[data.profile]
    for _, sd in ipairs(data.slots) do
        sd.problems = {}
        sd.notBis = false
        sd.preBis = false
        if sd.item then
            -- missing enchant on a core slot
            if self.CORE_ENCHANT_SLOTS[sd.id] and not sd.enchanted then
                local keys = self.ENCH_OK[data.type] and self.ENCH_OK[data.type][sd.slot]
                if keys then
                    table.insert(sd.problems, "missing enchant (want " .. table.concat(keys, "/") .. ")")
                else
                    table.insert(sd.problems, "missing enchant")
                end
            elseif self.CORE_ENCHANT_SLOTS[sd.id] and sd.enchanted then
                -- wrong enchant for role: GC.ENCH_OK[type][slot] is a loose keyword hint
                -- (e.g. Physical/Head = "Attack Power"). Profession-exclusive enchants
                -- (engineering, tailoring's Swordguard/Lightweave Embroidery, etc.) are
                -- valid alternatives regardless of role/type, since their effect text
                -- doesn't naturally match the expected keyword (e.g. Swordguard Embroidery
                -- gives Attack Power but the Physical/Back keyword is "Agility") — any
                -- bracketed profession tag in the enchant name exempts it from this check.
                local isProfEnchant = sd.specialEnch or (sd.enchName and sd.enchName:find("%[%a+%]"))
                local keys = self.ENCH_OK[data.type] and self.ENCH_OK[data.type][sd.slot]
                if keys and not isProfEnchant then
                    local combined = ((sd.enchName or "") .. " " .. (sd.enchRaw or "")):lower()
                    if combined:match("%S") then
                        local match = false
                        for _, kw in ipairs(keys) do
                            if combined:find(kw:lower(), 1, true) then match = true break end
                        end
                        if not match then
                            table.insert(sd.problems, "wrong enchant (want " .. table.concat(keys, "/") .. ")")
                        end
                    end
                end
            end
            -- belt: must have the Eternal Belt Buckle socket
            if sd.id == 6 and not sd.hasBuckle then
                table.insert(sd.problems, "no belt buckle (missing socket)")
            end
            -- empty sockets = error
            if sd.emptySockets and sd.emptySockets > 0 then
                table.insert(sd.problems, sd.emptySockets .. " empty socket" .. (sd.emptySockets > 1 and "s" or ""))
            end
            -- gem check: name must be recognized, AND (if we know the role's gem type)
            -- the gem must actually belong to that type — a real, recognized gem that's
            -- just the wrong stat for this role (e.g. a Tank wearing a pure Strength gem)
            -- was previously passing silently since it's still a valid gem name.
            for _, g in ipairs(sd.gems) do
                local isPlaceholder = g:find("^gem #")
                if not self.ALL_GEMS[g] and not isPlaceholder then
                    table.insert(sd.problems, "unrecognized gem: " .. g)
                elseif not isPlaceholder and data.type and self.GEMS_FOR_TYPE[data.type]
                       and not self.GEMS_FOR_TYPE[data.type][g]
                       and not self.META_GEMS[g] and not self.PRISMATIC[g] then
                    table.insert(sd.problems, "wrong gem for role: " .. g)
                end
            end
            -- item BiS by NAME + Heroic tag (skip Ranged/relic — no HC relics):
            --   name on list + Heroic  -> BiS (ok)
            --   name on list, not HC   -> pre-BiS (Normal/base version)
            --   name not on list       -> off-BiS
            if bis and sd.slot ~= "Ranged" then
                local key = sd.slot
                if key == "Ring 1" or key == "Ring 2" then key = "Ring" end
                if key == "Trinket 1" or key == "Trinket 2" then key = "Trinket" end
                local okset = bis[key]
                if okset then
                    if okset[sd.item] then
                        local noHeroicNeeded = self.NO_HEROIC_REQUIRED and self.NO_HEROIC_REQUIRED[sd.item]
                        if not sd.isHeroic and not noHeroicNeeded then
                            sd.preBis = true
                            data.prebis = data.prebis + 1
                        end
                    else
                        sd.notBis = true
                        data.offbis = data.offbis + 1
                    end
                end
            end
        end
        data.issues = data.issues + #sd.problems
    end
    data.validated = true
end

function GC:ClearResults()
    wipe(self.results)
    wipe(self.expanded)
    wipe(self.expandedItem)
    if self.Render then self:Render() end
end

-- Whisper a player their problems. mode "gems" = enchant/gem/socket fixes only;
-- mode "all" = also talents + Heroic upgrades. Each problem is its own line (no header).
function GC:WhisperProblems(name, mode)
    if not name or name == "" then return end
    local d = self.results[name]
    if not d then return end
    local fixes = {}
    for _, sd in ipairs(d.slots or {}) do
        if sd.problems then
            for _, p in ipairs(sd.problems) do fixes[#fixes + 1] = sd.slot .. " - " .. p end
        end
    end
    if mode == "all" then
        if d.talents and not d.talents.noref and (d.talents.wrong or 0) > 0 then
            local tl = {}
            for _, ln in ipairs(d.talents.lines or {}) do
                if ln.status == "extra" then tl[#tl + 1] = "drop " .. ln.name
                elseif ln.status ~= "ok" then tl[#tl + 1] = ln.name .. " " .. ln.got .. "/" .. ln.need end
            end
            if #tl > 0 then fixes[#fixes + 1] = "Talents (" .. (d.talentSpec or "?") .. ") - " .. table.concat(tl, ", ") end
        end
        local preb = {}
        for _, sd in ipairs(d.slots or {}) do if sd.preBis then preb[#preb + 1] = sd.slot end end
        if #preb > 0 then fixes[#fixes + 1] = "Upgrade to Heroic - " .. table.concat(preb, ", ") end
    end

    if #fixes == 0 then
        local what = (mode == "all") and "gear, gems, enchants and talents" or "gems and enchants"
        SendChatMessage("GearCheck: your " .. what .. " look good!", "WHISPER", nil, name)
        self:Print("Whispered " .. name .. ": no issues.")
        return
    end
    for i, f in ipairs(fixes) do
        local msg = "GearCheck: " .. f
        self:After(0.25 * (i - 1), function() SendChatMessage(msg, "WHISPER", nil, name) end)
    end
    self:Print("Whispered " .. name .. " their " .. #fixes .. " fix(es).")
end

-- Re-resolve any gems that were still caching when we scanned, then re-validate/re-render.
function GC:ResolvePendingGems()
    local changed = false
    for _, d in pairs(self.results) do
        local dChanged = false
        for _, sd in ipairs(d.slots or {}) do
            if sd.gemsPending and sd.gemIds then
                local newg, pending = {}, false
                for i = 1, 4 do
                    local gid = sd.gemIds[i]
                    if gid then
                        local name = GetItemInfo(tonumber(gid))
                        if name then newg[#newg + 1] = name
                        else newg[#newg + 1] = "gem #" .. gid; pending = true end
                    end
                end
                sd.gems = newg
                sd.gemsPending = pending
                dChanged = true
            end
        end
        if dChanged then self:Validate(d); changed = true end
    end
    if changed and self.Render then self:Render() end
end

-- Schedule a few re-resolves after a scan, to catch gems that were still caching.
function GC:ScheduleGemRetry()
    self:After(0.4, function() self:ResolvePendingGems() end)
    self:After(1.0, function() self:ResolvePendingGems() end)
    self:After(2.2, function() self:ResolvePendingGems() end)
end

-- When the client finishes caching an item, refresh (throttled). GET_ITEM_INFO_RECEIVED
-- may not exist on 3.3.5a, so guard it; the timed retries above are the real safety net.
local itemInfoEv = CreateFrame("Frame")
pcall(function() itemInfoEv:RegisterEvent("GET_ITEM_INFO_RECEIVED") end)
local refreshQueued = false
itemInfoEv:SetScript("OnEvent", function()
    if refreshQueued then return end
    refreshQueued = true
    GC:After(0.3, function() refreshQueued = false; GC:ResolvePendingGems() end)
end)

-- Manual role override (right-click a player) — cycles Tank -> Melee -> Ranged -> Healer
function GC:CycleRole(name)
    local d = self.results[name]
    if not d then return end
    local order = { "Tank", "Melee", "Ranged", "Healer" }
    local idx = 1
    for i, v in ipairs(order) do if v == d.role then idx = i break end end
    d.role = order[(idx % #order) + 1]
    d.type = self:TypeFor(d.role, d.class)
    self:Validate(d)
    self:Render()
    self:Print(name .. " role set to " .. d.role .. " (manual)")
end

-------------------------------------------------------------------------------
-- Simple OnUpdate timer (no C_Timer on 3.3.5a)
-------------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local timers = {}
function GC:After(delay, fn)
    timers[#timers+1] = { t = GetTime() + delay, fn = fn }
end
ticker:SetScript("OnUpdate", function()
    if #timers == 0 then return end
    local now = GetTime()
    for i = #timers, 1, -1 do
        if now >= timers[i].t then
            local fn = timers[i].fn
            table.remove(timers, i)
            fn()
        end
    end
end)

-------------------------------------------------------------------------------
-- Raid scan via inspection queue
-------------------------------------------------------------------------------
-- Plain NotifyInspect() is correct and sufficient to request data. It does NOT mean
-- all data has arrived yet, though: per Blizzard's own API notes, equipped item links
-- are available right after this call, but socketed GEM data specifically is not
-- available until the separate UNIT_INVENTORY_CHANGED event fires. Our previous bug
-- was scanning as soon as INSPECT_TALENT_READY fired without waiting for that.
local function DoInspect(unit)
    NotifyInspect(unit)
end

local queue, pendingUnit, pendingName = {}, nil, nil
local pendingTalent, pendingInventory, pendingRetried = false, false, false
local failedUnits, retryPass, MAX_PASSES = {}, 0, 4   -- re-inspect players who time out / are out of range
local processNext   -- forward declaration, defined below

-- Only scan once we have BOTH signals: talents ready AND inventory (gem) data ready.
-- If UNIT_INVENTORY_CHANGED never fires for some reason (rare caching edge case),
-- don't hang forever — proceed a short grace period after talents come in anyway.
--
-- We've also seen INSPECT_TALENT_READY fire before the inspected unit's talent data
-- is actually fully synced on this server — the addon would then read a near-empty
-- primary tree (e.g. a handful of points in tab 1) and mis-detect role/type entirely
-- (a Prot Paladin read as Healer, a spec'd DK read as Tank). This never happens on
-- self-scans (own talent data is always immediately correct), only inspected ones.
-- A real level-80 primary spec runs 40-50+ points deep, so treat a low point total
-- as "not synced yet" and give it one more short beat before trusting it.
local function finishInspect()
    if not pendingUnit then return end
    local unit = pendingUnit
    local _, treePts = GC:GetPrimaryTree(true)
    if (treePts or 0) < 15 and not pendingRetried then
        pendingRetried = true
        GC:After(0.3, finishInspect)
        return
    end
    pendingRetried = false
    local d = GC:ScanUnit(unit, true)
    GC:Validate(d)
    GC.results[d.name] = d
    if ClearInspectPlayer then ClearInspectPlayer() end
    pendingUnit, pendingName = nil, nil
    pendingTalent, pendingInventory, pendingRetried = false, false, false
    if GC.Render then GC:Render() end   -- show progress as we go
    GC:After(0.5, processNext)   -- space out inspects (Warmane throttles rapid requests)
end

local function tryFinishInspect()
    if pendingUnit and pendingTalent and pendingInventory then
        finishInspect()
    end
end

local function unitsToScan()
    local list = {}
    local n = GetNumRaidMembers and GetNumRaidMembers() or 0
    if n > 0 then
        for i = 1, n do list[#list+1] = "raid"..i end
    else
        local p = GetNumPartyMembers and GetNumPartyMembers() or 0
        list[#list+1] = "player"
        for i = 1, p do list[#list+1] = "party"..i end
    end
    return list
end

function GC:FinishScan()
    pendingUnit, pendingName = nil, nil
    pendingTalent, pendingInventory, pendingRetried = false, false, false
    -- Retry players who timed out / were out of range: they move into range during a
    -- fight and the one-at-a-time inspect frees up. Keep re-passing until everyone's
    -- resolved or we hit the pass cap.
    if #failedUnits > 0 and retryPass < MAX_PASSES then
        retryPass = retryPass + 1
        local retry = failedUnits
        failedUnits = {}
        for _, u in ipairs(retry) do queue[#queue + 1] = u end
        if self.Render then self:Render() end
        self:Print("Retry pass " .. retryPass .. "/" .. MAX_PASSES .. " for " .. #queue .. " unreachable player(s)...")
        self:After(3.0, function() processNext() end)
        return
    end
    if self.Render then self:Render() end
    self:ScheduleGemRetry()
    self:Print("Scan complete: " .. self:count(self.results) .. " player(s)"
               .. (#failedUnits > 0 and (", " .. #failedUnits .. " unreachable") or "") .. ".")
end

function GC:count(t) local c=0 for _ in pairs(t) do c=c+1 end return c end

processNext = function()
    if #queue == 0 then GC:FinishScan(); return end
    local unit = table.remove(queue, 1)
    if not UnitExists(unit) or not UnitIsConnected(unit) then return processNext() end

    if UnitIsUnit(unit, "player") then
        local d = GC:ScanUnit("player", nil); GC:Validate(d); GC.results[d.name] = d
        return processNext()
    end

    if CanInspect(unit) and CheckInteractDistance(unit, 1) then
        pendingUnit, pendingName = unit, UnitName(unit)
        pendingTalent, pendingInventory, pendingRetried = false, false, false
        DoInspect(unit)
        -- Poll for the inspect data rather than trusting INSPECT_TALENT_READY alone — on
        -- Warmane that event is frequently dropped / never fires even for in-range players.
        -- As soon as the inspected talents read as a real spec, scan. Far more reliable.
        local pollUnit = unit
        local function poll()
            if pendingUnit ~= pollUnit then return end
            local _, pts = GC:GetPrimaryTree(true)
            if pts and pts >= 15 then
                pendingTalent, pendingInventory = true, true
                finishInspect()
            else
                GC:After(0.25, poll)
            end
        end
        GC:After(0.4, poll)
        -- safety timeout: if the data truly never arrives, mark it and retry on a later pass
        GC:After(4.0, function()
            if pendingName and pendingUnit == pollUnit then
                GC.results[pendingName] = { name = pendingName, class = select(2, UnitClass(unit)),
                                            outOfRange = false, issues = 0, slots = {},
                                            note = "inspect timed out" }
                failedUnits[#failedUnits + 1] = unit   -- retry on a later pass
                pendingUnit, pendingName = nil, nil
                pendingTalent, pendingInventory, pendingRetried = false, false, false
                processNext()
            end
        end)
    else
        local nm = UnitName(unit)
        GC.results[nm] = { name = nm, class = select(2, UnitClass(unit)),
                           outOfRange = true, issues = 0, slots = {}, note = "out of range" }
        failedUnits[#failedUnits + 1] = unit   -- may come into range on a later pass
        processNext()
    end
end
GC.processNext = processNext

-- inspect events
local ev = CreateFrame("Frame")
ev:RegisterEvent("INSPECT_TALENT_READY")
ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if not pendingUnit then return end
    if event == "INSPECT_TALENT_READY" then
        pendingTalent = true
        -- grace period: if inventory data doesn't show up shortly after talents do,
        -- proceed anyway rather than hang (better a possibly-incomplete gem read than
        -- a scan that never finishes).
        local unit = pendingUnit
        GC:After(0.4, function()
            if pendingUnit == unit and not pendingInventory then
                pendingInventory = true
                tryFinishInspect()
            end
        end)
        tryFinishInspect()
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == pendingUnit then
        pendingInventory = true
        tryFinishInspect()
    end
end)

-------------------------------------------------------------------------------
-- Public actions
-------------------------------------------------------------------------------
function GC:ScanSelf()
    wipe(self.results)
    local d = self:ScanUnit("player", nil); self:Validate(d); self.results[d.name] = d
    self:Show(); self.expanded[d.name] = true; self:Render()
    self:ScheduleGemRetry()
    self:Print("Scanned "..d.name..".")
end

function GC:ScanTarget()
    local unit = "target"
    if not UnitExists(unit) or not UnitIsPlayer(unit) then self:Print("No player targeted."); return end
    wipe(self.results)
    self:Show()
    if UnitIsUnit(unit, "player") then return self:ScanSelf() end
    if CanInspect(unit) and CheckInteractDistance(unit, 1) then
        pendingUnit, pendingName = unit, UnitName(unit)
        pendingTalent, pendingInventory, pendingRetried = false, false, false
        DoInspect(unit)
        self:After(2.5, function()
            if pendingName then
                self:Print("Inspect timed out (move closer).")
                pendingUnit, pendingName = nil, nil
                pendingTalent, pendingInventory, pendingRetried = false, false, false
            end
        end)
        self:Print("Inspecting "..UnitName(unit).."...")
    else
        self:Print("Can't inspect "..UnitName(unit).." (move closer).")
    end
end

function GC:ScanRaid()
    wipe(self.results)
    wipe(queue)
    failedUnits = {}
    retryPass = 0
    for _, u in ipairs(unitsToScan()) do queue[#queue+1] = u end
    self:Show()
    self:Print("Scanning "..#queue.." unit(s)... (inspect needs line-of-sight & range)")
    processNext()
end

-- "Check" = same scan, but the window opens on the issues view (collapsed rows,
-- players with problems highlighted). Scanning already validates, so this just
-- runs a raid scan and focuses on gems/enchants.
function GC:Check()
    self.checkMode = true
    self:ScanRaid()
end

-------------------------------------------------------------------------------
-- Utility / slash
-------------------------------------------------------------------------------
function GC:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffGearCheck|r: " .. tostring(msg))
end

-- Diagnostic: print raw per-tab talent point totals (both the direct API value and
-- our own summed fallback) plus which tab we'd pick as primary. Use this to debug
-- role mis-detection, e.g. /gc talents  or  /gc talents target
function GC:DebugTalents(unit, inspect)
    local group = GetActiveTalentGroup and GetActiveTalentGroup(inspect) or nil
    self:Print("Active talent group: " .. tostring(group))
    local best, bestPts = 1, -1
    for tab = 1, 3 do
        local tabName, _, apiPts = GetTalentTabInfo(tab, inspect, nil, group)
        local summed = 0
        local n = GetNumTalents(tab, inspect, nil, group) or 0
        for i = 1, n do
            local _, _, _, _, rank = GetTalentInfo(tab, i, inspect, nil, group)
            summed = summed + (rank or 0)
        end
        self:Print(string.format("Tab %d (%s): API pts=%s, summed=%d",
            tab, tabName or "?", tostring(apiPts), summed))
        local used = (not apiPts or apiPts == 0) and summed or apiPts
        if used > bestPts then bestPts = used; best = tab end
    end
    self:Print("-> primary tab picked: " .. best .. " (pts=" .. bestPts .. ")")
    -- talent grade readout
    local _, class = UnitClass(unit)
    local role = self:RoleForUnit(unit, class, inspect)
    local spec = self:SpecForTalents(class, best, role)
    self:Print("spec for grading: " .. tostring(class) .. " / " .. tostring(spec))
    local build = self.TALENT_BUILD and class and self.TALENT_BUILD[class] and spec and self.TALENT_BUILD[class][spec]
    if not build then
        self:Print("no reference build for that spec (check the Talent Builds tab / Talents.lua)")
    else
        local have = self:ReadTalents(inspect)
        local wrong = 0
        for tal, need in pairs(build) do
            local got = have[tal] or 0
            if got ~= need then wrong = wrong + 1; self:Print("  WRONG: " .. tal .. " " .. got .. "/" .. need) end
        end
        self:Print("talent grade: " .. (wrong == 0 and "CORRECT" or (wrong .. " wrong")))
    end
end

-- Debug: print every tooltip line of an equipped item with its RGB colour, so we can
-- see exactly what the addon reads (why an enchant/gem isn't parsed on THIS client).
function GC:DumpItem(unit, slotId, label)
    scanTip:ClearLines()
    if not scanTip:SetInventoryItem(unit, slotId) then self:Print(label .. ": (no item)") return end
    local link = GetInventoryItemLink(unit, slotId)
    self:Print("--- " .. label .. " (slot " .. slotId .. ") ---")
    if link then
        local a, b2, c, d, e = link:match("item:(%d+):(%d*):(%d*):(%d*):(%d*)")
        self:Print("link: item=" .. (a or "?") .. " ench=" .. (b2 or "-") ..
                   " gems=" .. (c or "-") .. "," .. (d or "-") .. "," .. (e or "-"))
    end
    for i = 1, scanTip:NumLines() do
        local fs = _G["GearCheckScanTipTextLeft" .. i]
        local txt = fs and fs:GetText()
        if txt and txt ~= "" then
            local r, g, b = fs:GetTextColor()
            self:Print(string.format("%2d [%.1f %.1f %.1f] %s", i, r or 0, g or 0, b or 0, txt))
        end
    end
end

SLASH_GEARCHECK1 = "/gc"
SLASH_GEARCHECK2 = "/gearcheck"
SlashCmdList["GEARCHECK"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if msg == "self" or msg == "" then GC:ScanSelf()
    elseif msg == "target" or msg == "t" then GC:ScanTarget()
    elseif msg == "raid" then GC:ScanRaid()
    elseif msg == "check" then GC:Check()
    elseif msg == "show" then GC:Show()
    elseif msg == "hide" then GC:Hide()
    elseif msg == "talents" then GC:DebugTalents("player", nil)
    elseif msg == "talents target" then
        if not UnitExists("target") then GC:Print("No target.") return end
        if UnitIsUnit("target", "player") then GC:DebugTalents("player", nil); return end
        if not (CanInspect("target") and CheckInteractDistance("target", 1)) then
            GC:Print("Can't inspect target (move closer).")
            return
        end
        local targetName = UnitName("target")
        NotifyInspect("target")
        GC:Print("Requesting inspect data for " .. targetName .. "... (waiting for it to actually arrive)")
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("INSPECT_TALENT_READY")
        local done = false
        waiter:SetScript("OnEvent", function(w)
            if done then return end
            done = true
            w:UnregisterAllEvents()
            GC:DebugTalents("target", true)
        end)
        GC:After(3, function()
            if not done then
                done = true
                waiter:UnregisterAllEvents()
                GC:Print("Inspect timed out for " .. targetName .. " — talent data never arrived.")
            end
        end)
    elseif msg:find("^dump") then
        local DUMPSLOTS = { head=1, neck=2, shoulder=3, back=15, chest=5, wrist=9, hands=10,
            waist=6, legs=7, feet=8, mainhand=16, offhand=17, ranged=18, ring1=11, ring2=12 }
        local slot, tgt = msg:match("^dump%s+(%a+)%s*(%a*)")
        local id = slot and DUMPSLOTS[slot]
        if not id then
            GC:Print("usage: /gc dump <head|neck|shoulder|back|chest|wrist|hands|waist|legs|feet|mainhand|offhand|ranged> [target]")
        elseif tgt == "target" and UnitExists("target") and UnitIsPlayer("target") and not UnitIsUnit("target", "player") then
            if not (CanInspect("target") and CheckInteractDistance("target", 1)) then
                GC:Print("Move closer to target to inspect.")
            else
                local nm = UnitName("target")
                NotifyInspect("target")
                GC:Print("Inspecting " .. nm .. " to dump " .. slot .. "...")
                local w = CreateFrame("Frame"); w:RegisterEvent("INSPECT_TALENT_READY")
                local done = false
                w:SetScript("OnEvent", function(ww)
                    if done then return end; done = true; ww:UnregisterAllEvents()
                    GC:After(0.4, function() GC:DumpItem("target", id, nm .. " " .. slot) end)
                end)
                GC:After(3, function() if not done then done = true; w:UnregisterAllEvents(); GC:Print("Inspect timed out.") end end)
            end
        else
            GC:DumpItem("player", id, "self " .. slot)
        end
    else
        GC:Print("commands: /gc self | target | raid | check | show | hide | talents | talents target | dump <slot> [target]")
    end
end
