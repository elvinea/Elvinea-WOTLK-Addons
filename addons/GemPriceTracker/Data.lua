GPT = GPT or {}

-- Raw materials (Eternals + uncommon "feeder" gems used in rare gem recipes).
-- Order matches the "Raw Materials" column on the Heros.xlsm Gem Prices tab.
GPT.Materials = {
    { key = "eternal_air",     name = "Eternal Air",     price = 30 },
    { key = "eternal_fire",    name = "Eternal Fire",    price = 35 },
    { key = "eternal_shadow",  name = "Eternal Shadow",  price = 30 },
    { key = "eternal_life",    name = "Eternal Life",    price = 30 },
    { key = "autumns_glow",    name = "Autumn's Glow",   price = 80 },
    { key = "monarch_topaz",   name = "Monarch Topaz",   price = 50 },
    { key = "scarlet_ruby",    name = "Scarlet Ruby",    price = 80 },
    { key = "twilight_opal",   name = "Twilight Opal",   price = 4 },
    { key = "forest_emerald",  name = "Forest Emerald",  price = 3 },
    { key = "sky_sapphire",    name = "Sky Sapphire",    price = 5 },
}

-- Cut (rare) gems, their default sell price, and the raw material recipe
-- used to compute Mat Cost / Profit. recipe = { {materialKey, qty}, ... }
GPT.CutGems = {
    { key = "ametrine",         name = "Ametrine",         sell = 90,  recipe = { { "eternal_shadow", 1 }, { "monarch_topaz", 1 } } },
    { key = "cardinal_ruby",    name = "Cardinal Ruby",    sell = 125, recipe = { { "eternal_fire", 1 },    { "scarlet_ruby", 1 } } },
    { key = "dreadstone",       name = "Dreadstone",       sell = 55,  recipe = { { "eternal_shadow", 1 }, { "twilight_opal", 1 } } },
    { key = "eye_of_zul",       name = "Eye of Zul",       sell = 30,  recipe = { { "forest_emerald", 3 } } },
    { key = "kings_amber",      name = "King's Amber",     sell = 115, recipe = { { "eternal_life", 1 },    { "autumns_glow", 1 } } },
    { key = "majestic_zircon",  name = "Majestic Zircon",  sell = 60,  recipe = { { "eternal_air", 1 },     { "sky_sapphire", 1 } } },
}

-- Small Gem Kit: quick qty/price/value calculator for the uncommon feeder
-- gems themselves (prices come from Materials above).
GPT.SmallKit = {
    { key = "autumns_glow",   name = "Autumn's Glow",   qty = 440 },
    { key = "monarch_topaz",  name = "Monarch Topaz",   qty = 360 },
    { key = "scarlet_ruby",   name = "Scarlet Ruby",    qty = 400 },
    { key = "twilight_opal",  name = "Twilight Opal",   qty = 1000 },
    { key = "forest_emerald", name = "Forest Emerald",  qty = 760 },
    { key = "sky_sapphire",   name = "Sky Sapphire",    qty = 300 },
}
