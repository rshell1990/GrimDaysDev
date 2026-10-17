extends AnimationPlayer
## Coordinates battle animation player behavior for the battle system.
class_name BattleAnimationPlayer

## Scene loaded for basic attack particle; reused instead of looking up the file on each call.
const BASIC_ATTACK_PARTICLE := preload(
    "res://GrimDaysBattle/scenes/battle/effects/basic_attack_particle.tscn"
)


## Requests the basic attack particle for the unit owning this animation player.
func play_basic_attack_particle() -> void:
    SignalBus.spawn_battle_particles.emit(
        get_parent().unit_reference,
        BASIC_ATTACK_PARTICLE,
        0.0,
        StringName("basic_attack_particle:%s" % get_instance_id()),
        &"",
        Vector2.ZERO,
    )
