extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Resource loaded for harlok; reused instead of looking up the file on each call.
const HARLOK := preload("res://GrimDaysBattle/resources/units/harlok/harlok_battle_unit_template.tres")


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


class CountingAction:
    extends GameAction
    var executions: int = 0

    func execute() -> void:
        executions += 1


class Branch:
    extends GameEvent
    var starts: int = 0

    func start() -> void:
        starts += 1


class EndingEvent:
    extends GameEvent
    var next: GameEvent
    var finishes: int = 0

    func finish() -> void:
        finishes += 1
        VNSignalBus.event_found.emit(next)


## Permanent party manager used by the story-battle test fixture.
var _party: BattlePartyManager
## Permanent ally used to check story-battle and retry behavior.
var _ally: BattleUnit


## Runs the production story smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    await get_tree().process_frame
    var old_scene := get_tree().current_scene
    var old_active := SceneManager.active_node
    var old_party: BattlePartyManager = BattleController.party_manager
    var old_event: GameEvent = GameManager.current_event
    var old_seen: Array = GameManager.seen_events.duplicate()
    var old_state = GameManager.state
    var old_last_state = GameManager.last_state
    var old_manager_state = GameManager.state_manager.current_state
    var old_manager_last = GameManager.state_manager.last_state
    _party = IsolatedParty.new()
    add_child(_party)
    _ally = BattleUnit.create(CELINE_TEMPLATE)
    _party.add_child(_ally)
    _party.runtime_units[CELINE_TEMPLATE.id] = _ally
    _party.active_party_ids = [CELINE_TEMPLATE.id]
    BattleController.party_manager = _party
    await _test_branch(BattleResult.OUTCOME.VICTORY, true)
    await _test_branch(BattleResult.OUTCOME.DEFEAT, false)
    await _test_required_victory()
    await _test_timeline_reaction()
    await _test_cancel_pending_timeline()
    await _test_non_story_session()
    get_tree().current_scene = old_scene
    SceneManager.active_node = old_active
    BattleController.party_manager = old_party
    GameManager.current_event = old_event
    GameManager.seen_events.assign(old_seen)
    GameManager.state = old_state
    GameManager.last_state = old_last_state
    GameManager.state_manager.current_state = old_manager_state
    GameManager.state_manager.last_state = old_manager_last
    GameManager.state_changed.emit(old_state)
    await free_node(_party)


## Sets [code]event.id[/code] to [code]&"story_policy_test"[/code]; sets [code]event.foes[/code] to
## [code][HARLOK][/code]; sets [code]event.battle_seed[/code] to [code]818[/code]. Returns
## [code]event[/code].
func _event() -> GameEventBattle:
    var event := GameEventBattle.new()
    event.id = &"story_policy_test"
    event.foes = [HARLOK]
    event.battle_seed = 818
    event.rewards = {"experience": 7}
    event.finished_event = Branch.new()
    event.finished_event.id = &"story_victory"
    event.defeated_event = Branch.new()
    event.defeated_event.id = &"story_defeat"
    event.finishing_actions = [CountingAction.new()]
    return event


## Sets [code]SceneManager.active_node[/code] to [code]caller[/code]. Returns [code]caller[/code].
func _caller() -> Node:
    var caller := Node.new()
    get_tree().root.add_child(caller)
    get_tree().current_scene = caller
    SceneManager.active_node = caller
    return caller


## Waits up to five seconds for the story event to create a battle session, then asserts that it
## exists.
func _wait_started(event: GameEventBattle) -> void:
    var deadline := Time.get_ticks_msec() + 5000
    while not is_instance_valid(event._session) and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(is_instance_valid(event._session), "Story battle did not start.")


## Waits up to five seconds for a retry prompt, then asserts that the scene is waiting for retry
## input.
func _wait_retry(scene: BattleEncounterScene) -> void:
    var deadline := Time.get_ticks_msec() + 5000
    while not scene.awaiting_retry and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(scene.awaiting_retry, "Non-victory must present retry, not advance the story.")


## Checks branch using test objects and assertions. A failed assertion identifies behavior that no
## longer meets the test’s expectation.
func _test_branch(outcome: int, timeline_trigger: bool) -> void:
    var caller := _caller()
    var event := _event()
    if timeline_trigger:
        Dialogic.current_timeline = DialogicTimeline.new()
    VNSignalBus.event_found.emit(event)
    event.start()
    if timeline_trigger:
        assert(event._waiting_for_timeline and event._session == null)
        assert(get_tree().current_scene == caller and not caller.is_queued_for_deletion())
        Dialogic.current_timeline = null
        Dialogic.timeline_ended.emit()
    await _wait_started(event)
    var session := event._session
    var scene := session.encounter
    assert(get_tree().current_scene == scene and scene is BattleEncounterScene)
    assert(not is_instance_valid(caller) or caller.is_queued_for_deletion(), "The ended VN scene must be replaced.")
    assert(_ally.get_parent() == _party)
    assert(not SaveAndLoadSystemManager.can_save_game())
    assert(not await SaveAndLoadSystemManager.save_game("blocked_story", "blocked"))
    assert(not SaveAndLoadSystemManager.save_checkpoint())
    var result := scene.coordinator.finish(scene.coordinator.session_id, outcome)
    scene.coordinator.battle_finished.emit(scene.coordinator.session_id, result)
    await _wait_continue(scene)
    assert(event.last_battle_result == null and event.finishing_actions[0].executions == 0)
    assert(not SaveAndLoadSystemManager.can_save_game())
    scene.result_summary.continue_button.pressed.emit()
    await session.tree_exited
    assert(event.last_battle_result == result)
    assert(result.battle_seed == 818 and result.rewards == {"experience": 7})
    assert(event.finishing_actions[0].executions == 1)
    assert(event.finished_event.starts == (1 if outcome == BattleResult.OUTCOME.VICTORY else 0))
    assert(event.defeated_event.starts == (1 if outcome == BattleResult.OUTCOME.DEFEAT else 0))
    event.finish()
    event._on_battle_finished(result)
    assert(event.finishing_actions[0].executions == 1)
    assert(scene.flow.state == BattleEncounterFlow.STATE.STOPPED)
    assert(scene.coordinator.state == BattleCoordinator.STATE.IDLE)
    assert(SaveAndLoadSystemManager.can_save_game())
    await free_node(scene)


## Checks required victory using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_required_victory() -> void:
    _caller()
    var supply := ItemTemplate.new()
    supply.id = &"retry_supply"
    supply.stack_size = 3
    var owned_inventory: Inventory = _ally.inventory
    assert(owned_inventory.add_item(ItemBase.create(supply, 3)))
    var supplies_before: Dictionary = owned_inventory.capture_state()
    var stash_before: Dictionary = _party.stash.capture_state()
    var event := _event()
    event.require_victory = true
    var health := _ally.get_stat(CombatStats.STATS.Health)
    var energy := _ally.get_stat(CombatStats.STATS.Energy)
    var strength := _ally.get_stat(CombatStats.STATS.Strength)
    health.decrease_current_flat(5)
    var start_health := health.Current
    var start_energy := energy.Current
    var start_strength := strength.Max
    var baseline := EffectFlatChangeStatTemplate.new()
    baseline.id = &"retry_baseline"
    baseline.stat = CombatStats.STATS.Strength
    baseline.flat_amount = 3
    baseline.lifetime = EffectTemplate.LIFETIME.ROUNDS
    baseline.duration = 2
    baseline.trigger = CombatEffects.TRIGGER.EQUIP
    baseline.kind = CombatEffects.KIND.BUFF
    baseline.template_scene = STAT_EFFECT_SCENE
    var baseline_effect := _ally.effect_manager.add_effect(_ally, _ally, baseline)
    baseline_effect.apply()
    start_strength = strength.Max
    start_health = health.Current
    start_energy = energy.Current
    _ally._action_cooldowns[_ally.get_basic_action().id] = 3
    event.start()
    await _wait_started(event)
    var session := event._session
    var scene := session.encounter
    var old_foe := scene.coordinator.roster.get_foes()[0]
    var first_token := scene.coordinator.session_id
    for outcome in [BattleResult.OUTCOME.DEFEAT, BattleResult.OUTCOME.DRAW]:
        var token := scene.coordinator.session_id
        scene.flow.stop()
        assert(owned_inventory.use_item(1, 3), "Consume the entire supply stack during the failed attempt.")
        health.decrease_current_flat(health.Current)
        energy.decrease_current_flat(energy.Current)
        _ally._action_cooldowns.clear()
        strength.add_modifier(
            UnitStatModifier.create(
                &"failed_permanent",
                &"failed_attempt",
                CombatStats.STATS.Strength,
                UnitStatModifier.OPERATION.FLAT_ADD,
                20,
                UnitStatModifier.LIFETIME.PERSISTENT
            )
        )
        var failed_result := scene.coordinator.finish(token, outcome)
        await _wait_retry(scene)
        assert(
            not failed_result.party_recovered and health.Current == 0,
            "Failed required-victory attempts must not run accepted-result recovery."
        )
        assert(not failed_result.rewards_settled, "Failed attempts never award rewards.")
        assert(event.last_battle_result == null and event.finishing_actions[0].executions == 0)
        assert(event.finished_event.starts == 0 and event.defeated_event.starts == 0)
        assert(not SaveAndLoadSystemManager.can_save_game())
        var menu: BattleActionMenu = scene.get_node("Interface/ActionMenu")
        assert(menu.retry.visible and not menu.actions.visible and not menu.back.visible)
        menu.retry.pressed.emit()
        assert(scene.coordinator.session_id > token)
        assert(not scene.retry_encounter(token), "Stale/double retry cannot restart the next attempt.")
        assert(
            _ally.inventory == owned_inventory and owned_inventory.capture_state() == supplies_before,
            "Retry restores consumed supplies without replacing the permanent inventory node."
        )
        assert(_party.stash.capture_state() == stash_before, "Combat retries do not borrow or reset shared storage.")
        assert(_ally.get_parent() == _party and is_equal_approx(health.Current, start_health))
        assert(
            is_equal_approx(energy.Current, start_energy) and is_equal_approx(strength.Max, start_strength),
            "Retry energy %s/%s, strength %s/%s" % [energy.Current, start_energy, strength.Max, start_strength]
        )
        assert(not strength.mods.has(&"failed_permanent"))
        assert(_ally.get_action_cooldown(_ally.get_basic_action()) == 3)
        var restored_effects := _ally.effect_manager.get_effects_from_source(
            (
                baseline_effect.source_id
                if is_instance_valid(baseline_effect)
                else StringName("runtime_source:%s" % _ally.get_instance_id())
            )
        )
        assert(restored_effects.size() == 1 and restored_effects[0].duration == 2)
        scene.coordinator.battle_finished.emit(token, failed_result)
        assert(not scene.awaiting_retry)
    assert(scene.attempts == 3 and scene.coordinator.session_id > first_token)
    assert(scene.coordinator.roster.get_foes()[0] != old_foe)
    # The final attempt is fought through the real player action/target path.
    _ally._action_cooldowns.clear()
    for stat in [CombatStats.STATS.Swiftness, CombatStats.STATS.Accuracy, CombatStats.STATS.PhysicalDamage]:
        _ally.get_stat(stat).add_modifier(
            UnitStatModifier.create(
                StringName("retry_win:%s" % stat), &"test:retry_win", stat, UnitStatModifier.OPERATION.OVERRIDE, 1000.0
            )
        )
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    for stat in [CombatStats.STATS.Evasion, CombatStats.STATS.LuckyEvasion, CombatStats.STATS.PhysicalResistance]:
        foe.get_stat(stat).add_modifier(
            UnitStatModifier.create(
                StringName("retry_win:%s" % stat), &"test:retry_win", stat, UnitStatModifier.OPERATION.OVERRIDE, 0.0
            )
        )
    var deadline := Time.get_ticks_msec() + 5000
    while scene.flow.state != BattleEncounterFlow.STATE.ACTION and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(scene.flow.active_unit == _ally)
    assert(owned_inventory.use_item(1, 1))
    assert(scene.flow.choose_action(scene.flow.turn_id, _ally.get_basic_action()))
    scene.stage.get_unit_display(foe).targeting_controller.add_unit(foe)
    await _wait_continue(scene)
    assert(event.finishing_actions[0].executions == 0, "Even a required victory waits for Continue.")
    scene.result_summary.continue_button.pressed.emit()
    await session.tree_exited
    assert(event.last_battle_result.is_victory())
    assert(event.finishing_actions[0].executions == 1 and event.finished_event.starts == 1)
    assert(event.defeated_event.starts == 0)
    assert(owned_inventory.slots[1].count == 2, "Accepted victory retains actual supply consumption.")
    owned_inventory.clear_items()
    await free_node(scene)
    for stat in [CombatStats.STATS.Swiftness, CombatStats.STATS.Accuracy, CombatStats.STATS.PhysicalDamage]:
        _ally.get_stat(stat).remove_modifiers_from_source(&"test:retry_win")
    _ally._action_cooldowns.clear()
    health.increase_current_flat(health.Max)


## Waits for the settled result UI without advancing the story automatically.
func _wait_continue(scene: BattleEncounterScene) -> void:
    var deadline := Time.get_ticks_msec() + 5000
    while not scene.awaiting_continue and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(scene.awaiting_continue and scene.result_summary.visible)


## Checks cancel pending timeline using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_cancel_pending_timeline() -> void:
    var caller := _caller()
    var event := _event()
    Dialogic.current_timeline = DialogicTimeline.new()
    event.start()
    assert(event._waiting_for_timeline)
    event._cancel_pending_start()
    Dialogic.current_timeline = null
    Dialogic.timeline_ended.emit()
    await get_tree().process_frame
    assert(event._session == null and get_tree().current_scene == caller)
    await free_node(caller)


## Checks timeline reaction using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_timeline_reaction() -> void:
    _caller()
    var event := _event()
    var ending_event := EndingEvent.new()
    ending_event.id = &"timeline_before_battle"
    ending_event.next = event
    var timeline := DialogicTimeline.new()
    ending_event.finishing_timeline = timeline
    GameManager.current_event = ending_event
    Dialogic.current_timeline = timeline
    GameManager.on_timeline_ending(timeline)
    assert(event._session == null and ending_event.finishes == 0)
    Dialogic.current_timeline = null
    Dialogic.timeline_ended.emit()
    await _wait_started(event)
    assert(ending_event.finishes == 1 and GameManager.current_event == event)
    var scene := event._session.encounter
    await SaveAndLoadSystemManager.cancel_story_battles()
    assert(event.last_battle_result == null and event.finishing_actions[0].executions == 0)
    await free_node(scene)


## Checks non story session using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_non_story_session() -> void:
    var scene: BattleEncounterScene = ( # lint:ignore load-in-var -- Load fixtures during test execution.
        load("res://GrimDaysBattle/scenes/battle/production_encounter.tscn").instantiate()
    )
    add_child(scene)
    var results: Array[BattleResult] = []
    scene.encounter_completed.connect(func(result: BattleResult): results.append(result))
    assert(scene.begin_session(_party, [HARLOK], &"future_non_story", 100, {"caller": "other_system"}, {}, true))
    scene.coordinator.finish(scene.coordinator.session_id, BattleResult.OUTCOME.DEFEAT)
    await _wait_retry(scene)
    assert(results.is_empty())
    scene.cancel_session()
    assert(not scene.retry_encounter(scene.coordinator.session_id))
    assert(SaveAndLoadSystemManager.can_save_game())
    await free_node(scene)
