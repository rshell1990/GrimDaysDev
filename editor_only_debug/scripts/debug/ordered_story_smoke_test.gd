## Walks the authored story and three production battles without writing player saves.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

const MASTER = preload("res://GrimDaysVN/resources/events/all_events_prototype_1.tres")
const ROOM = preload("res://GrimDaysVN/resources/events/1_0010_livingroom.tres")

var narrative_checks: int = 0
var battle_checks: int = 0
var preparation_checks: int = 0
var requested_ids: Array[StringName] = []


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().create_timer(180.0).timeout.connect(_on_timeout)
    _run.call_deferred()


func _run() -> void:
    _check_registry()
    Dialogic.Text.text_finished.disconnect(SystemHeadquarters._on_text_finished)
    var original_party: BattlePartyManager = BattleController.party_manager
    var party := IsolatedParty.new()
    add_child(party)
    var ally: BattleUnit = BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids.assign([CELINE_TEMPLATE.id])
    BattleController.party_manager = party
    for stat in [CombatStats.STATS.Swiftness, CombatStats.STATS.Accuracy, CombatStats.STATS.PhysicalDamage]:
        _override(ally, stat, 1000.0)
    var caller := Node.new()
    get_tree().root.add_child(caller)
    get_tree().current_scene = caller
    SceneManager.active_node = caller
    GameManager.change_state(GameManagerStates.STATES.Scenario)
    VNSignalBus.event_found.connect(_on_event_found)
    VNSignalBus.event_found.emit(ROOM)
    for index in range(1, MASTER.called_events.size()):
        var event: GameEvent = MASTER.called_events[index]
        if event is GameEventBattle:
            await _check_battle(event, ally)
        else:
            await _check_narrative(event)
        if narrative_checks + battle_checks != index:
            push_error("ORDERED_STORY_SMOKE_TEST: a story check failed before completing.")
            get_tree().quit(1)
            return
    assert(narrative_checks == 46, "Every timeline after the opening cinematic must complete.")
    assert(battle_checks == 3 and preparation_checks == 3)
    assert(requested_ids.size() == 49, "Each event after the opening must be requested exactly once.")
    assert(GameManager.current_event == null and not SceneManager.swapping)
    assert(GameManager.state != GameManagerStates.STATES.Navigation)
    BattleController.party_manager = original_party
    GameManager.on_loading_sequence_start()
    await Dialogic.clear()
    var outgoing: Node = get_tree().current_scene
    get_tree().current_scene = self
    SceneManager.active_node = self
    outgoing.queue_free()
    party.queue_free()
    await get_tree().create_timer(0.5).timeout
    Dialogic.Text.text_finished.connect(SystemHeadquarters._on_text_finished)
    print("ORDERED_STORY_SMOKE_TEST: PASS (46 dialogue handoffs, 3 preparations, 3 battles)") # lint:ignore debug-print,line-length -- Required test/CLI output.
    get_tree().quit()


func _check_registry() -> void:
    assert(MASTER.called_events.size() == 50 and MASTER.all.is_empty())
    var ids: Dictionary = {}
    var timelines: Dictionary = {}
    for index in MASTER.called_events.size():
        var event: GameEvent = MASTER.called_events[index]
        assert(not ids.has(event.id))
        ids[event.id] = true
        assert(SystemAdministrators.find_event_by_id(String(event.id)) == event)
        assert(event.requirements.is_empty())
        if event is GameEventSequence:
            var timeline: DialogicTimeline = event.finishing_timeline
            assert(timeline != null and not timelines.has(timeline.resource_path))
            timelines[timeline.resource_path] = true
            if index > 0:
                assert(event.timeline == timeline and event.only_called and event.starting_scene == null)
                assert(event.blocks_swap == not (MASTER.called_events[index - 1] is GameEventBattle))
                var expected: GameEvent = (
                    MASTER.called_events[index + 1] if index + 1 < MASTER.called_events.size() else null
                )
                assert(event.finished_event == expected)
            for action: GameAction in event.finishing_actions:
                assert(action is GameActionSetWorldStage or (index == 0 and action is GameActionTriggerEvent))
        else:
            assert(event is GameEventBattle and event.foes.size() > 0)
            assert(event.finished_event == MASTER.called_events[index + 1])
    assert(timelines.size() == 47)
    for file: String in DirAccess.get_files_at("res://GrimDaysVN/dialogic/scripts"):
        if file.ends_with(".dtl"):
            assert(timelines.has("res://GrimDaysVN/dialogic/scripts/" + file), "Unreachable authored timeline: " + file)


func _check_narrative(event: GameEventSequence) -> void:
    var deadline: int = Time.get_ticks_msec() + 10000
    while (Dialogic.current_timeline != event.timeline or SceneManager.swapping) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(Dialogic.current_timeline == event.timeline and GameManager.current_event == event)
    assert(GameManager.state != GameManagerStates.STATES.Navigation)
    var call_index: int = -1
    for index in event.timeline.events.size():
        if event.timeline.events[index] is DialogicCallEvent:
            call_index = index
            break
    if call_index >= 0:
        # Skip prose, not the production milestone/preparation or its ending callback.
        Dialogic.start_timeline(event.timeline, call_index)
        if event.finished_event is GameEventBattle:
            var preparation: BattlePreparationSession = UIDirector._get_party_preparation()
            deadline = Time.get_ticks_msec() + 5000
            while not preparation.active and Time.get_ticks_msec() < deadline:
                await get_tree().process_frame
            assert(preparation.active and not event.finished_event._session)
            preparation.close()
            preparation_checks += 1
    else:
        Dialogic.end_timeline()
    deadline = Time.get_ticks_msec() + 5000
    while GameManager.current_event == event and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(GameManager.current_event != event)
    if call_index >= 0 and not event.finished_event is GameEventBattle:
        assert(BattleController.party_manager.get_active_party()[0].level >= 3)
    narrative_checks += 1


func _check_battle(event: GameEventBattle, ally: BattleUnit) -> void:
    var deadline: int = Time.get_ticks_msec() + 10000
    while not is_instance_valid(event._session) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(is_instance_valid(event._session), "Battle never started: " + event.id)
    var session: BattleStorySession = event._session
    var scene: BattleEncounterScene = session.encounter
    assert(get_tree().current_scene == scene and Dialogic.current_timeline == null)
    assert(scene.coordinator.roster.get_allies() == [ally])
    assert(scene.coordinator.roster.get_foes().size() == event.foes.size())
    assert(is_zero_approx(UIDirector.cover_operator.modulate.a), "The battle must be uncovered.")
    for foe: BattleUnit in scene.coordinator.roster.get_foes():
        assert(scene.stage.get_unit_display(foe).appearance_template_scene == foe.template_resource.battle_sprite)
        for stat in [CombatStats.STATS.Evasion, CombatStats.STATS.LuckyEvasion, CombatStats.STATS.PhysicalResistance]:
            _override(foe, stat, 0.0)
        foe.get_stat(CombatStats.STATS.Health).restore_current(1.0)
    deadline = Time.get_ticks_msec() + 45000
    while not scene.awaiting_continue and Time.get_ticks_msec() < deadline:
        if scene.flow.state == BattleEncounterFlow.STATE.ACTION:
            assert(scene.flow.active_unit == ally)
            assert(scene.flow.choose_action(scene.flow.turn_id, ally.get_basic_action()))
            for foe: BattleUnit in scene.coordinator.roster.get_foes():
                if foe.is_active:
                    scene.stage.get_unit_display(foe).targeting_controller.add_unit(foe)
                    break
        await get_tree().process_frame
    assert(scene.awaiting_continue and scene.result_summary.visible)
    var result: BattleResult = scene._accepted_result
    assert(result.is_victory())
    scene.result_summary.continue_button.pressed.emit()
    await session.tree_exited
    assert(event.last_battle_result == result)
    battle_checks += 1


func _override(unit: BattleUnit, stat: int, amount: float) -> void:
    unit.get_stat(stat).add_modifier(
        UnitStatModifier.create(
            StringName("ordered_story_test:%s" % stat), &"test:ordered_story",
            stat, UnitStatModifier.OPERATION.OVERRIDE, amount
        )
    )


func _on_event_found(event: GameEvent) -> void:
    requested_ids.append(event.id)


func _on_timeout() -> void:
    push_error("ORDERED_STORY_SMOKE_TEST: timed out before completion.")
    get_tree().quit(1)
