extends RefCounted
## Dispatches authored cosmetic operations to one production stage. Acceptance
## is synchronous; effects own their separate resolution timers.
## A new dispatcher is created on every binding, including same-attempt rebinds.
class_name BattleEffectPresentation

## Stage owns displays; this helper borrows them only while its binding is live.
var _stage: BattleVisualStage
## Attempt captured at construction, never updated to a later encounter.
var _session_id: int
## Explicit invalidation also rejects callbacks retained across same-token rebinds.
var _active: bool = true
## Previous and installed unit callbacks, restored only if still owned by us.
var _bindings: Dictionary = {}


## Called after the stage has accepted an active coordinator, before deployment.
func _init(stage: BattleVisualStage, session_id: int) -> void:
    _stage = stage
    _session_id = session_id


## Injects this display service without changing permanent unit ownership.
func bind_unit(unit: BattleUnit) -> void:
    var callback := present.bind(unit)
    _bindings[unit] = {"previous": unit.presentation_request, "installed": callback}
    unit.presentation_request = callback


## Rejects future work and releases only callbacks still belonging to this view.
func close() -> void:
    _active = false
    for unit: BattleUnit in _bindings:
        if is_instance_valid(unit) and unit.presentation_request == _bindings[unit].installed:
            unit.presentation_request = _bindings[unit].previous
    _bindings.clear()
    _stage = null


## Presents animation, sound or particles on the bound target. False means the
## request was skipped (stale binding, missing display/asset, or unknown kind).
## Callers must finish either way; this is not a combat-success result.
## Accepted Spine animations write their cycle length to payload.duration_seconds.
func present(kind: StringName, payload: Dictionary, target: BattleUnit) -> bool:
    if not _active or not is_instance_valid(_stage) or not _stage.is_inside_tree():
        return false
    if not _stage._is_current(_session_id) or not is_instance_valid(target):
        return false
    var display := _stage.get_unit_display(target)
    if not is_instance_valid(display) or display.is_queued_for_deletion():
        return false
    var request_id: StringName = payload.get("request_id", &"")
    match kind:
        &"animation":
            if payload.get("use_spine", false):
                var seconds := display.play_spine_animation(
                    payload.get("animation_id", &""), payload.get("loop", false), payload.get("track_number", 0)
                )
                if seconds < 0.0:
                    return false
                payload["duration_seconds"] = seconds
                return true
            var animation_id := resolve_animation_id(
                display, payload.get("animation_id", &""), payload.get("source") == target
            )
            var animator := display.get_node_or_null("%Animator") as AnimationPlayer
            if not animator or not animator.has_animation(animation_id):
                return false
            animator.play(animation_id)
        &"sound":
            if not payload.get("sound"):
                return false
            display.on_play_battle_sound(
                target, payload.sound, payload.get("volume_db", 0.0), payload.get("pitch_scale", 1.0), request_id
            )
        &"particles":
            if not payload.get("particle_scene"):
                return false
            display.on_spawn_battle_particles(
                target,
                payload.particle_scene,
                payload.get("lifetime_seconds", 2.0),
                request_id,
                payload.get("animation_name", &""),
                payload.get("starting_offset", Vector2.ZERO)
            )
        _:
            return false
    return true


## A trailing underscore uses the existing left/right animation naming scheme.
## Facing comes from screen placement, not unit parenting or temporary allegiance.
## Explicit animation names are passed through unchanged.
func resolve_animation_id(display: Unit2DDisplay, authored: StringName, self_target: bool) -> StringName:
    if not authored.ends_with("_"):
        return authored
    var center_x := (_stage.ally_holder.global_position.x + _stage.foe_holder.global_position.x) * 0.5
    var on_left := display.global_position.x < center_x
    var suffix := "left" if on_left == self_target else "right"
    return StringName(str(authored) + suffix)
