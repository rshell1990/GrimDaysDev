extends Object
## Coordinates combat stats behavior for the battle system.
class_name CombatStats

## Attributes eligible for authored starting-point distribution (excludes XP and Sanity).
const ATTRIBUTE_STATS := [
    STATS.Strength,
    STATS.Vitality,
    STATS.Finesse,
    STATS.Perception,
    STATS.Endurance,
    STATS.Willpower,
    STATS.Mysticism,
    STATS.Luck,
    STATS.Charisma,
    STATS.Barter
]

## BattleUnit stats that are not influenced by other stats, they changed based upon effects or player agency.
const FLAT_STATS: Array[STATS] = [
    STATS.Strength,
    STATS.Vitality,
    STATS.Finesse,
    STATS.Perception,
    STATS.Endurance,
    STATS.Willpower,
    STATS.Mysticism,
    STATS.Luck,
    STATS.Weight,
    STATS.DamageModifier,
    STATS.Experience,
    # Main Character Only
    STATS.Charisma,
    STATS.Barter,
    STATS.Sanity
]

## BattleUnit stats that are influenced by one of the FLAT_STATS.
const CALCULATED_STATS: Array[STATS] = [
    # STATS.Experience influences this:
    STATS.Level,
    # STATS.Strength influences this:
    STATS.PhysicalDamage,
    # STATS.Mysticism influences this:
    STATS.MagicDamage,
    # STATS.Vitality influences this:
    STATS.Health,
    # STATS.Vitality influences this:
    STATS.Energy,
    # STATS.Mysticism influences this:
    STATS.Mana,
    # STATS.Willpower influences this Main Character only stat:
    STATS.Lucidity,
    # STATS.Finesse influences this:
    STATS.Swiftness,
]

## BattleUnit stats that are influenced by one of the FLAT_STATS and STATS.Level from CALCULATED_STATS. These stats have
## a threshold each level that provides
## the maximum benefit for investment in the stat from FLAT_STATS that it is influenced by.
const SCALED_STATS: Array[STATS] = [
    # STATS.Endurance influences this:
    STATS.PhysicalResistance,
    # STATS.Willpower influences this:
    STATS.MagicResistance,
    # STATS.Perception influences this:
    STATS.Accuracy,
    # STATS.Finesse influences this:
    STATS.Evasion,
    # STATS.Luck influences this:
    STATS.LuckyEvasion,
    # STATS.Luck influences this:
    STATS.CriticalStrike,
    # STATS.Barter influences this Main Character only scaling stat:
    STATS.BuyingPower
]

## BattleUnit stats that have a unique calculation method.
const SPECIAL_STATS: Array[STATS] = [
    # Rounded average of Strength, Endurance and Vitality; accumulate curve gains per point.
    STATS.WeightLimit,
    # STATS.Weight and STATS.WeightLimit influence this.
    STATS.Encumberance,
]


## Returns stat as string for this combat stats.
static func get_stat_as_string(stat_id: STATS) -> String:
    return STATS.keys()[STATS.values().find(stat_id)]


## All the stats that a BattleUnit can have, some are unique to the main character of the game.
enum STATS {
    Empty = 0,
    # Attributes
    Strength = 10,
    Vitality = 20,
    Finesse = 30,
    Perception = 40,
    Endurance = 50,
    Willpower = 60,
    Mysticism = 70,
    Luck = 80,
    Charisma = 90,
    Barter = 100,
    Experience = 110,
    # Resources
    Health = 210,
    Energy = 220,
    Mana = 230,
    Lucidity = 240,
    # Combat Statistics
    Level = 300,
    PhysicalDamage = 310,
    MagicDamage = 320,
    PhysicalResistance = 330,
    MagicResistance = 335,
    Accuracy = 340,
    Evasion = 350,
    ## Finesse-derived action capacity before the BattleUnit.speed encumbrance penalty.
    Swiftness = 360,
    Weight = 370,
    WeightLimit = 372,
    Encumberance = 375,
    CriticalStrike = 380,
    LuckyEvasion = 390,
    DamageModifier = 400,
    # Main Character Only
    BuyingPower = 500,
    Sanity = 1000
}
