extends EffectChangeStatTemplate
## Adds points after scaling without raising the effective value past this grant's cap.
class_name EffectCappedChangeStatTemplate

@export var amount: float = 35.0
@export var contribution_cap: float = 90.0

## Absolute amounts by Action rank; the contribution cap remains independently authored.
@export var amount_by_rank: PackedFloat64Array


func _get_description_value(_as_percent: bool) -> Variant:
    return amount
