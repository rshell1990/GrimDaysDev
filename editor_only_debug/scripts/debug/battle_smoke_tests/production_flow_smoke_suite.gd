extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Resource loaded for encounter; reused instead of looking up the file on each call.
const ENCOUNTER := preload("res://GrimDaysBattle/scenes/battle/production_encounter.tscn")
## Resource loaded for harlok; reused instead of looking up the file on each call.
const HARLOK := preload("res://GrimDaysBattle/resources/units/harlok/harlok_battle_unit_template.tres")


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


## Runs the production flow smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    assert(HARLOK.basic_action_template == BASIC_ATTACK)
    await _test_player_multi_target_victory()
    await _test_ai_multi_round_defeat()
    await _test_cancel_during_approach()
    await _test_round_effect_defeat()
    await _test_no_action_turns_yield()


## Adds [code]party[/code] as a child node; adds [code]ally[/code] as a child of [code]party[/code];
## adds [code]scene[/code] as a child node. It also sets [code]party.active_party_ids[/code] to
## [code][ally_template.id][/code], defaulting to Celine. Returns [code]{"scene": scene, "party": party, "ally":
## ally}[/code].
func _fixture(
    foes: Array[BattleUnitTemplate],
    ally_template: BattleUnitTemplate = CELINE_TEMPLATE,
    with_round_display: bool = true
) -> Dictionary:
    var party := IsolatedParty.new()
    add_child(party)
    var ally := BattleUnit.create(ally_template)
    party.add_child(ally)
    party.runtime_units[ally_template.id] = ally
    party.active_party_ids = [ally_template.id]
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    if not with_round_display:
        scene.get_node("Interface/BattleHUD/RoundStart").free()
    add_child(scene)
    assert(scene.begin_encounter(party, foes, &"production_flow", 713), scene.last_error)
    _override(ally, CombatStats.STATS.Swiftness, 100.0)
    _override(ally, CombatStats.STATS.CriticalStrike, 0.0)
    _override(ally, CombatStats.STATS.PhysicalResistance, 0.0)
    _override(ally, CombatStats.STATS.Evasion, 0.0)
    _override(ally, CombatStats.STATS.LuckyEvasion, 0.0)
    for foe in scene.coordinator.roster.get_foes():
        # This fixture verifies one-hit flow, not authored encounter balance.
        _override(foe, CombatStats.STATS.Health, 50.0)
        _override(foe, CombatStats.STATS.Swiftness, 1.0)
        _override(foe, CombatStats.STATS.CriticalStrike, 0.0)
        _override(foe, CombatStats.STATS.PhysicalResistance, 0.0)
        _override(foe, CombatStats.STATS.Evasion, 0.0)
        _override(foe, CombatStats.STATS.LuckyEvasion, 0.0)
    return {"scene": scene, "party": party, "ally": ally}


## Checks player multi target victory using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_player_multi_target_victory() -> void:
    var fixture := _fixture([HARLOK, HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var ally: BattleUnit = fixture.ally
    _override(ally, CombatStats.STATS.PhysicalDamage, 100.0)
    _override(ally, CombatStats.STATS.Energy, 10.0)
    var action := BASIC_ATTACK.duplicate(true) as ActionTemplate
    action.id = &"production_multi_attack"
    action.always_hits = true
    action.target_amount = 2
    var rank := RankTemplate.new()
    rank.id = &"production_multi_rank"
    rank.level = 1
    rank.effects = BASIC_ATTACK.get_rank_template(1).effects
    rank.cost = {CombatStats.STATS.Energy: 3}
    rank.cooldown_turns = 1
    action.ranks = RanksTemplate.new()
    action.ranks.all = [rank]
    assert(BASIC_ATTACK.get_rank_template(1).cooldown_turns == 0)
    assert(ally.learn_action(action))
    var emitted: Array[BattleResult] = []
    scene.battle_finished.connect(func(result: BattleResult): emitted.append(result))
    var cues: Array[StringName] = []
    scene.flow._feedback.cue_started.connect(func(kind, _unit, _id): cues.append(kind))
    await _wait_for_action(scene.flow)
    assert(scene.flow.active_unit == ally and ally.player_controlled)
    var menu: BattleActionMenu = scene.get_node("Interface/ActionMenu")
    assert(not menu.actions.visible)
    assert(scene.get_node("Interface/BattleHUD/ActiveAlly").visible)
    var initial_energy := ally.get_stat(CombatStats.STATS.Energy).Current
    assert(scene.flow.choose_action(scene.flow.turn_id, action))
    assert(not scene.flow.choose_action(scene.flow.turn_id, action), "Repeated input cannot commit twice.")
    menu.back.pressed.emit()
    assert(scene.flow.state == BattleEncounterFlow.STATE.ACTION)
    assert(is_equal_approx(ally.get_stat(CombatStats.STATS.Energy).Current, initial_energy))
    assert(scene.flow.choose_action(scene.flow.turn_id, action))
    var foes := scene.coordinator.roster.get_foes()
    var area_action := BASIC_ATTACK.duplicate() as ActionTemplate
    area_action.target = CombatActions.TARGET.FOES
    assert(CombatActions.set_targets(area_action, ally).targets == foes)
    var area_effect := EffectFlatChangeStatTemplate.new()
    area_effect.target = CombatActions.TARGET.ALL
    assert(CombatActions.get_effect_target(ally, foes[0], area_effect) == scene.coordinator.roster.get_participants())
    for foe in foes:
        scene.stage.get_unit_display(foe).targeting_controller.add_unit(foe)
    await _wait_for_result(emitted)
    assert(emitted.size() == 1 and emitted[0].is_victory())
    assert(emitted[0].rounds == 1 and emitted[0].turns == 1)
    assert(is_equal_approx(ally.get_stat(CombatStats.STATS.Energy).Current, initial_energy - 3.0))
    assert(ally.get_action_cooldown(action) == 2)
    var damage_events := emitted[0].combat_events.filter(
        func(event): return event.type == BattleCombatEvent.TYPE.DAMAGE
    )
    assert(damage_events.size() == 2, "Each selected target takes damage exactly once.")
    assert(
        cues == [&"attack", &"damage", &"defeat", &"damage", &"defeat"],
        "Production must present each outcome once, before finalizing victory."
    )
    assert(scene.flow.state == BattleEncounterFlow.STATE.STOPPED)
    assert(not scene.flow.pass_turn(scene.flow.turn_id))
    assert(ally.get_parent() == fixture.party)
    assert(CombatActions.get_participant_source(ally) == scene.coordinator.roster)
    scene.coordinator.cleanup(scene.coordinator.session_id)
    assert(ally.participant_source == null)
    await free_node(scene)
    await free_node(fixture.party)


## Checks ai multi round defeat using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_ai_multi_round_defeat() -> void:
    # This checks two rounds of basic-attack flow, independent of authored enemy skills.
    var basic_foe := HARLOK.duplicate() as BattleUnitTemplate
    basic_foe.skill_collection = null
    var fixture := _fixture([basic_foe])
    var scene: BattleEncounterScene = fixture.scene
    var ally: BattleUnit = fixture.ally
    _override(ally, CombatStats.STATS.Health, 10.0)
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    _override(foe, CombatStats.STATS.Accuracy, 100.0)
    _override(foe, CombatStats.STATS.PhysicalDamage, 9.0)
    var emitted: Array[BattleResult] = []
    scene.battle_finished.connect(func(result: BattleResult): emitted.append(result))
    await _wait_for_action(scene.flow)
    var first_turn := scene.flow.turn_id
    assert(scene.flow.choose_command(first_turn, CombatActions.COMMAND.DEFEND))
    await _wait_for_action(scene.flow)
    assert(scene.coordinator.current_result.rounds == 2)
    assert(ally.get_stat(CombatStats.STATS.Health).Current < 10.0)
    assert(not scene.flow.pass_turn(first_turn), "An old turn's button must not advance the next turn.")
    assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
    await _wait_for_result(emitted)
    assert(emitted[0].is_defeat() and emitted[0].rounds == 2 and emitted[0].turns == 4)
    scene.coordinator.cleanup(scene.coordinator.session_id)
    await free_node(scene)
    await free_node(fixture.party)


## Checks cancel during approach using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_cancel_during_approach() -> void:
    var fixture := _fixture([HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var ally: BattleUnit = fixture.ally
    await _wait_for_action(scene.flow)
    assert(scene.flow.choose_action(scene.flow.turn_id, BASIC_ATTACK))
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    scene.stage.get_unit_display(foe).targeting_controller.add_unit(foe)
    await get_tree().process_frame
    var health_before := ally.get_stat(CombatStats.STATS.Health).Current
    assert(scene.coordinator.cleanup(scene.coordinator.session_id))
    await get_tree().create_timer(0.6).timeout
    assert(scene.flow.state == BattleEncounterFlow.STATE.STOPPED)
    assert(is_equal_approx(ally.get_stat(CombatStats.STATS.Health).Current, health_before))
    assert(ally.get_parent() == fixture.party)
    await free_node(scene)
    await free_node(fixture.party)


## Waits up to five seconds for the battle to request a player action, then asserts that it reached
## that step.
func _wait_for_action(flow: BattleEncounterFlow) -> void:
    var deadline := Time.get_ticks_msec() + 5000
    while flow.state != BattleEncounterFlow.STATE.ACTION and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(flow.state == BattleEncounterFlow.STATE.ACTION, "Production flow must reach player input.")


## Checks round effect defeat using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_round_effect_defeat() -> void:
    var fixture := _fixture([HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    var foe: BattleUnit = scene.coordinator.roster.get_foes()[0]
    _override(foe, CombatStats.STATS.PhysicalDamage, 0.0)
    var poison := EffectResourceChangeTemplate.new()
    poison.id = &"production_attributed_dot"
    poison.stat = CombatStats.STATS.Health
    poison.amount = -999.0
    poison.damage_type = CombatDamage.TYPE.True
    poison.always_hits = true  # This fixture checks round defeat, not avoidance.
    poison.trigger = CombatEffects.TRIGGER.ROUND_OVER
    poison.kind = CombatEffects.KIND.REPEAT
    poison.lifetime = EffectTemplate.LIFETIME.ROUNDS
    poison.duration = 1
    poison.template_scene = load("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")
    foe.add_effect(fixture.ally, foe, poison)
    # An unrelated runtime unit must not have its duration advanced by this battle.
    var outsider := BattleUnit.create(CELINE_TEMPLATE)
    add_child(outsider)
    var outside_poison := poison.duplicate() as EffectResourceChangeTemplate
    outside_poison.duration = 3
    var outside_effect := outsider.add_effect(fixture.ally, outsider, outside_poison)
    var emitted: Array[BattleResult] = []
    scene.battle_finished.connect(func(result: BattleResult): emitted.append(result))
    await _wait_for_action(scene.flow)
    assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
    await _wait_for_result(emitted)
    assert(emitted[0].is_victory() and emitted[0].rounds == 1)
    assert(foe.last_hit_by == fixture.ally, "Round damage retains the combatant who applied it.")
    assert(outside_effect.duration == 3)
    scene.coordinator.cleanup(scene.coordinator.session_id)
    await free_node(outsider)
    await free_node(scene)
    await free_node(fixture.party)


## Checks no action turns yield using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_no_action_turns_yield() -> void:
    var fixture := _fixture([HARLOK])
    var scene: BattleEncounterScene = fixture.scene
    for unit in scene.coordinator.roster.get_participants():
        unit.default_basic_action_template = null
        unit.player_controlled = false
    var deadline := Time.get_ticks_msec() + 5000
    while scene.flow.state != BattleEncounterFlow.STATE.STOPPED and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(scene.coordinator.current_result.outcome == BattleResult.OUTCOME.ERROR)
    assert(scene.flow.state == BattleEncounterFlow.STATE.STOPPED)
    assert(scene.coordinator.cleanup(scene.coordinator.session_id))
    await free_node(scene)
    await free_node(fixture.party)


## Waits up to five seconds for a result to appear in the supplied list, then asserts that the
## battle finished.
func _wait_for_result(results: Array[BattleResult]) -> void:
    var deadline := Time.get_ticks_msec() + 5000
    while results.is_empty() and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(not results.is_empty(), "Production flow must finish without a debug controller.")


## Adds a test-only stat adjustment that replaces the selected stat's value with the supplied
## amount.
func _override(unit: BattleUnit, stat: CombatStats.STATS, value: float) -> void:
    (
        unit
        . get_stat(stat)
        . add_modifier(
            (
                UnitStatModifier
                . create(
                    StringName("flow:%s" % stat),
                    &"test:production_flow",
                    stat,
                    UnitStatModifier.OPERATION.OVERRIDE,
                    value,
                )
            )
        )
    )
