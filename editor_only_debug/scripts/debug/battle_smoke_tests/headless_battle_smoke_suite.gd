extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for headless runner script; reused instead of looking up the file on each call.
const HEADLESS_RUNNER_SCRIPT := preload("res://editor_only_debug/scripts/battle_headless_runner.gd")
## Script loaded for battle result script; reused instead of looking up the file on each call.
const BATTLE_RESULT_SCRIPT := preload("res://GrimDaysBattle/scripts/Other/battle_result.gd")
## Script loaded for combat event script; reused instead of looking up the file on each call.
const COMBAT_EVENT_SCRIPT := preload("res://GrimDaysBattle/scripts/Actions/Runtime/battle_combat_event.gd")


## Runs the headless battle smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    await _test_one_turn_victory()
    await _test_three_round_defeat()
    await _test_round_limit_draw()


## Checks one turn victory using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_one_turn_victory() -> void:
    var context := _create_battle_context()
    var ally: BattleUnit = context.ally
    var foe: BattleUnit = context.foe
    _configure_combatant(ally, 100.0, 100.0, 0.0, 100.0)
    _configure_combatant(foe, 20.0, 1.0, 0.0, 1.0)
    var runner: Node = HEADLESS_RUNNER_SCRIPT.new()
    add_child(runner)
    var emitted_results: Array = []
    runner.battle_finished.connect(func(captured_results): emitted_results.append(captured_results))
    var allies: Array[BattleUnit] = [ally]
    var foes: Array[BattleUnit] = [foe]
    var result = await (
        runner
        . run_battle(
            allies,
            foes,
            &"headless_victory",
            12345,
            {"return_scene": "test"},
            5,
            {"experience": 10},
        )
    )
    assert(result.finalized)
    assert(result.outcome == BATTLE_RESULT_SCRIPT.OUTCOME.VICTORY)
    assert(result.turns == 1 and result.rounds == 1)
    assert(result.surviving_allies == [ally])
    assert(result.surviving_foes.is_empty())
    assert(result.defeated_units == [foe])
    assert(result.return_context == {"return_scene": "test"})
    assert(result.rewards == {"experience": 10})
    assert(result.winning_teams == [&"allies"] and result.defeated_teams == [&"foes"])
    assert(_event_count(result, COMBAT_EVENT_SCRIPT.TYPE.DAMAGE) == 1)
    assert(_event_count(result, COMBAT_EVENT_SCRIPT.TYPE.DEFEAT) == 1)
    assert(_event_count(result, COMBAT_EVENT_SCRIPT.TYPE.ACTION_FINISHED) == 1)
    assert(emitted_results == [result], "A terminal battle must emit its result exactly once.")
    assert(
        not result.finalize(BATTLE_RESULT_SCRIPT.OUTCOME.DEFEAT, allies, foes),
        "BattleResult finalization must be idempotent.",
    )
    assert(result.outcome == BATTLE_RESULT_SCRIPT.OUTCOME.VICTORY)
    await free_node(runner)
    await free_node(context.arena)


## Checks three round defeat using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_three_round_defeat() -> void:
    var context := _create_battle_context()
    var ally: BattleUnit = context.ally
    var foe: BattleUnit = context.foe
    _configure_combatant(ally, 25.0, 1.0, 0.0, 1.0)
    _configure_combatant(foe, 100.0, 100.0, 0.0, 10.0)
    var runner: Node = HEADLESS_RUNNER_SCRIPT.new()
    add_child(runner)
    var allies: Array[BattleUnit] = [ally]
    var foes: Array[BattleUnit] = [foe]
    var result = await runner.run_battle(allies, foes, &"headless_defeat", 54321, {}, 5)
    assert(result.outcome == BATTLE_RESULT_SCRIPT.OUTCOME.DEFEAT)
    assert(result.rounds == 3, "The deterministic defeat fixture must span three rounds.")
    assert(result.turns == 5, "The faster foe should finish round three before the ally acts.")
    assert(result.surviving_allies.is_empty())
    assert(result.surviving_foes == [foe])
    assert(result.defeated_units == [ally])
    assert(result.winning_teams == [&"foes"] and result.defeated_teams == [&"allies"])
    assert(_event_count(result, COMBAT_EVENT_SCRIPT.TYPE.DAMAGE) == 5)
    assert(_event_count(result, COMBAT_EVENT_SCRIPT.TYPE.DEFEAT) == 1)
    await free_node(runner)
    await free_node(context.arena)


## Checks round limit draw using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_round_limit_draw() -> void:
    var context := _create_battle_context()
    var ally: BattleUnit = context.ally
    var foe: BattleUnit = context.foe
    _configure_combatant(ally, 25.0, 2.0, 0.0, 0.0)
    _configure_combatant(foe, 25.0, 1.0, 0.0, 0.0)
    var runner: Node = HEADLESS_RUNNER_SCRIPT.new()
    add_child(runner)
    var allies: Array[BattleUnit] = [ally]
    var foes: Array[BattleUnit] = [foe]
    var result = await runner.run_battle(allies, foes, &"headless_draw", 10101, {}, 2)
    assert(result.outcome == BATTLE_RESULT_SCRIPT.OUTCOME.DRAW)
    assert(result.finalized and result.rounds == 2 and result.turns == 4)
    assert("maximum" in result.error.to_lower())
    assert(result.defeated_units.is_empty())
    assert(result.winning_teams.is_empty() and result.defeated_teams.is_empty())
    await free_node(runner)
    await free_node(context.arena)


## Adds [code]allies[/code] as a child of [code]arena[/code]; adds [code]foes[/code] as a child of
## [code]arena[/code]; adds [code]arena[/code] as a child node. It also sets [code]foes.name[/code]
## to [code]"Foes"[/code]. Returns [code]{"arena": arena, "ally": ally, "foe": foe}[/code].
func _create_battle_context() -> Dictionary:
    var arena := Node.new()
    arena.name = "HeadlessArena"
    var allies := Node.new()
    allies.name = "Allies"
    var foes := Node.new()
    foes.name = "Foes"
    arena.add_child(allies)
    arena.add_child(foes)
    add_child(arena)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    var foe := BattleUnit.create(CELINE_TEMPLATE)
    allies.add_child(ally)
    foes.add_child(foe)
    return {"arena": arena, "ally": ally, "foe": foe}


## Sets test combat stats to the supplied health, speed, evasion and damage, with guaranteed
## accuracy and no critical or lucky-evasion chance.
func _configure_combatant(
    unit: BattleUnit,
    health: float,
    speed: float,
    evasion: float,
    damage: float,
) -> void:
    _set_override(unit, CombatStats.STATS.Health, health)
    _set_override(unit, CombatStats.STATS.Swiftness, speed)
    _set_override(unit, CombatStats.STATS.Accuracy, 100.0)
    _set_override(unit, CombatStats.STATS.Evasion, evasion)
    _set_override(unit, CombatStats.STATS.LuckyEvasion, 0.0)
    _set_override(unit, CombatStats.STATS.CriticalStrike, 0.0)
    _set_override(unit, CombatStats.STATS.PhysicalDamage, damage)
    _set_override(unit, CombatStats.STATS.PhysicalResistance, 0.0)


## Adds a test-only stat adjustment that replaces the selected stat's value with the supplied
## amount.
func _set_override(unit: BattleUnit, stat_type: CombatStats.STATS, amount: float) -> void:
    var stat := unit.get_stat(stat_type)
    var modifier_id := StringName("headless:%s:%s" % [unit.get_instance_id(), stat_type])
    (
        stat
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    modifier_id,
                    &"test:headless_battle",
                    stat_type,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    amount,
                )
            )
        )
    )


## Counts combat events of the requested type in the supplied battle result.
func _event_count(result, event_type: int) -> int:
    var count: int
    for event in result.combat_events:
        if event.type == event_type:
            count += 1
    return count
