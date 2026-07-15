-- GearCheck :: Data.lua
-- All the reference data: slot list, class/spec -> role, acceptable gems & enchants.
-- Everything here is name-based, because on 3.3.5a we read gem names via GetItemGem()
-- and enchant text via a tooltip scan, so we don't need raw item IDs to validate.

GearCheck = GearCheck or {}
local GC = GearCheck

-------------------------------------------------------------------------------
-- Equipment slots we scan (skip Shirt/Tabard). ench = should carry an enchant.
-------------------------------------------------------------------------------
GC.SLOTS = {
    { id = 1,  name = "Head",       ench = true  },
    { id = 2,  name = "Neck",       ench = false },
    { id = 3,  name = "Shoulder",   ench = true  },
    { id = 15, name = "Back",       ench = true  },
    { id = 5,  name = "Chest",      ench = true  },
    { id = 9,  name = "Wrist",      ench = true  },
    { id = 10, name = "Hands",      ench = true  },
    { id = 6,  name = "Waist",      ench = false }, -- belt buckle is a socket, not an enchant
    { id = 7,  name = "Legs",       ench = true  },
    { id = 8,  name = "Feet",       ench = true  },
    { id = 11, name = "Ring 1",     ench = "jc"  }, -- enchanter only
    { id = 12, name = "Ring 2",     ench = "jc"  },
    { id = 13, name = "Trinket 1",  ench = false },
    { id = 14, name = "Trinket 2",  ench = false },
    { id = 16, name = "Main Hand",  ench = true  },
    { id = 17, name = "Off Hand",   ench = "oh"  }, -- shields/off-hand weapons
    { id = 18, name = "Ranged",     ench = "rng" }, -- scopes (bow/gun/xbow)
}

-------------------------------------------------------------------------------
-- Role detection. Primary talent tree (tab 1/2/3) -> role for each class.
-- Roles: Tank / Melee / Ranged / Healer  (Physical = Melee or Ranged for gems)
-------------------------------------------------------------------------------
GC.TREE_ROLE = {
    PALADIN     = { "Healer", "Tank",   "Melee"  },  -- Holy / Prot / Ret
    WARRIOR     = { "Melee",  "Melee",  "Tank"   },  -- Arms / Fury / Prot
    DEATHKNIGHT = { "Tank",   "Melee",  "Melee"  },  -- Blood(tank def) / Frost / Unholy
    DRUID       = { "Ranged", "Melee",  "Healer" },  -- Balance / Feral(cat def) / Resto
    HUNTER      = { "Ranged", "Ranged", "Ranged" },
    MAGE        = { "Ranged", "Ranged", "Ranged" },
    PRIEST      = { "Healer", "Healer", "Ranged" },  -- Disc / Holy / Shadow
    ROGUE       = { "Melee",  "Melee",  "Melee"  },
    SHAMAN      = { "Ranged", "Melee",  "Healer" },  -- Ele / Enh / Resto
    WARLOCK     = { "Ranged", "Ranged", "Ranged" },
}

-- Map a role to the gem/enchant "type" bucket used for validation.
GC.ROLE_TYPE = { Tank="Tank", Melee="Physical", Ranged=nil, Healer="Healer" }
-- Ranged is split: casters (Int/SP classes) -> Caster, hunter -> Physical.
GC.RANGED_CASTER = { MAGE=true, WARLOCK=true, DRUID=true, SHAMAN=true, PRIEST=true, PALADIN=true }

function GC:TypeFor(role, class)
    if role == "Tank" then return "Tank" end
    if role == "Healer" then return "Healer" end
    if role == "Melee" then return "Physical" end
    if role == "Ranged" then
        if class == "HUNTER" then return "Physical" else return "Caster" end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Which slots should carry an enchant, given the unit's class/prof situation.
-- Rings only if Enchanter, Off-hand only if a shield/held enchant applies,
-- Ranged only for bow/gun users (Hunter/Warrior/Rogue). We keep it simple:
-- the "core" slots below are always expected; the rest are informational.
-------------------------------------------------------------------------------
GC.CORE_ENCHANT_SLOTS = {
    [1]=true, [3]=true, [15]=true, [5]=true, [9]=true,
    [10]=true, [7]=true, [8]=true, [16]=true,
}

-------------------------------------------------------------------------------
-- GearScore — same formula as GearScoreLite / GearScoreRecorder, ported so we
-- can show a comparable number without requiring either addon installed too.
-- Critically, SlotMOD is keyed by the item's own equip-location string, NOT by
-- which physical inventory slot it's in — a Titan's Grip off-hand 2H weapon
-- must score at the same 2.0 weight as a main-hand 2H weapon, for example.
-------------------------------------------------------------------------------
GC.GS_ITEM_TYPES = {
    INVTYPE_RELIC          = { SlotMOD = 0.3164, Enchantable = false },
    INVTYPE_TRINKET        = { SlotMOD = 0.5625, Enchantable = false },
    INVTYPE_2HWEAPON       = { SlotMOD = 2.0000, Enchantable = true  },
    INVTYPE_WEAPONMAINHAND = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_WEAPONOFFHAND  = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_RANGED         = { SlotMOD = 0.3164, Enchantable = true  },
    INVTYPE_THROWN         = { SlotMOD = 0.3164, Enchantable = false },
    INVTYPE_RANGEDRIGHT    = { SlotMOD = 0.3164, Enchantable = false },
    INVTYPE_SHIELD         = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_WEAPON         = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_HOLDABLE       = { SlotMOD = 1.0000, Enchantable = false },
    INVTYPE_HEAD           = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_NECK           = { SlotMOD = 0.5625, Enchantable = false },
    INVTYPE_SHOULDER       = { SlotMOD = 0.7500, Enchantable = true  },
    INVTYPE_CHEST          = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_ROBE           = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_WAIST          = { SlotMOD = 0.7500, Enchantable = false },
    INVTYPE_LEGS           = { SlotMOD = 1.0000, Enchantable = true  },
    INVTYPE_FEET           = { SlotMOD = 0.7500, Enchantable = true  },
    INVTYPE_WRIST          = { SlotMOD = 0.5625, Enchantable = true  },
    INVTYPE_HAND           = { SlotMOD = 0.7500, Enchantable = true  },
    INVTYPE_FINGER         = { SlotMOD = 0.5625, Enchantable = false },
    INVTYPE_CLOAK          = { SlotMOD = 0.5625, Enchantable = true  },
    INVTYPE_BODY           = { SlotMOD = 0,       Enchantable = false },
}
-- ilvl>120 branch constants only — every ICC-relevant item is well above 120.
GC.GS_RARITY_AB = {
    [4] = { A = 91.45,  B = 0.65   },  -- Epic
    [3] = { A = 81.375, B = 0.8125 },  -- Rare
    [2] = { A = 73.0,   B = 1.0    },  -- Uncommon
}
local GS_SCALE = 1.8618

-- ilvl, rarity (item quality number), equipLoc (e.g. "INVTYPE_HEAD"), whether
-- this slot carries an enchant, and an extra multiplier (Titan's Grip halving,
-- Hunter's ranged/main-hand weight swap).
function GC:ItemGearScore(ilvl, rarity, equipLoc, isEnchanted, extraMod)
    if not ilvl or ilvl <= 0 or not rarity or not equipLoc then return 0 end
    local info = self.GS_ITEM_TYPES[equipLoc]
    if not info then return 0 end
    local r, qualityScale = rarity, 1
    if r == 5 then qualityScale = 1.3; r = 4          -- legendary scores like a boosted epic
    elseif r <= 1 then qualityScale = 0.005; r = 2 end -- common/poor barely count
    local ab = self.GS_RARITY_AB[r]
    if not ab then return 0 end
    local slotMod = info.SlotMOD * (extraMod or 1)
    local score = ((ilvl - ab.A) / ab.B) * slotMod * GS_SCALE * qualityScale
    if score < 0 then score = 0 end
    if info.Enchantable and not isEnchanted then
        local percent = math.floor((-2 * info.SlotMOD) * 100) / 100  -- negative: docks score
        score = score * (1 + percent / 100)
    end
    return math.floor(score)
end



-------------------------------------------------------------------------------
-- Acceptable GEMS by type (names, from the guild sheet). Meta gems handled
-- separately. Anything socketed that isn't in the set (and isn't a meta) is
-- flagged as an off-role gem.
-------------------------------------------------------------------------------
local function set(...) local t={} for _,v in ipairs({...}) do t[v]=true end return t end

GC.META_GEMS = set(
    "Austere Earthsiege Diamond","Eternal Earthsiege Diamond","Effulgent Skyflare Diamond",
    "Relentless Earthsiege Diamond","Chaotic Skyflare Diamond","Ember Skyflare Diamond",
    "Insightful Earthsiege Diamond","Beaming Earthsiege Diamond","Revitalizing Skyflare Diamond",
    "Bracing Earthsiege Diamond","Forlorn Skyflare Diamond","Persistent Earthsiege Diamond",
    "Powerful Earthsiege Diamond","Enigmatic Skyflare Diamond","Swift Skyflare Diamond"
)
GC.PRISMATIC = set("Nightmare Tear")   -- universal +10 all stats, valid in any socket for anyone

-- Items with no Normal/Heroic split at all (legendaries, quest rewards, reputation
-- rewards). These should always count as full BiS when on the list, never flagged
-- "pre-BiS: get the Heroic one".
GC.NO_HEROIC_REQUIRED = set("Shadowmourne", "Shadow's Edge",
    "Ashen Band of Endless Might", "Ashen Band of Endless Vengeance",
    "Ashen Band of Endless Wisdom", "Ashen Band of Endless Destruction",
    "Ashen Band of Endless Courage")

-- Meta the type is expected to run (for a soft check).
GC.META_FOR_TYPE = {
    Tank     = set("Austere Earthsiege Diamond","Eternal Earthsiege Diamond","Effulgent Skyflare Diamond"),
    Physical = set("Relentless Earthsiege Diamond","Chaotic Skyflare Diamond"),
    Caster   = set("Chaotic Skyflare Diamond","Ember Skyflare Diamond","Beaming Earthsiege Diamond"),
    Healer   = set("Insightful Earthsiege Diamond","Ember Skyflare Diamond","Revitalizing Skyflare Diamond"),
}

GC.GEMS_FOR_TYPE = {
    -- TANK (Stamina): solid sta + threat (hit/exp) + sta hybrids
    Tank = set(
        "Solid Majestic Zircon","Solid Sky Sapphire","Solid Stormjewel","Solid Dragon's Eye",  -- +Sta (JC = Dragon's Eye)
        "Rigid King's Amber","Rigid Dragon's Eye",                                  -- hit (threat)
        "Etched Ametrine","Accurate Ametrine","Guardian's Dreadstone",          -- hit/exp threat + exp/sta
        "Shifting Dreadstone","Sovereign Dreadstone","Regal Dreadstone",            -- +sta hybrids
        "Defender's Dreadstone","Puissant Dreadstone","Vivid Eye of Zul","Enduring Eye of Zul",
        "Nightmare Tear","Chaotic Skyflare Diamond"),
    -- PHYSICAL (Str / Agi / ArP): mains + hit + expertise + crit + haste hybrids + pure yellows (JC = Dragon's Eye)
    Physical = set(
        "Bold Cardinal Ruby","Bold Dragon's Eye","Delicate Cardinal Ruby","Delicate Dragon's Eye",  -- Str / Agi
        "Fractured Cardinal Ruby","Fractured Dragon's Eye","Bright Cardinal Ruby","Bright Dragon's Eye","Precise Cardinal Ruby", -- ArP / AP / Exp
        "Etched Ametrine","Glinting Ametrine",                                  -- +Hit  (Str+Hit / Agi+Hit)
        "Accurate Ametrine",                                                      -- +Expertise (Exp+Hit)
        "Inscribed Ametrine","Deadly Ametrine",                                     -- +Crit (Str+Crit / Agi+Crit)
        "Fierce Ametrine","Deft Ametrine","Wicked Ametrine",                        -- +Haste (Str+Haste / Agi+Haste)
        "Rigid King's Amber","Quick King's Amber","Smooth King's Amber",            -- pure Hit / Haste / Crit
        "Rigid Dragon's Eye","Quick Dragon's Eye","Smooth Dragon's Eye",            -- JC pure Hit / Haste / Crit
        "Nightmare Tear"),
    -- CASTER (Spell Power): SP + SP-hybrids for hit / crit / haste (JC = Runed Dragon's Eye)
    Caster = set(
        "Runed Cardinal Ruby","Runed Dragon's Eye",                                 -- +23 SP
        "Veiled Ametrine",                                                          -- SP + Hit
        "Potent Ametrine",                                                          -- SP + Crit
        "Reckless Ametrine",                                                        -- SP + Haste
        "Purified Dreadstone","Glowing Dreadstone","Sundered Dreadstone",           -- SP + Spirit / Sta / ArP
        "Nightmare Tear"),
    -- HEALER (Int / SP / Haste): int + sp cuts + haste + spirit (JC = Dragon's Eye)
    Healer = set(
        "Brilliant King's Amber","Brilliant Dragon's Eye",                          -- +20 Int
        "Runed Cardinal Ruby","Runed Dragon's Eye",                                 -- +23 SP
        "Quick King's Amber","Quick Dragon's Eye",                                  -- +20 Haste
        "Reckless Ametrine","Potent Ametrine","Veiled Ametrine",                    -- SP+haste / SP+crit / SP+hit
        "Sparkling Majestic Zircon","Purified Dreadstone","Royal Dreadstone","Timeless Dreadstone",
        "Nightmare Tear"),
}

-- Master list of every acceptable gem NAME (any role). Gem validation checks against
-- this by name only — a socketed gem that isn't in here is flagged as unrecognized.
GC.ALL_GEMS = {}
for _, s in pairs(GC.GEMS_FOR_TYPE) do
    for name in pairs(s) do GC.ALL_GEMS[name] = true end
end
for name in pairs(GC.META_GEMS) do GC.ALL_GEMS[name] = true end
for name in pairs(GC.PRISMATIC) do GC.ALL_GEMS[name] = true end

-------------------------------------------------------------------------------
-- Acceptable ENCHANTS. Enchants read from a tooltip scan give the *effect text*
-- (e.g. "+50 Attack Power"), not the enchant name, so we match on keywords.
-- Per slot per type: a list of Lua patterns; if the enchant line matches ANY,
-- it's accepted. Missing enchant on a core slot is always flagged.
-------------------------------------------------------------------------------
-- Read a socketed gem off the item tooltip by its stat line, for inspected units where
-- the link carries only enchant-ids (small numbers) instead of gem item-ids.
GC.GEM_BY_STAT = {
    ["+20 strength"]="Bold Cardinal Ruby", ["+20 agility"]="Delicate Cardinal Ruby",
    ["+20 armor penetration rating"]="Fractured Cardinal Ruby", ["+23 spell power"]="Runed Cardinal Ruby",
    ["+20 attack power"]="Bright Cardinal Ruby", ["+20 expertise rating"]="Precise Cardinal Ruby",
    ["+20 intellect"]="Brilliant King's Amber", ["+20 hit rating"]="Rigid King's Amber",
    ["+20 haste rating"]="Quick King's Amber", ["+20 critical strike rating"]="Smooth King's Amber",
    ["+30 stamina"]="Solid Majestic Zircon",
    ["+10 spell power and +10 critical strike rating"]="Potent Ametrine",
    ["+10 spell power and +10 haste rating"]="Reckless Ametrine",
    ["+10 spell power and +10 hit rating"]="Veiled Ametrine",
    ["+10 strength and +10 critical strike rating"]="Inscribed Ametrine",
    ["+10 strength and +10 haste rating"]="Fierce Ametrine",
    ["+10 strength and +10 hit rating"]="Etched Ametrine",
    ["+10 agility and +10 critical strike rating"]="Deadly Ametrine",
    ["+10 agility and +10 haste rating"]="Deft Ametrine",
    ["+10 agility and +10 hit rating"]="Glinting Ametrine",
    ["+10 expertise rating and +10 hit rating"]="Accurate Ametrine",
    ["+10 all stats"]="Nightmare Tear", ["+10 to all stats"]="Nightmare Tear",
    ["+34 strength"]="Bold Dragon's Eye", ["+34 agility"]="Delicate Dragon's Eye",
    ["+34 armor penetration rating"]="Fractured Dragon's Eye", ["+39 spell power"]="Runed Dragon's Eye",
    ["+27 intellect"]="Brilliant Dragon's Eye", ["+34 haste rating"]="Quick Dragon's Eye",
    ["+12 spell power and +10 spirit"]="Purified Dreadstone",
}

-- Profession enchants show their NAME as a line in the tooltip (often red / "Enchantment
-- Requires <Prof>"), not a green stat line, so match them by name directly. { display, stats }
GC.ENCH_BYNAME = {
    ["lightweave embroidery"]   = { "Lightweave Embroidery [Tailoring]",  "proc +295 SP" },
    ["swordguard embroidery"]   = { "Swordguard Embroidery [Tailoring]",  "proc +400 AP" },
    ["darkglow embroidery"]     = { "Darkglow Embroidery [Tailoring]",    "proc mana restore" },
    ["springy arachnoweave"]    = { "Springy Arachnoweave [Tailoring]",   "+27 SP + slowfall" },
    ["flexweave underlay"]      = { "Flexweave Underlay [Eng]",           "+23 Agi + parachute" },
    ["hyperspeed accelerators"] = { "Hyperspeed Accelerators [Eng]",      "+340 Haste on-use" },
    ["nitro boosts"]            = { "Nitro Boosts [Eng]",                 "+run speed, +crit" },
    ["reticulated armor webbing"] = { "Reticulated Armor Webbing [Eng]",  "+885 Armor" },
}

GC.ENCH_OK = {
    Tank = {
        Head="Stamina", Shoulder="Stamina", Back="Armor", Chest="Health",
        Wrist="Stamina", Hands="Threat", Legs="Stamina", Feet="Stamina",
        ["Main Hand"]="Blocking", },
    Physical = {
        Head="Attack Power", Shoulder="Attack Power", Back="Agility", Chest="All Stats",
        Wrist="Attack Power", Hands="Attack Power", Legs="Attack Power", Feet="Hit Rating",
        ["Main Hand"]="Berserking", Ranged="Critical Strike", },
    Caster = {
        Head="Spell Power", Shoulder="Spell Power", Back="Spell Power", Chest="All Stats",
        Wrist="Spell Power", Hands="Spell Power", Legs="Spell Power", Feet="Hit Rating",
        ["Main Hand"]="Spell Power", },
    Healer = {
        Head="Spell Power", Shoulder="Spell Power", Back="Speed", Chest="All Stats",
        Wrist="Spell Power", Hands="Spell Power", Legs="Spell Power", Feet="Stamina",
        ["Main Hand"]="Spell Power", },
}
-- Class + primary tree -> profile (for BiS item checking). Bear/DK-tank handled in Core.
GC.TREE_PROFILE = {
    PALADIN     = { "Healer — Intellect", "Plate Tank",      "Plate Strength"   },
    WARRIOR     = { "Plate Armor Pen",    "Plate Armor Pen", "Plate Tank"       },
    DEATHKNIGHT = { "Plate Tank",         "Plate Armor Pen", "Plate Strength"   },
    DRUID       = { "Leather Caster",     "Leather Armor Pen","Healer — Spell Power" },
    HUNTER      = { "Mail Armor Pen",     "Mail Armor Pen",  "Mail Armor Pen"   },
    MAGE        = { "Cloth Caster — Haste","Cloth Caster — Crit","Cloth Caster — Crit" },
    PRIEST      = { "Healer — Spell Power","Healer — Spell Power","Cloth Caster — Crit" },
    ROGUE       = { "Leather Armor Pen",  "Leather Armor Pen","Leather Armor Pen"},
    SHAMAN      = { "Mail Caster",        "Agi Mail",        "Healer — Haste"   },
    WARLOCK     = { "Cloth Caster — Haste","Cloth Caster — Crit","Cloth Caster — Crit" },
}

-- Enchant resolver: match the effect text (lowercased) by slot -> { name, stats }.
-- Each entry: { {keywords all-required}, "Name", "+stats" }. First full match wins.
GC.ENCH_NAME = {
    Head = {
        {{"attack power"},            "Arcanum of Torment",                 "+50 AP, +20 Crit"},
        {{"spell power","critical"},  "Arcanum of Burning Mysteries",       "+30 SP, +20 Crit"},
        {{"spell power","mana"},      "Arcanum of Blissful Mending",        "+30 SP, +10 mp5"},
        {{"spell power"},             "Arcanum of Burning Mysteries",       "+30 SP, +20 Crit"},
        {{"stamina"},                 "Arcanum of the Stalwart Protector",  "+37 Sta, +20 Def"},
    },
    Shoulder = {
        {{"attack power"}, "Greater Inscription of the Axe",       "+40 AP, +15 Crit"},
        {{"spell power"},  "Greater Inscription of the Storm",     "+24 SP, +15 Crit"},
        {{"stamina"},      "Greater Inscription of the Gladiator", "+30 Sta, +15 Resil"},
    },
    Back = {
        {{"agility"},       "Enchant Cloak - Major Agility", "+22 Agi"},
        {{"armor"},         "Enchant Cloak - Mighty Armor",  "+225 Armor"},
        {{"haste"},         "Enchant Cloak - Greater Speed", "+23 Haste"},
        {{"defense"},       "Enchant Cloak - Titanweave",    "+16 Def"},
        {{"spell power"},    "Lightweave / Spellpower (cloak) [Tailoring]", "+23 SP (proc/static)"},
        {{"attack power"},   "Swordguard Embroidery [Tailoring]",           "Use: +400 AP proc, 15 sec"},
        {{"falling speed"},  "Slow Fall Cloak Enchant [Eng]",                "Use: -fall speed, 30 sec (1 min CD)"},
    },
    Chest = {
        {{"all stats"}, "Enchant Chest - Powerful Stats", "+10 all stats"},
        {{"stats"},     "Enchant Chest - Powerful Stats", "+10 all stats"},
        {{"health"},    "Enchant Chest - Super Health",   "+275 Health"},
    },
    Wrist = {
        {{"spell power"},  "Enchant Bracers - Superior Spellpower", "+30 SP"},
        {{"attack power"}, "Enchant Bracers - Greater Assault",     "+50 AP"},
        {{"stamina"},      "Enchant Bracers - Major Stamina",       "+40 Sta"},
        {{"spirit"},       "Enchant Bracers - Greater Spirit",      "+18 Spirit"},
    },
    Hands = {
        {{"threat"},       "Enchant Gloves - Armsman",             "+2% threat, +10 Parry"},
        {{"attack power"}, "Enchant Gloves - Crusher",             "+44 AP"},
        {{"spell power"},  "Enchant Gloves - Exceptional Spellpower","+28 SP"},
        {{"haste"},        "Hyperspeed Accelerators [Eng]",        "+340 Haste on-use"},
    },
    Legs = {
        {{"attack power"},         "Icescale Leg Armor",   "+75 AP, +22 Crit"},
        {{"spell power","spirit"}, "Brilliant Spellthread","+50 SP, +20 Spirit"},
        {{"spell power","stamina"},"Sapphire Spellthread", "+50 SP, +30 Sta"},
        {{"spell power"},          "Master's Spellthread", "+50 SP"},
        {{"stamina"},              "Frosthide Leg Armor",  "+55 Sta, +22 Agi"},
    },
    Feet = {
        {{"hit"},     "Enchant Boots - Icewalker",         "+12 Hit, +12 Crit"},
        {{"speed"},   "Nitro Boosts [Eng]",                "Use: +150% run speed, 5 sec (2 min CD)"},
        {{"stamina"}, "Tuskarr's Vitality / Greater Fort", "+15 Sta+speed / +22 Sta"},
    },
    ["Main Hand"] = {
        {{"spell power"},  "Enchant Weapon - Mighty Spellpower", "+63 SP"},
        {{"attack power"}, "Enchant Weapon - Massacre",          "+110 AP"},
        {{"fallen crusader"},    "Rune of the Fallen Crusader [Runeforge]",    "Proc: heal + speed/Str"},
        {{"razorice"},           "Rune of Razorice [Runeforge]",               "Stacking Frost dmg debuff"},
        {{"cinderglacier"},      "Rune of Cinderglacier [Runeforge]",          "Frost dmg + slow proc"},
        {{"stoneskin gargoyle"}, "Rune of the Stoneskin Gargoyle [Runeforge]", "+ Defense (tank)"},
        {{"spellbreaking"},      "Rune of Spellbreaking [Runeforge]",          "Magic dmg reduction"},
        {{"swordbreaking"},      "Rune of Swordbreaking [Runeforge]",          "Physical dmg reduction"},
        {{"spellshattering"},    "Rune of Spellshattering [Runeforge]",        "Spell dmg reduction (tank)"},
    },
    ["Off Hand"] = {
        {{"intellect"}, "Enchant Shield - Greater Intellect", "+25 Int"},
        {{"stamina"},   "Enchant Shield - Major Stamina",     "+18 Sta"},
        {{"block"},     "Titanium Plating",                   "+81 Block"},
    },
    Ranged = {
        {{"critical"}, "Heartseeker Scope", "+40 Crit"},
        {{"hit"},      "Sun Scope",         "+? Hit"},
    },
}
