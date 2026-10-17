extends Node
## Plays bounded production feedback from resolved events. Never changes combat
## state or waits for animation_finished. Missing assets are cosmetic failures.
class_name BattleCombatPresentation

## Observable playback acceptance, useful to UI and visual regression tests.
signal cue_started(kind: StringName, unit: BattleUnit, request_id: StringName)
## Duration budget for a single attack, hit or dodge presentation cue.
@export_range(0.0, 1.0) var cue_seconds: float = 0.25
## Duration budget for a terminal victory or defeat presentation sequence.
@export_range(0.0, 5.0) var sequence_seconds: float = 3.0
## Cancellation token distinguishing the current playback from stale awaits.
var _generation: int = 0
## Animation player currently owned by this playback, if available.
var _animator: AnimationPlayer
## Visual stage supplying unit displays for the current sequence.
var _stage: BattleVisualStage
## Stage effect-presentation adapter resolving authored animation IDs.
var _binding: BattleEffectPresentation


## Wind-up occurs after approach and before domain resolution; one per action.
func attack(
    stage: BattleVisualStage,
    request: BattleActionRequest,
    continuation: Callable,
    timing: BattleActionContext = null
) -> void:
    var token := _begin(stage)
    if not _valid(token, continuation):
        return
    if request.action is BattleMadnessAction:
        await _madness_cue(request, token, continuation)
        return
    if request.action.attack_animation.is_empty():
        return
    await _animate(
        request.actor,
        request.actor,
        request.action.attack_animation,
        &"attack",
        request.request_id,
        token,
        continuation,
        cue_seconds,
        false,
        request.action.use_spine,
        request.action.loop,
        request.action.track_number,
        timing
    )


## Resource events preserve operation order, including damage/healing pairs.
## A total time budget bounds large multi-target/chained sequences; remaining
## cues settle immediately rather than holding the turn or losing final poses.
func play_events(stage: BattleVisualStage, events: Array, continuation: Callable) -> void:
    var token := _begin(stage)
    # Outcomes without a live callback still appear before any sequential cue waits.
    for event: BattleCombatEvent in events:
        if not _valid(token, continuation):
            return
        present_result(stage, event)
    var deadline := Time.get_ticks_msec() + int(sequence_seconds * 1000)
    for event: BattleCombatEvent in events:
        if not _valid(token, continuation):
            return
        var display := (
            stage.get_unit_display(event.target) if is_instance_valid(event.target) else null
        )
        if not is_instance_valid(display):
            continue
        var seconds := minf(cue_seconds, maxf(0, (deadline - Time.get_ticks_msec()) / 1000.0))
        var kind: StringName
        var animation: StringName
        match event.type:
            BattleCombatEvent.TYPE.TARGET_SUBSTITUTED:
                kind = &"substitution"
            BattleCombatEvent.TYPE.DAMAGE:
                kind = &"damage"
                animation = &"hit_from_" if event.amount > 0 else &""
            BattleCombatEvent.TYPE.HEALING:
                kind = &"healing"
            BattleCombatEvent.TYPE.MISS:
                kind = &"miss"
            BattleCombatEvent.TYPE.CRITICAL:
                kind = &"critical"
            BattleCombatEvent.TYPE.DEFEAT:
                kind = &"defeat"
                animation = &"death_"
            BattleCombatEvent.TYPE.REVIVED:
                kind = &"revived"
                _reset_display(display)
            _:
                continue
        present_result(stage, event)
        await _animate(
            event.target,
            event.actor,
            animation,
            kind,
            event.request_id,
            token,
            continuation,
            seconds,
            event.type == BattleCombatEvent.TYPE.DEFEAT
        )


## Invalidate waiting work before releasing its references; never touch a newer binding.
func cancel() -> void:
    _generation += 1
    if is_instance_valid(_animator):
        _animator.stop()
        var display := _animator.get_parent() as Unit2DDisplay
        if display:
            _reset_display(display)
    _animator = null
    _stage = null
    _binding = null


## Cancels earlier playback and remembers the current stage and its effect handler. Returns the
## number used to reject old playback work.
func _begin(stage: BattleVisualStage) -> int:
    cancel()
    _stage = stage
    _binding = (
        stage.get("_effect_presentation") as BattleEffectPresentation
        if is_instance_valid(stage)
        else null
    )
    return _generation


## Binding identity rejects same-attempt display replacement as well as retries.
func _valid(token: int, continuation: Callable) -> bool:
    return (
        token == _generation
        and continuation.is_valid()
        and continuation.call()
        and (
            is_instance_valid(_stage)
            and _stage.is_inside_tree()
            and _binding != null
            and _stage.get("_effect_presentation") == _binding
            and _stage.call(&"_is_current", _stage.get(&"_session_id"))
        )
    )


## Shows one feedback cue and plays its animation when available. Waits only for the allowed time,
## checks cancellation while waiting, and either keeps the final pose or returns the display to
## idle.
func _animate(
    unit: BattleUnit,
    source: BattleUnit,
    authored: StringName,
    kind: StringName,
    request_id: StringName,
    token: int,
    continuation: Callable,
    seconds: float,
    keep_pose: bool = false,
    use_spine: bool = false,
    loop: bool = false,
    track_number: int = 0,
    timing: BattleActionContext = null
) -> void:
    if not _valid(token, continuation):
        return
    var display := _stage.get_unit_display(unit)
    if not is_instance_valid(display):
        return
    cue_started.emit(kind, unit, request_id)
    if not _valid(token, continuation):
        return
    var animation: StringName
    if use_spine:
        seconds = display.play_spine_animation(authored, loop, track_number)
        if seconds < 0.0:
            return
        if timing:
            seconds = timing.split_animation(seconds)
    else:
        if display.spine_appearance:
            return
        var animator := display.get_node_or_null("%Animator") as AnimationPlayer
        animation = _binding.resolve_animation_id(display, authored, source == unit)
        if animator and not authored.is_empty() and animator.has_animation(animation):
            _animator = animator
            var clip := animator.get_animation(animation)
            animator.play(animation, -1, maxf(1, clip.length / maxf(seconds, 0.001)))
            animator.advance(0)
    var deadline := Time.get_ticks_msec() + int(seconds * 1000)
    while _valid(token, continuation) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    if not _valid(token, continuation):
        # A newer playback owns its own cleanup; do not cancel that generation.
        if token == _generation:
            cancel()
        return
    if is_instance_valid(_animator):
        if keep_pose:
            _animator.seek(_animator.get_animation(animation).length, true)
            _animator.stop(true)
        else:
            _reset_display(display)
    _animator = null


## Restore authored transforms and HUD opacity after hits, revival or cancellation.
func _reset_display(display: Unit2DDisplay) -> void:
    if display.spine_appearance:
        return
    var animator := display.get_node_or_null("%Animator") as AnimationPlayer
    if not animator:
        return
    if animator.has_animation(&"RESET"):
        animator.play(&"RESET")
        animator.advance(0)
    if animator.has_animation(&"idle"):
        animator.play(&"idle")


## Cancels waiting playback when this node leaves the scene.
func _exit_tree() -> void:
    cancel()


## Catatonic has no attack or movement. Future particles belong to an authored action effect.
## Missing visuals still produce a cue and cannot prevent the turn from completing.
func _madness_cue(request: BattleActionRequest, token: int, continuation: Callable) -> void:
    var kind: StringName = (
        &"cowering" if request.action.kind == BattleMadnessAction.KIND.COWER else &"catatonic"
    )
    cue_started.emit(kind, request.actor, request.request_id)
    if not _valid(token, continuation):
        return
    var deadline := Time.get_ticks_msec() + int(cue_seconds * 1000)
    while _valid(token, continuation) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame


## Show text and critical particles at the outcome; later playback must not repeat them.
func present_result(stage: BattleVisualStage, event: BattleCombatEvent) -> void:
    if event.get_meta(&"floating_text_presented", false) or not is_instance_valid(stage):
        return
    var display := stage.get_unit_display(event.target) if is_instance_valid(event.target) else null
    if not is_instance_valid(display):
        return
    for child in display.find_children("*", "", true, false):
        if child is FloatingTextController:
            child.present_event(event)
    if event.type == BattleCombatEvent.TYPE.CRITICAL:
        display.on_critical_damage(event.target)
        var source_display := stage.get_unit_display(event.actor) if is_instance_valid(event.actor) else null
        if is_instance_valid(source_display):
            source_display.on_critical_hit(event.actor)
    event.set_meta(&"floating_text_presented", true)
