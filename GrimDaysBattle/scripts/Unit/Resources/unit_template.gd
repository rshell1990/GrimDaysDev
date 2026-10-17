# Editor configuration for BattleUnitTemplate.
@tool
extends ResourceTemplate
#region UNIT TEMPLATE
## The resource to create a battle unit template, that will then create a unit in the game.
##
class_name BattleUnitTemplate
#endregion

#region BASIC

@export_group("Basic")
## The name displayed in the UI for the unit.
@export var display_name: String

## The 'class' that the unit belongs to.
@export_enum("Warrior", "Mage", "Hybrid") var unit_archetype: String

## The default level for the unit.
@export_range(0.0, 80.0, 1.0) var level: float

## Flags the unit as one that should be created upon a new game, and then their data saved.
@export var permanent: bool
#endregion

@export_group("Visual")
## The portrait for the unit.
@export var portrait: Texture2D

## The scene that contains the graphics for the unit when deployed in battle.
@export var battle_sprite: PackedScene

## The basic action that a unit uses to attack.
@export var basic_action_template: ActionTemplate

## Optional unique action assigned to this unit; null means no special action.
@export var special_action: ActionTemplate = null

@export_group("Leveling")
## Experience granted to each deployed party member when this original foe is
## defeated in an accepted victory. This is not the foe's own Experience stat.
@export_range(0, 2147483647, 1) var experience_reward: int = 0
## Project-owned definitions; the sole skill purchase authority.
@export var skill_collection: BattleSkillTreeCollection

## The attribute growth per level, divided into tiers.
@export var leveling_tiers: LevelingTierDefinitionCollection

#region RESOURCES
## Configures the stats used by this unit template.
@export var stats: UnitStatTemplateCollection

## Reroll 48 starting points plus earned tier pools. Automatic growth remains runtime-only.
@export_tool_button("Randomize Attribute Points") var randomize_attributes_button: Callable = randomize_attribute_points
## Tier pool points already baked into starting_amount by the helper; excluded from runtime spending.
@export_storage var starting_attribute_points_spent: Dictionary = {}

@export_group("Effects")
## Effects that inherently belong to every runtime unit created from this
## template. These effects are reconstructed with the unit and remain active
## for as long as their template is assigned.
@export var intrinsic_effects: Array[EffectTemplate]

#endregion
#region EQUIPMENT
## The starting equipment that is equipped to the unit.
@export var equipment: EquipmentTemplateCollection


## Rebuild starting attributes without baking in runtime automatic growth.
## Each attribute gets one ticket, plus two for specialization and two for archetype preference.
## Updates existing attribute resources in place after validating the whole allocation.
func randomize_attribute_points(rng: RandomNumberGenerator = null) -> bool:
	if not stats or not leveling_tiers or leveling_tiers.all.is_empty() or not leveling_tiers.all[0]:
		push_warning("Attribute distribution requires stats and a first leveling tier.")
		return false
	if not is_finite(level) or level < 0 or level > 80:
		push_warning("Attribute distribution requires a level between 0 and 80.")
		return false
	var combat: Array[UnitStatTemplate] = []
	var non_combat: Array[UnitStatTemplate] = []
	var amounts: Dictionary = {}
	var seen := {}
	for stat: UnitStatTemplate in stats.all:
		if not stat:
			continue
		var stat_id: int = stat.type
		if stat_id not in CombatStats.ATTRIBUTE_STATS:
			continue
		if seen.has(stat_id):
			push_warning("Attribute distribution requires unique attribute types.")
			return false
		seen[stat_id] = true
		amounts[stat] = 0
		if stat_id in [CombatStats.STATS.Charisma, CombatStats.STATS.Barter]:
			non_combat.append(stat)
		else:
			combat.append(stat)
	if combat.is_empty():
		push_warning("Attribute distribution requires combat attributes.")
		return false
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	_distribute_attribute_pool(combat + non_combat, 48, leveling_tiers.all[0].specialization, rng, amounts)
	var spent := {"combat": 0, "non_combat": 0}
	for attained_level in range(0, int(floor(level)) + 1):
		for tier in leveling_tiers.all:
			if not tier or tier.start_level < 0 or tier.end_level < tier.start_level:
				continue
			if attained_level < tier.start_level or attained_level > tier.end_level:
				continue
			if tier.npc_only and (permanent or self is MainCharacterTemplate):
				continue
			var breakthrough: bool = attained_level == tier.start_level
			var combat_points: int = maxi(tier.combat_base_grant if breakthrough else tier.combat_per_level, 0)
			var social_points: int = maxi(tier.non_combat_base_grant if breakthrough else tier.non_combat_per_level, 0)
			if social_points > 0 and non_combat.is_empty():
				push_warning("Non-combat grants require Charisma or Barter; no stats were changed.")
				return false
			_distribute_attribute_pool(combat, combat_points, tier.specialization, rng, amounts)
			_distribute_attribute_pool(non_combat, social_points, tier.specialization, rng, amounts)
			spent.combat += combat_points
			spent.non_combat += social_points
	starting_attribute_points_spent = spent
	for stat: UnitStatTemplate in amounts:
		stat.starting_amount = amounts[stat]
	for stat: UnitStatTemplate in amounts:
		stat.emit_changed()
	stats.emit_changed()
	emit_changed()
	notify_property_list_changed()
	return true


## Archetype preference stacks additively with tier specialization.
const ARCHETYPE_ATTRIBUTES := {
	"Warrior":
	[CombatStats.STATS.Strength, CombatStats.STATS.Vitality, CombatStats.STATS.Endurance, CombatStats.STATS.Perception],
	"Mage":
	[CombatStats.STATS.Mysticism, CombatStats.STATS.Willpower, CombatStats.STATS.Perception, CombatStats.STATS.Finesse],
	"Hybrid":
	[CombatStats.STATS.Strength, CombatStats.STATS.Mysticism, CombatStats.STATS.Vitality, CombatStats.STATS.Perception],
}


## Spend each point once. Weights are 1 (ordinary), 3 (one preference), or 5 (both).
## Unknown archetypes retain specialization-only weighting.
func _distribute_attribute_pool(
	attributes: Array[UnitStatTemplate],
	points: int,
	specializations: Array[CombatStats.STATS],
	rng: RandomNumberGenerator,
	amounts: Dictionary
) -> void:
	var tickets: Array[UnitStatTemplate] = []
	var preferred: Array = ARCHETYPE_ATTRIBUTES.get(unit_archetype, [])
	for attribute in attributes:
		tickets.append(attribute)
		if attribute.type in specializations:
			tickets.append(attribute)
			tickets.append(attribute)
		if attribute.type in preferred:
			tickets.append(attribute)
			tickets.append(attribute)
	for point in points:
		var selected: UnitStatTemplate = tickets[rng.randi_range(0, tickets.size() - 1)]
		amounts[selected] += 1
