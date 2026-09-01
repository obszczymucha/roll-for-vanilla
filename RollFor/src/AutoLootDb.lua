RollFor = RollFor or {}
local m = RollFor

if m.AutoLootDb then return end

local M = {}

-- Item ids sourced from AtlasLootClassic_DungeonsAndRaids (data-tbc.lua). AtlasLoot itself
-- doesn't hardcode name/link/icon either -- it resolves those live via GetItemInfo, which the
-- WoW client caches locally after the first server fetch. We do the same here instead of baking
-- in name/link/icon strings that could go stale or be wrong.
local ids = {
  [ "Serpentshrine Cavern" ] = {
    order = 4,
    bosses = {
      [ "Hydross the Unstable" ] = {
        order = 1,
        items = {
          [ 30056 ] = { quality = 4, icon = 132684, name = "Robe of Hateful Echoes" },
          [ 30664 ] = { quality = 4, icon = 134218, name = "Living Root of the Wildheart" },
          [ 30053 ] = { quality = 4, icon = 135051, name = "Pauldrons of the Wardancer" },
          [ 32516 ] = { quality = 4, icon = 132612, name = "Wraps of Purification" },
          [ 30050 ] = { quality = 4, icon = 132539, name = "Boots of the Shifting Nightmare" },
          [ 33055 ] = { quality = 4, icon = 133413, name = "Band of Vile Aggression" },
          [ 30049 ] = { quality = 4, icon = 134079, name = "Fathomstone" },
          [ 30047 ] = { quality = 4, icon = 132601, name = "Blackfathom Warbands" },
          [ 30051 ] = { quality = 4, icon = 134903, name = "Idol of the Crescent Goddess" },
          [ 30055 ] = { quality = 4, icon = 135054, name = "Shoulderpads of the Stranger" },
          [ 30629 ] = { quality = 4, icon = 135443, name = "Scarab of Displacement" },
          [ 30048 ] = { quality = 4, icon = 133124, name = "Brighthelm of Justice" },
          [ 30052 ] = { quality = 4, icon = 133393, name = "Ring of Lethality" },
          [ 30054 ] = { quality = 4, icon = 132744, name = "Ranger-General's Chestguard" }
        }
      },
      [ "The Lurker Below" ] = {
        order = 2,
        items = {
          [ 30064 ] = { quality = 4, icon = 132492, name = "Cord of Screaming Terrors" },
          [ 30067 ] = { quality = 4, icon = 132539, name = "Velvet Boots of the Guardian" },
          [ 30062 ] = { quality = 4, icon = 132601, name = "Grove-Bands of Remulos" },
          [ 30060 ] = { quality = 4, icon = 132587, name = "Boots of Effortless Striking" },
          [ 30066 ] = { quality = 4, icon = 132548, name = "Tempest-Strider Boots" },
          [ 30065 ] = { quality = 4, icon = 132740, name = "Glowing Breastplate of Truth" },
          [ 30057 ] = { quality = 4, icon = 132618, name = "Bracers of Eradication" },
          [ 30059 ] = { quality = 4, icon = 133341, name = "Choker of Animalistic Fury" },
          [ 30061 ] = { quality = 4, icon = 133383, name = "Ancestral Ring of Conquest" },
          [ 33054 ] = { quality = 4, icon = 133381, name = "The Seal of Danzalar" },
          [ 30665 ] = { quality = 4, icon = 133349, name = "Earring of Soulful Meditation" },
          [ 30063 ] = { quality = 4, icon = 134917, name = "Libram of Absolute Truth" },
          [ 30058 ] = { quality = 4, icon = 135677, name = "Mallet of the Tides" },
        }
      },
      [ "Leotheras the Blind" ] = {
        order = 3,
        items = {
          [ 30092 ] = { quality = 4, icon = 132573, name = "Orca-Hide Boots" },
          [ 30097 ] = { quality = 4, icon = 135050, name = "Coral-Barbed Shoulderpads" },
          [ 30091 ] = { quality = 4, icon = 132614, name = "True-Aim Stalker Bands" },
          [ 30096 ] = { quality = 4, icon = 132516, name = "Girdle of the Invulnerable" },
          [ 30627 ] = { quality = 4, icon = 136111, name = "Tsunami Talisman" },
          [ 30095 ] = { quality = 4, icon = 135383, name = "Fang of the Leviathan" },
          [ 30239 ] = { quality = 4, icon = 132961, name = "Gloves of the Vanquished Champion" },
          [ 30240 ] = { quality = 4, icon = 132961, name = "Gloves of the Vanquished Defender" },
          [ 30241 ] = { quality = 4, icon = 132961, name = "Gloves of the Vanquished Hero" },
        }
      },
      [ "Fathom-Lord Karathress" ] = {
        order = 4,
        items = {
          [ 30100 ] = { quality = 4, icon = 132579, name = "Soul-Strider Boots" },
          [ 30101 ] = { quality = 4, icon = 132743, name = "Bloodsea Brigand's Vest" },
          [ 30099 ] = { quality = 4, icon = 134326, name = "Frayed Tether of the Drowned" },
          [ 30663 ] = { quality = 4, icon = 134398, name = "Fathom-Brooch of the Tidewalker" },
          [ 30626 ] = { quality = 4, icon = 133003, name = "Sextant of Unstable Currents" },
          [ 30090 ] = { quality = 4, icon = 133532, name = "World Breaker" },
          [ 30245 ] = { quality = 4, icon = 134693, name = "Leggings of the Vanquished Champion" },
          [ 30246 ] = { quality = 4, icon = 134693, name = "Leggings of the Vanquished Defender" },
          [ 30247 ] = { quality = 4, icon = 134693, name = "Leggings of the Vanquished Hero" },
        }
      },
      [ "Morogrim Tidewalker" ] = {
        order = 5,
        items = {
          [ 30098 ] = { quality = 4, icon = 133772, name = "Razor-Scale Battlecloak" },
          [ 30079 ] = { quality = 4, icon = 135056, name = "Illidari Shoulderpads" },
          [ 30075 ] = { quality = 4, icon = 132725, name = "Gnarled Chestpiece of the Ancients" },
          [ 30085 ] = { quality = 4, icon = 135058, name = "Mantle of the Tireless Tracker" },
          [ 30068 ] = { quality = 4, icon = 132508, name = "Girdle of the Tidal Call" },
          [ 30084 ] = { quality = 4, icon = 135045, name = "Pauldrons of the Argent Sentinel" },
          [ 30081 ] = { quality = 4, icon = 132585, name = "Warboots of Obliteration" },
          [ 30008 ] = { quality = 4, icon = 133299, name = "Pendant of the Lost Ages" },
          [ 30083 ] = { quality = 4, icon = 133373, name = "Ring of Sundered Souls" },
          [ 33058 ] = { quality = 4, icon = 133385, name = "Band of the Vigilant" },
          [ 30720 ] = { quality = 4, icon = 136070, name = "Serpent-Coil Braid" },
          [ 30082 ] = { quality = 4, icon = 135360, name = "Talon of Azshara" },
          [ 30080 ] = { quality = 4, icon = 135476, name = "Luminescent Rod of the Naaru" },
        }
      },
      [ "Lady Vashj" ] = {
        order = 6,
        items = {
          [ 30107 ] = { quality = 4, icon = 132658, name = "Vestments of the Sea-Witch" },
          [ 30111 ] = { quality = 4, icon = 135038, name = "Runetotem's Mantle" },
          [ 30106 ] = { quality = 4, icon = 132515, name = "Belt of One-Hundred Deaths" },
          [ 30104 ] = { quality = 4, icon = 132555, name = "Cobra-Lash Boots" },
          [ 30102 ] = { quality = 4, icon = 132746, name = "Krakken-Heart Breastplate" },
          [ 30112 ] = { quality = 4, icon = 132954, name = "Glorious Gauntlets of Crestfall" },
          [ 30109 ] = { quality = 4, icon = 133386, name = "Ring of Endless Coils" },
          [ 30110 ] = { quality = 4, icon = 133377, name = "Coral Band of the Revived" },
          [ 30621 ] = { quality = 4, icon = 134100, name = "Prism of Inner Calm" },
          [ 30103 ] = { quality = 4, icon = 135674, name = "Fang of Vashj" },
          [ 30108 ] = { quality = 4, icon = 135678, name = "Lightfathom Scepter" },
          [ 30105 ] = { quality = 4, icon = 135496, name = "Serpent Spine Longbow" },
          [ 30242 ] = { quality = 4, icon = 133126, name = "Helm of the Vanquished Champion" },
          [ 30243 ] = { quality = 4, icon = 133126, name = "Helm of the Vanquished Defender" },
          [ 30244 ] = { quality = 4, icon = 133126, name = "Helm of the Vanquished Hero" },
        }
      },
      [ "Trash" ] = {
        order = 7,
        items = {
          [ 30027 ] = { quality = 4, icon = 132551, name = "Boots of Courage Unending" },
          [ 30022 ] = { quality = 4, icon = 133339, name = "Pendant of the Perilous" },
          [ 30620 ] = { quality = 4, icon = 134441, name = "Spyglass of the Hidden Fleet" },
          [ 30023 ] = { quality = 4, icon = 136022, name = "Totem of the Maelstrom" },
          [ 30021 ] = { quality = 4, icon = 135186, name = "Wildfury Greatstaff" },
          [ 30025 ] = { quality = 4, icon = 135430, name = "Serpentshrine Shuriken" },
          [ 30324 ] = { quality = 4, icon = 134940, name = "Plans: Red Havoc Boots" },
          [ 30322 ] = { quality = 4, icon = 134940, name = "Plans: Red Belt of Battle" },
          [ 30323 ] = { quality = 4, icon = 134940, name = "Plans: Boots of the Protector" },
          [ 30321 ] = { quality = 4, icon = 134940, name = "Plans: Belt of the Guardian" },
          [ 30280 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of Blasting" },
          [ 30282 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of Blasting" },
          [ 30283 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of the Long Road" },
          [ 30281 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of the Long Road" },
          [ 30308 ] = { quality = 4, icon = 134940, name = "Pattern: Hurricane Boots" },
          [ 30304 ] = { quality = 4, icon = 134940, name = "Pattern: Monsoon Belt" },
          [ 30305 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of Natural Grace" },
          [ 30307 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of the Crimson Hawk" },
          [ 30306 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of Utter Darkness" },
          [ 30301 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of Natural Power" },
          [ 30303 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of the Black Eagle" },
          [ 30302 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of Deep Shadow" },
          [ 32897 ] = { quality = 2, icon = 136172, name = "Mark of the Illidari" },
        }
      }
    }
  },
  [ "Karazhan" ] = {
    order = 1,
    bosses = {
      [ "Rokad the Ravager" ] = {
        order = 1,
        items = {
          [ 30684 ] = { quality = 4, icon = 132609, name = "Ravager's Cuffs" },
          [ 30685 ] = { quality = 4, icon = 132606, name = "Ravager's Wrist-Wraps" },
          [ 30686 ] = { quality = 4, icon = 132601, name = "Ravager's Bands" },
          [ 30687 ] = { quality = 4, icon = 132606, name = "Ravager's Bracers" },
        }
      },
      [ "Shadikith the Glider" ] = {
        order = 2,
        items = {
          [ 30680 ] = { quality = 4, icon = 132539, name = "Glider's Foot-Wraps" },
          [ 30681 ] = { quality = 4, icon = 132539, name = "Glider's Boots" },
          [ 30682 ] = { quality = 4, icon = 132548, name = "Glider's Sabatons" },
          [ 30683 ] = { quality = 4, icon = 132585, name = "Glider's Greaves" },
        }
      },
      [ "Hyakiss the Lurker" ] = {
        order = 3,
        items = {
          [ 30675 ] = { quality = 4, icon = 132492, name = "Lurker's Cord" },
          [ 30676 ] = { quality = 4, icon = 132514, name = "Lurker's Grasp" },
          [ 30677 ] = { quality = 4, icon = 132492, name = "Lurker's Belt" },
          [ 30678 ] = { quality = 4, icon = 132511, name = "Lurker's Girdle" },
        }
      },
      [ "Attumen the Huntsman" ] = {
        order = 4,
        items = {
          [ 28477 ] = { quality = 4, icon = 132612, name = "Harbinger Bands" },
          [ 28507 ] = { quality = 4, icon = 132951, name = "Handwraps of Flowing Thought" },
          [ 28508 ] = { quality = 4, icon = 132951, name = "Gloves of Saintly Blessings" },
          [ 28453 ] = { quality = 4, icon = 132601, name = "Bracers of the White Stag" },
          [ 28506 ] = { quality = 4, icon = 132962, name = "Gloves of Dexterous Manipulation" },
          [ 28503 ] = { quality = 4, icon = 132601, name = "Whirlwind Bracers" },
          [ 28454 ] = { quality = 4, icon = 132601, name = "Stalker's War Bands" },
          [ 28502 ] = { quality = 4, icon = 132618, name = "Vambraces of Courage" },
          [ 28505 ] = { quality = 4, icon = 132959, name = "Gauntlets of Renewed Hope" },
          [ 28509 ] = { quality = 4, icon = 133309, name = "Worgen Claw Necklace" },
          [ 28510 ] = { quality = 4, icon = 133373, name = "Spectral Band of Innervation" },
          [ 28504 ] = { quality = 4, icon = 135547, name = "Steelhawk Crossbow" },
          [ 30480 ] = { quality = 4, icon = 132238, name = "Fiery Warhorse's Reins" },
          [ 23809 ] = { quality = 3, icon = 134941, name = "Schematic: Stabilized Eternium Scope" },
        }
      },
      [ "Moroes" ] = {
        order = 5,
        items = {
          [ 28529 ] = { quality = 4, icon = 133762, name = "Royal Cloak of Arathi Kings" },
          [ 28570 ] = { quality = 4, icon = 133772, name = "Shadow-Cloak of Dalaran" },
          [ 28565 ] = { quality = 4, icon = 132497, name = "Nethershard Girdle" },
          [ 28545 ] = { quality = 4, icon = 132587, name = "Edgewalker Longboots" },
          [ 28567 ] = { quality = 4, icon = 132511, name = "Belt of Gale Force" },
          [ 28566 ] = { quality = 4, icon = 132516, name = "Crimson Girdle of the Indomitable" },
          [ 28569 ] = { quality = 4, icon = 132548, name = "Boots of Valiance" },
          [ 28530 ] = { quality = 4, icon = 133342, name = "Brooch of Unquenchable Fury" },
          [ 28528 ] = { quality = 4, icon = 134377, name = "Moroes' Lucky Pocket Watch" },
          [ 28525 ] = { quality = 4, icon = 133402, name = "Signet of Unshakable Faith" },
          [ 28568 ] = { quality = 4, icon = 134478, name = "Idol of the Avian Heart" },
          [ 28524 ] = { quality = 4, icon = 135673, name = "Emerald Ripper" },
          [ 22559 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Weapon - Mongoose" },
        }
      },
      [ "Maiden of Virtue" ] = {
        order = 6,
        items = {
          [ 28511 ] = { quality = 4, icon = 132612, name = "Bands of Indwelling" },
          [ 28515 ] = { quality = 4, icon = 132612, name = "Bands of Nefarious Deeds" },
          [ 28517 ] = { quality = 4, icon = 132562, name = "Boots of Foretelling" },
          [ 28514 ] = { quality = 4, icon = 132614, name = "Bracers of Maliciousness" },
          [ 28521 ] = { quality = 4, icon = 132959, name = "Mitts of the Treemender" },
          [ 28520 ] = { quality = 4, icon = 132959, name = "Gloves of Centering" },
          [ 28519 ] = { quality = 4, icon = 132959, name = "Gloves of Quickening" },
          [ 28512 ] = { quality = 4, icon = 132601, name = "Bracers of Justice" },
          [ 28518 ] = { quality = 4, icon = 132965, name = "Iron Gauntlets of the Maiden" },
          [ 28516 ] = { quality = 4, icon = 133340, name = "Barbed Choker of Discipline" },
          [ 28523 ] = { quality = 4, icon = 136037, name = "Totem of Healing Rains" },
          [ 28522 ] = { quality = 4, icon = 133063, name = "Shard of the Virtuous" },
        }
      },
      [ "The Wizard of Oz" ] = {
        order = 7,
        items = {
          [ 28586 ] = { quality = 4, icon = 133132, name = "Wicked Witch's Hat" },
          [ 28585 ] = { quality = 4, icon = 132566, name = "Ruby Slippers" },
          [ 28587 ] = { quality = 4, icon = 132436, name = "Legacy" },
          [ 28588 ] = { quality = 4, icon = 135477, name = "Blue Diamond Witchwand" },
          [ 28594 ] = { quality = 4, icon = 134599, name = "Trial-Fire Trousers" },
          [ 28591 ] = { quality = 4, icon = 134667, name = "Earthsoul Leggings" },
          [ 28589 ] = { quality = 4, icon = 135067, name = "Beastmaw Pauldrons" },
          [ 28593 ] = { quality = 4, icon = 133071, name = "Eternium Greathelm" },
          [ 28590 ] = { quality = 4, icon = 133686, name = "Ribbon of Sacrifice" },
          [ 28592 ] = { quality = 4, icon = 134915, name = "Libram of Souls Redeemed" },
        }
      },
      [ "The Big Bad Wolf" ] = {
        order = 7,
        items = {
          [ 28582 ] = { quality = 4, icon = 133770, name = "Red Riding Hood's Cloak" },
          [ 28583 ] = { quality = 4, icon = 133072, name = "Big Bad Wolf's Head" },
          [ 28584 ] = { quality = 4, icon = 134297, name = "Big Bad Wolf's Paw" },
          [ 28581 ] = { quality = 4, icon = 135631, name = "Wolfslayer Sniper Rifle" },
          [ 28594 ] = { quality = 4, icon = 134599, name = "Trial-Fire Trousers" },
          [ 28591 ] = { quality = 4, icon = 134667, name = "Earthsoul Leggings" },
          [ 28589 ] = { quality = 4, icon = 135067, name = "Beastmaw Pauldrons" },
          [ 28593 ] = { quality = 4, icon = 133071, name = "Eternium Greathelm" },
          [ 28590 ] = { quality = 4, icon = 133686, name = "Ribbon of Sacrifice" },
          [ 28592 ] = { quality = 4, icon = 134915, name = "Libram of Souls Redeemed" },
        }
      },
      [ "Romulo and Julianne" ] = {
        order = 7,
        items = {
          [ 28578 ] = { quality = 4, icon = 132684, name = "Masquerade Gown" },
          [ 28579 ] = { quality = 4, icon = 134711, name = "Romulo's Poison Vial" },
          [ 28572 ] = { quality = 4, icon = 135674, name = "Blade of the Unrequited" },
          [ 28573 ] = { quality = 4, icon = 135379, name = "Despair" },
          [ 28594 ] = { quality = 4, icon = 134599, name = "Trial-Fire Trousers" },
          [ 28591 ] = { quality = 4, icon = 134667, name = "Earthsoul Leggings" },
          [ 28589 ] = { quality = 4, icon = 135067, name = "Beastmaw Pauldrons" },
          [ 28593 ] = { quality = 4, icon = 133071, name = "Eternium Greathelm" },
          [ 28590 ] = { quality = 4, icon = 133686, name = "Ribbon of Sacrifice" },
          [ 28592 ] = { quality = 4, icon = 134915, name = "Libram of Souls Redeemed" },
        }
      },
      [ "The Curator" ] = {
        order = 8,
        items = {
          [ 28612 ] = { quality = 4, icon = 135056, name = "Pauldrons of the Solace-Giver" },
          [ 28647 ] = { quality = 4, icon = 135032, name = "Forest Wind Shoulderpads" },
          [ 28631 ] = { quality = 4, icon = 135045, name = "Dragon-Quake Shoulderguards" },
          [ 28621 ] = { quality = 4, icon = 134681, name = "Wrynn Dynasty Greaves" },
          [ 28649 ] = { quality = 4, icon = 133389, name = "Garona's Signet Ring" },
          [ 28633 ] = { quality = 4, icon = 135567, name = "Staff of Infinite Mysteries" },
          [ 29757 ] = { quality = 4, icon = 132961, name = "Gloves of the Fallen Champion" },
          [ 29758 ] = { quality = 4, icon = 132961, name = "Gloves of the Fallen Defender" },
          [ 29756 ] = { quality = 4, icon = 132961, name = "Gloves of the Fallen Hero" },
        }
      },
      [ "Terestian Illhoof" ] = {
        order = 9,
        items = {
          [ 28660 ] = { quality = 4, icon = 133772, name = "Gilded Thorium Cloak" },
          [ 28653 ] = { quality = 4, icon = 133757, name = "Shadowvine Cloak of Infusion" },
          [ 28652 ] = { quality = 4, icon = 132497, name = "Cincture of Will" },
          [ 28654 ] = { quality = 4, icon = 132492, name = "Malefic Girdle" },
          [ 28655 ] = { quality = 4, icon = 132511, name = "Cord of Nature's Sustenance" },
          [ 28656 ] = { quality = 4, icon = 132511, name = "Girdle of the Prowler" },
          [ 28662 ] = { quality = 4, icon = 132738, name = "Breastplate of the Lightbinder" },
          [ 28661 ] = { quality = 4, icon = 133378, name = "Mender's Heart-Ring" },
          [ 28785 ] = { quality = 4, icon = 135444, name = "The Lightning Capacitor" },
          [ 28657 ] = { quality = 4, icon = 135679, name = "Fool's Bane" },
          [ 28658 ] = { quality = 4, icon = 135191, name = "Terestian's Stranglestaff" },
          [ 28659 ] = { quality = 4, icon = 135671, name = "Xavian Stiletto" },
          [ 22561 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Weapon - Soulfrost" },
        }
      },
      [ "Shade of Aran" ] = {
        order = 10,
        items = {
          [ 28672 ] = { quality = 4, icon = 133762, name = "Drape of the Dark Reavers" },
          [ 28726 ] = { quality = 4, icon = 135056, name = "Mantle of the Mind Flayer" },
          [ 28670 ] = { quality = 4, icon = 132539, name = "Boots of the Infernal Coven" },
          [ 28663 ] = { quality = 4, icon = 132579, name = "Boots of the Incorrupt" },
          [ 28669 ] = { quality = 4, icon = 132587, name = "Rapscallion Boots" },
          [ 28671 ] = { quality = 4, icon = 133073, name = "Steelspine Faceguard" },
          [ 28666 ] = { quality = 4, icon = 135066, name = "Pauldrons of the Justice-Seeker" },
          [ 23933 ] = { quality = 1, icon = 133738, name = "Medivh's Journal" },
          [ 28674 ] = { quality = 4, icon = 133325, name = "Saberclaw Talisman" },
          [ 28675 ] = { quality = 4, icon = 133361, name = "Shermanar Great-Ring" },
          [ 28727 ] = { quality = 4, icon = 135440, name = "Pendant of the Violet Eye" },
          [ 28728 ] = { quality = 4, icon = 134132, name = "Aran's Soothing Sapphire" },
          [ 28673 ] = { quality = 4, icon = 135484, name = "Tirisfal Wand of Ascendancy" },
          [ 22560 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Weapon - Sunfire" },
        }
      },
      [ "Netherspite" ] = {
        order = 11,
        items = {
          [ 28744 ] = { quality = 4, icon = 133155, name = "Uni-Mind Headdress" },
          [ 28742 ] = { quality = 4, icon = 134607, name = "Pantaloons of Repentance" },
          [ 28732 ] = { quality = 4, icon = 133160, name = "Cowl of Defiance" },
          [ 28741 ] = { quality = 4, icon = 134638, name = "Skulker's Greaves" },
          [ 28735 ] = { quality = 4, icon = 132743, name = "Earthblood Chestguard" },
          [ 28740 ] = { quality = 4, icon = 134678, name = "Rip-Flayer Leggings" },
          [ 28743 ] = { quality = 4, icon = 135060, name = "Mantle of Abrahmis" },
          [ 28733 ] = { quality = 4, icon = 132511, name = "Girdle of Truth" },
          [ 28731 ] = { quality = 4, icon = 133323, name = "Shining Chain of the Afterworld" },
          [ 28730 ] = { quality = 4, icon = 133366, name = "Mithril Band of the Unscarred" },
          [ 28734 ] = { quality = 4, icon = 134102, name = "Jewel of Infinite Possibilities" },
          [ 28729 ] = { quality = 4, icon = 135384, name = "Spiteblade" },
        }
      },
      [ "Chess Event" ] = {
        order = 12,
        items = {
          [ 28756 ] = { quality = 4, icon = 132767, name = "Headdress of the High Potentate" },
          [ 28755 ] = { quality = 4, icon = 135060, name = "Bladed Shoulderpads of the Merciless" },
          [ 28750 ] = { quality = 4, icon = 132515, name = "Girdle of Treachery" },
          [ 28752 ] = { quality = 4, icon = 132548, name = "Forestlord Striders" },
          [ 28751 ] = { quality = 4, icon = 134667, name = "Heart-Flame Leggings" },
          [ 28746 ] = { quality = 4, icon = 132548, name = "Fiend Slayer Boots" },
          [ 28748 ] = { quality = 4, icon = 134694, name = "Legplates of the Innocent" },
          [ 28747 ] = { quality = 4, icon = 132587, name = "Battlescar Boots" },
          [ 28745 ] = { quality = 4, icon = 133293, name = "Mithril Chain of Heroism" },
          [ 28753 ] = { quality = 4, icon = 133357, name = "Ring of Recurrence" },
          [ 28749 ] = { quality = 4, icon = 135384, name = "King's Defender" },
          [ 28754 ] = { quality = 4, icon = 134976, name = "Triptych Shield of the Ancients" },
        }
      },
      [ "Prince Malchezaar" ] = {
        order = 13,
        items = {
          [ 28765 ] = { quality = 4, icon = 133758, name = "Stainless Cloak of the Pure Hearted" },
          [ 28766 ] = { quality = 4, icon = 133770, name = "Ruby Drape of the Mysticant" },
          [ 28764 ] = { quality = 4, icon = 133769, name = "Farstrider Wildercloak" },
          [ 28762 ] = { quality = 4, icon = 133319, name = "Adornment of Stolen Souls" },
          [ 28763 ] = { quality = 4, icon = 133350, name = "Jade Ring of the Everliving" },
          [ 28757 ] = { quality = 4, icon = 133427, name = "Ring of a Thousand Marks" },
          [ 28770 ] = { quality = 4, icon = 135676, name = "Nathrezim Mindblade" },
          [ 28768 ] = { quality = 4, icon = 135675, name = "Malchazeen" },
          [ 28767 ] = { quality = 4, icon = 132453, name = "The Decapitator" },
          [ 28773 ] = { quality = 4, icon = 132447, name = "Gorehowl" },
          [ 28771 ] = { quality = 4, icon = 133526, name = "Light's Justice" },
          [ 28772 ] = { quality = 4, icon = 135506, name = "Sunfury Bow of the Phoenix" },
          [ 29760 ] = { quality = 4, icon = 133126, name = "Helm of the Fallen Champion" },
          [ 29761 ] = { quality = 4, icon = 133126, name = "Helm of the Fallen Defender" },
          [ 29759 ] = { quality = 4, icon = 133126, name = "Helm of the Fallen Hero" },
        }
      },
      [ "Nightbane" ] = {
        order = 14,
        items = {
          [ 28602 ] = { quality = 4, icon = 132653, name = "Robe of the Elder Scribes" },
          [ 28600 ] = { quality = 4, icon = 132722, name = "Stonebough Jerkin" },
          [ 28601 ] = { quality = 4, icon = 132721, name = "Chestguard of the Conniver" },
          [ 28599 ] = { quality = 4, icon = 132629, name = "Scaled Breastplate of Carnage" },
          [ 28610 ] = { quality = 4, icon = 132547, name = "Ferocious Swift-Kickers" },
          [ 28597 ] = { quality = 4, icon = 132737, name = "Panzar'Thar Breastplate" },
          [ 28608 ] = { quality = 4, icon = 132585, name = "Ironstriders of Urgency" },
          [ 31751 ] = { quality = 1, icon = 135789, name = "Blazing Signet" },
          [ 24139 ] = { quality = 1, icon = 132867, name = "Faint Arcane Essence" },
          [ 28609 ] = { quality = 4, icon = 133304, name = "Emberspur Talisman" },
          [ 28603 ] = { quality = 4, icon = 134549, name = "Talisman of Nightbane" },
          [ 28604 ] = { quality = 4, icon = 135193, name = "Nightstaff of the Everliving" },
          [ 28611 ] = { quality = 4, icon = 134982, name = "Dragonheart Flameshield" },
          [ 28606 ] = { quality = 4, icon = 134974, name = "Shield of Impenetrable Darkness" },
        }
      },
      [ "Trash" ] = {
        order = 15,
        items = {
          [ 30642 ] = { quality = 4, icon = 133770, name = "Drape of the Righteous" },
          [ 30668 ] = { quality = 4, icon = 132951, name = "Grasp of the Dead" },
          [ 30673 ] = { quality = 4, icon = 132492, name = "Inferno Waist Cord" },
          [ 30644 ] = { quality = 4, icon = 132962, name = "Grips of Deftness" },
          [ 30674 ] = { quality = 4, icon = 132587, name = "Zierhut's Lost Treads" },
          [ 30643 ] = { quality = 4, icon = 132511, name = "Belt of the Tracker" },
          [ 30641 ] = { quality = 4, icon = 132585, name = "Boots of Elusion" },
          [ 23857 ] = { quality = 1, icon = 133739, name = "Legacy of the Mountain King" },
          [ 23864 ] = { quality = 1, icon = 133739, name = "Torment of the Worgen" },
          [ 23862 ] = { quality = 1, icon = 133739, name = "Redemption of the Fallen" },
          [ 23865 ] = { quality = 1, icon = 133739, name = "Wrath of the Titans" },
          [ 21882 ] = { quality = 1, icon = 136214, name = "Soul Essence" },
          [ 30666 ] = { quality = 4, icon = 133321, name = "Ritssyn's Lost Pendant" },
          [ 30667 ] = { quality = 4, icon = 133393, name = "Ring of Unrelenting Storms" },
          [ 21903 ] = { quality = 4, icon = 134940, name = "Pattern: Soulcloth Shoulders" },
          [ 21904 ] = { quality = 4, icon = 134940, name = "Pattern: Soulcloth Vest" },
          [ 22545 ] = { quality = 2, icon = 134327, name = "Formula: Enchant Boots - Surefooted" },
        }
      },
    }
  },
  [ "Gruul's Lair" ] = {
    order = 2,
    bosses = {
      [ "High King Maulgar" ] = {
        order = 1,
        items = {
          [ 28797 ] = { quality = 4, icon = 133768, name = "Brute Cloak of the Ogre-Magi" },
          [ 28799 ] = { quality = 4, icon = 132492, name = "Belt of Divine Inspiration" },
          [ 28796 ] = { quality = 4, icon = 133160, name = "Malefic Mask of the Shadows" },
          [ 28801 ] = { quality = 4, icon = 133125, name = "Maulgar's Warhelm" },
          [ 28795 ] = { quality = 4, icon = 132614, name = "Bladespire Warbands" },
          [ 28800 ] = { quality = 4, icon = 133065, name = "Hammer of the Naaru" },
          [ 29763 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Fallen Champion" },
          [ 29764 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Fallen Defender" },
          [ 29762 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Fallen Hero" },
        }
      },
      [ "Gruul the Dragonkiller" ] = {
        order = 2,
        items = {
          [ 28804 ] = { quality = 4, icon = 133129, name = "Collar of Cho'gall" },
          [ 28803 ] = { quality = 4, icon = 133117, name = "Cowl of Nature's Breath" },
          [ 28828 ] = { quality = 4, icon = 132515, name = "Gronn-Stitched Girdle" },
          [ 28827 ] = { quality = 4, icon = 132959, name = "Gauntlets of the Dragonslayer" },
          [ 28810 ] = { quality = 4, icon = 132548, name = "Windshear Boots" },
          [ 28824 ] = { quality = 4, icon = 132965, name = "Gauntlets of Martial Perfection" },
          [ 28822 ] = { quality = 4, icon = 133726, name = "Teeth of Gruul" },
          [ 28823 ] = { quality = 4, icon = 136224, name = "Eye of Gruul" },
          [ 28830 ] = { quality = 4, icon = 133720, name = "Dragonspine Trophy" },
          [ 31750 ] = { quality = 1, icon = 134577, name = "Earthen Signet" },
          [ 29766 ] = { quality = 4, icon = 134693, name = "Leggings of the Fallen Champion" },
          [ 29767 ] = { quality = 4, icon = 134693, name = "Leggings of the Fallen Defender" },
          [ 29765 ] = { quality = 4, icon = 134693, name = "Leggings of the Fallen Hero" },
          [ 28802 ] = { quality = 4, icon = 135375, name = "Bloodmaw Magus-Blade" },
          [ 28794 ] = { quality = 4, icon = 132451, name = "Axe of the Gronn Lords" },
          [ 28825 ] = { quality = 4, icon = 134975, name = "Aldori Legacy Defender" },
          [ 28826 ] = { quality = 4, icon = 133572, name = "Shuriken of Negation" },
        }
      },
    }
  },
  [ "Magtheridon's Lair" ] = {
    order = 3,
    bosses = {
      [ "Magtheridon" ] = {
        order = 1,
        items = {
          [ 28777 ] = { quality = 4, icon = 133766, name = "Cloak of the Pit Stalker" },
          [ 28780 ] = { quality = 4, icon = 132949, name = "Soul-Eater's Handwraps" },
          [ 28776 ] = { quality = 4, icon = 132953, name = "Liar's Tongue Gloves" },
          [ 28778 ] = { quality = 4, icon = 132509, name = "Terror Pit Girdle" },
          [ 28775 ] = { quality = 4, icon = 133160, name = "Thundering Greathelm" },
          [ 28779 ] = { quality = 4, icon = 132511, name = "Girdle of the Endless Pit" },
          [ 28789 ] = { quality = 4, icon = 132840, name = "Eye of Magtheridon" },
          [ 28781 ] = { quality = 4, icon = 134542, name = "Karaborian Talisman" },
          [ 28774 ] = { quality = 4, icon = 135566, name = "Glaive of the Pit" },
          [ 28782 ] = { quality = 4, icon = 135189, name = "Crystalheart Pulse-Staff" },
          [ 29458 ] = { quality = 4, icon = 134978, name = "Aegis of the Vindicator" },
          [ 28783 ] = { quality = 4, icon = 135483, name = "Eredar Wand of Obliteration" },
          [ 29754 ] = { quality = 4, icon = 132625, name = "Chestguard of the Fallen Champion" },
          [ 29753 ] = { quality = 4, icon = 132625, name = "Chestguard of the Fallen Defender" },
          [ 29755 ] = { quality = 4, icon = 132625, name = "Chestguard of the Fallen Hero" },
          [ 32385 ] = { quality = 4, icon = 134174, name = "Magtheridon's Head" },
          [ 34845 ] = { quality = 4, icon = 133666, name = "Pit Lord's Satchel" },
          [ 34846 ] = { quality = 2, icon = 133640, name = "Black Sack of Gems" },
        }
      },
    }
  },
  [ "Tempest Keep" ] = {
    order = 5,
    bosses = {
      [ "Al'ar" ] = {
        order = 1,
        items = {
          [ 29925 ] = { quality = 4, icon = 133760, name = "Phoenix-Wing Cloak" },
          [ 29918 ] = { quality = 4, icon = 132612, name = "Mindstorm Wristbands" },
          [ 29947 ] = { quality = 4, icon = 132962, name = "Gloves of the Searing Grip" },
          [ 29921 ] = { quality = 4, icon = 132738, name = "Fire Crest Breastplate" },
          [ 29922 ] = { quality = 4, icon = 133403, name = "Band of Al'ar" },
          [ 29920 ] = { quality = 4, icon = 133393, name = "Phoenix-Ring of Rebirth" },
          [ 30448 ] = { quality = 4, icon = 135827, name = "Talon of Al'ar" },
          [ 30447 ] = { quality = 4, icon = 133739, name = "Tome of Fiery Redemption" },
          [ 29923 ] = { quality = 4, icon = 134541, name = "Talisman of the Sun King" },
          [ 32944 ] = { quality = 4, icon = 135603, name = "Talon of the Phoenix" },
          [ 29948 ] = { quality = 4, icon = 135603, name = "Claw of the Phoenix" },
          [ 29924 ] = { quality = 4, icon = 132449, name = "Netherbane" },
          [ 29949 ] = { quality = 4, icon = 135626, name = "Arcanite Steam-Pistol" },
        }
      },
      [ "Void Reaver" ] = {
        order = 2,
        items = {
          [ 29986 ] = { quality = 4, icon = 133116, name = "Cowl of the Grand Engineer" },
          [ 29984 ] = { quality = 4, icon = 132497, name = "Girdle of Zaetar" },
          [ 29985 ] = { quality = 4, icon = 134667, name = "Void Reaver Greaves" },
          [ 29983 ] = { quality = 4, icon = 133071, name = "Fel-Steel Warhelm" },
          [ 32515 ] = { quality = 4, icon = 132618, name = "Wristguards of Determination" },
          [ 30619 ] = { quality = 4, icon = 133872, name = "Fel Reaver's Piston" },
          [ 30450 ] = { quality = 4, icon = 133016, name = "Warp-Spring Coil" },
          [ 30248 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Vanquished Champion" },
          [ 30249 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Vanquished Defender" },
          [ 30250 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Vanquished Hero" },
        }
      },
      [ "High Astromancer Solarian" ] = {
        order = 3,
        items = {
          [ 29977 ] = { quality = 4, icon = 134601, name = "Star-Soul Breeches" },
          [ 29972 ] = { quality = 4, icon = 134599, name = "Trousers of the Astromancer" },
          [ 29966 ] = { quality = 4, icon = 132614, name = "Vambraces of Ending" },
          [ 29976 ] = { quality = 4, icon = 132960, name = "Worldstorm Gauntlets" },
          [ 29951 ] = { quality = 4, icon = 132547, name = "Star-Strider Boots" },
          [ 29965 ] = { quality = 4, icon = 132511, name = "Girdle of the Righteous Path" },
          [ 29950 ] = { quality = 4, icon = 134681, name = "Greaves of the Bloodwarder" },
          [ 32267 ] = { quality = 4, icon = 132587, name = "Boots of the Resilient" },
          [ 30446 ] = { quality = 4, icon = 134131, name = "Solarian's Sapphire" },
          [ 30449 ] = { quality = 4, icon = 134101, name = "Void Star Talisman" },
          [ 29962 ] = { quality = 4, icon = 135681, name = "Heartrazor" },
          [ 29981 ] = { quality = 4, icon = 135188, name = "Ethereum Life-Staff" },
          [ 29982 ] = { quality = 4, icon = 135476, name = "Wand of the Forgotten Star" },
        }
      },
      [ "Kael'thas Sunstrider" ] = {
        order = 4,
        items = {
          [ 29992 ] = { quality = 4, icon = 133762, name = "Royal Cloak of the Sunstriders" },
          [ 29989 ] = { quality = 4, icon = 133758, name = "Sunshower Light Cloak" },
          [ 29994 ] = { quality = 4, icon = 133767, name = "Thalassian Wildercloak" },
          [ 29990 ] = { quality = 4, icon = 133134, name = "Crown of the Sun" },
          [ 29987 ] = { quality = 4, icon = 132951, name = "Gauntlets of the Sun King" },
          [ 29995 ] = { quality = 4, icon = 134628, name = "Leggings of Murderous Intent" },
          [ 29991 ] = { quality = 4, icon = 134683, name = "Sunhawk Leggings" },
          [ 29998 ] = { quality = 4, icon = 132963, name = "Royal Gauntlets of Silvermoon" },
          [ 29997 ] = { quality = 4, icon = 133397, name = "Band of the Ranger-General" },
          [ 29993 ] = { quality = 4, icon = 135337, name = "Twinblade of the Phoenix" },
          [ 29996 ] = { quality = 4, icon = 133528, name = "Rod of the Sun King" },
          [ 29988 ] = { quality = 4, icon = 135180, name = "The Nexus Key" },
          [ 30236 ] = { quality = 4, icon = 132625, name = "Chestguard of the Vanquished Champion" },
          [ 30237 ] = { quality = 4, icon = 132625, name = "Chestguard of the Vanquished Defender" },
          [ 30238 ] = { quality = 4, icon = 132625, name = "Chestguard of the Vanquished Hero" },
          [ 32458 ] = { quality = 4, icon = 134468, name = "Ashes of Al'ar" },
          [ 32405 ] = { quality = 4, icon = 134125, name = "Verdant Sphere" },
          [ 29905 ] = { quality = 1, icon = 134723, name = "Kael's Vial Remnant" },
        }
      },
      [ "Legendaries" ] = {
        order = 5,
        items = {
          [ 30312 ] = { quality = 5, icon = 135682, name = "Infinity Blade" },
          [ 30311 ] = { quality = 5, icon = 135379, name = "Warp Slicer" },
          [ 30317 ] = { quality = 5, icon = 133528, name = "Cosmic Infuser" },
          [ 30316 ] = { quality = 5, icon = 132455, name = "Devastation" },
          [ 30313 ] = { quality = 5, icon = 135188, name = "Staff of Disintegration" },
          [ 30314 ] = { quality = 5, icon = 134976, name = "Phaseshift Bulwark" },
          [ 30318 ] = { quality = 5, icon = 135507, name = "Netherstrand Longbow" },
          [ 30319 ] = { quality = 5, icon = 135753, name = "Nether Spike" },
        }
      },
      [ "Trash" ] = {
        order = 6,
        items = {
          [ 30024 ] = { quality = 4, icon = 135056, name = "Mantle of the Elven Kings" },
          [ 30020 ] = { quality = 4, icon = 132492, name = "Fire-Cord of the Magus" },
          [ 30029 ] = { quality = 4, icon = 132959, name = "Bark-Gloves of Ancient Wisdom" },
          [ 30026 ] = { quality = 4, icon = 132616, name = "Bands of the Celestial Archer" },
          [ 30030 ] = { quality = 4, icon = 132511, name = "Girdle of Fallen Stars" },
          [ 30028 ] = { quality = 4, icon = 133366, name = "Seventh Ring of the Tirisfalen" },
          [ 30324 ] = { quality = 4, icon = 134940, name = "Plans: Red Havoc Boots" },
          [ 30322 ] = { quality = 4, icon = 134940, name = "Plans: Red Belt of Battle" },
          [ 30323 ] = { quality = 4, icon = 134940, name = "Plans: Boots of the Protector" },
          [ 30321 ] = { quality = 4, icon = 134940, name = "Plans: Belt of the Guardian" },
          [ 30280 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of Blasting" },
          [ 30282 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of Blasting" },
          [ 30283 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of the Long Road" },
          [ 30281 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of the Long Road" },
          [ 30308 ] = { quality = 4, icon = 134940, name = "Pattern: Hurricane Boots" },
          [ 30304 ] = { quality = 4, icon = 134940, name = "Pattern: Monsoon Belt" },
          [ 30305 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of Natural Grace" },
          [ 30307 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of the Crimson Hawk" },
          [ 30306 ] = { quality = 4, icon = 134940, name = "Pattern: Boots of Utter Darkness" },
          [ 30301 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of Natural Power" },
          [ 30303 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of the Black Eagle" },
          [ 30302 ] = { quality = 4, icon = 134940, name = "Pattern: Belt of Deep Shadow" },
          [ 32897 ] = { quality = 2, icon = 136172, name = "Mark of the Illidari" },
        }
      },
    }
  },
  [ "Mount Hyjal" ] = {
    order = 6,
    bosses = {
      [ "Rage Winterchill" ] = {
        order = 1,
        items = {
          [ 30871 ] = { quality = 4, icon = 132612, name = "Bracers of Martyrdom" },
          [ 30870 ] = { quality = 4, icon = 132611, name = "Cuffs of Devastation" },
          [ 30863 ] = { quality = 4, icon = 132608, name = "Deadly Cuffs" },
          [ 30868 ] = { quality = 4, icon = 132607, name = "Rejuvenating Bracers" },
          [ 30864 ] = { quality = 4, icon = 132601, name = "Bracers of the Pathfinder" },
          [ 30869 ] = { quality = 4, icon = 132602, name = "Howling Wind Bracers" },
          [ 30873 ] = { quality = 4, icon = 132551, name = "Stillwater Boots" },
          [ 30866 ] = { quality = 4, icon = 135090, name = "Blood-stained Pauldrons" },
          [ 30862 ] = { quality = 4, icon = 132618, name = "Blessed Adamantite Bracers" },
          [ 30861 ] = { quality = 4, icon = 132614, name = "Furious Shackles" },
          [ 30865 ] = { quality = 4, icon = 135694, name = "Tracker's Blade" },
          [ 30872 ] = { quality = 4, icon = 134544, name = "Chronicle of Dark Secrets" },
          [ 32459 ] = { quality = 1, icon = 134799, name = "Time-Phased Phylactery" },
        }
      },
      [ "Anetheron" ] = {
        order = 2,
        items = {
          [ 30884 ] = { quality = 4, icon = 135093, name = "Hatefury Mantle" },
          [ 30888 ] = { quality = 4, icon = 132492, name = "Anetheron's Noose" },
          [ 30885 ] = { quality = 4, icon = 132571, name = "Archbishop's Slippers" },
          [ 30879 ] = { quality = 4, icon = 132515, name = "Don Alejandro's Money Belt" },
          [ 30886 ] = { quality = 4, icon = 132592, name = "Enchanted Leather Sandals" },
          [ 30887 ] = { quality = 4, icon = 132734, name = "Golden Links of Restoration" },
          [ 30880 ] = { quality = 4, icon = 132552, name = "Quickstrider Moccasins" },
          [ 30878 ] = { quality = 4, icon = 135090, name = "Glimmering Steel Mantle" },
          [ 30874 ] = { quality = 4, icon = 135396, name = "The Unbreakable Will" },
          [ 30881 ] = { quality = 4, icon = 135395, name = "Blade of Infamy" },
          [ 30883 ] = { quality = 4, icon = 135196, name = "Pillar of Ferocity" },
          [ 30882 ] = { quality = 4, icon = 134983, name = "Bastion of Light" },
        }
      },
      [ "Kaz'rogal" ] = {
        order = 3,
        items = {
          [ 30895 ] = { quality = 4, icon = 132497, name = "Angelista's Sash" },
          [ 30916 ] = { quality = 4, icon = 134621, name = "Leggings of Channeled Elements" },
          [ 30894 ] = { quality = 4, icon = 132558, name = "Blue Suede Shoes" },
          [ 30917 ] = { quality = 4, icon = 135092, name = "Razorfury Mantle" },
          [ 30914 ] = { quality = 4, icon = 132511, name = "Belt of the Crescent Moon" },
          [ 30891 ] = { quality = 4, icon = 132562, name = "Black Featherlight Boots" },
          [ 30892 ] = { quality = 4, icon = 135084, name = "Beast-tamer's Shoulders" },
          [ 30919 ] = { quality = 4, icon = 132511, name = "Valestalker Girdle" },
          [ 30893 ] = { quality = 4, icon = 134669, name = "Sun-touched Chain Leggings" },
          [ 30915 ] = { quality = 4, icon = 132516, name = "Belt of Seething Fury" },
          [ 30918 ] = { quality = 4, icon = 133537, name = "Hammer of Atonement" },
          [ 30889 ] = { quality = 4, icon = 134984, name = "Kaz'rogal's Hardened Heart" },
        }
      },
      [ "Azgalor" ] = {
        order = 4,
        items = {
          [ 30899 ] = { quality = 4, icon = 132716, name = "Don Rodrigo's Poncho" },
          [ 30898 ] = { quality = 4, icon = 134650, name = "Shady Dealer's Pantaloons" },
          [ 30900 ] = { quality = 4, icon = 134667, name = "Bow-stitched Leggings" },
          [ 30896 ] = { quality = 4, icon = 132737, name = "Glory of the Defender" },
          [ 30897 ] = { quality = 4, icon = 132517, name = "Girdle of Hope" },
          [ 30901 ] = { quality = 4, icon = 135694, name = "Boundless Agony" },
          [ 31092 ] = { quality = 4, icon = 132961, name = "Gloves of the Forgotten Conqueror" },
          [ 31094 ] = { quality = 4, icon = 132961, name = "Gloves of the Forgotten Protector" },
          [ 31093 ] = { quality = 4, icon = 132961, name = "Gloves of the Forgotten Vanquisher" },
        }
      },
      [ "Archimonde" ] = {
        order = 5,
        items = {
          [ 30913 ] = { quality = 4, icon = 132690, name = "Robes of Rhonin" },
          [ 30912 ] = { quality = 4, icon = 134608, name = "Leggings of Eternity" },
          [ 30905 ] = { quality = 4, icon = 132737, name = "Midnight Chestguard" },
          [ 30907 ] = { quality = 4, icon = 132639, name = "Mail of Fevered Pursuit" },
          [ 30904 ] = { quality = 4, icon = 132737, name = "Savior's Grasp" },
          [ 30903 ] = { quality = 4, icon = 134697, name = "Legguards of Endless Rage" },
          [ 30911 ] = { quality = 4, icon = 134542, name = "Scepter of Purification" },
          [ 30910 ] = { quality = 4, icon = 135400, name = "Tempest of Chaos" },
          [ 30902 ] = { quality = 4, icon = 135378, name = "Cataclysm's Edge" },
          [ 30908 ] = { quality = 4, icon = 135190, name = "Apostle of Argus" },
          [ 30909 ] = { quality = 4, icon = 134985, name = "Antonidas's Aegis of Rapt Concentration" },
          [ 30906 ] = { quality = 4, icon = 135510, name = "Bristleblitz Striker" },
          [ 31097 ] = { quality = 4, icon = 133126, name = "Helm of the Forgotten Conqueror" },
          [ 31095 ] = { quality = 4, icon = 133126, name = "Helm of the Forgotten Protector" },
          [ 31096 ] = { quality = 4, icon = 133126, name = "Helm of the Forgotten Vanquisher" },
        }
      },
      [ "Patterns" ] = {
        order = 6,
        items = {
          [ 32738 ] = { quality = 4, icon = 134940, name = "Plans: Dawnsteel Bracers" },
          [ 32739 ] = { quality = 4, icon = 134940, name = "Plans: Dawnsteel Shoulders" },
          [ 32736 ] = { quality = 4, icon = 134940, name = "Plans: Swiftsteel Bracers" },
          [ 32737 ] = { quality = 4, icon = 134940, name = "Plans: Swiftsteel Shoulders" },
          [ 32748 ] = { quality = 4, icon = 134940, name = "Pattern: Bindings of Lightning Reflexes" },
          [ 32744 ] = { quality = 4, icon = 134940, name = "Pattern: Bracers of Renewed Life" },
          [ 32750 ] = { quality = 4, icon = 134940, name = "Pattern: Living Earth Bindings" },
          [ 32751 ] = { quality = 4, icon = 134940, name = "Pattern: Living Earth Shoulders" },
          [ 32749 ] = { quality = 4, icon = 134940, name = "Pattern: Shoulders of Lightning Reflexes" },
          [ 32745 ] = { quality = 4, icon = 134940, name = "Pattern: Shoulderpads of Renewed Life" },
          [ 32746 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftstrike Bracers" },
          [ 32747 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftstrike Shoulders" },
          [ 32754 ] = { quality = 4, icon = 134940, name = "Pattern: Bracers of Nimble Thought" },
          [ 32755 ] = { quality = 4, icon = 134940, name = "Pattern: Mantle of Nimble Thought" },
          [ 32753 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftheal Mantle" },
          [ 32752 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftheal Wraps" },
        }
      },
      [ "Trash" ] = {
        order = 7,
        items = {
          [ 32590 ] = { quality = 4, icon = 133762, name = "Nethervoid Cloak" },
          [ 34010 ] = { quality = 4, icon = 133768, name = "Pepe's Shroud of Pacification" },
          [ 32609 ] = { quality = 4, icon = 132565, name = "Boots of the Divine Light" },
          [ 32592 ] = { quality = 4, icon = 132633, name = "Chestguard of Relentless Storms" },
          [ 32591 ] = { quality = 4, icon = 133325, name = "Choker of Serrated Blades" },
          [ 32589 ] = { quality = 4, icon = 133304, name = "Hellfire-Encased Pendant" },
          [ 34009 ] = { quality = 4, icon = 133537, name = "Hammer of Judgement" },
          [ 32946 ] = { quality = 4, icon = 135605, name = "Claw of Molten Fury" },
          [ 32945 ] = { quality = 4, icon = 135605, name = "Fist of Molten Fury" },
          [ 32428 ] = { quality = 3, icon = 136150, name = "Heart of Darkness" },
          [ 32897 ] = { quality = 2, icon = 136172, name = "Mark of the Illidari" },
          [ 32285 ] = { quality = 4, icon = 134940, name = "Design: Flashing Crimson Spinel" },
          [ 32296 ] = { quality = 4, icon = 134940, name = "Design: Great Lionseye" },
          [ 32303 ] = { quality = 4, icon = 134940, name = "Design: Inscribed Pyrestone" },
          [ 32295 ] = { quality = 4, icon = 134940, name = "Design: Mystic Lionseye" },
          [ 32298 ] = { quality = 4, icon = 134940, name = "Design: Shifting Shadowsong Amethyst" },
          [ 32297 ] = { quality = 4, icon = 134940, name = "Design: Sovereign Shadowsong Amethyst" },
          [ 32289 ] = { quality = 4, icon = 134940, name = "Design: Stormy Empyrean Sapphire" },
          [ 32307 ] = { quality = 4, icon = 134940, name = "Design: Veiled Pyrestone" },
        }
      },
    }
  },
  [ "Black Temple" ] = {
    order = 7,
    bosses = {
      [ "High Warlord Naj'entus" ] = {
        order = 1,
        items = {
          [ 32239 ] = { quality = 4, icon = 132573, name = "Slippers of the Seacaller" },
          [ 32240 ] = { quality = 4, icon = 133190, name = "Guise of the Tidal Lurker" },
          [ 32377 ] = { quality = 4, icon = 135092, name = "Mantle of Darkness" },
          [ 32241 ] = { quality = 4, icon = 133193, name = "Helm of Soothing Currents" },
          [ 32234 ] = { quality = 4, icon = 132982, name = "Fists of Mukoa" },
          [ 32242 ] = { quality = 4, icon = 132555, name = "Boots of Oceanic Fury" },
          [ 32232 ] = { quality = 4, icon = 132613, name = "Eternium Shell Bracers" },
          [ 32243 ] = { quality = 4, icon = 132551, name = "Pearl Inlaid Boots" },
          [ 32245 ] = { quality = 4, icon = 132585, name = "Tide-stomper's Greaves" },
          [ 32238 ] = { quality = 4, icon = 133399, name = "Ring of Calming Waves" },
          [ 32247 ] = { quality = 4, icon = 133402, name = "Ring of Captured Storms" },
          [ 32237 ] = { quality = 4, icon = 135693, name = "The Maelstrom's Fury" },
          [ 32236 ] = { quality = 4, icon = 132444, name = "Rising Tide" },
          [ 32248 ] = { quality = 4, icon = 135583, name = "Halberd of Desolation" },
        }
      },
      [ "Supremus" ] = {
        order = 2,
        items = {
          [ 32256 ] = { quality = 4, icon = 132492, name = "Waistwrap of Infinity" },
          [ 32252 ] = { quality = 4, icon = 132718, name = "Nether Shadow Tunic" },
          [ 32259 ] = { quality = 4, icon = 132601, name = "Bands of the Coming Storm" },
          [ 32251 ] = { quality = 4, icon = 132605, name = "Wraps of Precise Flight" },
          [ 32258 ] = { quality = 4, icon = 132511, name = "Naturalist's Preserving Cinch" },
          [ 32250 ] = { quality = 4, icon = 135123, name = "Pauldrons of Abyssal Fury" },
          [ 32260 ] = { quality = 4, icon = 133326, name = "Choker of Endless Nightmares" },
          [ 32261 ] = { quality = 4, icon = 133412, name = "Band of the Abyssal Lord" },
          [ 32257 ] = { quality = 4, icon = 134896, name = "Idol of the White Stag" },
          [ 32254 ] = { quality = 4, icon = 132446, name = "The Brutalizer" },
          [ 32262 ] = { quality = 4, icon = 133524, name = "Syphon of the Nathrezim" },
          [ 32255 ] = { quality = 4, icon = 134983, name = "Felstone Bulwark" },
          [ 32253 ] = { quality = 4, icon = 135549, name = "Legionkiller" },
        }
      },
      [ "Shade of Akama" ] = {
        order = 3,
        items = {
          [ 32273 ] = { quality = 4, icon = 135088, name = "Amice of Brilliant Light" },
          [ 32270 ] = { quality = 4, icon = 132609, name = "Focused Mana Bindings" },
          [ 32513 ] = { quality = 4, icon = 132612, name = "Wristbands of Divine Influence" },
          [ 32265 ] = { quality = 4, icon = 132515, name = "Shadow-walker's Cord" },
          [ 32271 ] = { quality = 4, icon = 134648, name = "Kilt of Immortal Nature" },
          [ 32264 ] = { quality = 4, icon = 135084, name = "Shoulders of the Hidden Predator" },
          [ 32275 ] = { quality = 4, icon = 132984, name = "Spiritwalker Gauntlets" },
          [ 32276 ] = { quality = 4, icon = 132502, name = "Flashfire Girdle" },
          [ 32279 ] = { quality = 4, icon = 132616, name = "The Seeker's Wristguards" },
          [ 32278 ] = { quality = 4, icon = 132985, name = "Grips of Silent Justice" },
          [ 32263 ] = { quality = 4, icon = 134683, name = "Praetorian's Legguards" },
          [ 32268 ] = { quality = 4, icon = 132587, name = "Myrmidon's Treads" },
          [ 32266 ] = { quality = 4, icon = 133410, name = "Ring of Deceitful Intent" },
          [ 32361 ] = { quality = 4, icon = 134337, name = "Blind-Seers Icon" },
        }
      },
      [ "Gurtogg Bloodboil" ] = {
        order = 4,
        items = {
          [ 32337 ] = { quality = 4, icon = 133765, name = "Shroud of Forgiveness" },
          [ 32338 ] = { quality = 4, icon = 135033, name = "Blood-cursed Shoulderpads" },
          [ 32340 ] = { quality = 4, icon = 132676, name = "Garments of Temperance" },
          [ 32339 ] = { quality = 4, icon = 132513, name = "Belt of Primal Majesty" },
          [ 32334 ] = { quality = 4, icon = 132759, name = "Vest of Mounting Assault" },
          [ 32342 ] = { quality = 4, icon = 132516, name = "Girdle of Mighty Resolve" },
          [ 32333 ] = { quality = 4, icon = 132522, name = "Girdle of Stability" },
          [ 32341 ] = { quality = 4, icon = 134696, name = "Leggings of Divine Retribution" },
          [ 32335 ] = { quality = 4, icon = 133413, name = "Unstoppable Aggressor's Ring" },
          [ 32501 ] = { quality = 4, icon = 133265, name = "Shadowmoon Insignia" },
          [ 32269 ] = { quality = 4, icon = 135698, name = "Messenger of Fate" },
          [ 32344 ] = { quality = 4, icon = 135197, name = "Staff of Immaculate Recovery" },
          [ 32343 ] = { quality = 4, icon = 135477, name = "Wand of Prismatic Focus" },
        }
      },
      [ "Reliquary of the Lost" ] = {
        order = 5,
        items = {
          [ 32353 ] = { quality = 4, icon = 132986, name = "Gloves of Unfailing Faith" },
          [ 32351 ] = { quality = 4, icon = 132608, name = "Elunite Empowered Bracers" },
          [ 32347 ] = { quality = 4, icon = 132988, name = "Grips of Damnation" },
          [ 32352 ] = { quality = 4, icon = 132542, name = "Naturewarden's Treads" },
          [ 32517 ] = { quality = 4, icon = 135086, name = "The Wavemender's Mantle" },
          [ 32346 ] = { quality = 4, icon = 132503, name = "Boneweave Girdle" },
          [ 32354 ] = { quality = 4, icon = 133192, name = "Crown of Empowered Fate" },
          [ 32345 ] = { quality = 4, icon = 132583, name = "Dreadboots of the Legion" },
          [ 32349 ] = { quality = 4, icon = 133320, name = "Translucent Spellthread Necklace" },
          [ 32362 ] = { quality = 4, icon = 133278, name = "Pendant of Titans" },
          [ 32350 ] = { quality = 4, icon = 134102, name = "Touch of Inspiration" },
          [ 32332 ] = { quality = 4, icon = 133529, name = "Torch of the Damned" },
          [ 32363 ] = { quality = 4, icon = 135476, name = "Naaru-Blessed Life Rod" },
        }
      },
      [ "Teron Gorefiend" ] = {
        order = 6,
        items = {
          [ 32323 ] = { quality = 4, icon = 133776, name = "Shadowmoon Destroyer's Drape" },
          [ 32329 ] = { quality = 4, icon = 133134, name = "Cowl of Benevolence" },
          [ 32327 ] = { quality = 4, icon = 132692, name = "Robe of the Shadow Council" },
          [ 32324 ] = { quality = 4, icon = 132603, name = "Insidious Bands" },
          [ 32328 ] = { quality = 4, icon = 132958, name = "Botanist's Gloves of Growth" },
          [ 32510 ] = { quality = 4, icon = 132544, name = "Softstep Boots of Tracking" },
          [ 32280 ] = { quality = 4, icon = 132985, name = "Gauntlets of Enforcement" },
          [ 32512 ] = { quality = 4, icon = 132517, name = "Girdle of Lordaeron's Fallen" },
          [ 32330 ] = { quality = 4, icon = 136037, name = "Totem of Ancestral Guidance" },
          [ 32348 ] = { quality = 4, icon = 132447, name = "Soul Cleaver" },
          [ 32326 ] = { quality = 4, icon = 135428, name = "Twisted Blades of Zarak" },
          [ 32325 ] = { quality = 4, icon = 135629, name = "Rifle of the Stoic Guardian" },
        }
      },
      [ "Mother Shahraz" ] = {
        order = 7,
        items = {
          [ 32367 ] = { quality = 4, icon = 134609, name = "Leggings of Devastation" },
          [ 32366 ] = { quality = 4, icon = 132559, name = "Shadowmaster's Boots" },
          [ 32365 ] = { quality = 4, icon = 132743, name = "Heartshatter Breastplate" },
          [ 32370 ] = { quality = 4, icon = 133323, name = "Nadina's Pendant of Purity" },
          [ 32368 ] = { quality = 4, icon = 134916, name = "Tome of the Lightbringer" },
          [ 32369 ] = { quality = 4, icon = 135397, name = "Blade of Savagery" },
          [ 31101 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Forgotten Conqueror" },
          [ 31103 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Forgotten Protector" },
          [ 31102 ] = { quality = 4, icon = 135053, name = "Pauldrons of the Forgotten Vanquisher" },
        }
      },
      [ "The Illidari Council" ] = {
        order = 8,
        items = {
          [ 32331 ] = { quality = 4, icon = 133772, name = "Cloak of the Illidari Council" },
          [ 32519 ] = { quality = 4, icon = 132496, name = "Belt of Divine Guidance" },
          [ 32518 ] = { quality = 4, icon = 135083, name = "Veil of Turning Leaves" },
          [ 32376 ] = { quality = 4, icon = 133191, name = "Forest Prowler's Helm" },
          [ 32373 ] = { quality = 4, icon = 133194, name = "Helm of the Illidari Shatterer" },
          [ 32505 ] = { quality = 4, icon = 136129, name = "Madness of the Betrayer" },
          [ 31098 ] = { quality = 4, icon = 134693, name = "Leggings of the Forgotten Conqueror" },
          [ 31100 ] = { quality = 4, icon = 134693, name = "Leggings of the Forgotten Protector" },
          [ 31099 ] = { quality = 4, icon = 134693, name = "Leggings of the Forgotten Vanquisher" },
        }
      },
      [ "Illidan Stormrage" ] = {
        order = 9,
        items = {
          [ 32524 ] = { quality = 4, icon = 133758, name = "Shroud of the Highborne" },
          [ 32525 ] = { quality = 4, icon = 133155, name = "Cowl of the Illidari High Lord" },
          [ 32235 ] = { quality = 4, icon = 133694, name = "Cursed Vision of Sargeras" },
          [ 32521 ] = { quality = 4, icon = 133194, name = "Faceplate of the Impenetrable" },
          [ 32497 ] = { quality = 4, icon = 133409, name = "Stormrage Signet Ring" },
          [ 32483 ] = { quality = 4, icon = 133729, name = "The Skull of Gul'dan" },
          [ 32496 ] = { quality = 4, icon = 135263, name = "Memento of Tyrande" },
          [ 32837 ] = { quality = 5, icon = 135561, name = "Warglaive of Azzinoth" },
          [ 32838 ] = { quality = 5, icon = 135561, name = "Warglaive of Azzinoth" },
          [ 31089 ] = { quality = 4, icon = 132625, name = "Chestguard of the Forgotten Conqueror" },
          [ 31091 ] = { quality = 4, icon = 132625, name = "Chestguard of the Forgotten Protector" },
          [ 31090 ] = { quality = 4, icon = 132625, name = "Chestguard of the Forgotten Vanquisher" },
          [ 32471 ] = { quality = 4, icon = 135697, name = "Shard of Azzinoth" },
          [ 32500 ] = { quality = 4, icon = 133536, name = "Crystal Spire of Karabor" },
          [ 32374 ] = { quality = 4, icon = 135195, name = "Zhar'doom, Greatstaff of the Devourer" },
          [ 32375 ] = { quality = 4, icon = 134977, name = "Bulwark of Azzinoth" },
          [ 32336 ] = { quality = 4, icon = 135511, name = "Black Bow of the Betrayer" },
        }
      },
      [ "Patterns" ] = {
        order = 10,
        items = {
          [ 32738 ] = { quality = 4, icon = 134940, name = "Plans: Dawnsteel Bracers" },
          [ 32739 ] = { quality = 4, icon = 134940, name = "Plans: Dawnsteel Shoulders" },
          [ 32736 ] = { quality = 4, icon = 134940, name = "Plans: Swiftsteel Bracers" },
          [ 32737 ] = { quality = 4, icon = 134940, name = "Plans: Swiftsteel Shoulders" },
          [ 32748 ] = { quality = 4, icon = 134940, name = "Pattern: Bindings of Lightning Reflexes" },
          [ 32744 ] = { quality = 4, icon = 134940, name = "Pattern: Bracers of Renewed Life" },
          [ 32750 ] = { quality = 4, icon = 134940, name = "Pattern: Living Earth Bindings" },
          [ 32751 ] = { quality = 4, icon = 134940, name = "Pattern: Living Earth Shoulders" },
          [ 32749 ] = { quality = 4, icon = 134940, name = "Pattern: Shoulders of Lightning Reflexes" },
          [ 32745 ] = { quality = 4, icon = 134940, name = "Pattern: Shoulderpads of Renewed Life" },
          [ 32746 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftstrike Bracers" },
          [ 32747 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftstrike Shoulders" },
          [ 32754 ] = { quality = 4, icon = 134940, name = "Pattern: Bracers of Nimble Thought" },
          [ 32755 ] = { quality = 4, icon = 134940, name = "Pattern: Mantle of Nimble Thought" },
          [ 32753 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftheal Mantle" },
          [ 32752 ] = { quality = 4, icon = 134940, name = "Pattern: Swiftheal Wraps" },
        }
      },
      [ "Trash" ] = {
        order = 11,
        items = {
          [ 32590 ] = { quality = 4, icon = 133762, name = "Nethervoid Cloak" },
          [ 34012 ] = { quality = 4, icon = 133768, name = "Shroud of the Final Stand" },
          [ 32609 ] = { quality = 4, icon = 132565, name = "Boots of the Divine Light" },
          [ 32593 ] = { quality = 4, icon = 132592, name = "Treads of the Den Mother" },
          [ 32592 ] = { quality = 4, icon = 132633, name = "Chestguard of Relentless Storms" },
          [ 32608 ] = { quality = 4, icon = 132985, name = "Pillager's Gauntlets" },
          [ 32606 ] = { quality = 4, icon = 132517, name = "Girdle of the Lightbearer" },
          [ 32591 ] = { quality = 4, icon = 133325, name = "Choker of Serrated Blades" },
          [ 32589 ] = { quality = 4, icon = 133304, name = "Hellfire-Encased Pendant" },
          [ 32526 ] = { quality = 4, icon = 133377, name = "Band of Devastation" },
          [ 32528 ] = { quality = 4, icon = 133377, name = "Blessed Band of Karabor" },
          [ 32527 ] = { quality = 4, icon = 133377, name = "Ring of Ancient Knowledge" },
          [ 34009 ] = { quality = 4, icon = 133537, name = "Hammer of Judgement" },
          [ 32943 ] = { quality = 4, icon = 133524, name = "Swiftsteel Bludgeon" },
          [ 34011 ] = { quality = 4, icon = 134947, name = "Illidari Runeshield" },
          [ 32228 ] = { quality = 4, icon = 133244, name = "Empyrean Sapphire" },
          [ 32231 ] = { quality = 4, icon = 133260, name = "Pyrestone" },
          [ 32229 ] = { quality = 4, icon = 133248, name = "Lionseye" },
          [ 32249 ] = { quality = 4, icon = 133263, name = "Seaspray Emerald" },
          [ 32230 ] = { quality = 4, icon = 133265, name = "Shadowsong Amethyst" },
          [ 32227 ] = { quality = 4, icon = 133238, name = "Crimson Spinel" },
          [ 32428 ] = { quality = 3, icon = 136150, name = "Heart of Darkness" },
          [ 32897 ] = { quality = 2, icon = 136172, name = "Mark of the Illidari" },
        }
      },
    }
  },
  [ "Zul'Aman" ] = {
    order = 8,
    bosses = {
      [ "Akil'zon" ] = {
        order = 1,
        items = {
          [ 29434 ] = { quality = 4, icon = 135884, name = "Badge of Justice" },
          [ 33286 ] = { quality = 4, icon = 133097, name = "Mojo-mender's Mask" },
          [ 33215 ] = { quality = 4, icon = 132756, name = "Bloodstained Elven Battlevest" },
          [ 33216 ] = { quality = 4, icon = 132758, name = "Chestguard of Hidden Purpose" },
          [ 33281 ] = { quality = 4, icon = 133341, name = "Brooch of Nature's Mercy" },
          [ 33293 ] = { quality = 4, icon = 133410, name = "Signet of Ancient Magics" },
          [ 33214 ] = { quality = 4, icon = 135289, name = "Akil'zon's Talonblade" },
          [ 33283 ] = { quality = 4, icon = 133512, name = "Amani Punisher" },
          [ 33307 ] = { quality = 3, icon = 134327, name = "Formula: Enchant Weapon - Executioner" },
        }
      },
      [ "Nalorakk" ] = {
        order = 2,
        items = {
          [ 33203 ] = { quality = 4, icon = 132676, name = "Robes of Heavenly Purpose" },
          [ 33285 ] = { quality = 4, icon = 132612, name = "Fury of the Ursine" },
          [ 33211 ] = { quality = 4, icon = 132503, name = "Bladeangel's Money Belt" },
          [ 33206 ] = { quality = 4, icon = 135110, name = "Pauldrons of Primal Fury" },
          [ 33327 ] = { quality = 4, icon = 133565, name = "Mask of Introspection" },
          [ 33191 ] = { quality = 4, icon = 132591, name = "Jungle Stompers" },
          [ 33640 ] = { quality = 4, icon = 135606, name = "Fury" },
        }
      },
      [ "Jan'alai" ] = {
        order = 3,
        items = {
          [ 33357 ] = { quality = 4, icon = 132539, name = "Footpads of Madness" },
          [ 33356 ] = { quality = 4, icon = 133093, name = "Helm of Natural Regeneration" },
          [ 33329 ] = { quality = 4, icon = 132721, name = "Shadowtooth Trollskin Cuirass" },
          [ 33328 ] = { quality = 4, icon = 132635, name = "Arrow-fall Chestguard" },
          [ 33354 ] = { quality = 4, icon = 135699, name = "Wub's Cursed Hexblade" },
          [ 33326 ] = { quality = 4, icon = 134987, name = "Bulwark of the Amani Empire" },
          [ 33332 ] = { quality = 4, icon = 134988, name = "Enamelled Disc of Mojo" },
        }
      },
      [ "Halazzi" ] = {
        order = 4,
        items = {
          [ 33317 ] = { quality = 4, icon = 132659, name = "Robe of Departed Spirits" },
          [ 33300 ] = { quality = 4, icon = 135055, name = "Shoulderpads of Dancing Blades" },
          [ 33322 ] = { quality = 4, icon = 132716, name = "Shimmer-pelt Vest" },
          [ 33533 ] = { quality = 4, icon = 134676, name = "Avalanche Leggings" },
          [ 33299 ] = { quality = 4, icon = 135109, name = "Spaulders of the Advocate" },
          [ 33303 ] = { quality = 4, icon = 132591, name = "Skullshatter Warboots" },
          [ 33297 ] = { quality = 4, icon = 133306, name = "The Savage's Choker" },
        }
      },
      [ "Hex Lord Malacrass" ] = {
        order = 5,
        items = {
          [ 33592 ] = { quality = 4, icon = 133768, name = "Cloak of Ancient Rituals" },
          [ 33453 ] = { quality = 4, icon = 133097, name = "Hood of Hexing" },
          [ 33463 ] = { quality = 4, icon = 133097, name = "Hood of the Third Eye" },
          [ 33432 ] = { quality = 4, icon = 133094, name = "Coif of the Jungle Stalker" },
          [ 33464 ] = { quality = 4, icon = 135111, name = "Hex Lord's Voodoo Pauldrons" },
          [ 33421 ] = { quality = 4, icon = 133092, name = "Battleworn Tuskguard" },
          [ 33446 ] = { quality = 4, icon = 132516, name = "Girdle of Stromgarde's Hope" },
          [ 33829 ] = { quality = 4, icon = 134177, name = "Hex Shrunken Head" },
          [ 34029 ] = { quality = 4, icon = 133067, name = "Tiny Voodoo Mask" },
          [ 33828 ] = { quality = 4, icon = 134554, name = "Tome of Diabolic Remedy" },
          [ 33389 ] = { quality = 4, icon = 135695, name = "Dagger of Bad Mojo" },
          [ 33298 ] = { quality = 4, icon = 135700, name = "Prowler's Strikeblade" },
          [ 33388 ] = { quality = 4, icon = 135288, name = "Heartless" },
          [ 33465 ] = { quality = 4, icon = 135149, name = "Staff of Primal Fury" },
        }
      },
      [ "Zul'jin" ] = {
        order = 6,
        items = {
          [ 33471 ] = { quality = 4, icon = 132579, name = "Two-toed Sandals" },
          [ 33479 ] = { quality = 4, icon = 133097, name = "Grimgrin Faceguard" },
          [ 33469 ] = { quality = 4, icon = 132735, name = "Hauberk of the Empire's Champion" },
          [ 33473 ] = { quality = 4, icon = 132756, name = "Chestguard of the Warlord" },
          [ 33466 ] = { quality = 4, icon = 133291, name = "Loop of Cursed Bones" },
          [ 33830 ] = { quality = 4, icon = 135443, name = "Ancient Aqir Artifact" },
          [ 33831 ] = { quality = 4, icon = 135727, name = "Berserker's Call" },
          [ 33467 ] = { quality = 4, icon = 135290, name = "Blade of Twisted Visions" },
          [ 33478 ] = { quality = 4, icon = 135289, name = "Jin'rohk, The Great Apocalypse" },
          [ 33476 ] = { quality = 4, icon = 132470, name = "Cleaver of the Unforgiving" },
          [ 33468 ] = { quality = 4, icon = 135199, name = "Dark Blessing" },
          [ 33474 ] = { quality = 4, icon = 135512, name = "Ancient Amani Longbow" },
          [ 33102 ] = { quality = 4, icon = 134800, name = "Blood of Zul'jin" },
        }
      },
      [ "Timed Chest" ] = {
        order = 7,
        items = {
          [ 33590 ] = { quality = 4, icon = 133772, name = "Cloak of Fiends" },
          [ 33591 ] = { quality = 4, icon = 133771, name = "Shadowcaster's Drape" },
          [ 33489 ] = { quality = 4, icon = 135107, name = "Mantle of Ill Intent" },
          [ 33480 ] = { quality = 4, icon = 132513, name = "Cord of Braided Troll Hair" },
          [ 33483 ] = { quality = 4, icon = 132500, name = "Life-step Belt" },
          [ 33971 ] = { quality = 4, icon = 134648, name = "Elunite Imbued Leggings" },
          [ 33805 ] = { quality = 4, icon = 132551, name = "Shadowhunter's Treads" },
          [ 33481 ] = { quality = 4, icon = 135106, name = "Pauldrons of Stone Resolve" },
          [ 33497 ] = { quality = 4, icon = 133392, name = "Mana Attuned Band" },
          [ 33500 ] = { quality = 4, icon = 133403, name = "Signet of Eternal Life" },
          [ 33496 ] = { quality = 4, icon = 133386, name = "Signet of Primal Wrath" },
          [ 33499 ] = { quality = 4, icon = 133409, name = "Signet of the Last Defender" },
          [ 33498 ] = { quality = 4, icon = 133379, name = "Signet of the Quiet Forest" },
          [ 33495 ] = { quality = 4, icon = 135606, name = "Rage" },
          [ 33493 ] = { quality = 4, icon = 135701, name = "Umbral Shiv" },
          [ 33492 ] = { quality = 4, icon = 132471, name = "Trollbane" },
          [ 33490 ] = { quality = 4, icon = 135198, name = "Staff of Dark Mending" },
          [ 33494 ] = { quality = 4, icon = 135145, name = "Amani Divining Staff" },
          [ 33491 ] = { quality = 4, icon = 135632, name = "Tuskbreaker" },
          [ 33809 ] = { quality = 4, icon = 132117, name = "Amani War Bear" },
        }
      },
      [ "Trash" ] = {
        order = 8,
        items = {
          [ 33993 ] = { quality = 3, icon = 134506, name = "Mojo" },
          [ 33865 ] = { quality = 2, icon = 135485, name = "Amani Hex Stick" },
          [ 33930 ] = { quality = 2, icon = 134232, name = "Amani Charm of the Bloodletter" },
          [ 33932 ] = { quality = 2, icon = 134232, name = "Amani Charm of the Witch Doctor" },
          [ 33931 ] = { quality = 2, icon = 134232, name = "Amani Charm of Mighty Mojo" },
          [ 33933 ] = { quality = 2, icon = 134232, name = "Amani Charm of the Raging Defender" },
        }
      },
    }
  },
  [ "Sunwell Plateau" ] = {
    order = 9,
    bosses = {
      [ "Kalecgos" ] = {
        order = 1,
        items = {
          [ 34170 ] = { quality = 4, icon = 134601, name = "Pantaloons of Calming Strife" },
          [ 34169 ] = { quality = 4, icon = 134648, name = "Breeches of Natural Aggression" },
          [ 34168 ] = { quality = 4, icon = 134668, name = "Starstalker Legguards" },
          [ 34167 ] = { quality = 4, icon = 134698, name = "Legplates of the Holy Juggernaut" },
          [ 34166 ] = { quality = 4, icon = 133399, name = "Band of Lucent Beams" },
          [ 34848 ] = { quality = 4, icon = 132615, name = "Bracers of the Forgotten Conqueror" },
          [ 34851 ] = { quality = 4, icon = 132616, name = "Bracers of the Forgotten Protector" },
          [ 34852 ] = { quality = 4, icon = 132614, name = "Bracers of the Forgotten Vanquisher" },
          [ 34165 ] = { quality = 4, icon = 135709, name = "Fang of Kalecgos" },
          [ 34164 ] = { quality = 4, icon = 135297, name = "Dragonscale-Encrusted Longblade" },
        }
      },
      [ "Brutallus" ] = {
        order = 2,
        items = {
          [ 34181 ] = { quality = 4, icon = 134599, name = "Leggings of Calamity" },
          [ 34180 ] = { quality = 4, icon = 134700, name = "Felfury Legplates" },
          [ 34178 ] = { quality = 4, icon = 133338, name = "Collar of the Pit Lord" },
          [ 34177 ] = { quality = 4, icon = 133334, name = "Clutch of Demise" },
          [ 34853 ] = { quality = 4, icon = 132520, name = "Belt of the Forgotten Conqueror" },
          [ 34854 ] = { quality = 4, icon = 132522, name = "Belt of the Forgotten Protector" },
          [ 34855 ] = { quality = 4, icon = 132516, name = "Belt of the Forgotten Vanquisher" },
          [ 34176 ] = { quality = 4, icon = 133553, name = "Reign of Misery" },
          [ 34179 ] = { quality = 4, icon = 134557, name = "Heart of the Pit" },
        }
      },
      [ "Felmyst" ] = {
        order = 3,
        items = {
          [ 34352 ] = { quality = 4, icon = 132991, name = "Borderland Fortress Grips" },
          [ 34188 ] = { quality = 4, icon = 134652, name = "Leggings of the Immortal Night" },
          [ 34186 ] = { quality = 4, icon = 134667, name = "Chain Links of the Tumultuous Storm" },
          [ 34184 ] = { quality = 4, icon = 133335, name = "Brooch of the Highborne" },
          [ 34856 ] = { quality = 4, icon = 132587, name = "Boots of the Forgotten Conqueror" },
          [ 34857 ] = { quality = 4, icon = 132585, name = "Boots of the Forgotten Protector" },
          [ 34858 ] = { quality = 4, icon = 132588, name = "Boots of the Forgotten Vanquisher" },
          [ 34182 ] = { quality = 4, icon = 135209, name = "Grand Magister's Staff of Torrents" },
          [ 34185 ] = { quality = 4, icon = 134998, name = "Sword Breaker's Bulwark" },
        }
      },
      [ "Eredar Twins" ] = {
        order = 4,
        items = {
          [ 34205 ] = { quality = 4, icon = 133758, name = "Shroud of Redeemed Souls" },
          [ 34190 ] = { quality = 4, icon = 133770, name = "Crimson Paragon's Cover" },
          [ 34210 ] = { quality = 4, icon = 135121, name = "Amice of the Convoker" },
          [ 34202 ] = { quality = 4, icon = 135121, name = "Shawl of Wonderment" },
          [ 34209 ] = { quality = 4, icon = 135113, name = "Spaulders of Reclamation" },
          [ 34195 ] = { quality = 4, icon = 135113, name = "Shoulderpads of Vehemence" },
          [ 34194 ] = { quality = 4, icon = 135115, name = "Mantle of the Golden Forest" },
          [ 34208 ] = { quality = 4, icon = 135115, name = "Equilibrium Epaulets" },
          [ 34192 ] = { quality = 4, icon = 135114, name = "Pauldrons of Perseverance" },
          [ 34193 ] = { quality = 4, icon = 135114, name = "Spaulders of the Thalassian Savior" },
          [ 35290 ] = { quality = 4, icon = 133327, name = "Sin'dorei Pendant of Conquest" },
          [ 35291 ] = { quality = 4, icon = 133327, name = "Sin'dorei Pendant of Salvation" },
          [ 35292 ] = { quality = 4, icon = 133327, name = "Sin'dorei Pendant of Triumph" },
          [ 34204 ] = { quality = 4, icon = 133331, name = "Amulet of Unfettered Magics" },
          [ 34189 ] = { quality = 4, icon = 133378, name = "Band of Ruinous Delight" },
          [ 34206 ] = { quality = 4, icon = 134556, name = "Book of Highborne Hymns" },
          [ 34197 ] = { quality = 4, icon = 135710, name = "Shiv of Exsanguination" },
          [ 34199 ] = { quality = 4, icon = 133551, name = "Archon's Gavel" },
          [ 34203 ] = { quality = 4, icon = 135606, name = "Grip of Mannoroth" },
          [ 34198 ] = { quality = 4, icon = 135149, name = "Stanchion of Primal Instinct" },
          [ 34196 ] = { quality = 4, icon = 135518, name = "Golden Bow of Quel'Thalas" },
        }
      },
      [ "M'uru" ] = {
        order = 5,
        items = {
          [ 34232 ] = { quality = 4, icon = 132692, name = "Fel Conquerer Raiments" },
          [ 34233 ] = { quality = 4, icon = 132673, name = "Robes of Faltered Light" },
          [ 34212 ] = { quality = 4, icon = 132727, name = "Sunglow Vest" },
          [ 34211 ] = { quality = 4, icon = 132729, name = "Harness of Carnal Instinct" },
          [ 34234 ] = { quality = 4, icon = 132962, name = "Shadowed Gauntlets of Paroxysm" },
          [ 34229 ] = { quality = 4, icon = 132633, name = "Garments of Serene Shores" },
          [ 34228 ] = { quality = 4, icon = 132639, name = "Vicious Hawkstrider Hauberk" },
          [ 34215 ] = { quality = 4, icon = 132754, name = "Warharness of Reckless Fury" },
          [ 34240 ] = { quality = 4, icon = 132954, name = "Gauntlets of the Soothed Soul" },
          [ 34216 ] = { quality = 4, icon = 132752, name = "Heroic Judicator's Chestguard" },
          [ 34213 ] = { quality = 4, icon = 133414, name = "Ring of Hardened Resolve" },
          [ 34230 ] = { quality = 4, icon = 133410, name = "Ring of Omnipotence" },
          [ 35282 ] = { quality = 4, icon = 133402, name = "Sin'dorei Band of Dominance" },
          [ 35283 ] = { quality = 4, icon = 133402, name = "Sin'dorei Band of Salvation" },
          [ 35284 ] = { quality = 4, icon = 133402, name = "Sin'dorei Band of Triumph" },
          [ 34427 ] = { quality = 4, icon = 133449, name = "Blackened Naaru Sliver" },
          [ 34430 ] = { quality = 4, icon = 133450, name = "Glimmering Naaru Sliver" },
          [ 34429 ] = { quality = 4, icon = 133448, name = "Shifting Naaru Sliver" },
          [ 34428 ] = { quality = 4, icon = 133451, name = "Steely Naaru Sliver" },
          [ 34214 ] = { quality = 4, icon = 135296, name = "Muramasa" },
          [ 34231 ] = { quality = 4, icon = 134997, name = "Aegis of Angelic Fortune" },
        }
      },
      [ "Kil'jaeden" ] = {
        order = 6,
        items = {
          [ 34241 ] = { quality = 4, icon = 133776, name = "Cloak of Unforgivable Sin" },
          [ 34242 ] = { quality = 4, icon = 133772, name = "Tattered Cape of Antonidas" },
          [ 34339 ] = { quality = 4, icon = 133114, name = "Cowl of Light's Purity" },
          [ 34340 ] = { quality = 4, icon = 133114, name = "Dark Conjuror's Collar" },
          [ 34342 ] = { quality = 4, icon = 132950, name = "Handguards of the Dawn" },
          [ 34344 ] = { quality = 4, icon = 132949, name = "Handguards of Defiled Worlds" },
          [ 34244 ] = { quality = 4, icon = 133108, name = "Duplicitous Guise" },
          [ 34245 ] = { quality = 4, icon = 133108, name = "Cover of Ursol the Wise" },
          [ 34333 ] = { quality = 4, icon = 133068, name = "Coif of Alleria" },
          [ 34332 ] = { quality = 4, icon = 133068, name = "Cowl of Gul'dan" },
          [ 34343 ] = { quality = 4, icon = 132974, name = "Thalassian Ranger Gauntlets" },
          [ 34243 ] = { quality = 4, icon = 133127, name = "Helm of Burning Righteousness" },
          [ 34345 ] = { quality = 4, icon = 133188, name = "Crown of Anasterian" },
          [ 34341 ] = { quality = 4, icon = 132988, name = "Borderland Paingrips" },
          [ 34334 ] = { quality = 5, icon = 135519, name = "Thori'dal, the Stars' Fury" },
          [ 34329 ] = { quality = 4, icon = 135710, name = "Crux of the Apocalypse" },
          [ 34247 ] = { quality = 4, icon = 135298, name = "Apolyon, the Soul-Render" },
          [ 34335 ] = { quality = 4, icon = 133552, name = "Hammer of Sanctification" },
          [ 34331 ] = { quality = 4, icon = 135606, name = "Hand of the Deceiver" },
          [ 34336 ] = { quality = 4, icon = 135708, name = "Sunflare" },
          [ 34337 ] = { quality = 4, icon = 135208, name = "Golden Staff of the Sin'dorei" },
        }
      },
      [ "Patterns" ] = {
        order = 7,
        items = {
          [ 35212 ] = { quality = 4, icon = 134940, name = "Pattern: Leather Gauntlets of the Sun" },
          [ 35216 ] = { quality = 4, icon = 134940, name = "Pattern: Leather Chestguard of the Sun" },
          [ 35213 ] = { quality = 4, icon = 134940, name = "Pattern: Fletcher's Gloves of the Phoenix" },
          [ 35217 ] = { quality = 4, icon = 134940, name = "Pattern: Embrace of the Phoenix" },
          [ 35214 ] = { quality = 4, icon = 134940, name = "Pattern: Gloves of Immortal Dusk" },
          [ 35218 ] = { quality = 4, icon = 134940, name = "Pattern: Carapace of Sun and Shadow" },
          [ 35215 ] = { quality = 4, icon = 134940, name = "Pattern: Sun-Drenched Scale Gloves" },
          [ 35219 ] = { quality = 4, icon = 134940, name = "Pattern: Sun-Drenched Scale Chestguard" },
          [ 35204 ] = { quality = 4, icon = 134940, name = "Pattern: Sunfire Handwraps" },
          [ 35206 ] = { quality = 4, icon = 134940, name = "Pattern: Sunfire Robe" },
          [ 35205 ] = { quality = 4, icon = 134940, name = "Pattern: Hands of Eternal Light" },
          [ 35207 ] = { quality = 4, icon = 134940, name = "Pattern: Robe of Eternal Light" },
          [ 35198 ] = { quality = 4, icon = 134940, name = "Design: Loop of Forged Power" },
          [ 35201 ] = { quality = 4, icon = 134940, name = "Design: Pendant of Sunfire" },
          [ 35199 ] = { quality = 4, icon = 134940, name = "Design: Ring of Flowing Life" },
          [ 35202 ] = { quality = 4, icon = 134940, name = "Design: Amulet of Flowing Life" },
          [ 35200 ] = { quality = 4, icon = 134940, name = "Design: Hard Khorium Band" },
          [ 35203 ] = { quality = 4, icon = 134940, name = "Design: Hard Khorium Choker" },
          [ 35186 ] = { quality = 4, icon = 134940, name = "Schematic: Annihilator Holo-Gogs" },
          [ 35187 ] = { quality = 4, icon = 134940, name = "Schematic: Justicebringer 3000 Specs" },
          [ 35189 ] = { quality = 4, icon = 134940, name = "Schematic: Powerheal 9000 Lens" },
          [ 35190 ] = { quality = 4, icon = 134940, name = "Schematic: Hyper-Magnified Moon Specs" },
          [ 35191 ] = { quality = 4, icon = 134940, name = "Schematic: Wonderheal XT68 Shades" },
          [ 35192 ] = { quality = 4, icon = 134940, name = "Schematic: Primal-Attuned Goggles" },
          [ 35193 ] = { quality = 4, icon = 134940, name = "Schematic: Lightning Etched Specs" },
          [ 35194 ] = { quality = 4, icon = 134940, name = "Schematic: Surestrike Goggles v3.0" },
          [ 35195 ] = { quality = 4, icon = 134940, name = "Schematic: Mayhem Projection Goggles" },
          [ 35196 ] = { quality = 4, icon = 134940, name = "Schematic: Hard Khorium Goggles" },
          [ 35197 ] = { quality = 4, icon = 134940, name = "Schematic: Quad Deathblow X44 Goggles" },
        }
      },
      [ "Trash" ] = {
        order = 8,
        items = {
          [ 34351 ] = { quality = 4, icon = 132971, name = "Tranquil Majesty Wraps" },
          [ 34350 ] = { quality = 4, icon = 132968, name = "Gauntlets of the Ancient Shadowmoon" },
          [ 35733 ] = { quality = 4, icon = 133399, name = "Ring of Harmonic Beauty" },
          [ 34183 ] = { quality = 4, icon = 135583, name = "Shivering Felspine" },
          [ 34346 ] = { quality = 4, icon = 135604, name = "Mounting Vengeance" },
          [ 34349 ] = { quality = 4, icon = 135431, name = "Blade of Life's Inevitability" },
          [ 34348 ] = { quality = 4, icon = 135487, name = "Wand of Cleansing Light" },
          [ 34347 ] = { quality = 4, icon = 135488, name = "Wand of the Demonsoul" },
          [ 35273 ] = { quality = 3, icon = 133740, name = "Study of Advanced Smelting" },
          [ 34664 ] = { quality = 3, icon = 136030, name = "Sunmote" },
          [ 32228 ] = { quality = 4, icon = 133244, name = "Empyrean Sapphire" },
          [ 32231 ] = { quality = 4, icon = 133260, name = "Pyrestone" },
          [ 32229 ] = { quality = 4, icon = 133248, name = "Lionseye" },
          [ 32249 ] = { quality = 4, icon = 133263, name = "Seaspray Emerald" },
          [ 32230 ] = { quality = 4, icon = 133265, name = "Shadowsong Amethyst" },
          [ 32227 ] = { quality = 4, icon = 133238, name = "Crimson Spinel" },
          [ 35208 ] = { quality = 4, icon = 134940, name = "Plans: Sunblessed Gauntlets" },
          [ 35210 ] = { quality = 4, icon = 134940, name = "Plans: Sunblessed Breastplate" },
          [ 35209 ] = { quality = 4, icon = 134940, name = "Plans: Hard Khorium Battlefists" },
          [ 35211 ] = { quality = 4, icon = 134940, name = "Plans: Hard Khorium Battleplate" },
        }
      },
    }
  }
}

---@class AutoLootDbItem
---@field name string
---@field icon number
---@field quality number

---@class ResolvedAutoLootDbItem: AutoLootDbItem
---@field link string

-- The catalogue-shaped half of this module -- seeding the persisted selection db and the two
-- queries the auto-loot pass runs against it -- is shared with AutoRoundRobinDb and lives in
-- ItemCatalogue. These stay here as the names the rest of the addon already calls, and because
-- only this module knows which static catalogue is its own.
--
-- Quality -> |cffXXXXXX prefix was verified live via /rf autolootdb against real items
-- (Refreshing Spring Water, Glyph of Frost Warding, Manual Crowd Pummeler, Hydross' drops); see
-- ItemCatalogue for the table itself.
local catalogue = m.ItemCatalogue

---@param item_id number
---@param quality number
---@param name string
---@return string
function M.make_link( item_id, quality, name )
  return catalogue.make_link( item_id, quality, name )
end

-- The raw |cffXXXXXX prefix, for callers that need it rather than a fully-built item link.
---@param quality number
---@return string
function M.quality_color_hex( quality )
  return catalogue.quality_color_hex( quality )
end

---@param db table
function M.ensure_seeded( db )
  catalogue.ensure_seeded( db, ids )
end

---@param db table the persisted autoloot_db
---@param item_id number
---@return boolean
function M.is_enabled( db, item_id )
  return catalogue.is_enabled( db, item_id )
end

---@param db table the persisted autoloot_db
---@return boolean
function M.has_enabled_items( db )
  return catalogue.has_enabled_items( db )
end

-- "Trash" and "Patterns" are not bosses. Every raid has a "Trash" node, Black Temple
-- and Mount Hyjal share a "Patterns" one, and the same items are listed under several
-- of them, so the name on its own doesn't even say which raid an item came from. The
-- lookup below skips them, and the GUI greys them out the same way.
local NON_BOSSES = {
  [ "Trash" ] = true,
  [ "Patterns" ] = true
}

-- A few items belong to more than one boss even after trash is dropped, and only
-- one of those bosses can actually have dropped it: Karazhan's Opera event picks
-- one of The Big Bad Wolf / The Wizard of Oz / Romulo and Julianne per lockout
-- and all three share six items. Nothing in the item id says which one it was,
-- so the lowest (dungeon order, boss order, name) wins -- an arbitrary answer,
-- but a stable one, and stability is what a catalogue lookup owes its callers:
-- pairs() order isn't fixed, so returning the first match found would name a
-- different boss on different calls. Callers that must not guess at all screen
-- those items out beforehand; BossKilled.ignored_items does.
---@return boolean -- whether the candidate sorts ahead of the best one so far
local function sorts_first( dungeon_order, boss_order, boss_name, best )
  if not best then return true end
  if dungeon_order ~= best.dungeon_order then return dungeon_order < best.dungeon_order end
  if boss_order ~= best.boss_order then return boss_order < best.boss_order end

  return boss_name < best.boss_name
end

-- Which boss drops this item, according to the catalogue. Reads the static `ids`
-- above, not the persisted db: who drops what is a fact about the game, not
-- about what the user ticked in the autoloot GUI.
--
-- Walks the catalogue rather than keeping an item id index, for the same reason
-- the enabled/selection queries above keep none: a full walk is ~868 entries and
-- runs a handful of times per loot window, which measures at a few hundredths of
-- a millisecond. An index would only be memoising that.
---@param item_id number
---@return string? -- nil for trash drops and for anything not in the catalogue
function M.find_boss( item_id )
  if not item_id then return nil end

  local best

  for _, dungeon_entry in pairs( ids ) do
    for boss_name, boss_entry in pairs( dungeon_entry.bosses or {} ) do
      if not NON_BOSSES[ boss_name ] and boss_entry.items and boss_entry.items[ item_id ] then
        local dungeon_order, boss_order = dungeon_entry.order or 0, boss_entry.order or 0

        if sorts_first( dungeon_order, boss_order, boss_name, best ) then
          best = { dungeon_order = dungeon_order, boss_order = boss_order, boss_name = boss_name }
        end
      end
    end
  end

  return best and best.boss_name or nil
end

-- Only used by the fetch tool below (dump_to_db / on_item_info_received) -- its output is meant
-- to be inspected/pasted back, so unlike the permanent `ids` entries it also includes a real,
-- client-generated `link` (the whole point right now: reading the true |cffXXXXXX per quality off
-- of it, to replace the ITEM_QUALITY_COLORS lookup in make_link with verified values).
---@param item_id number
---@return ResolvedAutoLootDbItem?
local function resolve_item( item_id )
  local name, _, quality, _, _, _, _, _, _, texture = m.api.GetItemInfo( item_id )
  if not name then return end

  local link = m.fetch_item_link( item_id )
  if not link then return end

  return { enabled = true, name = name, icon = texture, quality = quality, link = link }
end

-- Items that resolved as nil during the last dump: item_id -> { dungeon, boss }. Retried as
-- GET_ITEM_INFO_RECEIVED fires (see on_item_info_received below) instead of requiring the
-- player to rerun the command by hand.
local pending = {}
local pending_db
local on_all_resolved

-- Separate from `pending` above: items queued by on_print_command, which just prints straight to
-- chat instead of writing anywhere -- no SavedVariables round trip needed to read the result.
local print_pending = {}

local function count_pending()
  local n = 0
  for _ in pairs( pending ) do n = n + 1 end
  return n
end

-- Lazily creates (only when there's actually something to write) the dungeon/boss scaffolding in
-- db.items and returns its items table.
local function ensure_boss_items( db, dungeon, boss )
  db.items[ dungeon ] = db.items[ dungeon ] or { enabled = true, bosses = {} }
  db.items[ dungeon ].bosses[ boss ] = db.items[ dungeon ].bosses[ boss ] or { enabled = true, items = {} }

  return db.items[ dungeon ].bosses[ boss ].items
end

-- Only fetches stub items -- ones in `ids` missing a `quality`, meaning they haven't been fully
-- resolved yet (name alone can be hardcoded from a trusted static source like AtlasLoot without
-- needing a live fetch; quality/icon can't). Already-fully-resolved items (e.g. the 14
-- Serpentshrine Cavern ones) are skipped entirely and never written to db.items, so the dump
-- output only ever contains what actually still needs fetching. Writes into db.items in the same
-- shape as `ids` so it can be pasted straight back in. GetItemInfo only returns data once the
-- client has it cached (usually near-instant after the first query); anything not cached yet is
-- tracked in `pending` and retried automatically via on_item_info_received.
---@param db table
---@return number resolved_count, number pending_count
local function dump_to_db( db )
  db.items = db.items or {}
  pending_db = db

  local resolved_count = 0

  for dungeon, dungeon_entry in pairs( ids ) do
    for boss, boss_entry in pairs( dungeon_entry.bosses or {} ) do
      for item_id, item_entry in pairs( boss_entry.items or {} ) do
        if not item_entry.quality then
          local item = resolve_item( item_id )

          if item then
            ensure_boss_items( db, dungeon, boss )[ item_id ] = item
            resolved_count = resolved_count + 1
          else
            pending[ item_id ] = { dungeon = dungeon, boss = boss }
          end
        end
      end
    end
  end

  return resolved_count, count_pending()
end

---@param db table
---@param on_done fun( resolved_count: number )? called once every pending item has resolved
--- (synchronously, with the initial resolved_count, if nothing was pending to begin with). Owns
--- no printing itself -- the caller decides what, if anything, to tell the player.
function M.on_command( db, on_done )
  local resolved_count, pending_count = dump_to_db( db )

  if pending_count > 0 then
    m.print( string.format(
      "AutoLootDb: resolved %d item(s), %d still uncached -- will keep retrying automatically as their info arrives.",
      resolved_count, pending_count
    ) )
    on_all_resolved = on_done
  else
    m.print( string.format( "AutoLootDb: resolved %d item(s), stored in the DB.", resolved_count ) )
    on_all_resolved = nil
    if on_done then on_done( resolved_count ) end
  end
end

-- Same "only stub items" scan as dump_to_db, but prints `id -> quality, icon` straight to chat
-- instead of writing to SavedVariables -- no /reload + file-digging needed to read the result.
-- Stragglers not cached yet get printed as they arrive, same as the db path.
function M.on_print_command()
  local resolved_count = 0
  local buffer = {}

  local function flush()
    if #buffer == 0 then return end
    m.print( table.concat( buffer, "   " ) )
    buffer = {}
  end

  for _, dungeon_entry in pairs( ids ) do
    for _, boss_entry in pairs( dungeon_entry.bosses or {} ) do
      for item_id, item_entry in pairs( boss_entry.items or {} ) do
        if not item_entry.quality then
          local item = resolve_item( item_id )

          if item then
            table.insert( buffer, string.format( "%d -> %d, %d", item_id, item.quality, item.icon ) )
            if #buffer >= 2 then flush() end
            resolved_count = resolved_count + 1
          else
            print_pending[ item_id ] = true
          end
        end
      end
    end
  end

  flush()

  local pending_count = 0
  for _ in pairs( print_pending ) do pending_count = pending_count + 1 end

  m.print( string.format(
    "AutoLootDb: printed %d item(s), %d still uncached -- will print as they resolve.",
    resolved_count, pending_count
  ) )
end

-- Stragglers resolve one at a time as GET_ITEM_INFO_RECEIVED fires, so this buffers them the same
-- two-per-line way on_print_command batches its own bulk output.
local print_straggler_buffer = {}

local function flush_print_stragglers()
  if #print_straggler_buffer == 0 then return end
  m.print( table.concat( print_straggler_buffer, "   " ) )
  print_straggler_buffer = {}
end

-- Hooked up to the GET_ITEM_INFO_RECEIVED event (see main.lua's on_item_info_received). Not
-- available on vanilla clients, but this raid is TBC-only so that's a non-issue here.
---@param item_id number
function M.on_item_info_received( item_id )
  if print_pending[ item_id ] then
    local item = resolve_item( item_id )

    if item then
      print_pending[ item_id ] = nil
      table.insert( print_straggler_buffer, string.format( "%d -> %d, %d", item_id, item.quality, item.icon ) )

      if #print_straggler_buffer >= 2 or not next( print_pending ) then
        flush_print_stragglers()
      end
    end
  end

  local target = pending[ item_id ]
  if not target or not pending_db then return end

  local item = resolve_item( item_id )
  if not item then return end

  ensure_boss_items( pending_db, target.dungeon, target.boss )[ item_id ] = item
  pending[ item_id ] = nil

  local remaining = count_pending()

  if remaining > 0 then
    m.print( string.format( "AutoLootDb: resolved another item, %d still pending.", remaining ) )
    return
  end

  local callback = on_all_resolved
  on_all_resolved = nil
  if callback then callback() end
end

M.ids = ids
M.non_bosses = NON_BOSSES

m.AutoLootDb = M
return M
