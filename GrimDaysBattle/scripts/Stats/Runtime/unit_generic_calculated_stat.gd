extends UnitGenericStat
## Coordinates unit generic calculated stat behavior for the battle system.
class_name UnitGenericCalculatedStat
## Runtime influenced by state used by this unit generic calculated stat.
var _influenced_by: UnitGenericStat
## Whether the recalculating condition currently holds.
var recalculating: bool
## Whether the initialized condition currently holds.
var initialized: bool


## Setup a calculated stat.
func setup(template: UnitStatTemplate, sender: BattleUnit) -> void:
    super(template, sender)
    var influencing_stat_name: String = CombatStats.get_stat_as_string(template.influenced_by)
    original_template = template
    _influenced_by = sender.get_stat(template.influenced_by)
    if not _influenced_by:
        push_error("Influencing stat: " + influencing_stat_name + " not found...")
        return

    _influenced_by.changed.connect(recalculate)
    owner = sender
    _min = 0
    recalculate()


## When the influcing stat changes, recalculate this stat to reflect the new values.
func recalculate(_stat_name: StringName = &"", _amount: float = 0.0) -> void:
    if recalculating:
        return
    recalculating = true
    var calculated_base: float = original_template.calculate_base(_influenced_by.Current)
    set_calculated_base(calculated_base, initialized)
    initialized = true
    recalculating = false
