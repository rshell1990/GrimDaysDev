extends Node
## Executes a deterministic battle without presentation or player input. Units
## are seeded independently, ordered by speed, and driven through basic actions.
class_name BattleHeadlessRunner

## Preloaded dependency used to construct or identify the action request script.
const ACTION_REQUEST_SCRIPT := preload("uid://df4ueaosb3d4f")
## Preloaded dependency used to construct or identify the action resolver script.
const ACTION_RESOLVER_SCRIPT := preload("uid://ds3ko5hlktsom")
## Preloaded dependency used to construct or identify the battle result script.
const BATTLE_RESULT_SCRIPT := preload("uid://getexvd6ak5i")
## Shared deterministic participant-seeding policy.
const RANDOM_STREAMS_SCRIPT := preload("uid://b5fxusfgl6ljh")

## Safety cap that prevents an unwinnable encounter from running forever.
const DEFAULT_MAX_ROUNDS: int = 100
## Emitted after cleanup and finalization for success, draw, or error.
signal battle_finished(result)

## Resolver used for every action in the active simulation.
var action_resolver: Node
## Re-entrancy guard that prevents overlapping simulations on one runner.
var running: bool


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    if not action_resolver:
        action_resolver = ACTION_RESOLVER_SCRIPT.new()
        action_resolver.name = "ActionResolver"
        add_child(action_resolver)


## Runs until a team is defeated or [param max_rounds] is reached. Participant
## nodes are borrowed, not freed, and battle-scoped effects are cleaned up.
func run_battle(
    allies: Array[BattleUnit],
    foes: Array[BattleUnit],
    encounter_id: StringName,
    battle_seed: int,
    return_context: Dictionary = {},
    max_rounds: int = DEFAULT_MAX_ROUNDS,
    rewards: Dictionary = {},
):
    var result = BATTLE_RESULT_SCRIPT.new()
    result.encounter_id = encounter_id
    result.battle_seed = battle_seed
    result.return_context = return_context.duplicate(true)
    result.set_rewards(rewards)
    if running:
        return _finish(
            result,
            BATTLE_RESULT_SCRIPT.OUTCOME.ERROR,
            allies,
            foes,
            "Battle runner is already active.",
        )
    var validation_error := _validate_participants(allies, foes, max_rounds)
    if not validation_error.is_empty():
        return _finish(result, BATTLE_RESULT_SCRIPT.OUTCOME.ERROR, allies, foes, validation_error)

    running = true
    RANDOM_STREAMS_SCRIPT.seed_participants(allies, foes, battle_seed)
    var stable_order: Array[BattleUnit] = _build_stable_turn_order(allies, foes)
    while result.rounds < max_rounds:
        result.rounds += 1
        SignalBus.tick.emit(StringName("%s:round:%s" % [encounter_id, result.rounds]))
        for actor in stable_order:
            if not is_instance_valid(actor) or not actor.is_active:
                continue
            var opponents: Array[BattleUnit] = foes if actor in allies else allies
            var target := _first_active(opponents)
            if not target:
                return _finish_from_state(result, allies, foes)
            actor.on_turn_started()
            if actor.is_stunned():
                await actor.effect_manager.trigger_effects(CombatEffects.TRIGGER.PROCESS_OVER)
                result.turns += 1
                continue
            var forced := actor.get_forced_action_effect()
            var action: ActionTemplate = (
                forced.definition.action if forced else actor.get_basic_action()
            )
            if not action:
                return _finish(
                    result,
                    BATTLE_RESULT_SCRIPT.OUTCOME.ERROR,
                    allies,
                    foes,
                    "Unit %s has no basic action." % actor.name,
                )
            var request_id := StringName(
                "%s:round:%s:turn:%s" % [encounter_id, result.rounds, result.turns + 1]
            )
            var selected: Array[BattleUnit] = [target]
            if forced:
                selected.assign(actor.get_targets_from_ai(action).get("targets", []))
            var request = ACTION_REQUEST_SCRIPT.new(request_id, actor, action, selected)
            var resolution = await action_resolver.resolve(request)
            if not resolution.success:
                return _finish(
                    result,
                    BATTLE_RESULT_SCRIPT.OUTCOME.ERROR,
                    allies,
                    foes,
                    resolution.error,
                )
            result.turns += 1
            result.combat_events.append_array(resolution.events)
            if not _has_active_units(allies) or not _has_active_units(foes):
                return _finish_from_state(result, allies, foes)

        await _process_round_effects(allies, foes, result.encounter_id, result.rounds)
        if not _has_active_units(allies) or not _has_active_units(foes):
            return _finish_from_state(result, allies, foes)

    return _finish(
        result,
        BATTLE_RESULT_SCRIPT.OUTCOME.DRAW,
        allies,
        foes,
        "Battle reached the maximum of %s rounds." % max_rounds,
    )


## Verifies team membership, state, RNG availability, uniqueness, and round cap
## before the simulation mutates any combatant.
func _validate_participants(
    allies: Array[BattleUnit],
    foes: Array[BattleUnit],
    max_rounds: int,
) -> String:
    if max_rounds < 1:
        return "Battle requires a positive maximum round count."
    if allies.is_empty() or foes.is_empty():
        return "Battle requires at least one ally and one foe."
    var seen: Dictionary = {}
    for unit in allies + foes:
        if not is_instance_valid(unit):
            return "Battle participant is invalid."
        if not unit.is_active:
            return "Battle participant %s begins defeated." % unit.name
        if not unit.randomizer:
            return "Battle participant %s has no randomizer." % unit.name
        if seen.has(unit.get_instance_id()):
            return "The same unit cannot occupy both battle teams."
        seen[unit.get_instance_id()] = true
    for ally in allies:
        for foe in foes:
            if ally.get_parent() == foe.get_parent():
                return "Allies and foes must belong to distinct team holders."
    return ""


## Sorts by descending speed and uses input order as a stable tie-break.
func _build_stable_turn_order(
    allies: Array[BattleUnit],
    foes: Array[BattleUnit],
) -> Array[BattleUnit]:
    var indexed: Array[Dictionary] = []
    var index: int
    for unit in allies + foes:
        indexed.append({"unit": unit, "index": index})
        index += 1
    indexed.sort_custom(
        func(a: Dictionary, b: Dictionary) -> bool:
            var a_unit: BattleUnit = a.unit
            var b_unit: BattleUnit = b.unit
            if not is_equal_approx(a_unit.speed, b_unit.speed):
                return a_unit.speed > b_unit.speed
            return a.index < b.index
    )
    var ordered: Array[BattleUnit] = []
    for entry in indexed:
        ordered.append(entry.unit)
    return ordered


## Triggers round-end effects sequentially for every active combatant.
func _process_round_effects(
    allies: Array[BattleUnit],
    foes: Array[BattleUnit],
    encounter_id: StringName,
    round_number: int,
) -> void:
    for unit in allies + foes:
        if not is_instance_valid(unit) or not unit.is_active or not unit.effect_manager:
            continue
        if unit.effect_manager.has_effects_to_trigger(CombatEffects.TRIGGER.ROUND_OVER):
            await (
                unit
                . resolve_effects(
                    CombatEffects.TRIGGER.ROUND_OVER,
                    StringName("%s:round:%s" % [encounter_id, round_number]),
                )
            )


## Derives victory, defeat, or draw from current active team membership.
func _finish_from_state(result, allies: Array[BattleUnit], foes: Array[BattleUnit]):
    var allies_active := _has_active_units(allies)
    var foes_active := _has_active_units(foes)
    if allies_active and not foes_active:
        return _finish(result, BATTLE_RESULT_SCRIPT.OUTCOME.VICTORY, allies, foes)
    if foes_active and not allies_active:
        return _finish(result, BATTLE_RESULT_SCRIPT.OUTCOME.DEFEAT, allies, foes)
    return _finish(result, BATTLE_RESULT_SCRIPT.OUTCOME.DRAW, allies, foes)


## Cleans transient effects, finalizes the result, clears [member running], and
## emits [signal battle_finished].
func _finish(
    result,
    outcome: int,
    allies: Array[BattleUnit],
    foes: Array[BattleUnit],
    error: String = "",
):
    _cleanup_battle_effects(allies + foes)
    result.finalize(outcome, allies, foes, error)
    running = false
    battle_finished.emit(result)
    return result


## Revokes transient effects while retaining equipment and progression grants.
func _cleanup_battle_effects(units: Array[BattleUnit]) -> void:
    for unit in units:
        if is_instance_valid(unit) and unit.effect_manager:
            unit.effect_manager.remove_battle_scoped_effects()


## Returns whether [param units] contains a valid active combatant.
func _has_active_units(units: Array[BattleUnit]) -> bool:
    return _first_active(units) != null


## Returns the first valid active unit in authored order, or [code]null[/code].
func _first_active(units: Array[BattleUnit]) -> BattleUnit:
    for unit in units:
        if is_instance_valid(unit) and unit.is_active:
            return unit
    return null
