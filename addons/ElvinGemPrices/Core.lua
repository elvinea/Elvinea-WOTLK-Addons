EGP = EGP or {}

local DEFAULTS_SECTIONS = {
    materials = true,
    cutgems   = true,
    kit       = true,
    smallkit  = true,
}

-- ============================================================
-- SavedVariables init
-- ============================================================
function EGP_InitDB()
    ElvinGemPricesDB = ElvinGemPricesDB or {}
    local db = ElvinGemPricesDB

    db.materialPrice = db.materialPrice or {}
    for _, m in ipairs(EGP.Materials) do
        if db.materialPrice[m.key] == nil then
            db.materialPrice[m.key] = m.price
        end
    end

    db.gemSell = db.gemSell or {}
    for _, g in ipairs(EGP.CutGems) do
        if db.gemSell[g.key] == nil then
            db.gemSell[g.key] = g.sell
        end
    end

    db.kit = db.kit or {}
    for _, g in ipairs(EGP.CutGems) do
        if db.kit[g.key] == nil then
            db.kit[g.key] = { include = true, manualQty = 0 }
        end
    end
    db.budget = db.budget or 20000

    db.smallKit = db.smallKit or {}
    for _, s in ipairs(EGP.SmallKit) do
        if db.smallKit[s.key] == nil then
            db.smallKit[s.key] = { include = true, qty = s.qty }
        end
    end

    db.sections = db.sections or {}
    for k, v in pairs(DEFAULTS_SECTIONS) do
        if db.sections[k] == nil then
            db.sections[k] = v
        end
    end

    if db.framePos == nil then
        db.framePos = { point = "CENTER", x = 0, y = 0 }
    end
    if db.frameSize == nil then
        db.frameSize = { w = 470, h = 560 }
    end

    EGP.db = db
end

-- ============================================================
-- Calculated results, refreshed by EGP_Recalc()
-- ============================================================
EGP.calc = {
    cutGems  = {},   -- key -> { matCost, profit }
    kit      = {},   -- key -> { qty, stacks, value }
    kitTotalValue = 0,
    kitOverBudget = false,
    smallKit = {},   -- key -> { stacks, price, value }
    smallKitTotalValue = 0,
}

local function matPrice(key)
    return EGP.db.materialPrice[key] or 0
end

local function recalcCutGems()
    for _, g in ipairs(EGP.CutGems) do
        local cost = 0
        for _, comp in ipairs(g.recipe) do
            local mKey, qty = comp[1], comp[2]
            cost = cost + matPrice(mKey) * qty
        end
        local sell = EGP.db.gemSell[g.key] or g.sell
        EGP.calc.cutGems[g.key] = {
            matCost = cost,
            profit  = sell - cost,
        }
    end
end

-- Gold-budget kit calculator: gems with a manual qty > 0 are "locked" and
-- reserve their gold first. Remaining budget is split evenly (in stacks of
-- 20) across the remaining "auto" gems, then any leftover gold is handed
-- out round-robin, one more stack at a time, until nothing more fits.
local function recalcKit()
    local db = EGP.db
    local budget = tonumber(db.budget) or 0

    local lockedCost = 0
    local autoList = {}

    for _, g in ipairs(EGP.CutGems) do
        local row = db.kit[g.key]
        local price = db.gemSell[g.key] or g.sell
        if row.include then
            if row.manualQty and row.manualQty > 0 then
                lockedCost = lockedCost + row.manualQty * price
            else
                table.insert(autoList, { key = g.key, price = price })
            end
        end
    end

    local remaining = budget - lockedCost
    if remaining < 0 then remaining = 0 end

    local autoQty = {}
    if #autoList > 0 then
        local share = remaining / #autoList
        local spent = 0
        for _, ag in ipairs(autoList) do
            local q = 0
            if ag.price > 0 then
                q = math.floor(share / ag.price / 20) * 20
            end
            if q < 0 then q = 0 end
            autoQty[ag.key] = q
            spent = spent + q * ag.price
        end

        local leftover = remaining - spent
        local guard = 0
        local progress = true
        while progress and guard < 1000 do
            progress = false
            guard = guard + 1
            for _, ag in ipairs(autoList) do
                if ag.price > 0 and leftover >= 20 * ag.price then
                    autoQty[ag.key] = autoQty[ag.key] + 20
                    leftover = leftover - 20 * ag.price
                    progress = true
                end
            end
        end
    end

    local totalValue = 0
    for _, g in ipairs(EGP.CutGems) do
        local row = db.kit[g.key]
        local price = db.gemSell[g.key] or g.sell
        local qty = 0
        if row.include then
            if row.manualQty and row.manualQty > 0 then
                qty = row.manualQty
            else
                qty = autoQty[g.key] or 0
            end
        end
        local value = qty * price
        EGP.calc.kit[g.key] = {
            qty = qty,
            stacks = qty / 20,
            value = value,
        }
        totalValue = totalValue + value
    end

    EGP.calc.kitTotalValue = totalValue
    EGP.calc.kitOverBudget = totalValue > budget
end

local function recalcSmallKit()
    local db = EGP.db
    local total = 0
    for _, s in ipairs(EGP.SmallKit) do
        local row = db.smallKit[s.key]
        local price = matPrice(s.key)
        local qty = tonumber(row.qty) or 0
        local value = 0
        local stacks = qty / 20
        if row.include then
            value = qty * price
        else
            value = 0
        end
        EGP.calc.smallKit[s.key] = {
            price = price,
            stacks = stacks,
            value = value,
        }
        total = total + value
    end
    EGP.calc.smallKitTotalValue = total
end

function EGP_Recalc()
    if not EGP.db then return end
    recalcCutGems()
    recalcKit()
    recalcSmallKit()
    if EGP.RefreshUI then
        EGP.RefreshUI()
    end
end

-- ============================================================
-- Load / slash command
-- ============================================================
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon == "ElvinGemPrices" then
        EGP_InitDB()
        EGP_Recalc()
        if EGP.BuildUI then
            EGP.BuildUI()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

SLASH_ELVINGEMPRICES1 = "/egp"
SLASH_ELVINGEMPRICES2 = "/elvingemprices"
SlashCmdList["ELVINGEMPRICES"] = function()
    if EGP.ToggleFrame then
        EGP.ToggleFrame()
    end
end
