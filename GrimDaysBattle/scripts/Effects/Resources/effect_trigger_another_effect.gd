extends EffectTemplate
#region EFFECT CHAIN
## Template to store data related to an effect that will cause multiple effects to trigger at once.
##
##
class_name EffectTriggerAnotherEffect
#endregion

#region VARIABLES
## Chance to apply.
@export var chance: int = 100
## Absolute 0-100 percentages by Action rank; empty uses chance, short lists hold the last value.
@export var chance_by_rank: PackedInt32Array
## The effects triggered by this effect.
@export var triggers: Array[EffectTemplate]
## Inclusive repeat bounds. Equal bounds produce a fixed count; chance is rolled once for the sequence.
@export_range(1, 99, 1) var repeat_min: int = 1
@export_range(1, 99, 1) var repeat_max: int = 1
## Absolute total execution counts per generated Action rank; empty arrays retain scalar bounds.
@export var repeat_min_by_rank: PackedInt32Array
@export var repeat_max_by_rank: PackedInt32Array
#endregion


func _get_description_value(_as_percent: bool) -> Variant:
    return chance
