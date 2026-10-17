extends EffectBase
## Implements the runtime effect spawn particles behavior used by the battle effect pipeline.
class_name EffectSpawnParticles

## Fixed presentation timeout seconds value shared by all effect spawn particles instances.
const PRESENTATION_TIMEOUT_SECONDS: float = 1.0

## Runtime effect template state used by this effect spawn particles.
var effect_template
## Stable request id used to correlate or persist this effect spawn particles.
var request_id: StringName
## Runtime request serial state used by this effect spawn particles.
var request_serial: int


## Initializes this effect spawn particles from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template


## Applies this effect spawn particles's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    if not effect_template or not effect_template.particle_scene:
        CustomLogger.error(
            self, apply, "Particle effect %s requires a particle scene." % id, CustomLogger.LEVEL.IMPORTANT
        )
        _finish_apply()
        return
    if not targeting or not is_instance_valid(targeting):
        _finish_apply()
        return
    # The production display owns spawned nodes and their cleanup, not this effect.
    if targeting is BattleUnit and not targeting.presentation_request.is_null():
        request_serial += 1
        request_id = StringName("particles:%s:%s" % [get_instance_id(), request_serial])
        if targeting.presentation_request.is_valid():
            targeting.presentation_request.call(
                &"particles",
                {
                    "particle_scene": effect_template.particle_scene,
                    "lifetime_seconds": effect_template.lifetime_seconds,
                    "request_id": request_id,
                    "animation_name": effect_template.animation_name,
                    "starting_offset": effect_template.starting_offset
                }
            )
        if effect_template.lifetime_seconds > 0.0:
            await get_tree().create_timer(effect_template.lifetime_seconds).timeout
        _finish_apply()
        return
    if targeting is BattleUnit and not BattleController.get_unit_display(targeting):
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
            targeting,
            effect_template.particle_scene,
            effect_template.lifetime_seconds,
            request_id,
            effect_template.animation_name,
            effect_template.starting_offset,
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


## Handles the particles spawned notification for this effect spawn particles.
func on_particles_spawned(completed_target: Variant, completed_request_id: StringName) -> void:
    if targeting != completed_target or request_id != completed_request_id:
        return
    _disconnect_completion_signal()
    _finish_apply()


## Handles the presentation timeout notification for this effect spawn particles.
func on_presentation_timeout(expected_request_id: StringName) -> void:
    if finished or request_id != expected_request_id:
        return
    _disconnect_completion_signal()
    _finish_apply()


## Disconnects completion signal for this effect spawn particles.
func _disconnect_completion_signal() -> void:
    if SignalBus.spawned_battle_particles.is_connected(on_particles_spawned):
        SignalBus.spawned_battle_particles.disconnect(on_particles_spawned)


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _disconnect_completion_signal()
