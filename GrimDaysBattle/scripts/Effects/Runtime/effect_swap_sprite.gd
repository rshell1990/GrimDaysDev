extends EffectBase
## Implements the runtime effect swap sprite behavior used by the battle effect pipeline.
class_name EffectSwapSprite

## Scene loaded for basic attack particle; reused instead of looking up the file on each call.
const BASIC_ATTACK_PARTICLE := preload(
    "res://GrimDaysBattle/scenes/battle/effects/basic_attack_particle.tscn"
)
## Fixed presentation timeout seconds value shared by all effect swap sprite instances.
const PRESENTATION_TIMEOUT_SECONDS: float = 5.0

## Runtime effect template state used by this effect swap sprite.
var effect_template
## Runtime affected unit state used by this effect swap sprite.
var affected_unit: BattleUnit
## Runtime resolved animation id state used by this effect swap sprite.
var animation_id: StringName
## Stable request id used to correlate or persist this effect swap sprite.
var request_id: StringName
## Runtime request serial state used by this effect swap sprite.
var request_serial: int


## Initializes this effect swap sprite from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template
    animation_id = template.sprite_scene.resource_path.get_file().get_basename()


## Applies this effect swap sprite's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    affected_unit = targeting as BattleUnit
    if not affected_unit or not effect_template or not effect_template.sprite_scene:
        (
            CustomLogger
            . error(
                self,
                apply,
                "Sprite swap requires a BattleUnit and Unit2DSprite scene.",
                CustomLogger.LEVEL.IMPORTANT,
            )
        )
        _finish_apply()
        return
    var candidate: Node = effect_template.sprite_scene.instantiate()
    if candidate is not Unit2DSprite:
        (
            CustomLogger
            . error(
                self,
                apply,
                "Sprite swap scene must instantiate Unit2DSprite.",
                CustomLogger.LEVEL.IMPORTANT,
            )
        )
        candidate.free()
        _finish_apply()
        return
    if candidate.attack_particle:
        candidate.attack_particle.play("default")
    candidate.free()
    affected_unit.add_battle_sprite_override(self, effect_template.sprite_scene)
    if not affected_unit.presentation_request.is_null():
        _request_production_attack_particle()
        _finish_apply()
        return
    if not BattleController.get_unit_display(affected_unit):
        _finish_apply()
        return
    request_serial += 1
    request_id = StringName("particles:%s:%s" % [get_instance_id(), request_serial])
    if not SignalBus.spawned_battle_particles.is_connected(on_particles_spawned):
        SignalBus.spawned_battle_particles.connect(on_particles_spawned)
    (
        SignalBus
        . spawn_battle_particles
        . emit(
            affected_unit,
            BASIC_ATTACK_PARTICLE,
            0.0,
            request_id,
            &"",
            Vector2.ZERO,
        )
    )
    (
        get_tree()
        . create_timer(PRESENTATION_TIMEOUT_SECONDS)
        . timeout
        . connect(
            on_presentation_timeout.bind(request_id),
            CONNECT_ONE_SHOT,
        )
    )


## Requests the basic attack particle through the production display request contract.
func _request_production_attack_particle() -> void:
    request_serial += 1
    request_id = StringName("particles:%s:%s" % [get_instance_id(), request_serial])
    if not affected_unit.presentation_request.is_valid():
        return
    affected_unit.presentation_request.call(
        &"particles",
        {
            "particle_scene": BASIC_ATTACK_PARTICLE,
            "lifetime_seconds": 0.0,
            "request_id": request_id,
            "animation_name": &"",
            "starting_offset": Vector2.ZERO,
        }
    )


## Handles the particles spawned notification for this effect swap sprite.
func on_particles_spawned(completed_target: Variant, completed_request_id: StringName) -> void:
    if targeting != completed_target or request_id != completed_request_id:
        return
    _disconnect_completion_signal()


## Handles the presentation timeout notification for this effect swap sprite.
func on_presentation_timeout(expected_request_id: StringName) -> void:
    if request_id != expected_request_id:
        return
    _disconnect_completion_signal()


## Disconnects completion signal for this effect swap sprite.
func _disconnect_completion_signal() -> void:
    if SignalBus.spawned_battle_particles.is_connected(on_particles_spawned):
        SignalBus.spawned_battle_particles.disconnect(on_particles_spawned)


## Reverses revoke for this effect swap sprite.
func _revoke() -> void:
    if affected_unit:
        affected_unit.remove_battle_sprite_override(self)
    affected_unit = null


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _disconnect_completion_signal()
    _revoke()
