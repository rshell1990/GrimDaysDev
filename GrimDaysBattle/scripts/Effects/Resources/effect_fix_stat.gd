extends EffectChangeStatTemplate
## Holds Current at an exact value until this effect is removed; does not change Base or Max.
class_name EffectFixStatTemplate

const RUNTIME = preload("res://GrimDaysBattle/scenes/battle/effects/effect_fix_stat.tscn")

@export var value: float = 0.0
## Capture the recipient's Current value on first application instead of using the authored value.
@export var capture_current: bool = false
## Higher priority wins; equal priorities use the most recently applied lock.
@export var priority: int = 0


func _init() -> void:
    template_scene = RUNTIME
    lifetime = LIFETIME.UNTIL_BATTLE_END


func _get_description_value(_as_percent: bool) -> Variant:
    return null if capture_current else value
