extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Existing Harlok placeholders at the Demorai and raider handoffs.
## Only the aftermath is intercepted; no downstream narrative or player save runs.

const VARIANTS := ["2_0035_fight_harlok_alone", "2_0032_fight_harlok_and_goons"]


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


class CountingAftermath:
    extends GameEvent
    var starts: int = 0

    func start() -> void:
        starts += 1


## Runs both authored courtyard handoffs through preparation, retry, victory, summary and one
## follow-up event.
func run() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    var old_scene := get_tree().current_scene
    var old_active: Node = SceneManager.active_node
    var old_party: BattlePartyManager = BattleController.party_manager
    var old_event: GameEvent = GameManager.current_event
    var old_seen: Array = GameManager.seen_events.duplicate()
    var old_state: GameManagerStates.STATES = GameManager.state
    var old_last: GameManagerStates.STATES = GameManager.last_state
    var old_manager_state = GameManager.state_manager.current_state
    var old_manager_last = GameManager.state_manager.last_state
    var old_timeline: DialogicTimeline = Dialogic.last_timeline
    for variant in VARIANTS:
        await _test_variant(variant)
    get_tree().current_scene = old_scene
    SceneManager.active_node = old_active
    BattleController.party_manager = old_party
    GameManager.current_event = old_event
    GameManager.seen_events.assign(old_seen)
    GameManager.state = old_state
    GameManager.last_state = old_last
    GameManager.state_manager.current_state = old_manager_state
    GameManager.state_manager.last_state = old_manager_last
    GameManager.state_changed.emit(old_state)
    Dialogic.last_timeline = old_timeline


## Exercises one real handoff timeline with accelerated test combat and a counting replacement for
## the aftermath event. This checks transitions, not encounter difficulty.
func _test_variant(id: String) -> void:
    var event := SystemAdministrators.find_event_by_id(id) as GameEventBattle
    assert(event and event.only_called and event.require_victory)
    var expected_next: StringName = (
        &"2_0030_attempt_chores" if id == VARIANTS[0] else &"2_0035_villagers_reward_party_for_rescue"
    )
    assert(event.finished_event.id == expected_next and not event.defeated_event)
    var expected: Array = [&"HarlokTeen"] if id == VARIANTS[0] else [&"HarlokTeen", &"GoonATeen", &"GoonBTeen"]
    assert(event.foes.size() == expected.size())
    for index in expected.size():
        assert(event.foes[index].id == expected[index] and not event.foes[index].permanent)
    var original_aftermath := event.finished_event
    var aftermath := CountingAftermath.new()
    aftermath.id = &"courtyard_test_aftermath"
    event.finished_event = aftermath
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(ally)
    party.runtime_units[CELINE_TEMPLATE.id] = ally
    party.active_party_ids.assign([CELINE_TEMPLATE.id])
    BattleController.party_manager = party
    assert(party.ensure_minimum_level(CELINE_TEMPLATE.id, 3))
    assert(ally.get_stat(CombatStats.STATS.Level).Base == 3)
    # Deterministic integration fixture, not a change to authored encounter balance.
    for stat in [CombatStats.STATS.Swiftness, CombatStats.STATS.Accuracy, CombatStats.STATS.PhysicalDamage]:
        _override(ally, stat, 1000.0)
    var caller := Node.new()
    get_tree().root.add_child(caller)
    get_tree().current_scene = caller
    SceneManager.active_node = caller
    GameManager.change_state(GameManagerStates.STATES.Scenario)
    var prelude_id: String = (
        "2_0025_chores_choice" if id == VARIANTS[0] else "2_0032_party_fights_raiders_and_cave_troll"
    )
    var prelude := SystemAdministrators.find_event_by_id(prelude_id) as GameEventSequence
    assert(prelude.finished_event == event)
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
    var preparation := UIDirector._get_party_preparation()
    var deadline := Time.get_ticks_msec() + 5000
    while not preparation.active and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(preparation.active and not event._session, "Preparation must precede battle handoff.")
    assert(get_tree().current_scene == caller)
    preparation.close()
    deadline = Time.get_ticks_msec() + 5000
    while not is_instance_valid(event._session) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(event._session and not Dialogic.current_timeline)
    var session := event._session
    var scene := session.encounter
    assert(get_tree().current_scene == scene and scene.coordinator.roster.get_allies() == [ally])
    assert(scene.coordinator.roster.get_foes().size() == expected.size())
    var bars: Array[Rect2] = []
    for foe in scene.coordinator.roster.get_foes():
        var display := scene.stage.get_unit_display(foe)
        assert(display.stats_display.z_index > display.sprite_holder.z_index)
        var rect: Rect2 = display.health_bar.get_global_rect()
        for previous in bars:
            assert(not rect.intersects(previous), "Courtyard foe Health bars must not overlap.")
        bars.append(rect)
    assert(ally.get_parent() == party)
    var token: int = scene.coordinator.session_id
    var failed := scene.coordinator.finish(token, BattleResult.OUTCOME.DEFEAT)
    scene.coordinator.battle_finished.emit(token, failed)
    deadline = Time.get_ticks_msec() + 5000
    while not scene.awaiting_retry and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(scene.awaiting_retry and aftermath.starts == 0 and not failed.rewards_settled)
    assert(scene.retry_encounter(token))
    assert(scene.coordinator.current_result.battle_seed == event.battle_seed)
    for foe in scene.coordinator.roster.get_foes():
        assert(scene.stage.get_unit_display(foe).appearance_template_scene == foe.template_resource.battle_sprite)
        for stat in [CombatStats.STATS.Evasion, CombatStats.STATS.LuckyEvasion, CombatStats.STATS.PhysicalResistance]:
            _override(foe, stat, 0.0)
        foe.get_stat(CombatStats.STATS.Health).restore_current(1.0)
    deadline = Time.get_ticks_msec() + 45000
    while not scene.awaiting_continue and Time.get_ticks_msec() < deadline:
        if scene.flow.state == BattleEncounterFlow.STATE.ACTION:
            assert(scene.flow.active_unit == ally)
            assert(scene.flow.choose_action(scene.flow.turn_id, ally.get_basic_action()))
            for foe in scene.coordinator.roster.get_foes():
                if foe.is_active:
                    scene.stage.get_unit_display(foe).targeting_controller.add_unit(foe)
                    break
        await get_tree().process_frame
    assert(scene.awaiting_continue and aftermath.starts == 0)
    assert(scene.result_summary.visible)
    scene.result_summary.continue_button.pressed.emit()
    await session.tree_exited
    assert(event.last_battle_result.is_victory() and aftermath.starts == 1)
    assert(event.last_battle_result.foe_snapshots.size() == expected.size())
    event.finish()
    assert(aftermath.starts == 1)
    event.finished_event = original_aftermath
    await free_node(scene)
    await free_node(party)


## Applies a test-only stat modifier used to make the integration checks finish quickly.
func _override(unit: BattleUnit, stat: int, amount: float) -> void:
    unit.get_stat(stat).add_modifier(
        UnitStatModifier.create(
            StringName("courtyard_test:%s" % stat), &"test:courtyard", stat, UnitStatModifier.OPERATION.OVERRIDE, amount
        )
    )
