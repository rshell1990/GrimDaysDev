extends EffectBase
## Implements the runtime effect trigger sound behavior used by the battle effect pipeline.
class_name EffectTriggerSound

## Fixed presentation timeout seconds value shared by all effect trigger sound instances.
const PRESENTATION_TIMEOUT_SECONDS: float = 1.0

## Runtime effect template state used by this effect trigger sound.
var effect_template
## Stable request id used to correlate or persist this effect trigger sound.
var request_id: StringName
## Runtime request serial state used by this effect trigger sound.
var request_serial: int


## Initializes this effect trigger sound from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template


## Applies this effect trigger sound's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    if not effect_template or not effect_template.sound:
        CustomLogger.error(self, apply, "Sound effect %s requires an audio stream." % id, CustomLogger.LEVEL.IMPORTANT)
        _finish_apply()
        return
    if not targeting or not is_instance_valid(targeting):
        _finish_apply()
        return
    # Production dispatch is non-blocking and never consults the debug adapter.
    if targeting is BattleUnit and not targeting.presentation_request.is_null():
        request_serial += 1
        request_id = StringName("sound:%s:%s" % [get_instance_id(), request_serial])
        if targeting.presentation_request.is_valid():
            targeting.presentation_request.call(
                &"sound",
                {
                    "sound": effect_template.sound,
                    "volume_db": effect_template.volume_db,
                    "pitch_scale": effect_template.pitch_scale,
                    "request_id": request_id
                }
            )
        _finish_apply()
        return
    if targeting is BattleUnit and not BattleController.get_unit_display(targeting):
        _finish_apply()
        return
    request_serial += 1
    request_id = StringName("sound:%s:%s" % [get_instance_id(), request_serial])
    if not SignalBus.played_battle_sound.is_connected(on_sound_played):
        SignalBus.played_battle_sound.connect(on_sound_played)
    (
        SignalBus
        . play_battle_sound
        . emit(
            targeting,
            effect_template.sound,
            effect_template.volume_db,
            effect_template.pitch_scale,
            request_id,
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


## Handles the sound played notification for this effect trigger sound.
func on_sound_played(completed_target: Variant, completed_request_id: StringName) -> void:
    if targeting != completed_target or request_id != completed_request_id:
        return
    _disconnect_completion_signal()
    _finish_apply()


## Handles the presentation timeout notification for this effect trigger sound.
func on_presentation_timeout(expected_request_id: StringName) -> void:
    if finished or request_id != expected_request_id:
        return
    _disconnect_completion_signal()
    _finish_apply()


## Disconnects completion signal for this effect trigger sound.
func _disconnect_completion_signal() -> void:
    if SignalBus.played_battle_sound.is_connected(on_sound_played):
        SignalBus.played_battle_sound.disconnect(on_sound_played)


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _disconnect_completion_signal()
