extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Authored basement handoff and both accepted outcomes, with an intercepted aftermath.
## Only the aftermath is intercepted; no downstream narrative or player save runs.

const ENCOUNTER_ID := "2_0095_battle_with_nuns"


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


class CountingAftermath:
    extends GameEvent
    var starts: int = 0

    func start() -> void:
        starts += 1


## Restores all story globals after exercising the real handoff and summary path.
func run() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var old_scene := get_tree().current_scene
    var old_active: Node = SceneManager.active_node
    var old_party: BattlePartyManager = BattleController.party_manager
    var old_event: GameEvent = GameManager.current_event
    var old_seen: Array = GameManager.seen_events.duplicate()
    var old_world: int = GameManager.world_stage
    var old_state: GameManagerStates.STATES = GameManager.state
    var old_last: GameManagerStates.STATES = GameManager.last_state
    var old_manager_state = GameManager.state_manager.current_state
    var old_manager_last = GameManager.state_manager.last_state
    var old_timeline: DialogicTimeline = Dialogic.last_timeline
    for victory in [true, false]:
        await _test_basement(victory)
    get_tree().current_scene = old_scene
    SceneManager.active_node = old_active
    BattleController.party_manager = old_party
    GameManager.current_event = old_event
    GameManager.world_stage = old_world
    GameManager.seen_events.assign(old_seen)
    GameManager.state = old_state
    GameManager.last_state = old_last
    GameManager.state_manager.current_state = old_manager_state
    GameManager.state_manager.last_state = old_manager_last
    GameManager.state_changed.emit(old_state)
    Dialogic.last_timeline = old_timeline
    print("BASEMENT_STORY_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.


# Accelerated combat verifies transitions, while SacredDutySmokeSuite verifies authored tuning.
func _test_basement(victory: bool) -> void:
    var event := SystemAdministrators.find_event_by_id(ENCOUNTER_ID) as GameEventBattle
    assert(event and event.only_called and not event.require_victory)
    assert(event.finished_event.id == &"2_0100_basement_after_battle")
    assert(event.finished_event == event.defeated_event)
    assert(event.foes.size() == 3)
    for index in 3:
        assert(event.foes[index].id == [&"SisterHara", &"SisterKatherine", &"SisterAnastasia"][index])
        assert(event.foes[index].level == 5 and event.foes[index].skill_collection)
    # The preceding sequence must not dispatch the aftermath before battle acceptance.
    var preceding := SystemAdministrators.find_event_by_id("2_0090_in_the_basement_before_battle")
    for action in preceding.finishing_actions:
        assert(not (action is GameActionTriggerEvent))
    GameManager.world_stage = 280
    var original_cover: float = UIDirector.cover_operator.modulate.a
    UIDirector.cover_operator.modulate.a = 1.0
    var original_aftermath := event.finished_event
    var aftermath := CountingAftermath.new()
    aftermath.id = &"basement_test_aftermath"
    event.finished_event = aftermath
    event.defeated_event = aftermath
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids.assign([CELINE_TEMPLATE.id])
    BattleController.party_manager = party
    for stat in [CombatStats.STATS.Swiftness, CombatStats.STATS.Accuracy, CombatStats.STATS.PhysicalDamage]:
        _override(ally, stat, 1000)
    if not victory:
        ally.get_stat(CombatStats.STATS.Health).restore_current(1)
        _override(ally, CombatStats.STATS.Evasion, 0)
        _override(ally, CombatStats.STATS.LuckyEvasion, 0)
    var caller := Node.new()
    get_tree().root.add_child(caller)
    get_tree().current_scene = caller
    SceneManager.active_node = caller
    GameManager.change_state(GameManagerStates.STATES.Scenario)
    var prelude := SystemAdministrators.find_event_by_id(
        "2_0095_party_fights_lich_for_ember_void_blades"
    ) as GameEventSequence
    assert(prelude.finished_event == event and preceding.finished_event == prelude)
    GameManager._on_event_found(prelude)
    await get_tree().process_frame
    var timeline: DialogicTimeline = prelude.timeline
    timeline.process()
    var preparation_index: int = -1
    for index in timeline.events.size():
        if timeline.events[index] is DialogicCallEvent:
            preparation_index = index
            break
    assert(preparation_index >= 0)
    Dialogic.start_timeline(timeline, preparation_index)
    var preparation: BattlePreparationSession = UIDirector._get_party_preparation()
    var preparation_deadline := Time.get_ticks_msec() + 5000
    while not preparation.active and Time.get_ticks_msec() < preparation_deadline:
        await get_tree().process_frame
    assert(preparation.active and not event._session)
    preparation.close()
    var deadline := Time.get_ticks_msec() + 5000
    while not is_instance_valid(event._session) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(event._session and not Dialogic.current_timeline)
    deadline = Time.get_ticks_msec() + 5000
    while not is_zero_approx(UIDirector.cover_operator.modulate.a) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(is_zero_approx(UIDirector.cover_operator.modulate.a), "The introduction fade must uncover battle.")
    var session := event._session
    var scene := session.encounter
    assert(get_tree().current_scene == scene and scene.coordinator.roster.get_allies() == [ally])
    var bars: Array[Rect2] = []
    for foe in scene.coordinator.roster.get_foes():
        var display := scene.stage.get_unit_display(foe)
        assert(display.appearance_template_scene == foe.template_resource.battle_sprite)
        var rect: Rect2 = display.health_bar.get_global_rect()
        for previous in bars:
            assert(not rect.intersects(previous), "Nun Health bars must not overlap.")
        bars.append(rect)
        _override(foe, CombatStats.STATS.Accuracy, 100)
        _override(foe, CombatStats.STATS.Evasion, 0)
        _override(foe, CombatStats.STATS.LuckyEvasion, 0)
        if victory:
            foe.get_stat(CombatStats.STATS.Health).restore_current(1)
    deadline = Time.get_ticks_msec() + 45000
    while not scene.awaiting_continue and Time.get_ticks_msec() < deadline:
        if scene.flow.state == BattleEncounterFlow.STATE.ACTION:
            assert(scene.flow.active_unit == ally)
            if victory:
                assert(scene.flow.choose_action(scene.flow.turn_id, ally.get_basic_action()))
                for foe in scene.coordinator.roster.get_foes():
                    if foe.is_active:
                        scene.stage.get_unit_display(foe).targeting_controller.add_unit(foe)
                        break
            else:
                assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.WAIT))
        await get_tree().process_frame
    assert(scene.awaiting_continue and not scene.awaiting_retry and aftermath.starts == 0)
    assert(scene.result_summary.visible and GameManager.world_stage == 280)
    scene.result_summary.continue_button.pressed.emit()
    await session.tree_exited
    assert(event.last_battle_result.is_victory() == victory and aftermath.starts == 1)
    assert(event.last_battle_result.foe_snapshots.size() == 3)
    assert(GameManager.world_stage == 290, "Both accepted outcomes must preserve the original stage advance.")
    event.finish()
    assert(aftermath.starts == 1)
    event.finished_event = original_aftermath
    event.defeated_event = original_aftermath
    UIDirector.cover_operator.modulate.a = original_cover
    await free_node(scene)
    await free_node(party)


func _override(unit: BattleUnit, stat: int, amount: float) -> void:
    unit.get_stat(stat).add_modifier(
        UnitStatModifier.create(
            StringName("basement_test:%s" % stat), &"test:basement", stat, UnitStatModifier.OPERATION.OVERRIDE, amount
        )
    )
