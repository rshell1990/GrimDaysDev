extends RefCounted
## Represents the battle combat event portion of deterministic battle action processing.
class_name BattleCombatEvent

## Action stages and resource-operation outcomes, including lifecycle dispatch.
enum TYPE {
    ACTION_STARTED,
    COST_PAID,
    BEFORE_ATTACK,
    BEFORE_TARGETED,
    HIT,
    MISS,
    CRITICAL,
    DAMAGE,
    HEALING,
    DEFEAT,
    ACTION_FINISHED,
    RESOURCE_CHANGED,
    REVIVED,
    ITEM_USED,
    TURN_DELAY,
    MADNESS_ACTION,
    TARGET_SUBSTITUTED,
}

## Kind of occurrence represented by this event.
var type: TYPE
## Action request or attempt-correlated lifecycle dispatch ID.
var request_id: StringName
## Original effect sender for resource operations; initiating actor for action stages.
var actor: BattleUnit
## Unit affected by this event, or [code]null[/code] for action-wide events.
var target: BattleUnit
## Authored action being resolved, or null for round/defeat/kill lifecycle scopes.
var action: ActionTemplate
## Resolved damage or healing magnitude when relevant; otherwise zero.
var amount: float
## Deep-copied extensible metadata that cannot rewrite prior combat history.
var data: Dictionary


## Initializes a new combat event with the supplied values.
func _init(
    event_type: TYPE,
    request,
    target_unit: BattleUnit = null,
    resolved_amount: float = 0.0,
    event_data: Dictionary = {},
) -> void:
    type = event_type
    request_id = request.request_id if request else &""
    actor = request.actor if request else null
    target = target_unit
    action = request.action if request else null
    amount = resolved_amount
    data = event_data.duplicate(true)
