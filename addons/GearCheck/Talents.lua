-- GearCheck :: Talents.lua  (auto-generated from the 'Talent Builds' tab)
-- GC.TALENT_BUILD[classToken][spec] = { [talentName]=rank }  — the reference build.
GearCheck = GearCheck or {}
local GC = GearCheck
GC.TALENT_BUILD = {
  ["DEATHKNIGHT"] = {
    ["Blood"] = { ["Blade Barrier"]=5, ["Bladed Armor"]=5, ["Dark Conviction"]=5, ["Bloody Vengeance"]=3, ["Death Rune Mastery"]=3, ["Improved Rune Tap"]=3, ["Spell Deflection"]=3, ["Veteran of the Third War"]=3, ["Will of the Necropolis"]=3, ["Abomination's Might"]=2, ["Improved Death Strike"]=2, ["Two-Handed Weapon Specialization"]=2, ["Hysteria"]=1, ["Rune Tap"]=1, ["Scent of Blood"]=1, ["Vampiric Blood"]=1, ["Icy Talons"]=5, ["Killing Machine"]=5, ["Toughness"]=5, ["Frigid Dreadplate"]=3, ["Improved Icy Touch"]=3, ["Glacier Rot"]=2, ["Icy Reach"]=2, ["Improved Icy Talons"]=1 },
    ["Unholy"] = { ["Desolation"]=5, ["Impurity"]=5, ["Necrosis"]=5, ["Rage of Rivendare"]=5, ["Blood-Caked Blade"]=3, ["Crypt Fever"]=3, ["Ebon Plaguebringer"]=3, ["Outbreak"]=3, ["Ravenous Dead"]=3, ["Virulence"]=3, ["Wandering Plague"]=3, ["Dirge"]=2, ["Epidemic"]=2, ["Night of the Dead"]=2, ["Vicious Strikes"]=2, ["Bone Shield"]=1, ["Master of Ghouls"]=1, ["Scourge Strike"]=1, ["Summon Gargoyle"]=1, ["Unholy Blight"]=1, ["Black Ice"]=5, ["Icy Talons"]=5, ["Improved Icy Touch"]=3, ["Endless Winter"]=2, ["Runic Power Mastery"]=2 },
    ["Frost"] = { ["Icy Talons"]=5, ["Tundra Stalker"]=5, ["Killing Machine"]=4, ["Annihilation"]=3, ["Blood of the North"]=3, ["Glacier Rot"]=3, ["Guile of Gorefiend"]=3, ["Improved Icy Touch"]=3, ["Nerves of Cold Steel"]=3, ["Rime"]=3, ["Threat of Thassarian"]=3, ["Black Ice"]=2, ["Chill of the Grave"]=2, ["Endless Winter"]=2, ["Merciless Combat"]=2, ["Runic Power Mastery"]=2, ["Frost Strike"]=1, ["Howling Blast"]=1, ["Improved Icy Talons"]=1, ["Unbreakable Armor"]=1, ["Necrosis"]=5, ["Blood-Caked Blade"]=3, ["Ravenous Dead"]=3, ["Virulence"]=3, ["Epidemic"]=2, ["Vicious Strikes"]=2 },
  },
  ["PALADIN"] = {
    ["Protection"] = { ["Anticipation"]=5, ["Divine Strength"]=5, ["Toughness"]=5, ["Ardent Defender"]=3, ["Combat Expertise"]=3, ["Improved Devotion Aura"]=3, ["Improved Righteous Fury"]=3, ["One-Handed Weapon Specialization"]=3, ["Redoubt"]=3, ["Shield of the Templar"]=3, ["Touched by the Light"]=3, ["Divine Guardian"]=2, ["Divinity"]=2, ["Guarded by the Light"]=2, ["Improved Hammer of Justice"]=2, ["Judgements of the Just"]=2, ["Sacred Duty"]=2, ["Avenger's Shield"]=1, ["Blessing of Sanctuary"]=1, ["Divine Sacrifice"]=1, ["Hammer of the Righteous"]=1, ["Holy Shield"]=1, ["Reckoning"]=1, ["Spiritual Attunement"]=1, ["Deflection"]=5, ["Heart of the Crusader"]=3, ["Improved Judgements"]=2, ["Vindication"]=2, ["Seal of Command"]=1 },
    ["Holy"] = { ["Divine Intellect"]=5, ["Holy Guidance"]=5, ["Holy Power"]=5, ["Illumination"]=5, ["Judgements of the Pure"]=5, ["Spiritual Focus"]=5, ["Healing Light"]=3, ["Light's Grace"]=3, ["Sanctified Light"]=3, ["Enlightened Judgements"]=2, ["Improved Lay on Hands"]=2, ["Infusion of Light"]=2, ["Aura Mastery"]=1, ["Beacon of Light"]=1, ["Blessed Hands"]=1, ["Divine Favor"]=1, ["Divine Illumination"]=1, ["Holy Shock"]=1, ["Divinity"]=5, ["Toughness"]=4, ["Improved Devotion Aura"]=3, ["Stoicism"]=3, ["Divine Guardian"]=2, ["Guardian's Favor"]=2, ["Divine Sacrifice"]=1 },
  },
  ["WARRIOR"] = {
    ["Fury"] = { ["Cruelty"]=5, ["Dual Wield Specialization"]=5, ["Flurry"]=5, ["Improved Berserker Stance"]=5, ["Unending Fury"]=5, ["Enrage"]=4, ["Armored to the Teeth"]=3, ["Bloodsurge"]=3, ["Improved Cleave"]=3, ["Intensify Rage"]=3, ["Unbridled Wrath"]=3, ["Improved Whirlwind"]=2, ["Precision"]=2, ["Bloodthirst"]=1, ["Death Wish"]=1, ["Piercing Howl"]=1, ["Rampage"]=1, ["Titan's Grip"]=1, ["Deep Wounds"]=3, ["Improved Heroic Strike"]=3, ["Tactical Mastery"]=3, ["Two-Handed Weapon Specialization"]=3, ["Impale"]=2, ["Improved Rend"]=2, ["Iron Will"]=2 },
  },
  ["HUNTER"] = {
    ["Marksmanship"] = { ["Lethal Shots"]=5, ["Marked for Death"]=5, ["Master Marksman"]=5, ["Mortal Shots"]=5, ["Barrage"]=3, ["Careful Aim"]=3, ["Focused Aim"]=3, ["Improved Barrage"]=3, ["Improved Stings"]=3, ["Piercing Shots"]=3, ["Ranged Weapon Specialization"]=3, ["Wild Quiver"]=3, ["Combat Experience"]=2, ["Concussive Barrage"]=2, ["Aimed Shot"]=1, ["Chimera Shot"]=1, ["Go for the Throat"]=1, ["Readiness"]=1, ["Silencing Shot"]=1, ["Trueshot Aura"]=1, ["Improved Tracking"]=5, ["Entrapment"]=3, ["Hawk Eye"]=3, ["Survival Instincts"]=2, ["Survival Tactics"]=2, ["Scatter Shot"]=1, ["Surefooted"]=1 },
  },
  ["DRUID"] = {
    ["Feral (Cat)"] = { ["Feral Aggression"]=5, ["Ferocity"]=5, ["Heart of the Wild"]=5, ["Rend and Tear"]=5, ["Feral Instinct"]=3, ["King of the Jungle"]=3, ["Predatory Instincts"]=3, ["Predatory Strikes"]=3, ["Sharpened Claws"]=3, ["Survival of the Fittest"]=3, ["Feral Swiftness"]=2, ["Improved Mangle"]=2, ["Primal Fury"]=2, ["Primal Precision"]=2, ["Savage Fury"]=2, ["Shredding Attacks"]=2, ["Berserk"]=1, ["Feral Charge"]=1, ["Leader of the Pack"]=1, ["Mangle"]=1, ["Primal Gore"]=1, ["Naturalist"]=5, ["Furor"]=3, ["Natural Shapeshifter"]=3, ["Improved Mark of the Wild"]=2, ["Master Shapeshifter"]=2, ["Omen of Clarity"]=1 },
    ["Restoration"] = { ["Empowered Rejuvenation"]=5, ["Gift of Nature"]=5, ["Gift of the Earthmother"]=5, ["Nature's Bounty"]=5, ["Improved Rejuvenation"]=3, ["Improved Tree of Life"]=3, ["Intensity"]=3, ["Living Seed"]=3, ["Living Spirit"]=3, ["Natural Shapeshifter"]=3, ["Nature's Focus"]=3, ["Revitalize"]=3, ["Empowered Touch"]=2, ["Improved Mark of the Wild"]=2, ["Master Shapeshifter"]=2, ["Natural Perfection"]=2, ["Subtlety"]=2, ["Nature's Swiftness"]=1, ["Omen of Clarity"]=1, ["Swiftmend"]=1, ["Tranquil Spirit"]=1, ["Tree of Life"]=1, ["Wild Growth"]=1, ["Genesis"]=5, ["Moonglow"]=3, ["Nature's Majesty"]=2, ["Nature's Splendor"]=1 },
    ["Balance"] = { ["Starlight Wrath"]=5, ["Vengeance"]=5, ["Wrath of Cenarius"]=5, ["Celestial Focus"]=3, ["Earth and Moon"]=3, ["Eclipse"]=3, ["Genesis"]=3, ["Improved Faerie Fire"]=3, ["Improved Moonkin Form"]=3, ["Lunar Guidance"]=3, ["Moonfury"]=3, ["Nature's Grace"]=3, ["Owlkin Frenzy"]=3, ["Balance of Power"]=2, ["Improved Insect Swarm"]=2, ["Nature's Majesty"]=2, ["Force of Nature"]=1, ["Insect Swarm"]=1, ["Moonkin Form"]=1, ["Nature's Reach"]=1, ["Nature's Splendor"]=1, ["Starfall"]=1, ["Furor"]=5, ["Natural Shapeshifter"]=3, ["Improved Mark of the Wild"]=2, ["Master Shapeshifter"]=2, ["Omen of Clarity"]=1 },
  },
  ["ROGUE"] = {
    ["Combat"] = { ["Aggression"]=5, ["Combat Potency"]=5, ["Dual Wield Specialization"]=5, ["Hack and Slash"]=5, ["Precision"]=5, ["Prey on the Weak"]=5, ["Lightning Reflexes"]=3, ["Vitality"]=3, ["Blade Twisting"]=2, ["Improved Sinister Strike"]=2, ["Improved Slice and Dice"]=2, ["Savage Combat"]=2, ["Weapon Expertise"]=2, ["Adrenaline Rush"]=1, ["Blade Flurry"]=1, ["Endurance"]=1, ["Killing Spree"]=1, ["Surprise Attacks"]=1, ["Lethality"]=5, ["Malice"]=5, ["Improved Poisons"]=4, ["Improved Eviscerate"]=3, ["Ruthlessness"]=2, ["Vile Poisons"]=1 },
  },
  ["SHAMAN"] = {
    ["Restoration"] = { ["Improved Healing Wave"]=5, ["Purification"]=5, ["Tidal Focus"]=5, ["Tidal Mastery"]=5, ["Tidal Waves"]=5, ["Ancestral Awakening"]=3, ["Ancestral Healing"]=3, ["Healing Focus"]=3, ["Healing Way"]=3, ["Improved Water Shield"]=3, ["Nature's Blessing"]=3, ["Restorative Totems"]=3, ["Blessing of the Eternals"]=2, ["Improved Chain Heal"]=2, ["Improved Earth Shield"]=2, ["Cleanse Spirit"]=1, ["Earth Shield"]=1, ["Mana Tide Totem"]=1, ["Nature's Swiftness"]=1, ["Riptide"]=1, ["Tidal Force"]=1, ["Ancestral Knowledge"]=5, ["Thundering Strikes"]=5, ["Improved Shields"]=3 },
  },
  ["PRIEST"] = {
    ["Shadow"] = { ["Darkness"]=5, ["Shadow Power"]=5, ["Twisted Faith"]=5, ["Focused Mind"]=3, ["Improved Devouring Plague"]=3, ["Misery"]=3, ["Pain and Suffering"]=3, ["Shadow Focus"]=3, ["Shadow Weaving"]=3, ["Spirit Tap"]=3, ["Improved Shadow Word: Pain"]=2, ["Improved Shadowform"]=2, ["Improved Spirit Tap"]=2, ["Improved Vampiric Embrace"]=2, ["Mind Melt"]=2, ["Shadow Affinity"]=2, ["Shadow Reach"]=2, ["Veiled Shadows"]=2, ["Dispersion"]=1, ["Mind Flay"]=1, ["Shadowform"]=1, ["Vampiric Embrace"]=1, ["Vampiric Touch"]=1, ["Twin Disciplines"]=5, ["Improved Inner Fire"]=3, ["Meditation"]=3, ["Improved Power Word: Fortitude"]=2, ["Inner Focus"]=1 },
  },
  ["WARLOCK"] = {
    ["Demonology"] = { ["Demonic Pact"]=5, ["Demonic Tactics"]=5, ["Master Demonologist"]=5, ["Unholy Power"]=5, ["Demonic Aegis"]=3, ["Demonic Brutality"]=3, ["Demonic Embrace"]=3, ["Demonic Knowledge"]=3, ["Fel Vitality"]=3, ["Molten Core"]=3, ["Nemesis"]=3, ["Decimation"]=2, ["Fel Synergy"]=2, ["Master Conjuror"]=2, ["Demonic Empowerment"]=1, ["Fel Domination"]=1, ["Mana Feed"]=1, ["Master Summoner"]=1, ["Metamorphosis"]=1, ["Soul Link"]=1, ["Summon Felguard"]=1, ["Bane"]=5, ["Improved Shadow Bolt"]=5, ["Ruin"]=5, ["Intensity"]=2 },
  },
}
GC.TREE_SPEC = {
  ["DEATHKNIGHT"] = { "Blood", "Frost", "Unholy" },
  ["PALADIN"] = { "Holy", "Protection", "Retribution" },
  ["WARRIOR"] = { "Fury", "Fury", "Protection" },
  ["DRUID"] = { "Balance", "Feral (Cat)", "Restoration" },
  ["HUNTER"] = { "Marksmanship", "Marksmanship", "Marksmanship" },
  ["MAGE"] = { "Arcane", "Frost", "Frost" },
  ["PRIEST"] = { "Discipline", "Discipline", "Shadow" },
  ["ROGUE"] = { "Assassination", "Combat", "Combat" },
  ["SHAMAN"] = { "Elemental", "Enhancement", "Restoration" },
  ["WARLOCK"] = { "Affliction", "Demonology", "Demonology" },
}
