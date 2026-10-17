extends ResourceTemplate
## Inclusive level band for BattleAttributeProgression. Breakthrough pools are
## granted at start_level; per-level pools begin at start_level + 1. Automatic
## attribute growth begins at start_level + 1, through end_level.
class_name LevelingTierDefinition

@export_group("Tier Bounds")
## Configures the tier name used by this leveling tier definition.
@export var tier_name: String = "New Tier"
## Configures the start level used by this leveling tier definition.
@export var start_level: int
## Configures the end level used by this leveling tier definition.
@export var end_level: int
## Skip this tier for permanent party members and MainCharacterTemplate units.
@export var npc_only: bool = false
## Attributes receiving specialization_growth in addition to ordinary growth.
@export var specialization: Array[CombatStats.STATS]

@export_group("Tier Breakthrough (Granted at start_level)")
## Spendable points for Strength, Vitality, Finesse, Perception, Endurance,
## Willpower, Mysticism and Luck at the tier breakthrough.
@export var combat_base_grant: int = 0
## Spendable Charisma/Barter points at the tier breakthrough.
@export var non_combat_base_grant: int = 0
## Earned skill-point budget; independent of attribute spending.
@export var skill_points_base_grant: int = 0

@export_group("Tier Growth (Granted per level-up inside tier)")
## Configures the combat per level used by this leveling tier definition.
@export var combat_per_level: int = 0
## Configures the non combat per level used by this leveling tier definition.
@export var non_combat_per_level: int = 0
## Configures the skill points per level used by this leveling tier definition.
@export var skill_points_per_level: int = 0

@export_group("Level Growth (Granted after the breakthrough level)")
## Automatic gain to each of the eight combat attributes, not a spendable pool.
@export var level_combat_growth: int = 0
## Additional automatic gain to each listed specialization attribute.
@export var specialization_growth: int = 0
