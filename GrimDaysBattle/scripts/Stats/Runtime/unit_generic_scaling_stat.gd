extends UnitGenericStat

## A stat whose value scales with another stat and the owning unit's level.
##
## The configured level curve determines how much of the influencing stat is
## needed to cap the attribute-derived base at the owner's current level.
## Direct defensive grants apply afterward and may exceed this authored base cap.
class_name UnitGenericScalingStat

## The stat whose current value determines this stat's scaled value.
var _influenced_by: UnitGenericStat
## The owner's level stat, used to sample the maximum-threshold curve.
var _level_stat: UnitGenericStat
## Prevents changes made during recalculation from recursively recalculating the stat.
var recalculating: bool
## Whether the initialized condition currently holds.
var initialized: bool


## Initializes the stat from [param template] and connects it to its influencing
## and level stats on [param sender].
func setup(template: UnitStatTemplate, sender: BattleUnit) -> void:
    super(template, sender)
    var influencing_stat_name: String = CombatStats.get_stat_as_string(template.influenced_by)
    original_template = template
    _influenced_by = sender.get_stat(template.influenced_by)
    if not _influenced_by:
        push_error("Influencing stat: " + influencing_stat_name + " not found...")
        return

    var level_stat_name: String = CombatStats.get_stat_as_string(CombatStats.STATS.Level)
    _level_stat = sender.get_stat(CombatStats.STATS.Level)
    if not _level_stat:
        push_error("Level stat: " + level_stat_name + " not found...")
        return

    _influenced_by.changed.connect(recalculate)
    _level_stat.changed.connect(recalculate)

    owner = sender
    _min = 0
    recalculate()


## Recalculates the base, maximum, and current values from the influencing stat
## and the level-dependent threshold. Active modifiers remain in the stat ledger.
func recalculate(_stat_name: StringName = &"", _amount: float = 0.0) -> void:
    if recalculating:
        return
    recalculating = true
    var amount_needed_for_maximum: float = snappedf(
        original_template.to_stat_maximum_curve.sample(_level_stat.Current), 1.0
    )
    var minimum_for_scaling_stat: float = original_template.minimum
    var maximum_for_scaling_stat: float = original_template.maximum
    var range_of_base: float = maximum_for_scaling_stat - minimum_for_scaling_stat
    var percentage_to_maximum := 1.0
    if amount_needed_for_maximum > 0.0:
        percentage_to_maximum = clampf(_influenced_by.Current / amount_needed_for_maximum, 0.0, 1.0)
    var calculated_base := minimum_for_scaling_stat + (range_of_base * percentage_to_maximum)
    set_calculated_base(calculated_base, initialized)
    initialized = true
    recalculating = false
