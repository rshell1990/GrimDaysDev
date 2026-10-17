extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Resource loaded for encounter; reused instead of looking up the file on each call.
const ENCOUNTER := preload("res://GrimDaysBattle/scenes/battle/production_encounter.tscn")
## Resource loaded for resource effect; reused instead of looking up the file on each call.
const RESOURCE_EFFECT := preload("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


## Runs the action trigger routing smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    await _test_spine_resolution_timing()
    await _test_action_animation_tail()
    await _test_particle_target_policies()
    await _test_routing_and_round_grants()
    await _test_miss_and_equip_rejection()
    await _test_visual_kill_and_defeat()
    await _test_cancellation_between_operations()
    await _test_rank_and_random_recipient()
    await _test_defeat_revival()
    await _test_operation_events()
    await _test_round_event_attribution()


## Adds [code]party[/code] as a child node; adds [code]actor[/code] as a child of
## [code]party[/code]; adds [code]CELINE_TEMPLATE[/code] to [code]templates[/code]. It also sets
## [code]party.active_party_ids[/code] to [code][CELINE_TEMPLATE.id][/code].
func _fixture(count: int = 2) -> Dictionary:
    var party := IsolatedParty.new()
    add_child(party)
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(actor)
    party.runtime_units[CELINE_TEMPLATE.id] = actor
    party.active_party_ids = [CELINE_TEMPLATE.id]
    var templates: Array[BattleUnitTemplate] = []
    for _index in count:
        templates.append(CELINE_TEMPLATE)
    var scene: BattleEncounterScene = ENCOUNTER.instantiate()
    add_child(scene)
    assert(scene.begin_encounter(party, templates, &"routing", 515))
    scene.flow.stop()
    for unit in scene.coordinator.roster.get_participants():
        for stat in [CombatStats.STATS.Health, CombatStats.STATS.Mana, CombatStats.STATS.Energy]:
            unit.get_stat(stat).add_modifier(
                UnitStatModifier.create(
                    StringName("routing:%s" % stat), &"test:routing", stat, UnitStatModifier.OPERATION.OVERRIDE, 100
                )
            )
            unit.get_stat(stat).increase_current_flat(100)
    actor.get_stat(CombatStats.STATS.Health).decrease_current_flat(50)
    actor.get_stat(CombatStats.STATS.Mana).decrease_current_flat(50)
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    return {
        "scene": scene,
        "actor": actor,
        "foes": scene.coordinator.roster.get_foes(),
        "party": party,
        "resolver": resolver
    }


## Sets [code]effect.id[/code] to [code]id[/code]; sets [code]effect.template_scene[/code] to
## [code]RESOURCE_EFFECT[/code]; sets [code]effect.trigger[/code] to [code]trigger[/code]. Returns
## [code]effect[/code].
func _resource(
    id: StringName,
    trigger: CombatEffects.TRIGGER,
    target: CombatActions.TARGET,
    amount: float,
    stat: CombatStats.STATS = CombatStats.STATS.Health
) -> EffectResourceChangeTemplate:
    var effect := EffectResourceChangeTemplate.new()
    effect.id = id
    effect.template_scene = RESOURCE_EFFECT
    effect.trigger = trigger
    effect.target = target
    effect.kind = CombatEffects.KIND.ONCE
    effect.lifetime = EffectTemplate.LIFETIME.INSTANT
    effect.stat = stat
    effect.amount = amount
    effect.damage_type = CombatDamage.TYPE.True
    return effect


## Sets [code]action.id[/code] to [code]&"routing_action"[/code]; sets [code]action.target[/code] to
## [code]CombatActions.TARGET.FOE[/code]; sets [code]action.target_amount[/code] to [code]2[/code].
## Returns [code]action[/code].
func _action(actor: BattleUnit, effects: Array[EffectTemplate]) -> ActionTemplate:
    var action := ActionTemplate.new()
    action.id = &"routing_action"
    action.target = CombatActions.TARGET.FOE
    action.target_amount = 2
    action.always_hits = true
    var rank := RankTemplate.new()
    rank.effects = EffectTemplates.new()
    rank.effects.all.assign(effects)
    rank.cost = {CombatStats.STATS.Energy: 3}
    action.ranks = RanksTemplate.new()
    action.ranks.all = [rank]
    assert(actor.learn_action(action))
    return action


## Checks routing and round grants using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_routing_and_round_grants() -> void:
    var f := _fixture()
    var poison := _resource(&"round", CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.FOE, -1)
    poison.always_hits = true
    poison.kind = CombatEffects.KIND.REPEAT
    poison.lifetime = EffectTemplate.LIFETIME.ROUNDS
    poison.duration = 2
    var action := _action(
        f.actor,
        [
            _resource(
                &"attacking", CombatEffects.TRIGGER.ATTACKING, CombatActions.TARGET.SELF, 2, CombatStats.STATS.Mana
            ),
            _resource(
                &"targeted", CombatEffects.TRIGGER.TARGETED, CombatActions.TARGET.SELF, 3, CombatStats.STATS.Mana
            ),
            _resource(&"area_damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -10),
            _resource(&"after_hit", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.SELF, 4),
            _resource(&"finish_self", CombatEffects.TRIGGER.PROCESS_OVER, CombatActions.TARGET.SELF, 5),
            _resource(&"finish_targets", CombatEffects.TRIGGER.PROCESS_OVER, CombatActions.TARGET.FOE, -2),
            poison,
        ]
    )
    var unrelated := _resource(&"unrelated_passive", CombatEffects.TRIGGER.TARGETED, CombatActions.TARGET.SELF, -40)
    f.actor.add_effect(f.actor, f.actor, unrelated, {"defer_application": true})
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"routing_area", f.actor, action, f.foes)
    )
    assert(result.success)
    assert(f.actor.get_stat(CombatStats.STATS.Health).Current == 71)
    assert(f.actor.get_stat(CombatStats.STATS.Mana).Current == 55)
    assert(f.actor.get_stat(CombatStats.STATS.Energy).Current == 97)
    assert(result.get_events(BattleCombatEvent.TYPE.COST_PAID).size() == 1)
    for foe in f.foes:
        assert(
            foe.get_stat(CombatStats.STATS.Health).Current == 88,
            "Area effects must not multiply with selected targets."
        )
    var damage_events := result.get_events(BattleCombatEvent.TYPE.DAMAGE)
    var healing_events := result.get_events(BattleCombatEvent.TYPE.HEALING)
    assert(damage_events.size() == 4 and healing_events.size() == 5)
    assert(result.events.find(healing_events[0]) < result.events.find(damage_events[0]))
    assert(
        healing_events[0].target == f.actor and healing_events[0].data.trigger == CombatEffects.TRIGGER.AFTER_HITTING
    )
    var effects := BattleEncounterEffects.new()
    var round_events := await effects.end_round(f.scene.coordinator.roster, func(): return true, &"routing_round")
    assert(round_events.size() == 4)
    for event in round_events:
        assert(event.type in [BattleCombatEvent.TYPE.HIT, BattleCombatEvent.TYPE.DAMAGE] and event.actor == f.actor)
        assert(event.request_id == &"routing_round" and event.data.trigger == CombatEffects.TRIGGER.ROUND_OVER)
    for foe in f.foes:
        assert(
            foe.get_stat(CombatStats.STATS.Health).Current == 87,
            "Round grants must wait for the actual round boundary."
        )
    await _free_fixture(f)


## Checks miss and equip rejection using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_miss_and_equip_rejection() -> void:
    var f := _fixture(1)
    var action := _action(
        f.actor,
        [
            _resource(&"damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
            _resource(&"after_hit", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.SELF, 4),
            _resource(&"round", CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.FOE, -5),
            _resource(&"finish", CombatEffects.TRIGGER.PROCESS_OVER, CombatActions.TARGET.SELF, 5),
        ]
    )
    action.always_hits = false
    f.actor.get_stat(CombatStats.STATS.Accuracy).add_modifier(
        UnitStatModifier.create(
            &"miss", &"test:routing", CombatStats.STATS.Accuracy, UnitStatModifier.OPERATION.OVERRIDE, 0
        )
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"routing_miss", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(f.actor.get_stat(CombatStats.STATS.Health).Current == 55)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 100)
    assert(f.foes[0].effect_manager.on_round_over_holder.get_child_count() == 0)
    action.ranks.all[0].effects.all.append(
        _resource(&"equip_invalid", CombatEffects.TRIGGER.EQUIP, CombatActions.TARGET.SELF, 99)
    )
    var energy: float = f.actor.get_stat(CombatStats.STATS.Energy).Current
    result = await f.resolver.resolve(BattleActionRequest.new(&"invalid_equip", f.actor, action, f.foes))
    assert(not result.success and "EQUIP" in result.error)
    assert(f.actor.get_stat(CombatStats.STATS.Energy).Current == energy)
    await _free_fixture(f)


## Checks visual kill and defeat using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_visual_kill_and_defeat() -> void:
    var f := _fixture(1)
    var action := _action(
        f.actor,
        [
            _resource(&"lethal", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -100),
            _resource(&"defeat", CombatEffects.TRIGGER.DEFEAT, CombatActions.TARGET.FOE, -2, CombatStats.STATS.Mana),
            _resource(&"kill", CombatEffects.TRIGGER.KILL, CombatActions.TARGET.SELF, 7, CombatStats.STATS.Mana),
        ]
    )
    f.actor.get_stat(CombatStats.STATS.Swiftness).add_modifier(
        UnitStatModifier.create(
            &"first", &"test:routing", CombatStats.STATS.Swiftness, UnitStatModifier.OPERATION.OVERRIDE, 1000
        )
    )
    assert(f.scene.flow.start(f.scene.coordinator, f.scene.stage))
    var deadline := Time.get_ticks_msec() + 5000
    while f.scene.flow.state != BattleEncounterFlow.STATE.ACTION and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(f.scene.flow.active_unit == f.actor)
    assert(f.scene.flow.choose_action(f.scene.flow.turn_id, action))
    f.scene.stage.get_unit_display(f.foes[0]).targeting_controller.add_unit(f.foes[0])
    while f.scene.coordinator.state != BattleCoordinator.STATE.FINISHED and Time.get_ticks_msec() < deadline:
        await get_tree().process_frame
    assert(f.scene.coordinator.current_result.is_victory())
    assert(f.actor.get_stat(CombatStats.STATS.Mana).Current == 57)
    assert(f.foes[0].get_stat(CombatStats.STATS.Mana).Current == 98)
    var hook_events: Array = f.scene.coordinator.current_result.combat_events.filter(
        func(event): return event.data.get("lifecycle", false)
    )
    assert(hook_events.size() == 2, "Production results must include both defeat and kill resource operations.")
    assert(hook_events[0].data.trigger == CombatEffects.TRIGGER.DEFEAT)
    assert(hook_events[1].data.trigger == CombatEffects.TRIGGER.KILL)
    await _free_fixture(f)


## Checks cancellation between operations using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_cancellation_between_operations() -> void:
    var f := _fixture(1)
    var action := _action(
        f.actor,
        [
            _resource(&"first", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1),
            _resource(&"second", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -50),
        ]
    )
    var running := {"active": true}
    var health: UnitGenericStat = f.foes[0].get_stat(CombatStats.STATS.Health)
    var cancel := func(_stat, _old, _new): running.active = false
    health.value_changed.connect(cancel, CONNECT_ONE_SHOT)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"routing_cancel", f.actor, action, f.foes), func(): return running.active
    )
    assert(not result.success and health.Current == 99, "Cancellation must stop the next operation in the same bucket.")
    assert(f.foes[0].resource_operation_resolved.get_connections().is_empty(), "Cancelled capture must disconnect.")
    await _free_fixture(f)


## Cleans up the test encounter and waits for the resolver, scene and party nodes to be released.
func _free_fixture(f: Dictionary) -> void:
    f.scene.coordinator.cleanup(f.scene.coordinator.session_id)
    await free_node(f.resolver)
    await free_node(f.scene)
    await free_node(f.party)


## Checks rank and random recipient using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_rank_and_random_recipient() -> void:
    var f := _fixture()
    var action := _action(f.actor, [_resource(&"ranked", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1)])
    var rank_two := RankTemplate.new()
    rank_two.effects = EffectTemplates.new()
    rank_two.effects.all = [
        _resource(&"ranked", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -4),
        _resource(
            &"random", CombatEffects.TRIGGER.AFTER_HITTING, CombatActions.TARGET.RANDOM_FOE, -5, CombatStats.STATS.Mana
        ),
    ]
    action.ranks.all.append(rank_two)
    assert(f.actor.learn_action(action, 2))
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"routing_rank", f.actor, action, f.foes)
    )
    assert(result.success)
    for foe in f.foes:
        assert(foe.get_stat(CombatStats.STATS.Health).Current == 96)
    assert(
        f.foes[0].get_stat(CombatStats.STATS.Mana).Current + f.foes[1].get_stat(CombatStats.STATS.Mana).Current == 190,
        "An after-hit random proc selects once per successful damage operation."
    )
    await _free_fixture(f)


## Checks defeat revival using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_defeat_revival() -> void:
    var f := _fixture(1)
    var action := _action(
        f.actor,
        [
            _resource(&"lethal", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -100),
            _resource(&"revive", CombatEffects.TRIGGER.DEFEAT, CombatActions.TARGET.FOE, 1),
            _resource(&"kill", CombatEffects.TRIGGER.KILL, CombatActions.TARGET.SELF, 7, CombatStats.STATS.Mana),
        ]
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"routing_revival", f.actor, action, f.foes)
    )
    assert(result.success and f.foes[0].is_active)
    var lifecycle := BattleEncounterEffects.new()
    var events := await lifecycle.process_defeats(f.scene.coordinator.roster, func(): return true, &"revival_hooks")
    assert(events.is_empty(), "Revival already resolved within the lethal operation.")
    assert(result.get_events(BattleCombatEvent.TYPE.REVIVED).size() == 1)
    assert(f.foes[0].is_active and f.foes[0].get_stat(CombatStats.STATS.Health).Current == 1)
    assert(
        f.actor.get_stat(CombatStats.STATS.Mana).Current == 50,
        "A defeat hook that revives its owner must not award a kill."
    )
    await _free_fixture(f)


## Same-stage damage and healing remain separate, even inside a chain. Reactive
## damage belongs to its actual sender, not whichever unit initiated the action.
func _test_operation_events() -> void:
    var f := _fixture(1)
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"event_chain"
    chain.template_scene = load("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.target = CombatActions.TARGET.FOE
    chain.kind = CombatEffects.KIND.ONCE
    chain.lifetime = EffectTemplate.LIFETIME.INSTANT
    chain.triggers = [
        _resource(&"chain_damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
        _resource(&"chain_heal", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, 10),
    ]
    var action := _action(f.actor, [chain])
    var reactive := _resource(&"reactive", CombatEffects.TRIGGER.ATTACKING, CombatActions.TARGET.FOE, -3)
    assert(f.actor.add_effect(f.foes[0], f.actor, reactive, {"defer_application": true}) != null)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"operation_events", f.actor, action, f.foes)
    )
    assert(result.success)
    var damage := result.get_events(BattleCombatEvent.TYPE.DAMAGE)
    var healing := result.get_events(BattleCombatEvent.TYPE.HEALING)
    assert(damage.size() == 2 and healing.size() == 1, "Zero-net chain still contains damage and healing.")
    assert(damage[0].actor == f.foes[0] and damage[0].target == f.actor)
    assert(damage[0].data.action_actor == f.actor and damage[0].amount == 3)
    assert(damage[1].amount == 10 and healing[0].amount == 10)
    assert(damage[1].data.before == 100 and damage[1].data.after == 90)
    assert(healing[0].data.before == 90 and healing[0].data.after == 100)
    assert(damage[1].data.instance_id != healing[0].data.instance_id)
    assert(result.events.find(damage[1]) < result.events.find(healing[0]))
    for unit in f.scene.coordinator.roster.get_participants():
        assert(unit.resource_operation_resolved.get_connections().is_empty())
    await _free_fixture(f)


## DOT retains a defeated original attacker. Clamped damage reports actual Health
## lost, followed by defeat, and repeated lifecycle checks must not duplicate it.
func _test_round_event_attribution() -> void:
    var f := _fixture(1)
    var dot := _resource(&"lethal_dot", CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.FOE, -150)
    dot.always_hits = true
    dot.kind = CombatEffects.KIND.REPEAT
    dot.lifetime = EffectTemplate.LIFETIME.ROUNDS
    dot.duration = 2
    f.foes[0].add_effect(f.actor, f.foes[0], dot, {"defer_application": true, "source_id": &"test:dot"})
    f.actor.get_stat(CombatStats.STATS.Health).decrease_current_flat(100)
    var effects := BattleEncounterEffects.new()
    var live_events: Array[BattleCombatEvent] = []
    var events := await effects.end_round(
        f.scene.coordinator.roster,
        func(): return true,
        &"round:1",
        func(event: BattleCombatEvent): live_events.append(event)
    )
    assert(live_events == events, "Lifecycle feedback must receive the same event objects before batch playback.")
    assert(events.size() == 3 and events[0].type == BattleCombatEvent.TYPE.HIT)
    assert(events[1].type == BattleCombatEvent.TYPE.DAMAGE)
    assert(events[1].actor == f.actor and events[1].amount == 100 and events[1].data.raw_change == -150)
    assert(events[1].action == null and events[1].request_id == &"round:1")
    assert(events[2].type == BattleCombatEvent.TYPE.DEFEAT and f.foes[0].last_hit_by == f.actor)
    assert((await effects.process_defeats(f.scene.coordinator.roster, func(): return true)).is_empty())
    for unit in f.scene.coordinator.roster.get_participants():
        assert(unit.resource_operation_resolved.get_connections().is_empty())
    await _free_fixture(f)


## Particle policies expand once per actor-relative group and Default follows each selected target.
func _test_particle_target_policies() -> void:
    var f := _fixture(3)
    var actor: BattleUnit = f.actor
    var ally: BattleUnit = f.foes[0]
    var foe: BattleUnit = f.foes[1]
    var inactive: BattleUnit = f.foes[2]
    ally.add_team_override(self, actor.team_id)
    inactive.get_stat(CombatStats.STATS.Health).decrease_current_flat(10000)
    var expected := {
        CombatActions.TARGET.SELF: [actor],
        CombatActions.TARGET.ALLIES: [ally],
        CombatActions.TARGET.FOES: [foe],
        CombatActions.TARGET.OTHERS: [ally, foe],
        CombatActions.TARGET.ALL: [actor, ally, foe],
        CombatActions.TARGET.DEFAULT: [foe],
    }
    for mode in expected:
        var template := EffectSpawnParticlesTemplate.new()
        template.id = StringName("particle_targets_%s" % mode)
        template.template_scene = preload(
            "res://GrimDaysBattle/scenes/battle/effects/effect_spawn_particles.tscn"
        )
        template.trigger = CombatEffects.TRIGGER.ATTACKING
        template.target = mode
        var action := _action(actor, [template])
        var routing := BattleActionEffects.new(BattleActionRequest.new(&"particle_targets", actor, action, [foe]))
        routing.execution.select(foe)
        var grants := await routing.grant(CombatEffects.TRIGGER.ATTACKING, [foe])
        assert(grants.keys() == expected[mode], "Particle target policy must select the expected active units.")
        for recipient in grants:
            assert(grants[recipient].size() == 1)
            assert(grants[recipient][0].targeting == recipient)
        assert((await routing.grant(CombatEffects.TRIGGER.ATTACKING, [foe])).is_empty())
        if mode == CombatActions.TARGET.DEFAULT:
            routing.execution.select(ally)
            var next := await routing.grant(CombatEffects.TRIGGER.ATTACKING, [ally])
            assert(next.keys() == [ally], "Default must not cache the first selected target.")
    await free_node(f.resolver)
    await free_node(f.scene)
    await free_node(f.party)


## Exercise the real resolver/directors with nested animation, damage and terminal animation.
func _test_spine_resolution_timing() -> void:
    for miss in [false, true]:
        var f := _fixture(1)
        var animation := EffectTemplateTriggerAnimation.new()
        animation.id = &"timing_animation"
        animation.template_scene = preload(
            "res://GrimDaysBattle/scenes/battle/effects/effect_trigger_animation.tscn"
        )
        animation.trigger = CombatEffects.TRIGGER.DAMAGED
        animation.target = CombatActions.TARGET.SELF
        animation.lifetime = EffectTemplate.LIFETIME.INSTANT
        animation.use_spine = true
        animation.animation_id = &"timing_probe"
        var damage := _resource(&"timing_damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1)
        var chain := EffectTriggerAnotherEffect.new()
        chain.id = &"timing_chain"
        chain.template_scene = preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")
        chain.trigger = CombatEffects.TRIGGER.DAMAGED
        chain.target = CombatActions.TARGET.FOE
        chain.lifetime = EffectTemplate.LIFETIME.INSTANT
        chain.triggers.assign([animation, damage, animation, animation])
        var action := _action(f.actor, [chain])
        if miss:
            action.always_hits = false
            f.actor.get_stat(CombatStats.STATS.Accuracy).add_modifier(
                UnitStatModifier.create(
                    &"timing_miss", &"test:timing", CombatStats.STATS.Accuracy, UnitStatModifier.OPERATION.OVERRIDE, 0
                )
            )
        var starts: Array[int] = []
        var outcomes: Array[int] = []
        f.actor.presentation_request = func(_kind: StringName, payload: Dictionary):
            starts.append(Time.get_ticks_msec())
            payload["duration_seconds"] = 1.0
            return true
        f.resolver.operation_resolved.connect(
            func(event: BattleCombatEvent):
                if event.type == (BattleCombatEvent.TYPE.MISS if miss else BattleCombatEvent.TYPE.DAMAGE):
                    outcomes.append(Time.get_ticks_msec())
        )
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"timing", f.actor, action, f.foes)
        )
        assert(result.success and starts.size() == 3 and outcomes.size() == 1)
        var impact := outcomes[0] - starts[0]
        assert(impact >= 680 and impact < 950, "Hit/miss must resolve near 70 percent: %s" % impact)
        assert(starts[1] - starts[0] >= 990, "Next animation must preserve the first clip's tail.")
        assert(starts[2] - starts[1] >= 990, "Consecutive animations cannot overwrite unfinished clips.")
        assert(Time.get_ticks_msec() - starts[2] >= 990, "A final animation must drain its tail.")
        await _free_fixture(f)


## A carried action-animation tail is consumed after the first damage response.
func _test_action_animation_tail() -> void:
    var f := _fixture(1)
    var action := _action(
        f.actor,
        [
            _resource(&"first", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1),
            _resource(&"second", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1)
        ]
    )
    var timing := BattleActionContext.new()
    timing.split_animation(1.0)
    var started := Time.get_ticks_msec()
    await timing.wait_until(self, started + 700)
    var impacts: Array[int] = []
    f.resolver.operation_resolved.connect(
        func(event: BattleCombatEvent):
            if event.type == BattleCombatEvent.TYPE.DAMAGE:
                impacts.append(Time.get_ticks_msec())
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"action_tail", f.actor, action, f.foes), Callable(), timing
    )
    assert(result.success and impacts.size() == 2)
    assert(impacts[0] - started < 950 and impacts[1] - started >= 990)
    # Cancellation must abandon an outstanding tail rather than block a replaced encounter.
    var cancelled := [false]
    var completed: Array[bool] = []
    timing.split_animation(30.0)
    var resolve_cancelled := func():
        var cancelled_result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"cancel_tail", f.actor, action, f.foes), func(): return not cancelled[0], timing
        )
        completed.append(not cancelled_result.success)
    resolve_cancelled.call()
    cancelled[0] = true
    for frame in 3:
        await get_tree().process_frame
    assert(completed == [true])
    await _free_fixture(f)
