extends Object
## BattleUnit creation split into it's own class to remove clutter from the main BattleUnit class.
class_name BattleUnitCreation
#region CONSTANTS
## The scene file that is the template for all unit's, that will be instantiated upon a new unit's creation.
const TEMPLATE := preload("uid://e1uydvv7d2ii")
## Fixed inventory name value shared by all unit creation instances.
const INVENTORY_NAME: StringName = &"Inventory"
## Fixed inventory size value shared by all unit creation instances.
const INVENTORY_SIZE: int = 9
## Preloaded dependency used to construct or identify the template validator.
const TEMPLATE_VALIDATOR := preload(
    "res://GrimDaysBattle/scripts/Unit/Resources/battle_unit_template_validator.gd"
)


#endregion
#
## Creates and returns a configured unit creation instance.
static func create(template: BattleUnitTemplate, starting_equipment: bool = true) -> BattleUnit:
    var validation_errors: PackedStringArray = TEMPLATE_VALIDATOR.validate(template)
    if not validation_errors.is_empty():
        push_error("Cannot create battle unit:\n- %s" % "\n- ".join(validation_errors))
        return null

    var unit: BattleUnit = TEMPLATE.instantiate()
    unit.save_name = template.id
    unit.name = template.display_name
    unit.template_resource = template

    unit = init_stat_dictionary(unit, template)
    var runtime_errors: PackedStringArray = TEMPLATE_VALIDATOR.validate_runtime(unit)
    if not runtime_errors.is_empty():
        push_error("Battle unit %s failed runtime validation:\n- %s" % [template.id, "\n- ".join(runtime_errors)])
        unit.free()
        return null

    _initialize_experience(unit, template.level)
    BattleAttributeProgression.initialize(unit)

    unit.inventory = Inventory.new()
    unit.inventory.name = INVENTORY_NAME
    unit.inventory.size = INVENTORY_SIZE
    unit.inventory.initialize()
    unit.add_child(unit.inventory)
    if starting_equipment:
        BattleEquipmentLoadout.stage_starting(unit)
    return unit


## Finds the starting XP on the unit's increasing XP-to-level curve. Apply it
## after all stats exist so dependent stats update before progression grants.
static func _initialize_experience(unit: BattleUnit, starting_level: float) -> void:
    var experience := unit.get_stat(CombatStats.STATS.Experience)
    var amount := experience_for_level(unit, starting_level)
    if experience and amount >= 0:
        experience.set_base(amount)


## Shared inverse for creation and story milestones. Returns whole XP on the
## authored increasing curve, capped at its domain, or -1 for invalid definitions.
## This only computes a threshold: it never changes a unit or authored Resource.
static func experience_for_level(unit: BattleUnit, requested_level: float) -> int:
    if not is_instance_valid(unit) or not is_finite(requested_level) or requested_level < 0:
        return -1
    var level := unit.get_stat(CombatStats.STATS.Level)
    if not level:
        return -1
    var level_template := level.original_template as UnitCalculatedStatTemplate
    if not level_template or level_template.influenced_by != CombatStats.STATS.Experience:
        return -1
    var curve := level_template.growth_curve
    if not curve or curve.point_count == 0:
        return -1
    var lower: int = maxi(0, ceili(curve.min_domain))
    var upper: int = maxi(lower, ceili(curve.max_domain))
    # Find the first whole XP amount reaching the requested level, capped at
    # the authored curve's domain when the requested level is out of range.
    while lower < upper:
        var midpoint: int = lower + (upper - lower) / 2
        if level_template.calculate_base(midpoint) < requested_level:
            lower = midpoint + 1
        else:
            upper = midpoint
    return lower


## Initializes stat dictionary for this unit creation.
static func init_stat_dictionary(unit: BattleUnit, template: BattleUnitTemplate) -> BattleUnit:
    unit.stat_dictionary.clear()
    for stat_template in TEMPLATE_VALIDATOR.sort_templates(template.stats.all):
        var runtime_stat := _create_runtime_stat(stat_template)
        runtime_stat.setup(stat_template, unit)
        unit.stat_dictionary.set(stat_template.id, runtime_stat)

    return unit


## Creates runtime stat for this unit creation.
static func _create_runtime_stat(template: UnitStatTemplate) -> UnitGenericStat:
    if template.type == CombatStats.STATS.WeightLimit:
        return UnitWeightLimitStat.new()
    if template.type == CombatStats.STATS.Encumberance:
        return UnitEncumberanceStat.new()
    if template.type in CombatStats.SCALED_STATS:
        return UnitGenericScalingStat.new()
    if template.type in CombatStats.CALCULATED_STATS:
        return UnitGenericCalculatedStat.new()
    return UnitGenericStat.new()
