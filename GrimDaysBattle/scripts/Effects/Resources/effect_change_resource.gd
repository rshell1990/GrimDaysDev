extends EffectChangeStatTemplate
## Implements the runtime effect resource change template behavior used by the battle effect pipeline.
class_name EffectResourceChangeTemplate

## Enumerates the supported amount mode values.
enum AMOUNT_MODE {
    FLAT,
    PERCENT_CURRENT,
    PERCENT_MAX,
}

## Positive values restore the pool; negative values consume it or deal damage.
@export var amount: float
## Percent modes treat amount as a fraction: 0.25 means 25%.
@export var amount_mode: AMOUNT_MODE = AMOUNT_MODE.FLAT

## Absolute amounts by Action rank, in the same units as amount.
@export var amount_by_rank: PackedFloat64Array


func _get_description_value(_as_percent: bool) -> Variant:
    return amount if amount_mode == AMOUNT_MODE.FLAT else amount * 100.0
