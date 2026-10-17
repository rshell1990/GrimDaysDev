extends RefCounted
## Represents the battle action request portion of deterministic battle action processing.
class_name BattleActionRequest

## Backing storage for the immutable public [member request_id].
var _request_id: StringName
## Stable identifier that correlates the request with combat and presentation events.
var request_id: StringName:
    get:
        return _request_id

## Backing storage for the immutable public [member actor].
var _actor: BattleUnit
## Active unit attempting to perform [member action].
var actor: BattleUnit:
    get:
        return _actor

## Backing storage for the immutable public [member action].
var _action: ActionTemplate
## Authored action the actor intends to use.
var action: ActionTemplate:
    get:
        return _action

## Private snapshot of the targets supplied at construction time.
var _targets: Array[BattleUnit]
## Copy of the selected targets, safe for callers to mutate.
var targets: Array[BattleUnit]:
    get:
        return _targets.duplicate()

## Capture targeting rules at commitment; expiry during a cast does not retarget it.
var _madness_targeting: bool
var madness_targeting: bool:
    get:
        return _madness_targeting

## Automatic Lucidity outcomes bypass resource costs and cooldowns without changing the skill.
var _lucidity_outcome: bool
var lucidity_outcome: bool:
    get:
        return _lucidity_outcome


## Initializes a new action request with the supplied values.
func _init(
    request_id_value: StringName,
    actor_value: BattleUnit,
    action_value: ActionTemplate,
    target_values: Array[BattleUnit],
    lucidity_outcome_value: bool = false,
) -> void:
    _lucidity_outcome = lucidity_outcome_value
    _request_id = request_id_value
    _actor = actor_value
    _madness_targeting = (
        is_instance_valid(actor_value)
        and actor_value.has_madness()
        and not action_value is BattleMadnessAction
    )
    _action = action_value
    _targets.assign(target_values)
    if is_instance_valid(actor_value) and not lucidity_outcome_value:
        var forced := actor_value.get_forced_action_effect()
        if forced and forced.definition.action == action_value:
            _forced_effect_id = forced.get_instance_id()
            _forced_rank = forced.definition.action_rank


var _forced_effect_id: int = 0
var _forced_rank: int = 0

## Both automatic policies bypass cost/cooldown payment,
## preserving normal targeting and restrictions.
var free_action: bool:
    get:
        return _lucidity_outcome or _forced_effect_id != 0

var forced_action: bool:
    get:
        return _forced_effect_id != 0


func get_execution_rank() -> int:
    if forced_action:
        return _forced_rank
    return actor.get_action_rank(action, lucidity_outcome)


func has_current_forced_source() -> bool:
    var effect := actor.get_forced_action_effect()
    return (
        effect != null
        and effect.get_instance_id() == _forced_effect_id
        and effect.definition.action == action
    )
