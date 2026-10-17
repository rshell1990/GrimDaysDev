extends UnitGenericStat
## Coordinates unit weight limit stat behavior for the battle system.
class_name UnitWeightLimitStat
## Ordered runtime collection of influenced by.
var _influenced_by: Array[UnitGenericStat]
## Whether the recalculating condition currently holds.
var recalculating: bool
## Whether the initialized condition currently holds.
var initialized: bool


## Setup the weight limit stat.
func setup(template: UnitStatTemplate, sender: BattleUnit) -> void:
    super(template, sender)
    for stat in template.influenced_by:
        var influencing_stat_name: String = CombatStats.get_stat_as_string(stat)
        original_template = template
        if sender.stat_dictionary.has(influencing_stat_name):
            var generic_stat: UnitGenericStat = sender.get_stat(stat)
            _influenced_by.append(generic_stat)
            generic_stat.changed.connect(recalculate)

        else:
            push_error("Influencing stat: " + influencing_stat_name + " not found...")

    owner = sender
    _min = 0
    recalculate()


## When the influencing stats changes, recalculate the weight limit to reflect the new values.
func recalculate(_stat_name: StringName = &"", _amount: float = 0.0) -> void:
    if recalculating:
        return
    recalculating = true
    if _influenced_by.is_empty():
        push_error("WeightLimit requires at least one influencing stat.")
        recalculating = false
        return
    var total: int = 0

    for stat in _influenced_by:
        total += stat.Current

    var averaged_current: int = int(snappedf(total / _influenced_by.size(), 1.0))

    # Preserve the authored rounded-average dependency policy, then accumulate
    # each point's carrying-capacity gain just like other attribute-derived stats.
    var calculated_base: float = (
        original_template.starting_amount
        + UnitCalculatedStatTemplate.cumulative_growth(original_template.growth_curve, averaged_current)
    )
    set_calculated_base(calculated_base, initialized)
    initialized = true
    recalculating = false
