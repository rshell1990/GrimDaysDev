extends EffectTemplate
## Hands control to AI and mandates the supplied action while applied, without costs or cooldowns.
class_name EffectForceActionTemplate

const RUNTIME = preload("res://GrimDaysBattle/scenes/battle/effects/effect_force_action.tscn")

@export var action: ActionTemplate
@export_range(1, 99, 1) var action_rank: int = 1
## Absolute forced-action ranks for generated progression; short arrays hold their final value.
@export var action_rank_by_rank: PackedInt32Array
## Higher priority wins; equal priorities use the most recently applied effect.
@export var priority: int = 0


func _init() -> void:
    template_scene = RUNTIME
    lifetime = LIFETIME.UNTIL_BATTLE_END
