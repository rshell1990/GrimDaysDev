extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/production_flow_smoke_suite.gd"
## Turn-start Lucidity outcomes, round-based madness and source-owned restoration.


func run() -> void:
    await _test_authored_disabled()
    await _test_authored_outcomes()
    await _test_action_outcome()
    await _test_turn_start_defeat()
    await _test_round_expiry_and_overrides()
    await _test_cleanup_and_retry()
    await _test_zero_capacity_and_revive()
    await _test_production_handoff()
    await _test_unrestricted_targeting()
    await _test_madness_action_choices()
    _test_definition_validation()


## Exercise a three-round duration independently of Celine's authored two rounds.
func _madness_fixture() -> Dictionary:
    var template := _madness_template(3)
    return _fixture([HARLOK], template)


## Verifies an explicitly disabled madness fixture preserves player control when Lucidity
## empties.
func _test_authored_disabled() -> void:
    var template := CELINE_TEMPLATE.duplicate() as MainCharacterTemplate
    template.lucidity_break_options = [_effect_option(_authored_madness(), 0.0)]
    var f := _fixture([HARLOK], template)
    f.scene.flow.stop()
    assert(f.ally.template_resource.lucidity_break_options[0].weight == 0.0)
    f.ally.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    assert(_madness(f.ally).is_empty() and f.ally.player_controlled)
    await _dispose(f)


## Returns only effects owned by this unit's automatic Lucidity-break source ID.
func _madness(unit: BattleUnit) -> Array[EffectBase]:
    return unit.effect_manager.get_effects_from_source(StringName("lucidity_break:%s" % unit.get_instance_id()))


## Frees the fixture encounter before its isolated party and waits for both removals.
func _dispose(f: Dictionary) -> void:
    await free_node(f.scene)
    await free_node(f.party)


## Verifies three round boundaries expire fixture madness, restore Lucidity once and preserve
## unrelated control overrides; turns and repeated zero values do not refresh it.
func _test_round_expiry_and_overrides() -> void:
    var f := _madness_fixture()
    f.scene.flow.stop()
    var unit: BattleUnit = f.ally
    var lucidity := unit.get_stat(CombatStats.STATS.Lucidity)
    var other := Node.new()
    add_child(other)
    unit.add_control_override(other, false)
    lucidity.restore_current(0)
    assert(_madness(unit).is_empty())
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    assert(_madness(unit).size() == 1 and not unit.player_controlled)
    var madness := _madness(unit)[0]
    for _turn in 6:
        unit.on_turn_started()
        await f.scene.coordinator._lucidity.process_turn(unit)
    assert(madness.duration == 3, "Individual turns do not shorten madness.")
    var effects := BattleEncounterEffects.new()
    var guard: Callable = f.scene.coordinator.is_current_session.bind(f.scene.coordinator.session_id)
    await effects.end_round(f.scene.coordinator.roster, guard)
    assert(madness.duration == 2)
    lucidity.restore_current(lucidity.Max * 0.5)
    assert(not unit.player_controlled and madness.duration == 2, "Recovery does not end timed madness early.")
    lucidity.restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    lucidity.value_changed.emit(lucidity, 0, 0)
    assert(_madness(unit).size() == 1 and madness.duration == 2, "No duplicate/refresh at zero.")
    await effects.end_round(f.scene.coordinator.roster, guard)
    assert(madness.duration == 1 and lucidity.Current == 0)
    var events := await effects.end_round(f.scene.coordinator.roster, guard)
    assert(_madness(unit).is_empty() and lucidity.Current == lucidity.Max)
    assert(events.size() == 1 and events[0].type == BattleCombatEvent.TYPE.RESOURCE_CHANGED)
    assert(events[0].data.stat == CombatStats.STATS.Lucidity)
    assert(not unit.player_controlled, "Expiry preserves the preceding control override.")
    unit.remove_control_override(other)
    assert(unit.player_controlled)
    await free_node(other)
    await _dispose(f)


## Verifies encounter cleanup does not refill Lucidity, retry restores the checkpoint and a new
## encounter waits until the unit starts a turn.
func _test_cleanup_and_retry() -> void:
    var f := _madness_fixture()
    f.scene.flow.stop()
    var unit: BattleUnit = f.ally
    var lucidity := unit.get_stat(CombatStats.STATS.Lucidity)
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([unit])
    lucidity.restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    assert(_madness(unit).size() == 1)
    assert(f.scene.coordinator.cleanup(f.scene.coordinator.session_id))
    assert(_madness(unit).is_empty() and lucidity.Current == 0, "Cleanup is not natural expiry/recovery.")
    assert(f.scene.coordinator._lucidity._connections.is_empty())
    assert(checkpoint.restore() and lucidity.Current == lucidity.Max)
    lucidity.restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    assert(_madness(unit).is_empty(), "No automatic control effects outside battle.")
    var foes: Array[BattleUnitTemplate] = [HARLOK]
    assert(f.scene.coordinator.begin_encounter(f.party, foes, &"madness_retry", 713))
    assert(_madness(unit).is_empty(), "Entering with empty Lucidity waits for its turn.")
    assert(f.scene.coordinator._lucidity._connections.size() == 1)
    await f.scene.coordinator._lucidity.process_turn(unit)
    assert(_madness(unit).size() == 1)
    assert(f.scene.coordinator.finish(f.scene.coordinator.session_id, BattleResult.OUTCOME.DEFEAT))
    assert(_madness(unit).is_empty() and lucidity.Current == 0)
    assert(f.scene.coordinator._lucidity._connections.is_empty())
    await _dispose(f)


## Verifies zero capacity does not trigger madness, while revival with an empty positive-capacity
## pool does.
func _test_zero_capacity_and_revive() -> void:
    var f := _madness_fixture()
    f.scene.flow.stop()
    var unit: BattleUnit = f.ally
    var lucidity := unit.get_stat(CombatStats.STATS.Lucidity)
    _override(unit, CombatStats.STATS.Lucidity, 0)
    await f.scene.coordinator._lucidity.process_turn(unit)
    assert(lucidity.Current == 0 and _madness(unit).is_empty())
    unit.get_stat(CombatStats.STATS.Health).restore_current(0)
    _override(unit, CombatStats.STATS.Lucidity, 100)
    assert(lucidity.Max == 100 and _madness(unit).is_empty())
    lucidity.restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    unit.get_stat(CombatStats.STATS.Health).restore_current(1)
    assert(_madness(unit).is_empty(), "Revival alone does not trigger a break.")
    await f.scene.coordinator._lucidity.process_turn(unit)
    assert(_madness(unit).size() == 1 and not unit.player_controlled)
    await _dispose(f)


## Mid-turn depletion preserves player targets; madness starts on the next owned turn.
func _test_production_handoff() -> void:
    var f := _madness_fixture()
    var scene: BattleEncounterScene = f.scene
    var unit: BattleUnit = f.ally
    var foe := scene.coordinator.roster.get_foes()[0]
    foe.player_controlled = true
    _override(unit, CombatStats.STATS.PhysicalDamage, 1)
    _override(foe, CombatStats.STATS.Health, 5000)
    var completed: Array[BattleActionResolution] = []
    scene.flow.action_completed.connect(func(result): completed.append(result))
    await _wait_for_action(scene.flow)
    var input_turn := scene.flow.turn_id
    assert(scene.flow.choose_action(input_turn, unit.get_basic_action()))
    assert(scene.flow.state == BattleEncounterFlow.STATE.TARGETS)
    unit.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    assert(scene.flow.state == BattleEncounterFlow.STATE.TARGETS and unit.player_controlled)
    assert(_madness(unit).is_empty(), "Stat changes cannot interrupt the current turn.")
    scene.stage.target_added.emit(scene.coordinator.session_id, foe)
    await _wait_for_action(scene.flow)
    assert(scene.flow.active_unit == foe and completed.size() == 1)
    assert(_madness(unit).is_empty(), "Another unit's turn cannot process this character.")
    await scene.coordinator.process_lucidity_turn(unit, scene.coordinator.session_id)
    assert(_madness(unit).is_empty(), "Coordinator rejects processing a non-active unit.")
    assert(foe.get_stat(CombatStats.STATS.Lucidity) == null)
    await scene.coordinator.process_lucidity_turn(foe, scene.coordinator.session_id)
    assert(_madness(foe).is_empty(), "Units without Lucidity are skipped.")
    for remaining in [3, 2, 1]:
        assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
        await _wait_for_action(scene.flow)
        assert(scene.flow.active_unit == foe and _madness(unit)[0].duration == remaining)
    assert(completed.size() == 4, "One player action, then one AI action per madness round.")
    assert(scene.flow.choose_command(scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
    await _wait_for_action(scene.flow)
    assert(scene.flow.active_unit == unit and unit.player_controlled)
    assert(_madness(unit).is_empty())
    assert(unit.get_stat(CombatStats.STATS.Lucidity).Current == unit.get_stat(CombatStats.STATS.Lucidity).Max)
    assert(scene.coordinator.current_result.turns == 9 and scene.coordinator.current_result.rounds == 5)
    await _dispose(f)


## Checks enabled madness requires Lucidity, negative durations are rejected and the authored
## Celine definition remains valid.
func _test_definition_validation() -> void:
    var template := CELINE_TEMPLATE.duplicate() as MainCharacterTemplate
    template.stats = HARLOK.stats
    assert(not BattleUnitTemplateValidator.validate(template).is_empty(), "Enabled madness needs Lucidity.")
    for duration in [-1, 0]:
        template = _madness_template(duration)
        assert(not BattleUnitTemplateValidator.validate(template).is_empty())
    assert(_authored_madness().duration == 2, "Fixtures preserve Celine's authored Madness duration.")
    assert(BattleUnitTemplateValidator.validate(CELINE_TEMPLATE).is_empty())


## Every living participant, including the actor, is reachable; team areas retain cardinality.
func _test_unrestricted_targeting() -> void:
    var template := _madness_template(3)
    var f := _fixture([HARLOK, HARLOK], template)
    f.scene.flow.stop()
    var actor: BattleUnit = f.ally
    var roster: BattleEncounterRoster = f.scene.coordinator.roster
    var participants := roster.get_all_active_units()
    actor.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    assert(actor.has_madness())
    var action := BASIC_ATTACK.duplicate() as ActionTemplate
    for policy in CombatActions.TARGET.values():
        action.target = policy
        action.target_amount = 1
        var seen := {}
        actor.randomizer.set_seed(981)
        for roll in 60:
            var targets := CombatActions.madness_targets(action, actor)
            assert(not targets.is_empty())
            for target in targets:
                assert(CombatActions.valid_target(action, actor, target))
                seen[target] = true
            if policy in [CombatActions.TARGET.ALLIES, CombatActions.TARGET.FOES]:
                assert(targets.size() == roster.get_active_team(targets[0].team_id).size())
                for target in targets:
                    assert(target.team_id == targets[0].team_id)
        assert(seen.size() == participants.size(), "Madness cannot exclude self, allies, or foes.")
    # Action SELF and effect SELF must both permit a different recipient.
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    var foe: BattleUnit = roster.get_foes()[0]
    var sibling: BattleUnit = roster.get_foes()[1]
    var effect := EffectResourceChangeTemplate.new()
    effect.id = &"madness_damage"
    effect.template_scene = preload("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")
    effect.trigger = CombatEffects.TRIGGER.DAMAGED
    effect.target = CombatActions.TARGET.SELF
    effect.stat = CombatStats.STATS.Health
    effect.amount = -1
    effect.damage_type = CombatDamage.TYPE.True
    effect.always_hits = true
    action = ActionTemplate.new()
    action.id = &"madness_test_action"
    action.target = CombatActions.TARGET.SELF
    action.target_amount = 1
    var rank := RankTemplate.new()
    rank.effects = EffectTemplates.new()
    rank.effects.all = [effect]
    action.ranks = RanksTemplate.new()
    action.ranks.all = [rank]
    assert(actor.learn_action(action))
    var before := foe.get_stat(CombatStats.STATS.Health).Current
    var resolution: BattleActionResolution = await resolver.resolve(
        BattleActionRequest.new(&"mad_self", actor, action, [foe])
    )
    assert(resolution.success and foe.get_stat(CombatStats.STATS.Health).Current == before - 1)
    # Area effects follow the rolled team, rather than the actor's authored relationship.
    effect.target = CombatActions.TARGET.ALLIES
    before = sibling.get_stat(CombatStats.STATS.Health).Current
    resolution = await resolver.resolve(BattleActionRequest.new(&"mad_area", actor, action, [foe]))
    assert(resolution.success and sibling.get_stat(CombatStats.STATS.Health).Current == before - 1)
    # Nested SELF operations inherit the cast's targeting override too.
    var nested := effect.duplicate() as EffectResourceChangeTemplate
    nested.id = &"mad_nested"
    nested.target = CombatActions.TARGET.SELF
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"mad_chain"
    chain.template_scene = preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")
    chain.target = CombatActions.TARGET.SELF
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.triggers = [nested]
    rank.effects.all = [chain]
    before = foe.get_stat(CombatStats.STATS.Health).Current
    resolution = await resolver.resolve(BattleActionRequest.new(&"mad_nested", actor, action, [foe]))
    assert(resolution.success and foe.get_stat(CombatStats.STATS.Health).Current == before - 1)
    assert(chain.target == CombatActions.TARGET.SELF and nested.target == CombatActions.TARGET.SELF)
    # Committed casts keep their targeting snapshot when madness is removed.
    var committed := BattleActionRequest.new(&"mad_snapshot", actor, action, [foe])
    actor.effect_manager.remove_effects_from_source(StringName("lucidity_break:%s" % actor.get_instance_id()))
    assert(not actor.has_madness() and not CombatActions.valid_target(action, actor, foe))
    before = foe.get_stat(CombatStats.STATS.Health).Current
    resolution = await resolver.resolve(committed)
    assert(resolution.success and foe.get_stat(CombatStats.STATS.Health).Current == before - 1)
    # Defeated units remain in the encounter but cannot be randomly selected.
    foe.get_stat(CombatStats.STATS.Health).restore_current(0)
    for roll in 20:
        assert(foe not in CombatActions.madness_targets(action, actor))
    await free_node(resolver)
    await _dispose(f)


## Exclusive choices, effect-restricted actions, reversible defenses and cosmetic-only passing.
func _test_madness_action_choices() -> void:
    var f := _madness_fixture()
    f.scene.flow.stop()
    var actor: BattleUnit = f.ally
    assert(BattleMadnessAction.available(actor).is_empty())
    actor.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    var override_source := Node.new()
    add_child(override_source)
    actor.add_control_override(override_source, true)
    assert(not actor.player_controlled, "Generic control grants cannot override madness AI.")
    actor.remove_control_override(override_source)
    await free_node(override_source)
    for command in [CombatActions.COMMAND.FLEE, CombatActions.COMMAND.WAIT]:
        var forbidden := BASIC_ATTACK.duplicate() as ActionTemplate
        forbidden.id = StringName("forbidden_%s" % command)
        forbidden.disabled_by_effects = [&"lucidity_madness"]
        assert(actor.learn_action(forbidden))
        assert(not actor.can_use_action(forbidden) and forbidden not in actor.get_ai_actions())
    var seen := {}
    actor.randomizer.set_seed(812)
    for roll in 100:
        seen[actor.choose_action_for_ai().id] = true
    assert(seen.has(&"madness_cowering") and seen.has(&"madness_catatonic") and seen.has(actor.get_basic_action().id))
    var choices := BattleMadnessAction.available(actor)
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    for stat_id in actor.COWERING_STATS:
        _override(actor, stat_id, 30)
    _override(actor, CombatStats.STATS.LuckyEvasion, 7)
    var resolution: BattleActionResolution = await resolver.resolve(
        BattleActionRequest.new(&"cower", actor, choices[0], [actor])
    )
    assert(resolution.success)
    for stat_id in actor.COWERING_STATS:
        assert(actor.get_stat(stat_id).Current == 0)
    assert(actor.get_stat(CombatStats.STATS.LuckyEvasion).Current == 7)
    actor.on_turn_started()
    for stat_id in actor.COWERING_STATS:
        assert(actor.get_stat(stat_id).Current == 30)
    var hp := actor.get_stat(CombatStats.STATS.Health).Current
    resolution = await resolver.resolve(BattleActionRequest.new(&"catatonic", actor, choices[1], [actor]))
    assert(resolution.success and actor.get_stat(CombatStats.STATS.Health).Current == hp)
    assert(
        not resolution.events.any(
            func(event): return event.type in [BattleCombatEvent.TYPE.BEFORE_ATTACK, BattleCombatEvent.TYPE.DAMAGE]
        )
    )
    var cues: Array[StringName] = []
    f.scene.flow._feedback.cue_started.connect(func(kind, _unit, _id): cues.append(kind))
    await f.scene.flow._feedback.attack(
        f.scene.stage,
        BattleActionRequest.new(&"catatonic_cue", actor, choices[1], [actor]),
        f.scene.coordinator.is_current_session.bind(f.scene.coordinator.session_id)
    )
    assert(cues == [&"catatonic"])
    actor.apply_cowering()
    assert(f.scene.coordinator.cleanup(f.scene.coordinator.session_id))
    for stat_id in actor.COWERING_STATS:
        assert(actor.get_stat(stat_id).Current == 30)
    assert(not actor.can_use_action(choices[0]) and not actor.can_use_action(choices[1]))
    await free_node(resolver)
    await _dispose(f)


## Authored alternatives replace hard-coded madness, with one roll per empty episode.
func _test_authored_outcomes() -> void:
    var template := CELINE_TEMPLATE.duplicate() as MainCharacterTemplate
    template.lucidity_break_options = []
    var f := _fixture([HARLOK], template)
    f.scene.flow.stop()
    f.ally.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    assert(_madness(f.ally).is_empty() and f.ally.player_controlled)
    await _dispose(f)
    var first := EffectResourceChangeTemplate.new()
    first.id = &"break_energy_one"
    first.template_scene = preload("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")
    first.target = CombatActions.TARGET.SELF
    first.stat = CombatStats.STATS.Energy
    first.amount = -1
    first.always_hits = true
    var second := first.duplicate() as EffectResourceChangeTemplate
    second.id = &"break_energy_two"
    second.amount = -2
    template.lucidity_break_options = [_effect_option(first), _effect_option(second, 3.0)]
    f = _fixture([HARLOK], template)
    f.scene.flow.stop()
    var actor: BattleUnit = f.ally
    var lucidity := actor.get_stat(CombatStats.STATS.Lucidity)
    _override(actor, CombatStats.STATS.Energy, 100)
    var energy := actor.get_stat(CombatStats.STATS.Energy)
    actor.randomizer.set_seed(471)
    var expected := RandomNumberGenerator.new()
    expected.seed = 471
    var seen := {}
    for roll in 20:
        lucidity.restore_current(lucidity.Max)
        energy.restore_current(energy.Max)
        var amount := 1 if expected.randf_range(0.0, 4.0) < 1.0 else 2
        seen[amount] = true
        lucidity.restore_current(0)
        await f.scene.coordinator._lucidity.process_turn(f.ally)
        assert(energy.Current == energy.Max - amount)
        assert(not actor.has_madness() and actor.player_controlled)
        lucidity.value_changed.emit(lucidity, 0, 0)
        await f.scene.coordinator._lucidity.process_turn(actor)
        assert(energy.Current == energy.Max - amount, "Instant outcomes cannot repeat at zero.")
        await get_tree().process_frame
        assert(_madness(actor).is_empty(), "Instant outcomes complete their trigger cycle.")
    assert(seen.size() == 2)
    assert(first.duration == 0 and first.lifetime == EffectTemplate.LIFETIME.INSTANT)
    await _dispose(f)
    # A regular round effect uses only its own duration, without changing shared authoring.
    var alternative := _authored_madness().duplicate() as EffectControlOverrideTemplate
    alternative.template_scene = preload(
        "res://GrimDaysBattle/scenes/battle/effects/effect_control_override.tscn"
    )
    alternative.duration = 2
    template.lucidity_break_options = [_effect_option(alternative)]
    f = _fixture([HARLOK], template)
    f.scene.flow.stop()
    actor = f.ally
    lucidity = actor.get_stat(CombatStats.STATS.Lucidity)
    lucidity.restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    assert(not actor.has_madness() and not actor.player_controlled)
    assert(_madness(actor)[0].duration == 2 and alternative.duration == 2)
    var effects := BattleEncounterEffects.new()
    await effects.end_round(
        f.scene.coordinator.roster, f.scene.coordinator.is_current_session.bind(f.scene.coordinator.session_id)
    )
    assert(_madness(actor)[0].duration == 1 and alternative.duration == 2)
    await effects.end_round(
        f.scene.coordinator.roster, f.scene.coordinator.is_current_session.bind(f.scene.coordinator.session_id)
    )
    assert(_madness(actor).is_empty() and actor.player_controlled and lucidity.Current == 0)
    lucidity.value_changed.emit(lucidity, 0, 0)
    assert(_madness(actor).is_empty(), "Expiry alone does not rearm the empty-pool episode.")
    await _dispose(f)


## Build weighted effect entries without mutating the authored production table.
func _effect_option(effect: EffectTemplate, weight: float = 1.0) -> LucidityBreakOption:
    var option := LucidityBreakOption.new()
    option.effect = effect
    option.weight = weight
    return option


## Immediate actions retain authored ranks, bypass costs/cooldowns and leave no learned grant.
func _test_action_outcome() -> void:
    var operation := EffectResourceChangeTemplate.new()
    operation.id = &"break_action_restore"
    operation.template_scene = preload(
        "res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn"
    )
    operation.target = CombatActions.TARGET.SELF
    operation.trigger = CombatEffects.TRIGGER.DAMAGED
    operation.stat = CombatStats.STATS.Energy
    operation.amount = 5
    var rank := RankTemplate.new()
    rank.cost = {CombatStats.STATS.Energy: 2}
    rank.cooldown_turns = 3
    rank.effects = EffectTemplates.new()
    rank.effects.all = [operation]
    var action := ActionTemplate.new()
    action.id = &"lucidity_test_action"
    action.target = CombatActions.TARGET.SELF
    action.target_amount = 1
    action.ranks = RanksTemplate.new()
    action.ranks.all = [rank]
    var option := LucidityBreakOption.new()
    option.action = action
    var disabled := _effect_option(_authored_madness(), 0.0)
    var template := CELINE_TEMPLATE.duplicate() as MainCharacterTemplate
    template.lucidity_break_options = [disabled, option]
    assert(BattleUnitTemplateValidator.validate(template).is_empty())
    var f := _fixture([HARLOK], template)
    f.scene.flow.stop()
    var actor: BattleUnit = f.ally
    _override(actor, CombatStats.STATS.Energy, 100)
    var energy := actor.get_stat(CombatStats.STATS.Energy)
    energy.restore_current(50)
    var results: Array[BattleActionResolution] = []
    f.scene.coordinator._lucidity.action_completed.connect(func(result): results.append(result))
    var turns: int = f.scene.coordinator.current_result.turns
    actor.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    for frame in 60:
        if not results.is_empty():
            break
        await get_tree().process_frame
    assert(results.size() == 1 and results[0].success)
    assert(energy.Current == 55 and not actor.owns_action(action) and not actor.has_madness())
    assert(f.scene.coordinator._lucidity._action_grants.is_empty())
    assert(not actor._action_cooldowns.has(action.id))
    for event: BattleCombatEvent in results[0].events:
        assert(event.type != BattleCombatEvent.TYPE.COST_PAID)
    assert(f.scene.coordinator.current_result.turns == turns)
    assert(not f.scene.coordinator.current_result.combat_events.is_empty())
    actor.get_stat(CombatStats.STATS.Lucidity).value_changed.emit(actor.get_stat(CombatStats.STATS.Lucidity), 0, 0)
    assert(results.size() == 1)
    # Empty resources and an existing cooldown cannot block an automatic outcome.
    actor.get_stat(CombatStats.STATS.Lucidity).restore_current(1)
    energy.restore_current(0)
    assert(actor.grant_action_from_source(&"existing_skill", action, 1))
    actor._action_cooldowns[action.id] = 2
    actor.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    await f.scene.coordinator._lucidity.process_turn(f.ally)
    for frame in 60:
        if results.size() == 2:
            break
        await get_tree().process_frame
    assert(results.size() == 2 and results[1].success)
    assert(energy.Current == 5 and actor.owns_action(action))
    assert(actor._action_cooldowns[action.id] == 2)
    assert(rank.cost == {CombatStats.STATS.Energy: 2} and rank.cooldown_turns == 3)
    assert(not actor.can_use_action(action), "Normal use still respects the existing cooldown.")
    actor._action_cooldowns.clear()
    energy.restore_current(0)
    assert(not actor.can_use_action(action), "Normal use still requires the authored resources.")
    energy.restore_current(50)
    assert(actor.pay_action_cost(action))
    assert(energy.Current == 48 and actor._action_cooldowns[action.id] == 4)
    actor.revoke_action_source(&"existing_skill")
    await _dispose(f)
    # Depleting Lucidity during selection waits until the actor's next turn.
    f = _fixture([HARLOK], template)
    var foe: BattleUnit = f.scene.coordinator.roster.get_foes()[0]
    foe.player_controlled = true
    await _wait_for_action(f.scene.flow)
    actor = f.ally
    _override(actor, CombatStats.STATS.Energy, 100)
    energy = actor.get_stat(CombatStats.STATS.Energy)
    energy.restore_current(50)
    var input_turn: int = f.scene.flow.turn_id
    assert(f.scene.flow.choose_action(input_turn, actor.get_basic_action()))
    assert(f.scene.flow.state == BattleEncounterFlow.STATE.TARGETS)
    actor.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    assert(f.scene.flow.state == BattleEncounterFlow.STATE.TARGETS and energy.Current == 50)
    f.scene.flow.cancel_selection()
    assert(f.scene.flow.choose_command(input_turn, CombatActions.COMMAND.DEFEND))
    await _wait_for_action(f.scene.flow)
    assert(f.scene.flow.active_unit == foe and energy.Current == 50)
    assert(f.scene.flow.choose_command(f.scene.flow.turn_id, CombatActions.COMMAND.DEFEND))
    await _wait_for_action(f.scene.flow)
    assert(f.scene.flow.active_unit == actor and f.scene.flow.turn_id == input_turn + 2)
    assert(energy.Current == 55, "Break action completes before normal action selection.")
    assert(not actor.owns_action(action))
    option.effect = operation
    assert(not option.validate().is_empty(), "Ambiguous payloads are rejected.")
    option.effect = null
    option.weight = -1
    assert(not option.validate().is_empty(), "Negative weights are rejected.")
    await _dispose(f)


## Read the resource at runtime; avoid constant-folding an editor-cached template after reload.
func _authored_madness() -> EffectTemplate:
    var template: MainCharacterTemplate = CELINE_TEMPLATE
    return template.lucidity_break_options[0].effect


## Isolate fixture duration on a duplicated effect, never on the character template.
func _madness_template(duration: int) -> MainCharacterTemplate:
    var template := CELINE_TEMPLATE.duplicate() as MainCharacterTemplate
    var effect := _authored_madness().duplicate() as EffectTemplate
    effect.duration = duration
    template.lucidity_break_options = [_effect_option(effect)]
    return template


## A lethal turn-start outcome finishes defeat handling before normal action selection.
func _test_turn_start_defeat() -> void:
    var effect := EffectResourceChangeTemplate.new()
    effect.id = &"lethal_lucidity_outcome"
    effect.template_scene = preload("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")
    effect.target = CombatActions.TARGET.SELF
    effect.stat = CombatStats.STATS.Health
    effect.amount = -100000
    effect.damage_type = CombatDamage.TYPE.True
    effect.always_hits = true
    var template := CELINE_TEMPLATE.duplicate() as MainCharacterTemplate
    template.lucidity_break_options = [_effect_option(effect)]
    var f := _fixture([HARLOK], template)
    var results: Array[BattleResult] = []
    f.scene.coordinator.battle_finished.connect(func(_token, result): results.append(result))
    var normal_actions: Array[BattleActionResolution] = []
    f.scene.flow.action_completed.connect(func(result): normal_actions.append(result))
    f.ally.get_stat(CombatStats.STATS.Lucidity).restore_current(0)
    assert(f.ally.is_active, "Depletion before the first turn does not apply the outcome.")
    await _wait_for_result(results)
    assert(results[0].outcome == BattleResult.OUTCOME.DEFEAT)
    assert(results[0].turns == 1 and normal_actions.is_empty())
    assert(f.scene.flow.state == BattleEncounterFlow.STATE.STOPPED)
    await _dispose(f)
