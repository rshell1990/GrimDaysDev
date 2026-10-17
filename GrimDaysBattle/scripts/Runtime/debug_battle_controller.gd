# Editor configuration for debug_battle_controller.
@icon("res://GrimDays/assets/visuals/class_icons/crown.svg")
extends Node

## Preloaded dependency used to construct or identify the battle result script.
const BATTLE_RESULT_SCRIPT := preload("res://GrimDaysBattle/scripts/Other/battle_result.gd")
## Default adapter used whenever no visual battle scene is registered.
const IMMEDIATE_PRESENTATION_ADAPTER := preload(
    "res://GrimDaysBattle/scripts/Presentation/battle_immediate_presentation_adapter.gd"
)
## Shared deterministic seeding policy for deployed battle participants.
const RANDOM_STREAMS_SCRIPT := preload("res://GrimDaysBattle/scripts/Runtime/battle_random_streams.gd")

## Emitted when battle started.
signal battle_started(encounter_id: StringName)
## Emitted when battle finished.
signal battle_finished(result)

## Saving is intentionally disabled while this controller owns an encounter.
## Runtime party members are temporarily reparented during deployment, so a save
## made before cleanup would not represent a stable exploration state.
const ACTIVE_BATTLE_SAVE_BLOCK_REASON := "Saving is unavailable until the active battle has finished and cleaned up."

#region EXPORT / ONREADY
##
## Configures the state manager used by this debug battle controller.
@export var state_manager: BattlePhaseController
##
## Configures the ally unit holder used by this debug battle controller.
@export var ally_unit_holder: UnitPartyDebug
##
## Configures the foe unit holder used by this debug battle controller.
@export var foe_unit_holder: UnitPartyDebug
##
## Cached reference to the turn controller node, resolved when this node becomes ready.
@onready var turn_controller = %"Turn Controller"
#endregion

#region VARS
##
## Runtime focused unit state used by this debug battle controller.
var focused_unit: BattleUnit
##
## Presentation implementation for this battle. Headless resolution uses the
## immediate adapter until a visual scene explicitly registers another one.
var presentation_adapter: BattlePresentationAdapter = IMMEDIATE_PRESENTATION_ADAPTER.new()
## The mutable result for the active session and the most recently completed result.
var current_battle_result
## Runtime last battle result state used by this debug battle controller.
var last_battle_result
## Cached reference to the party manager node, resolved when this node becomes ready.
@onready var party_manager = $"Runtime Party"
## Ordered runtime collection of pending foes.
var pending_foes: Array[BattleUnitTemplate]
#endregion

#region PROPERTIES
## Current state used by this debug battle controller.
var current_state:
    get:
        return state_manager.current_phase
#region

## Ordered runtime collection of inactive since turn start.
var inactive_since_turn_start: Array:
    get:
        return state_manager.inactive_since_turn_start


#region SIGNAL RESPONSES
## Handles the switch to combat camera notification for this debug battle controller.
func on_switch_to_combat_camera(unit: BattleUnit) -> void:
    focused_unit = unit


#endregion


## Passes cargo to current phase for this debug battle controller.
func pass_cargo_to_current_phase(cargo: Variant) -> void:
    state_manager.pass_cargo_to_current_phase(cargo)


## Advances to next phase for this debug battle controller.
func go_to_next_phase(cargo: Variant = null) -> void:
    (
        CustomLogger
        . hint(
            self,
            go_to_next_phase,
            (
                "Going to phase: %s"
                % state_manager.known_phases[state_manager.known_phases[state_manager.current_phase].next_phase]
            ),
            CustomLogger.LEVEL.VERBOSE,
        )
    )
    state_manager.go_to_next_phase(cargo)


## Changes phase for this debug battle controller.
func change_phase(new_phase: Combat.BATTLE_STATES, cargo: Variant = null) -> void:
    (
        CustomLogger
        . hint(
            self,
            change_phase,
            "Changing to phase: %s" % state_manager.known_phases[new_phase],
            CustomLogger.LEVEL.VERBOSE,
        )
    )
    state_manager.change_phase(new_phase, cargo)


## Returns active unit for this debug battle controller.
func get_active_unit() -> BattleUnit:
    if turn_controller.turn_order.is_empty():
        return null
    return turn_controller.turn_order[0]


## Sets next unit for this debug battle controller.
func set_next_unit() -> void:
    turn_controller.set_next_unit()
    SignalBus.set_next_unit.emit()


## Sets active unit for this debug battle controller.
func set_active_unit(unit: BattleUnit) -> void:
    state_manager.active_unit = unit


## Sets selected action for this debug battle controller.
func set_selected_action(action: Variant) -> void:
    state_manager.selected_action = action


## Updates turn order on unit defeat for this debug battle controller.
func update_turn_order_on_unit_defeat(defeated: Array) -> Array[int]:
    var removed_indices: Array[int] = turn_controller.update_turn_order_on_unit_defeat(defeated)
    # Presentation may animate these removals, but domain progress never depends on it.
    SignalBus.units_removed_from_turn.emit(removed_indices)
    return removed_indices


## Begins battle session for this debug battle controller.
func begin_battle_session(
    encounter_id: StringName = &"battle",
    battle_seed: int = 0,
    return_context: Dictionary = {},
    rewards: Dictionary = {},
) -> void:
    if current_battle_result and not current_battle_result.finalized:
        (
            CustomLogger
            . error(
                self,
                begin_battle_session,
                "Cannot begin a battle while another battle session is active.",
                CustomLogger.LEVEL.IMPORTANT,
            )
        )
        return
    current_battle_result = BATTLE_RESULT_SCRIPT.new()
    current_battle_result.encounter_id = encounter_id
    current_battle_result.battle_seed = battle_seed
    current_battle_result.return_context = return_context.duplicate(true)
    current_battle_result.set_rewards(rewards)
    if state_manager:
        state_manager.reset_action_resolution()
    battle_started.emit(encounter_id)


## Queues battle for this debug battle controller.
func queue_battle(
    foes: Array[BattleUnitTemplate],
    encounter_id: StringName = &"battle",
    battle_seed: int = 0,
    return_context: Dictionary = {},
    rewards: Dictionary = {},
) -> bool:
    if not party_manager or party_manager.get_active_party().is_empty():
        CustomLogger.error(
            self, queue_battle, "Cannot begin battle without an active runtime party.", CustomLogger.LEVEL.IMPORTANT
        )
        return false
    if foes.is_empty() or foes.any(func(template): return template == null):
        CustomLogger.error(
            self, queue_battle, "Cannot begin battle without valid foe templates.", CustomLogger.LEVEL.IMPORTANT
        )
        return false
    if current_battle_result and not current_battle_result.finalized:
        CustomLogger.error(
            self, queue_battle, "Cannot queue a battle while another session is active.", CustomLogger.LEVEL.IMPORTANT
        )
        return false
    pending_foes.assign(foes)
    begin_battle_session(encounter_id, battle_seed, return_context, rewards)
    return true


## Returns pending battle payload for this debug battle controller.
func get_pending_battle_payload() -> Dictionary:
    return {
        "allies": party_manager.get_active_party() if party_manager else [],
        "foes": pending_foes.duplicate(),
    }


## Returns whether an encounter still owns transient battle state. A finalized
## result remains active until its caller invokes [method cleanup_battle].
func is_battle_session_active() -> bool:
    return current_battle_result != null


## Returns the user-facing reason saving is currently unavailable, or an empty
## string when the runtime party is in a stable saveable state.
func get_save_block_reason() -> String:
    return ACTIVE_BATTLE_SAVE_BLOCK_REASON if is_battle_session_active() else ""


## Records round started for this debug battle controller.
func record_round_started() -> void:
    _ensure_battle_session()
    current_battle_result.rounds += 1


## Records turn started for this debug battle controller.
func record_turn_started() -> void:
    _ensure_battle_session()
    current_battle_result.turns += 1


## Finishes battle for this debug battle controller.
func finish_battle(outcome: BattleResult.OUTCOME, error: String = ""):
    _ensure_battle_session()
    if current_battle_result.finalized:
        return current_battle_result
    var allies: Array[BattleUnit] = _units_in_holder(ally_unit_holder)
    var foes: Array[BattleUnit] = _units_in_holder(foe_unit_holder)
    _remove_battle_scoped_effects(allies + foes)
    current_battle_result.finalize(outcome, allies, foes, error)
    last_battle_result = current_battle_result
    _clear_transient_battle_state()
    battle_finished.emit(last_battle_result)
    return last_battle_result


## Removes battle scoped effects for this debug battle controller.
func _remove_battle_scoped_effects(units: Array[BattleUnit]) -> void:
    for unit in units:
        if is_instance_valid(unit) and unit.effect_manager:
            unit.clear_cowering()
            unit.effect_manager.remove_battle_scoped_effects()


## Validates and accepts battle result for this debug battle controller.
func accept_battle_result(result) -> bool:
    if not result or not result.finalized:
        CustomLogger.error(
            self, accept_battle_result, "Cannot accept an unfinished battle result.", CustomLogger.LEVEL.IMPORTANT
        )
        return false
    if current_battle_result and result.encounter_id != current_battle_result.encounter_id:
        CustomLogger.error(
            self,
            accept_battle_result,
            "Battle result does not match the active encounter.",
            CustomLogger.LEVEL.IMPORTANT
        )
        return false
    current_battle_result = result
    last_battle_result = result
    pending_foes.clear()
    _clear_transient_battle_state()
    battle_finished.emit(last_battle_result)
    return true


## Releases scene-owned combatants after battle_finished consumers have copied
## the result. BattleResult value snapshots deliberately survive this cleanup.
func cleanup_battle() -> void:
    free_old_units()
    if turn_controller:
        turn_controller.turn_order.clear()
    _clear_transient_battle_state()
    current_battle_result = null
    pending_foes.clear()


## Handles battle session for this debug battle controller.
func _ensure_battle_session() -> void:
    if not current_battle_result:
        begin_battle_session()


## Clears transient battle state for this debug battle controller.
func _clear_transient_battle_state() -> void:
    focused_unit = null
    if not state_manager:
        return
    state_manager.active_unit = null
    state_manager.targets.clear()
    state_manager.selected_action = null
    state_manager.inactive_since_turn_start.clear()


## Installs a presentation implementation for subsequent battle requests.
func set_presentation_adapter(adapter: BattlePresentationAdapter) -> void:
    presentation_adapter = adapter if adapter else IMMEDIATE_PRESENTATION_ADAPTER.new()


## Restores immediate/headless presentation. An expected adapter prevents an old
## scene from clearing a newer scene's registration during deferred teardown.
func clear_presentation_adapter(expected: BattlePresentationAdapter = null) -> void:
    if expected and presentation_adapter != expected:
        return
    presentation_adapter = IMMEDIATE_PRESENTATION_ADAPTER.new()


## Handles in holder for this debug battle controller.
func _units_in_holder(holder: Node) -> Array[BattleUnit]:
    var units: Array[BattleUnit] = []
    if not holder:
        return units
    for child in holder.get_children():
        if child is BattleUnit:
            units.append(child)
    return units


#region INIT BATTLE
##
## Initializes battlefield for this debug battle controller.
func init_battlefield(ally_templates: Array[BattleUnitTemplate], foe_templates: Array[BattleUnitTemplate]) -> void:
    CustomLogger.hint(self, init_battlefield, "Initializing battlefield.", CustomLogger.LEVEL.VERBOSE)
    get_dependencies()
    free_old_units()
    _ensure_battle_session()

    var ally_displays: Array[Unit2DDisplay] = []
    var foe_displays: Array[Unit2DDisplay] = []
    for ally in ally_templates:
        if not ally:
            continue
        ally_displays.append(presentation_adapter.deploy_unit(ally, &"allies"))
        ally_unit_holder.add_to_party(ally)

    for foe in foe_templates:
        if not foe:
            continue
        foe_displays.append(presentation_adapter.deploy_unit(foe, &"foes"))
        foe_unit_holder.add_to_party(foe)

    for y in range(0, ally_unit_holder.get_child_count()):
        var unit: BattleUnit = ally_unit_holder.get_child(y)
        unit.player_controlled = true
        unit.team_id = &"allies"
        SignalBus.ally_added_to_party.emit(unit)
        if ally_displays.size() <= y or not ally_displays[y]:
            continue
        var two_d_unit: Unit2DDisplay = ally_displays[y]
        var stat_panel: UnitStatsTooltipDisplay = two_d_unit.stats_tooltip_panel
        two_d_unit.unit_reference = unit
        if y < 2:
            stat_panel.set_position(UnitStatsTooltipDisplay.LEFT_ALIGN)
        else:
            stat_panel.set_position(UnitStatsTooltipDisplay.RIGHT_ALIGN)
        var status_bar: UnitStatusBar = two_d_unit.stats_display
        status_bar.initialize(unit)

    for x in range(0, foe_unit_holder.get_child_count()):
        var unit: BattleUnit = foe_unit_holder.get_child(x)
        unit.player_controlled = false
        unit.team_id = &"foes"
        if foe_displays.size() <= x or not foe_displays[x]:
            continue
        var two_d_unit: Unit2DDisplay = foe_displays[x]
        var stat_panel: UnitStatsTooltipDisplay = two_d_unit.stats_tooltip_panel
        two_d_unit.unit_reference = unit
        if x < 2:
            stat_panel.set_position(UnitStatsTooltipDisplay.RIGHT_ALIGN)
        else:
            stat_panel.set_position(UnitStatsTooltipDisplay.LEFT_ALIGN)
        var status_bar: UnitStatusBar = two_d_unit.stats_display
        status_bar.initialize(unit)
    _seed_current_participants()


## Initializes battlefield from runtime party for this debug battle controller.
func init_battlefield_from_runtime_party(foe_templates: Array[BattleUnitTemplate]) -> Dictionary:
    get_dependencies()
    free_old_units()
    _ensure_battle_session()
    var allies: Array[BattleUnit] = party_manager.get_active_party() if party_manager else []
    for unit in allies:
        var old_parent := unit.get_parent()
        if old_parent:
            old_parent.remove_child(unit)
        ally_unit_holder.add_child(unit)
        unit.player_controlled = true
        unit.team_id = &"allies"
        SignalBus.ally_added_to_party.emit(unit)
    for template in foe_templates:
        foe_unit_holder.add_to_party(template)
    var foes: Array[BattleUnit] = _units_in_holder(foe_unit_holder)
    for unit in foes:
        unit.player_controlled = false
        unit.team_id = &"foes"
    _seed_current_participants()
    return {"allies": allies, "foes": foes}


## Applies the active encounter seed to phase-driven combatants in holder order.
func _seed_current_participants() -> void:
    var seed_value: int = current_battle_result.battle_seed if current_battle_result else 0
    (
        RANDOM_STREAMS_SCRIPT
        . seed_participants(
            _units_in_holder(ally_unit_holder),
            _units_in_holder(foe_unit_holder),
            seed_value,
        )
    )


#	SignalBus.dispatch_battle_signal.emit(BattleStateManager.FIRST_TURN_EVENT, null)


## Releases old units for this debug battle controller.
func free_old_units() -> void:
    presentation_adapter.clear()
    for child in ally_unit_holder.get_children():
        ally_unit_holder.remove_child(child)
        if not party_manager or not party_manager.reclaim_unit(child):
            child.queue_free()
    for child in foe_unit_holder.get_children():
        foe_unit_holder.remove_child(child)
        child.queue_free()


#endregion


#region GETTERS
##
## Returns dependencies for this debug battle controller.
func get_dependencies() -> void:
    assert(state_manager, "BattleController requires a phase controller.")
    assert(turn_controller, "BattleController requires a turn controller.")
    assert(ally_unit_holder and foe_unit_holder, "BattleController requires logical ally and foe holders.")


##
## Returns unit by index for this debug battle controller.
func get_unit_by_index(holder_name: StringName, index: int) -> void:
    var unit: BattleUnit
    if holder_name == ally_unit_holder.name:
        unit = get_ally_unit_by_index(index)
    if holder_name == foe_unit_holder.name:
        unit = get_foe_unit_by_index(index)
    SignalBus.unit_requested_by_index.emit(unit)


##
## Returns ally unit by index for this debug battle controller.
func get_ally_unit_by_index(index: int) -> BattleUnit:
    return ally_unit_holder.get_child(index)


##
## Returns foe unit by index for this debug battle controller.
func get_foe_unit_by_index(index: int) -> BattleUnit:
    return foe_unit_holder.get_child(index)


##
## Returns unit allies for this debug battle controller.
func get_unit_allies(unit: BattleUnit) -> Array[BattleUnit]:
    var allies: Array[BattleUnit] = []
    for candidate in get_all_active_units():
        if candidate != unit and _same_team(unit, candidate):
            allies.append(candidate)
    return allies


##
## Returns unit foes for this debug battle controller.
func get_unit_foes(unit: BattleUnit) -> Array[BattleUnit]:
    var foes: Array[BattleUnit] = []
    for candidate in get_all_active_units():
        if candidate != unit and not _same_team(unit, candidate):
            foes.append(candidate)
    return foes


## Returns whether debug battle controller same team.
func _same_team(first: BattleUnit, second: BattleUnit) -> bool:
    if not first.team_id.is_empty() and not second.team_id.is_empty():
        return first.team_id == second.team_id
    return first.get_parent() == second.get_parent()


##
## Returns units in ally holder for this debug battle controller.
func get_units_in_ally_holder() -> Array[BattleUnit]:
    var all: Array[BattleUnit]
    for unit in get_every_unit():
        if unit.is_active and _matches_team(unit, &"allies", ally_unit_holder):
            all.append(unit)
    return all


##
## Returns units in foe holder for this debug battle controller.
func get_units_in_foe_holder() -> Array[BattleUnit]:
    var all: Array[BattleUnit]
    for unit in get_every_unit():
        if unit.is_active and _matches_team(unit, &"foes", foe_unit_holder):
            all.append(unit)
    return all


## Returns whether debug battle controller matches team.
func _matches_team(unit: BattleUnit, expected_team: StringName, fallback_holder: Node) -> bool:
    if not unit.team_id.is_empty():
        return unit.team_id == expected_team
    return unit.get_parent() == fallback_holder


##
## Returns all active units for this debug battle controller.
func get_all_active_units() -> Array[BattleUnit]:
    var all: Array[BattleUnit]
    for unit in ally_unit_holder.get_children():
        if unit.is_active:
            all.append(unit)

    for unit in foe_unit_holder.get_children():
        if unit.is_active:
            all.append(unit)

    return all


## Returns every unit for this debug battle controller.
func get_every_unit() -> Array[BattleUnit]:
    var every: Array[BattleUnit]
    for unit in ally_unit_holder.get_children():
        every.append(unit)

    for unit in foe_unit_holder.get_children():
        every.append(unit)
    return every


##
## Returns unit display for this debug battle controller.
func get_unit_display(unit: BattleUnit) -> Unit2DDisplay:
    return presentation_adapter.get_unit_display(unit)


#endregion


#region HOUSEKEEPING
## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    SignalBus.init_battlefield.connect(init_battlefield)
    SignalBus.switch_to_combat_camera.connect(on_switch_to_combat_camera)
#endregion
