extends EffectBase
## Implements the runtime effect trigger animation behavior used by the battle effect pipeline.
class_name EffectTriggerAnimation

## Fixed presentation timeout seconds value shared by all effect trigger animation instances.
const PRESENTATION_TIMEOUT_SECONDS: float = 5.0

## Runtime animation id state used by this effect trigger animation.
var animation_id: StringName
## Unexpanded definition retained for display-relative production facing.
var authored_animation_id: StringName
## Stable request id used to correlate or persist this effect trigger animation.
var request_id: StringName
## Runtime request serial state used by this effect trigger animation.
var request_serial: int
## Authored Spine playback settings; names bypass AnimationPlayer directional expansion.
var use_spine: bool = false
var loop: bool = false
var track_number: int = 0


## Initializes this effect trigger animation from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    authored_animation_id = template.animation_id
    use_spine = template.use_spine
    loop = template.loop
    track_number = template.track_number
    var animation_name: StringName = template.animation_id
    if not use_spine and template.animation_id.ends_with("_"):
        var target_is_ally: bool = (
            target_node is Node and target_node.get_parent() and target_node.get_parent().name == "Allies"
        )
        if target_node != sent_by:
            animation_name = StringName(str(animation_name) + ("right" if target_is_ally else "left"))
        else:
            animation_name = StringName(str(animation_name) + ("left" if target_is_ally else "right"))

    animation_id = animation_name


## Applies this effect trigger animation's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    var timing: BattleActionContext = get_meta(CHAIN_CONTEXT_META, {}).get("action_context")
    if timing:
        await timing.finish_animation(self, can_continue_resolution)
        if not can_continue_resolution():
            _finish_apply()
            return
    request_serial += 1
    request_id = StringName("animation:%s:%s" % [get_instance_id(), request_serial])
    if not targeting or not is_instance_valid(targeting):
        _finish_apply()
        return
    # Production accepts playback synchronously and reports the actual Spine duration.
    # Looping clips wait one cycle; no animation completion signal can block resolution.
    if targeting is BattleUnit and not targeting.presentation_request.is_null():
        if targeting.presentation_request.is_valid():
            var payload := {
                "animation_id": authored_animation_id,
                "source": sender,
                "request_id": request_id,
                "use_spine": use_spine,
                "loop": loop,
                "track_number": track_number
            }
            var accepted: Variant = targeting.presentation_request.call(&"animation", payload)
            var seconds: float = payload.get("duration_seconds", 0.0) if accepted and use_spine else 0.0
            if seconds > 0.0:
                await _wait_spine_animation(seconds, timing)
        _finish_apply()
        return
    if targeting is BattleUnit and not BattleController.get_unit_display(targeting):
        _finish_apply()
        return
    if use_spine:
        var display: Unit2DDisplay = BattleController.get_unit_display(targeting) if targeting is BattleUnit else null
        if display:
            var seconds := display.play_spine_animation(authored_animation_id, loop, track_number)
            if seconds > 0.0:
                await _wait_spine_animation(seconds, timing)
        _finish_apply()
        return
    if not SignalBus.played_battle_animation.is_connected(on_animation_played):
        SignalBus.played_battle_animation.connect(on_animation_played)
    SignalBus.play_battle_animation.emit(targeting, animation_id, request_id)
    get_tree().create_timer(PRESENTATION_TIMEOUT_SECONDS).timeout.connect(
        on_animation_timeout.bind(request_id), CONNECT_ONE_SHOT
    )


## Handles the animation played notification for this effect trigger animation.
func on_animation_played(
    completed_target: Variant, animation_name: StringName, completed_request_id: StringName
) -> void:
    (
        CustomLogger
        . confirm(
            self,
            on_animation_played,
            "%s completed request %s." % [animation_name, completed_request_id],
            CustomLogger.LEVEL.VERBOSE,
        )
    )
    if targeting != completed_target or animation_id != animation_name or request_id != completed_request_id:
        return
    disconnect_completion_signal()
    _finish_apply()


## Handles the animation timeout notification for this effect trigger animation.
func on_animation_timeout(expected_request_id: StringName) -> void:
    if finished or request_id != expected_request_id:
        return
    disconnect_completion_signal()
    _finish_apply()


## Disconnects completion signal for this effect trigger animation.
func disconnect_completion_signal() -> void:
    if SignalBus.played_battle_animation.is_connected(on_animation_played):
        SignalBus.played_battle_animation.disconnect(on_animation_played)


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    disconnect_completion_signal()


## Standalone callers retain full-cycle waits; action resolution carries the final 30 percent.
func _wait_spine_animation(seconds: float, timing: BattleActionContext) -> void:
    var wind_up := timing.split_animation(seconds) if timing else seconds
    var clock := timing if timing else BattleActionContext.new()
    await clock.wait_until(self, Time.get_ticks_msec() + ceili(wind_up * 1000.0), can_continue_resolution)
