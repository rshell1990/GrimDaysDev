extends RefCounted
## Mutable execution targets; the request's original selections remain immutable history.
class_name BattleActionContext

var attacker: BattleUnit
var current_target: BattleUnit
var targets: Array[BattleUnit] = []
var target_index: int = 0
var response_owner: BattleUnit
var targeting_response: bool
var targeted: Dictionary = {}
var history: Array[Dictionary] = []
## Animation tail carried to the next primitive operation, shared across nested chains.
var pending_animation_deadline: int = 0
## Protects the playing clip even while a primitive owns its carried delay.
var animation_deadline: int = 0


## Explicit selection replaces the live target. Previous selections are never looked up for routing.
func select(unit: BattleUnit) -> void:
    current_target = unit
    if target_index < targets.size():
        targets[target_index] = unit


## TARGETED bindings compete in attachment order; the newest valid binding wins.
func substitute(unit: BattleUnit) -> bool:
    if not targeting_response or not is_instance_valid(unit) or not unit.is_active:
        return false
    if unit == response_owner:
        return false
    var source := CombatActions.get_participant_source(attacker)
    if source is BattleEncounterRoster and not source.is_present(unit):
        return false
    var same_team := unit.get_parent() == response_owner.get_parent()
    if not unit.team_id.is_empty() and not response_owner.team_id.is_empty():
        same_team = unit.team_id == response_owner.team_id
    if not same_team:
        return false
    history.append({"previous": current_target, "replacement": unit})
    select(unit)
    return true


## Starts a Spine cycle and returns the 70 percent wind-up duration.
func split_animation(seconds: float) -> float:
    animation_deadline = Time.get_ticks_msec() + ceili(seconds * 1000.0)
    pending_animation_deadline = animation_deadline
    return seconds * 0.7


## A primitive claims the prior tail; containers leave it for their first child.
func take_animation_delay() -> int:
    var deadline := pending_animation_deadline
    pending_animation_deadline = 0
    return deadline


## Frame-based waits stop promptly when an encounter is cancelled.
func wait_until(node: Node, deadline: int, continuation: Callable = Callable()) -> void:
    while Time.get_ticks_msec() < deadline:
        if continuation.is_valid() and not continuation.call():
            return
        await node.get_tree().process_frame


## Used before another animation and at action completion, including empty final stages.
func finish_animation(node: Node, continuation: Callable = Callable()) -> void:
    var deadline := maxi(animation_deadline, take_animation_delay())
    await wait_until(node, deadline, continuation)
