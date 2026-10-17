extends EffectTemplate
## Skips action selection while applied. One round expires at the next round boundary.
class_name EffectStunTemplate

const RUNTIME = preload("res://GrimDaysBattle/scenes/battle/effects/effect_stun.tscn")


func _init() -> void:
    template_scene = RUNTIME
    lifetime = LIFETIME.ROUNDS
    duration = 1
