extends EffectChangeStatTemplate
## Implements the runtime effect percentage change stat template behavior used by the battle effect pipeline.
class_name EffectPercentageChangeStatTemplate

## Fractional additive percentage: 0.15 grants +15%, while -0.15 removes 15%.
@export var percentage: float

## Absolute fractions by Action rank. Empty uses percentage; short lists hold the final value.
@export var percentage_by_rank: PackedFloat64Array


func _get_description_value(_as_percent: bool) -> Variant:
    return percentage * 100.0
