extends Node
## Starts and ends battles, keeps their results, and cleans up afterwards.
## Other scripts handle player input, turns and what appears on screen.
class_name BattleCoordinator

## Script loaded for roster; reused instead of looking up the file on each call.
const ROSTER := preload("res://GrimDaysBattle/scripts/Battle/Runtime/battle_encounter_roster.gd")
## Script loaded for turn order; reused instead of looking up the file on each call.
const TURN_ORDER := preload("res://GrimDaysBattle/scripts/Battle/Runtime/battle_turn_order.gd")
## Script loaded for random streams; reused instead of looking up the file on each call.
const RANDOM_STREAMS := preload("res://GrimDaysBattle/scripts/Battle/Runtime/battle_random_streams.gd")

## Announces that units and the result have been prepared for the supplied battle attempt number.
signal battle_started(session_id: int)
## Announces the finalized result and attempt number before the encounter is cleaned up.
signal battle_finished(session_id: int, result: BattleResult)
## Tells displays to stop using the battle's units before opponents are deleted.
signal battle_clearing(session_id: int)

## Named choices for state: [code]IDLE[/code], [code]PREPARING[/code], [code]ACTIVE[/code],
## [code]FINISHED[/code], [code]CLEANING[/code].
enum STATE { IDLE, PREPARING, ACTIVE, FINISHED, CLEANING }

## Manages opponents created for this battle and existing allies from the player's party.
var roster: BattleEncounterRoster = ROSTER.new()
## List of units still waiting to take a turn in this battle's current round.
var turn_order: BattleTurnOrder = TURN_ORDER.new()
## Current battle stage, used to decide which operations and save requests are allowed.
var state: STATE = STATE.IDLE
## Battle attempt number. Increases each time a battle starts successfully, so old requests can be
## rejected.
var session_id: int = 0
## Battle result updated during play, completed when the battle ends, and cleared during cleanup.
var current_result: BattleResult
## Reason the latest begin_encounter call failed; cleared before each attempt.
var last_error: String = ""
## Battle-only watchers are disconnected before pool restoration or teardown.
var _lucidity := BattleLucidityMonitor.new()


## Adds this node to the group checked before saving, so a running battle can block saves.
func _ready() -> void:
    add_to_group(&"battle_save_guards")


## Adds the unit roster as a child node so it is removed along with this coordinator.
func _init() -> void:
    roster.name = "EncounterRoster"
    add_child(roster)
    _lucidity.action_completed.connect(_on_lucidity_action_completed)


## Starts a battle using the existing party manager and opponent templates.
## Allies are the player's existing units, rather than new copies made from templates.
func begin_encounter(
    party: BattlePartyManager,
    foes: Array[BattleUnitTemplate],
    encounter_id: StringName,
    battle_seed: int = 0,
    return_context: Dictionary = {},
    rewards: Dictionary = {},
) -> bool:
    last_error = ""
    if state != STATE.IDLE or not is_inside_tree() or is_queued_for_deletion():
        last_error = "The coordinator must be live and idle before starting an encounter."
        return false
    if encounter_id.is_empty():
        last_error = "An encounter ID is required."
        return false
    state = STATE.PREPARING
    if not roster.deploy(party, foes):
        last_error = roster.last_error
        state = STATE.IDLE
        return false
    session_id += 1
    current_result = BattleResult.new()
    current_result.encounter_id = encounter_id
    current_result.battle_seed = battle_seed
    current_result.return_context = return_context.duplicate(true)
    current_result.set_rewards(rewards)
    RANDOM_STREAMS.seed_participants(roster.get_allies(), roster.get_foes(), battle_seed)
    state = STATE.ACTIVE
    roster.turn_delay_request = delay_pending_turn.bind(session_id)
    _lucidity.start(roster, is_current_session.bind(session_id))
    battle_started.emit(session_id)
    return true


## Returns whether the supplied attempt number still belongs to the running battle.
## Code that waits for animations or effects should check this before continuing.
func is_current_session(token: int) -> bool:
    return state == STATE.ACTIVE and token == session_id


## Rebuilds the turn list and adds one to the round count. Returns false if the attempt number is no
## longer current.
func begin_round(token: int) -> bool:
    if not is_current_session(token):
        return false
    turn_order.begin_round(roster.get_all_active_units())
    current_result.rounds += 1
    return true


## Adds one to the turn count only if the supplied attempt number belongs to the running battle.
func record_turn_started(token: int) -> bool:
    if not is_current_session(token) or not turn_order.mark_turn_started():
        return false
    current_result.turns += 1
    return true


## Attempt-correlated domain mutation, independent from UI or animation. The
## roster injects this capability into effects without a global controller lookup.
func delay_pending_turn(unit: BattleUnit, token: int) -> bool:
    return is_current_session(token) and unit in roster.get_participants() and turn_order.delay_pending(unit)


## Completes the result and announces that the battle has ended. Repeated calls return the same
## result until cleanup.
## Code responding to that announcement may immediately clean up the battle.
func finish(token: int, outcome: BattleResult.OUTCOME, error: String = "") -> BattleResult:
    if token != session_id or outcome == BattleResult.OUTCOME.NONE:
        return null
    if state == STATE.FINISHED:
        return current_result
    if state != STATE.ACTIVE:
        return null
    state = STATE.FINISHED
    _lucidity.stop()
    var result := current_result
    roster.remove_battle_effects()
    result.escaped_allies.assign(roster.escaped.keys())
    result.finalize(outcome, roster.get_allies(), roster.get_foes(), error)
    turn_order.clear()
    battle_finished.emit(token, result)
    return result


## Releases this attempt's units and result, including when stopping an unfinished battle.
## An old attempt number cannot clean up a newer battle.
func cleanup(token: int) -> bool:
    if token != session_id or state not in [STATE.ACTIVE, STATE.FINISHED]:
        return false
    state = STATE.CLEANING
    _lucidity.stop()
    battle_clearing.emit(token)
    turn_order.clear()
    roster.release()
    current_result = null
    state = STATE.IDLE
    return true


## Returns the save rejection message, or an empty string while idle.
func get_save_block_reason() -> String:
    return "Saving is unavailable during an active battle." if state != STATE.IDLE else ""


## Releases the current encounter when the coordinator leaves the scene tree.
func _exit_tree() -> void:
    cleanup(session_id)


## Automatic break actions keep their combat history without consuming a scheduled turn.
func _on_lucidity_action_completed(resolution: BattleActionResolution) -> void:
    if state == STATE.ACTIVE and current_result:
        current_result.combat_events.append_array(resolution.events)


## Process only the scheduled actor, and only when it defines a Lucidity stat.
## Turn flow awaits any selected effect/action before offering normal choices.
func process_lucidity_turn(unit: BattleUnit, token: int) -> void:
    if (
        not is_current_session(token)
        or unit != turn_order.get_active_unit()
        or not is_instance_valid(unit)
        or not unit.get_stat(CombatStats.STATS.Lucidity)
    ):
        return
    await _lucidity.process_turn(unit)
