# Item Catalog

Catalog of the GrimDays item definitions, imported as item resources in both Godot projects.

- **245 unique item IDs** after deduplication, plus nine recipe outputs without source definitions. All 254 entries are imported.
- Runtime resources are registered in `GrimDaysBattle/resources/items/_equipment.tres` and
  `GrimDaysVN/resources/items/imported/all_items.tres`.
- Imported item names and IDs come from this catalog. The original `.rpy` definitions were not available in the workspace,
  so battle stats, use effects, stack sizes, prices, and descriptions are generated defaults, not recovered source values.
- The recipe file contains **114 outputs**; nine have no item definition in the supplied `.rpy` files and are listed separately below.
- Compiled `.rpyc` files were not read; the editable `.rpy` sources are authoritative. The passive-skill file defines a skill-learning helper, not an item, so it is not listed as an item.
- Weapon family index: `sword`, `greatsword`, `axe`, `dagger`, `knuckle`, `liquid_reagent`, `polearm`, `bow`, `crossbow`, `wand`, `staff`, `tome`.
- Duplicate source definitions were deduplicated by item ID: `sword_2h`, `orc_tribal_axe`, `ves_family_axe`, `book_legends_far_wide`.

## Currency

- Gold — `gold`

## Armor

- Leather armor — `leather_armor`
- Scout armor — `scout_armor`
- Plate armor — `father_armor_item`
- Reinforced leather armor — `reinforced_leather_armor` (craftable)
- Chainmail — `chainmail` (craftable)
- Bronze armor — `bronze_armor` (craftable)
- Iron armor — `iron_armor` (craftable)
- Steel armor — `steel_armor` (craftable)
- Syaxian armor — `syaxian_armor` (craftable)
- Inquisitor uniform — `inquisitor_uniform`
- Orc tribal wear — `orc_tribal_wear`
- Duskshroud Raiment — `duskshroud_raiment`
- Bronlite armor — `bronlite_armor` (craftable)
- Reinforced desert robes — `reinf_desert_robes` (craftable)
- Order of Xeriya armor — `xeriya_armor`
- Faymore armor — `faymore_armor`

## Axes and greatswords

- Scout axe — `scout_axe` (craftable)
- Goblin axe — `goblin_axe` (craftable)
- Two-handed steel axe — `axe_2h` (craftable)
- Bronze axe — `bronze_axe` (craftable)
- Iron axe — `iron_axe` (craftable)
- Steel axe — `steel_axe` (craftable)
- Syaxian axe — `syaxian_axe` (craftable)
- Inquisitor axe — `axe_inquisitor`
- Corrupted axe — `corrupted_axe`
- Bronlite axe — `bronlite_axe` (craftable)

## Books and skill books

- A Brief History of the Dragon Wars — `book_dragonwars`
- The Evils of Dark Mages, Vol 6 — `book_darkmages`
- General Newheart, Hero of Destiny — `book_newheart`
- Mages, an introductory guide — `book_mageguide`
- The Prince of Onji — `book_prince_onji`
- Legends far and wide — `book_legends_far_wide`
- A history of Alderian houses — `book_thornfall`
- Notes on traders and slavers — `book_notes_on_slavers`
- Dreams of Astatar — `book_dreams_of_astatar`
- The First Darkness — `book_the_first_darkness`
- Loving Ophelia — `book_loving_ophelia`
- Knight Skill Book — `skill_book_knight`
- Swordsman Skill Book — `skill_book_swordsman`
- Summoner Skill Book — `skill_book_summoner`
- Priest Skill Book — `skill_book_priest`
- Saint Skill Book — `skill_book_Saint`

## Bows and crossbows

- Shortbow — `shortbow` (craftable)
- Hunting Bow — `hunting_bow` (craftable)
- Longbow — `longbow` (craftable)
- Composite Bow — `composite_bow` (craftable)
- Syaxian Warbow — `syaxian_warbow` (craftable)
- Hand Crossbow — `hand_crossbow` (craftable)
- Hunting Hand Crossbow — `hunting_crossbow` (craftable)
- Iron Hand Crossbow — `iron_crossbow` (craftable)
- Steel Hand Crossbow — `steel_crossbow` (craftable)
- Syaxian Hand Crossbow — `syaxian_crossbow` (craftable)

## Consumables

### Status-effect bomb mechanics

These are approved prototype defaults, not values recovered from the original
source game. Each normal bomb targets one living foe; its `_area` burst version
automatically targets all living foes. A normal bomb has base impact damage 18;
a burst has base impact damage 12 per foe.

| Bomb pair | Impact type | Status |
| --- | --- | --- |
| Fire | Magic | Burn: base 4 magic damage at two round ends |
| Ice | Magic | Freeze: cannot act until the next round boundary |
| Lightning | Magic | Stun: cannot act until the next round boundary |
| Poison | Physical | Poison: 6 true damage at three round ends |

Magic/physical damage uses the existing damage variance, resistance and Health
rounding rules. True damage ignores resistance. Bomb impacts always hit, and
statuses attach only to surviving hit recipients. A burst consumes one bomb,
not one per foe; invalid target requests do not consume it.

Single and burst variants share their status identity. Reapplication refreshes
duration without multiplying damage ticks, including across different casters.
Burn and poison tick once per round, not on attachment. Freeze/stun stop new
actions but do not interrupt actions already resolving; one round means the
next round boundary, not a guaranteed future turn. All four statuses expire and
are removed by battle cleanup. Item IDs and save formats are unchanged.
Goblin bombs remain damage-only; the legacy numeric-ID Basic Bomb is not one of
these eight catalog entries.

Battle resources supply executable behavior. The corresponding VN resources
retain matching descriptions and `use_effects` metadata; VN metadata is not a
second combat executor.

- Minor Health Potion — `potion_heal_minor` (craftable)
- Regular Health Potion — `potion_heal_regular` (craftable)
- Large Health Potion — `potion_heal_large` (craftable)
- Very Large Health Potion — `potion_heal_vlarge` (craftable)
- Goblin bomb — `goblin_bomb` (craftable)
- Goblin Scrapnel bomb — `goblin_scrapnelbomb` (craftable)
- Fire bomb — `fire_bomb` (craftable)
- Ice bomb — `ice_bomb` (craftable)
- Lightning bomb — `lightning_bomb` (craftable)
- Poison bomb — `poison_bomb` (craftable)
- Fire burst bomb — `fire_bomb_area` (craftable)
- Ice burst bomb — `ice_bomb_area` (craftable)
- Lightning burst bomb — `lightning_bomb_area` (craftable)
- Poison burst bomb — `poison_bomb_area` (craftable)
- Bunch of grapes — `grapes`
- Goblin Stimulants — `goblin_stims`
- The dreams of Ashara - A love story — `elena_gift_book`
- A small slime jar — `myu_gift_jar`
- Ramonian Twister — `ramonian_twister`
- Raza seed — `raza_seed`
- Strange meat — `strange_meat`
- Antidote — `potion_antidote` (craftable)
- Low Revive Potion — `potion_lowrevive` (craftable)
- Mid Revive Potion — `potion_midrevive` (craftable)
- High Revive Potion — `potion_highrevive` (craftable)
- Low Ether Potion — `potion_lowether` (craftable)
- Mid Ether Potion — `potion_midether` (craftable)
- High Ether Potion — `potion_highether` (craftable)
- Low Elixer — `potion_lowelixer` (craftable)
- Mid Elixer — `potion_midelixer` (craftable)
- High Elixer — `potion_highelixer` (craftable)
- Soul Fragment of Strength — `soul_fragment_strength`
- Soul Fragment of Endurance — `soul_fragment_endurance`
- Soul Fragment of Willpower — `soul_fragment_willpower`
- Soul Fragment of Agility — `soul_fragment_agility`
- Soul Fragment of Dexterity — `soul_fragment_dexterity`
- Soul Fragment of Luck — `soul_fragment_luck`
- Soul Fragment of Charisma — `soul_fragment_charisma`
- Soul Fragment of Barter — `soul_fragment_barter`
- Soul Fragment of Mana Power — `soul_fragment_mana_power`

## Magic weapons

- novice wand — `scout_wand` (craftable)
- Goblin wand — `goblin_wand` (craftable)
- Basic stick — `basic_stick` (craftable)
- Refined wand — `refined_wand` (craftable)
- Elder wand — `elder_wand` (craftable)
- Master wand — `master_wand` (craftable)
- Corrupted wand — `corrupted_wand`
- Scout staff — `scout_staff` (craftable)
- Rusty scout staff — `scout_staff_rusty` (craftable)
- Goblin staff — `goblin_staff` (craftable)
- Basic staff — `basic_staff` (craftable)
- Refined staff — `refined_staff` (craftable)
- Elder staff — `elder_staff` (craftable)
- Master staff — `master_staff` (craftable)
- Corrupted staff — `corrupted_staff`
- Basic tome — `basic_tome` (craftable)
- Decayed tome — `decayed_tome` (craftable)
- Goblin tome — `goblin_tome` (craftable)
- Leather tome — `leather_tome` (craftable)
- Elemental tome — `elemental_tome` (craftable)
- Elder tome — `elder_tome` (craftable)
- Master tome — `master_tome` (craftable)
- Corrupted tome — `corrupted_tome`

## Melee weapons

- Two-handed steel sword — `sword_2h` (craftable)
- Orc tribal axe — `orc_tribal_axe` (craftable)
- Ves family axe — `ves_family_axe`
- Alderian officer sword — `nyx_gift_sword`
- Scout sword — `scout_sword` (craftable)
- Rusty scout sword — `scout_sword_rusty` (craftable)
- Goblin cleaver — `goblin_cleaver` (craftable)
- Simple greatsword — `simple_greatsword` (craftable)
- Bronze greatsword — `bronze_greatsword` (craftable)
- Iron greatsword — `iron_greatsword` (craftable)
- Steel greatsword — `steel_greatsword` (craftable)
- Syaxian greatsword — `syaxian_greatsword` (craftable)
- Tarek's blade — `tarek_blade`
- Bronze sword — `bronze_sword` (craftable)
- Iron sword — `iron_sword` (craftable)
- Steel sword — `steel_sword` (craftable)
- Syaxian sword — `syaxian_sword` (craftable)
- Inquisitor blade — `sword_inquisitor`
- Corrupted blade — `corrupted_blade`
- Simple knife — `simple_knife` (craftable)
- Hunting knife — `hunting_knife` (craftable)
- Iron dagger — `iron_dagger` (craftable)
- Steel dagger — `steel_dagger` (craftable)
- Syaxian dagger — `syaxian_dagger` (craftable)
- Bronlite dagger — `bronlite_dagger` (craftable)
- Bronlite sword — `bronlite_sword` (craftable)
- Simple spear — `simple_spear` (craftable)
- Bronze spear — `bronze_spear` (craftable)
- Iron spear — `iron_spear` (craftable)
- Steel spear — `steel_spear` (craftable)
- Syaxian spear — `syaxian_spear` (craftable)
- Spear of Xeriya — `xeriya_spear`
- Faymore blade — `faymore_blade`

## Shields

- Alderian officer shield — `nyx_gift_shield`
- Scout shield — `scout_shield` (craftable)
- Rusty scout shield — `scout_shield_rusty` (craftable)
- Goblin shield — `goblin_shield` (craftable)
- Tarek's shield — `tarek_shield`
- Bronze shield — `bronze_shield` (craftable)
- Iron shield — `iron_shield` (craftable)
- Steel shield — `steel_shield` (craftable)
- Syaxian shield — `syaxian_shield` (craftable)
- Inquisitor shield — `shield_inquisitor`
- Corrupted shield — `corrupted_shield`
- Bronlite shield — `bronlite_shield` (craftable)
- Shield of Xeriya — `xeriya_shield`
- Faymore shield — `faymore_shield`

## Rings and amulets

- Amplifier Amulet — `divine_gift_amulet`
- Heart Amulet — `arlena_gift_amulet`
- Protection Amulet — `amulet_protection`
- Inquisitor ring of divine protection — `ring_inquisitor`
- A ruby ring — `dros_gift`
- Infernium ring — `infernium_ring`
- Elven house insignia ring — `elven_house_insignia_ring`
- Orc tribal necklace — `orc_tribal_necklace`
- Shadow ring — `shadow_ring`
- Ring of Wealth — `ring_of_wealth` (craftable)
- Half-Heart locket — `lovers_locket`
- Ring of Power — `ring_1`

## Quest items

- Power Crystal — `qst_dros_power_crystal`
- Regina's Package — `qst_regina_package`
- Bloodied Scroll — `qst_tarek_bloody_scroll`
- Dravenham's Key — `qst_draven_key`
- Slimelark Jar — `qst_slime_jar`
- An assortment of herbs — `qst_rebirth_herbs`
- Medicine bag — `qst_green_fever_meds`
- Amira's Tears — `qst_amiras_tears`
- Raza — `qst_raza_bottle`
- A pile of books — `qst_myu_books`
- Wildflowers — `qst_wild_flowers`
- Sweet Roll — `qst_sweet_roll`
- A bottle of wine — `qst_wine_bottle`
- Mysterious Gem — `qst_kraken_gem`
- Ransom money — `qst_ransom_money`
- Captain Nyx's panties — `qst_nyx_panties`
- Nyx's room key — `qst_nyx_room_key`
- A toy for Mrs. Winward — `qst_winward_plug`
- A parcel for Vala — `qst_vala_parcel`
- Valchek's marble eye — `qst_valchek_eye`
- Golden token — `qst_tarbeck_golden_token`
- Strange circular device — `qst_strange_circular_device`
- Bloodwake vial — `qst_bigtroub_poison_device`
- Wedding lingerie — `qst_marbella_wedding_ling`
- Single rose — `qst_marbella_flowers`
- Simple ring — `qst_marbella_ring`
- Butterfly sigil invitation letter — `qst_butterfly_letter`
- A strange totem — `qst_strange_totem`
- Small mysterious key — `qst_small_myst_key`
- Red skull key — `qst_red_skull_key`
- Green skull key — `qst_green_skull_key`
- Blue skull key — `qst_blue_skull_key`
- Pink skull key — `qst_pink_skull_key`
- Purple skull key — `qst_purple_skull_key`
- Small key (dragon) — `qst_dragon_key`
- Dull key — `qst_dull_key`
- Diamond shaped key — `qst_diamond_key`
- Tree-shaped key — `qst_small_tree_key`
- White demon-shaped key — `qst_white_demon_key`
- Red demon-shaped key — `qst_red_demon_key`
- Orange demon-shaped key — `qst_orange_demon_key`
- Blue demon-shaped key — `qst_blue_demon_key`
- Snake key — `qst_snake_key`
- Gator key — `qst_gator_key`
- Cat key — `qst_cat_key`
- Raven key — `qst_raven_key`
- Wolf key — `qst_wolf_key`
- Dark Mage Grimoire — `qst_darkmage_grimoire`
- Emperor's Hand Pin — `qst_emperors_hand_pin`

## Materials and miscellaneous

- Bronze scraps — `bronze_scraps`
- Gems — `gems`
- Raw gems — `raw_gems`
- Slimelark remains — `slimelark_remains`
- Red meat — `red_meat`
- Dark Mage design notes — `darkmage_design_notes`
- Animal hide — `animal_hide`
- White bear hide — `white_bear_hide`
- Iron ore — `iron_ore`
- Copper ore — `copper_ore`
- Leather — `leather`
- Syax ore — `syax_ore`
- Cow hide — `cow_hide`
- Royal Decree — `royal_decree`
- Bronze pickaxe — `bronze_pickaxe`
- Iron pickaxe — `iron_pickaxe`
- Syax pickaxe — `syax_pickaxe`
- Strange crystal — `spaceship_crystal`
- Rune of Quickness — `rune_of_quickness`
- Rune of Power — `rune_of_power`
- Rune of Defense — `rune_of_defense`

## Recipe outputs without supplied item definitions

These IDs occur in `craft_recipes.rpy` and `weapon_families.rpy`, but no item definition for them was present in the supplied `.rpy` files:

- Simple knuckles — `simple_knuckles`
- Bronze knuckles — `bronze_knuckles`
- Iron knuckles — `iron_knuckles`
- Steel knuckles — `steel_knuckles`
- Syaxian knuckles — `syaxian_knuckles`
- Fire reagent set — `fire_reagent_set`
- Ice reagent set — `ice_reagent_set`
- Lightning reagent set — `lightning_reagent_set`
- Poison reagent set — `poison_reagent_set`

Two additional weapon-family references have no matching definition or recipe output in the supplied files: `shadowreach` and `star_bringer`.

## Source files

Item definitions: `base_item_def.rpy`, `item_defs_armor.rpy`, `item_defs_axes.rpy`, `item_defs_book.rpy`, `item_defs_bows.rpy`, `item_defs_consumable.rpy`, `item_defs_magic_weapons.rpy`, `item_defs_passiveskills.rpy`, `item_defs_quest.rpy`, `item_defs_resources.rpy`, `item_defs_rings_amulets.rpy`, `item_defs_shields.rpy`, and `item_defs_weapons.rpy`.
Crafting annotations come from `craft_recipes.rpy`; weapon families come from `weapon_families.rpy`.
