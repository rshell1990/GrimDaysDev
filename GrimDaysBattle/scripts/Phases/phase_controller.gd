# Editor configuration for BattlePhaseController.
@icon("res://GrimDays/assets/visuals/class_icons/control-tower.png")
extends Node
## Ordered phase state machine for the presentation-driven battle flow. It owns
## action/target context while individual [BattlePhase] nodes perform each step.
class_name BattlePhaseController

## Preloaded request type used to snapshot an action before domain resolution.
const ACTION_REQUEST_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Actions/Runtime/battle_action_request.gd"
)
## Preloaded resolver type instantiated as a child of this controller.
const ACTION_RESOLVER_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Actions/Runtime/battle_action_resolver.gd"
)

## Child phase nodes keyed by their unique [enum Combat.BATTLE_STATES] identifier.
var known_phases: Dictionary[Combat.BATTLE_STATES, BattlePhase]

## Identifier of the phase currently accepting callbacks and execution.
var current_phase: Combat.BATTLE_STATES
## Identifier most recently exited; used by cancellable selection phases.
var previous_phase: Combat.BATTLE_STATES

## Combatant whose turn is currently being processed.
var active_unit: BattleUnit
## Immutable selection snapshot for the current action. Runtime redirection is
## applied to [member targets] without rewriting this history.
var original_targets: Array
## Index of the current target within immutable [member original_targets].
var target_cursor: int
## Remaining processing view. The current target is always index zero.
var targets: Array
## Action selected for the current combatant and target sequence.
var selected_action: Variant
## Units defeated during the current turn, retained to prevent duplicate processing.
var inactive_since_turn_start: Array
## Domain resolver shared by every action submitted through this phase flow.
var action_resolver: BattleActionResolver
## Monotonic serial used to make phase action requests unique and reproducible.
var action_request_serial: int


## Registers child phases and assigns this controller as their coordinator.
func _ready() -> void:
    action_resolver = ACTION_RESOLVER_SCRIPT.new()
    action_resolver.name = "Action Resolver"
    add_child(action_resolver)
    for phase in get_children():
        if phase is not BattlePhase:
            continue
        known_phases.set(phase.id, phase)
        phase.phase_controller = self


## Resolves the selected action against the immutable target snapshot and adds
## its authoritative events to the active battle result.
func resolve_current_action() -> BattleActionResolution:
    action_request_serial += 1
    var request_targets: Array[BattleUnit] = []
    request_targets.assign(original_targets if not original_targets.is_empty() else targets)
    var encounter_id: StringName = &"battle"
    var round_number: int
    var turn_number: int
    if BattleController.current_battle_result:
        encounter_id = BattleController.current_battle_result.encounter_id
        round_number = BattleController.current_battle_result.rounds
        turn_number = BattleController.current_battle_result.turns
    var request_id := StringName(
        "%s:round:%s:turn:%s:action:%s" % [encounter_id, round_number, turn_number, action_request_serial]
    )
    var request = (
        ACTION_REQUEST_SCRIPT
        . new(
            request_id,
            active_unit,
            selected_action,
            request_targets,
        )
    )
    var resolution: BattleActionResolution = await action_resolver.resolve(request)
    if (
        resolution.success
        and BattleController.current_battle_result
        and not BattleController.current_battle_result.finalized
    ):
        BattleController.current_battle_result.combat_events.append_array(resolution.events)
    return resolution


## Resets per-encounter action correlation without reconstructing phase nodes.
func reset_action_resolution() -> void:
    action_request_serial = 0
    clear_action_targets(true)
    selected_action = null


## Replaces the active phase's transient handoff payload.
func pass_cargo_to_current_phase(cargo: Variant) -> void:
    known_phases[current_phase].cargo = cargo


## Enters the active phase's selected [member BattlePhase.next_phase].
func go_to_next_phase(cargo: Variant) -> void:
    change_phase(known_phases[current_phase].next_phase, cargo)


## Begins an asynchronous phase transition. The destination enters only after
## the current phase emits [signal BattlePhase.exited].
func change_phase(new_phase: Combat.BATTLE_STATES, cargo: Variant) -> void:
    CustomLogger.hint(
        self, change_phase, "Changing to phase: %s" % known_phases[new_phase], CustomLogger.LEVEL.IMPORTANT
    )
    CustomLogger.hint(self, change_phase, "Cargo: " + str(cargo), CustomLogger.LEVEL.IMPORTANT)
    if new_phase == Combat.BATTLE_STATES.END_ROUND:
        active_unit = null
        clear_action_targets(true)
        selected_action = null

    if cargo and cargo.has("action"):
        CustomLogger.hint(self, change_phase, "Action: " + str(cargo.action), CustomLogger.LEVEL.IMPORTANT)
        selected_action = cargo.action
        if new_phase == Combat.BATTLE_STATES.GET_COMBAT_TARGETS and active_unit.player_controlled:
            CustomLogger.hint(self, change_phase, "Emitting action selected signal.", CustomLogger.LEVEL.VERBOSE)
            SignalBus.action_selected.emit(selected_action)

    if cargo and cargo.has("targets") and new_phase == Combat.BATTLE_STATES.SET_COMBAT_TARGETS:
        begin_target_processing(cargo.targets)
    previous_phase = current_phase
    current_phase = new_phase
    # The callback is bound to this transition's cargo, so the unbound method is
    # not an equivalent Callable for is_connected()/disconnect(). A one-shot
    # connection prevents stale cargo handlers from accumulating across turns.
    (
        known_phases[previous_phase]
        . exited
        . connect(
            _exited_last_phase.bind(cargo),
            CONNECT_ONE_SHOT,
        )
    )
    known_phases[previous_phase]._exit()


## Transfers shared action state and [param cargo] after the prior phase exits.
func _exited_last_phase(cargo: Variant) -> void:
    active_unit = BattleController.get_active_unit()

    if selected_action:
        known_phases[current_phase].selected_action = selected_action
    if not targets.is_empty():
        known_phases[current_phase].targets = targets
    known_phases[current_phase].active_unit = active_unit
    if not known_phases[current_phase].entered.is_connected(execute_current_phase):
        known_phases[current_phase].entered.connect(execute_current_phase)
    known_phases[current_phase].cargo = cargo
    known_phases[current_phase]._enter()


## Invokes the active phase after it emits [signal BattlePhase.entered].
func execute_current_phase() -> void:
    known_phases[current_phase].execute()


## Returns to [member previous_phase], primarily for cancellable player input.
func return_to_previous_phase() -> void:
    change_phase(previous_phase, null)


## Copies the selection and resets the cursor so target redirection cannot mutate
## the original action history.
func begin_target_processing(selected_targets: Array) -> void:
    original_targets.assign(selected_targets)
    target_cursor = 0
    _refresh_remaining_targets()


## Returns whether another original target follows the current cursor.
func has_next_target() -> bool:
    return target_cursor + 1 < original_targets.size()


## Moves to the next target and refreshes [member targets]; returns whether it advanced.
func advance_target() -> bool:
    if not has_next_target():
        return false
    target_cursor += 1
    _refresh_remaining_targets()
    return true


## Clears the processing view. Pass [param clear_history] at action/round teardown
## when the immutable selection snapshot is no longer needed.
func clear_action_targets(clear_history: bool = false) -> void:
    targets.clear()
    target_cursor = 0
    if clear_history:
        original_targets.clear()


## Rebuilds the mutable processing view from the current immutable cursor.
func _refresh_remaining_targets() -> void:
    targets = (original_targets.slice(target_cursor) if target_cursor < original_targets.size() else [])
