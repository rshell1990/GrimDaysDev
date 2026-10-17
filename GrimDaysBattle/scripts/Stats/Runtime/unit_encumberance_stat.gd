extends UnitGenericStat
## Coordinates unit encumberance stat behavior for the battle system.
class_name UnitEncumberanceStat

## Fixed base encumberance value shared by all unit encumberance stat instances.
const BASE_ENCUMBERANCE: float = 0.0
## Fixed max encumberance value shared by all unit encumberance stat instances.
const MAX_ENCUMBERANCE: float = 200.0
## Fixed to hunderad percent value shared by all unit encumberance stat instances.
const TO_HUNDERAD_PERCENT: float = 100.0

## Runtime weight state used by this unit encumberance stat.
var weight: UnitGenericStat
## Runtime weight limit state used by this unit encumberance stat.
var weight_limit: UnitWeightLimitStat
## Whether the recalculating condition currently holds.
var recalculating: bool


## Initializes this unit encumberance stat from the supplied runtime dependencies.
func setup(template: UnitStatTemplate, sender: BattleUnit) -> void:
    super(template, sender)
    weight = sender.get_stat(CombatStats.STATS.Weight)
    weight_limit = sender.get_stat(CombatStats.STATS.WeightLimit)

    if weight and weight_limit:
        weight.changed.connect(recalculate)
        weight_limit.changed.connect(recalculate)
    else:
        if not weight:
            push_error("Weight missing from stat dictionary of sender.")
        if not weight_limit:
            push_error("Weight Limit missing from stat dictionary of sender.")
        return
    recalculate()


## Recalculates recalculate for this unit encumberance stat.
func recalculate(_stat_name: StringName = &"", _amount: float = 0.0) -> void:
    if recalculating:
        return
    recalculating = true
    var load_ratio: float = weight.Current / weight_limit.Current if weight_limit.Current > 0.0 else 0.0
    _base = minf(load_ratio * TO_HUNDERAD_PERCENT, MAX_ENCUMBERANCE)
    _refresh_from_base()
    recalculating = false


## Encumberance is a capped scalar, not a partially filled resource pool.
## All inherited modifier/base mutation paths must use the same evaluation.
func _refresh_from_base(_preserve_ratio: bool = true) -> void:
    var old_current := _current
    var old_max := _max
    _max = MAX_ENCUMBERANCE
    _current = clampf(calculate_modified_value(_base), _min, _max)
    _apply_current_lock()
    _emit_change(old_current, old_max)
