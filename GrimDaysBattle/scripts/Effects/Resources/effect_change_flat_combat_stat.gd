extends EffectChangeStatTemplate
## Implements the runtime effect flat change stat template behavior used by the battle effect pipeline.
class_name EffectFlatChangeStatTemplate

## Configures the flat amount used by this effect flat change stat template.
@export var flat_amount: float

## Absolute amounts by Action rank. Empty uses flat_amount; short lists hold the final value.
@export var flat_amount_by_rank: PackedFloat64Array


func _get_description_value(_as_percent: bool) -> Variant:
    return flat_amount
