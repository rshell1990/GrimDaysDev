extends BattlePhase
## Battle phase responsible for round start.
class_name BattlePhaseRoundStart

## Maximum time optional round presentation may delay phase progression.
const PRESENTATION_TIMEOUT_SECONDS: float = 5.0

## Stable correlation state for the current execution.
var request_id: StringName
## Monotonic local serial prevents two entries in the same frame sharing an ID.
var request_serial: int
## One-shot guard against duplicate, stale, and timeout completion.
var completed: bool


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()
    SignalBus.battle_round_presentation_finished.connect(on_round_presentation_finished)


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    request_serial += 1
    request_id = StringName("round:%s:%s" % [get_instance_id(), request_serial])
    completed = false
    entered.emit()


## Executes the round start step and advances the phase state machine when complete.
func execute() -> void:
    super()
    BattleController.record_round_started()
    var has_presentation := get_tree().get_first_node_in_group(SignalBus.BATTLE_ROUND_PRESENTATION_GROUP) != null
    if not has_presentation:
        for ally in BattleController.get_units_in_ally_holder():
            ally.player_controlled = false
    SignalBus.tick.emit(request_id)
    if not has_presentation:
        finish_execution()
        return
    (
        get_tree()
        . create_timer(PRESENTATION_TIMEOUT_SECONDS)
        . timeout
        . connect(
            on_presentation_timeout.bind(request_id),
            CONNECT_ONE_SHOT,
        )
    )


## Accepts only the completion belonging to the currently executing round.
func on_round_presentation_finished(completed_request_id: StringName) -> void:
    if not is_matching_completion(completed_request_id):
        return
    finish_execution()


## Releases the phase if optional presentation disappears or fails to respond.
func on_presentation_timeout(expected_request_id: StringName) -> void:
    if not is_matching_completion(expected_request_id):
        return
    finish_execution()


## Returns whether an acknowledgement may finish the current execution.
func is_matching_completion(completed_request_id: StringName) -> bool:
    return not completed and not request_id.is_empty() and completed_request_id == request_id


## Advances the phase exactly once for its current round request.
func finish_execution() -> void:
    if completed:
        return
    completed = true
    executed.emit()
    BattleController.go_to_next_phase()


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
