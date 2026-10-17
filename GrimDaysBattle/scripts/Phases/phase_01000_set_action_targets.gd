extends BattlePhase
## Battle phase responsible for set action targets.
class_name BattlePhaseSetActionTargets

## Fixed presentation timeout seconds value shared by all phase set action targets instances.
const PRESENTATION_TIMEOUT_SECONDS: float = 5.0

## Whether the completed condition currently holds.
var completed: bool
## Whether the movement requested condition currently holds.
var movement_requested: bool
## Stable request id used to correlate or persist this phase set action targets.
var request_id: StringName
## Combatant currently used as the expected target.
var expected_target: BattleUnit
## Runtime expected camera state used by this phase set action targets.
var expected_camera: PhantomCamera2D


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    super()
    SignalBus.unit_moved_towards_unit.connect(on_moved)


## Validates and prepares transient state when the phase becomes active.
func _enter() -> void:
    super()
    completed = false
    movement_requested = false
    request_id = StringName("move:%s:%s" % [get_instance_id(), Time.get_ticks_usec()])
    expected_target = null
    expected_camera = null
    if cargo is not Dictionary:
        cargo = {}
    if not cargo.has("targets"):
        cargo = CombatActions.set_targets(selected_action, active_unit)
    targets.assign(cargo.get("targets", []))
    entered.emit()


## Executes the set action targets step and advances the phase state machine when complete.
func execute() -> void:
    super()
    if targets.is_empty():
        next_phase = Combat.BATTLE_STATES.PROCESS_ACTIVE_ACTION_FINISHED
        finish_execution()
        return
    expected_target = targets[0]
    var active_display = BattleController.get_unit_display(active_unit)
    var target_display = BattleController.get_unit_display(expected_target)
    if not active_display or not target_display or not active_display.combat_camera:
        finish_execution()
        return
    expected_camera = active_display.combat_camera
    if not expected_camera.tween_completed.is_connected(on_combat_camera_tween_complete):
        expected_camera.tween_completed.connect(on_combat_camera_tween_complete, CONNECT_ONE_SHOT)
    SignalBus.switch_to_combat_camera.emit(active_unit)
    get_tree().create_timer(PRESENTATION_TIMEOUT_SECONDS).timeout.connect(
        on_presentation_timeout.bind(request_id), CONNECT_ONE_SHOT
    )


## Handles the combat camera tween complete notification for this phase set action targets.
func on_combat_camera_tween_complete():
    if completed or targets.is_empty():
        finish_execution()
        return
    request_movement()


## Requests movement for this phase set action targets.
func request_movement() -> void:
    if completed or movement_requested:
        return
    movement_requested = true
    SignalBus.unit_moved_towards_unit.emit(active_unit, expected_target, request_id)


## Handles the moved notification for this phase set action targets.
func on_moved(unit: BattleUnit, target: BattleUnit, completed_request_id: StringName) -> void:
    if unit != active_unit or target != expected_target or completed_request_id != request_id:
        return
    finish_execution()


## Handles the presentation timeout notification for this phase set action targets.
func on_presentation_timeout(expected_request_id: StringName) -> void:
    if completed or expected_request_id != request_id:
        return
    if not movement_requested:
        request_movement()
        get_tree().create_timer(PRESENTATION_TIMEOUT_SECONDS).timeout.connect(
            on_presentation_timeout.bind(request_id), CONNECT_ONE_SHOT
        )
        return
    finish_execution()


## Finishes execution for this phase set action targets.
func finish_execution() -> void:
    if completed:
        return
    completed = true
    if expected_camera and expected_camera.tween_completed.is_connected(on_combat_camera_tween_complete):
        expected_camera.tween_completed.disconnect(on_combat_camera_tween_complete)
    executed.emit()
    BattleController.go_to_next_phase(cargo)


## Publishes the phase result and clears transient state before advancing.
func _exit() -> void:
    super()
    exited.emit()
