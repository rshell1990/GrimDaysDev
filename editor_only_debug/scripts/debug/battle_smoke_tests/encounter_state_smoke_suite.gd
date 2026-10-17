extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/action_trigger_routing_smoke_suite.gd"
## Reuses the isolated production-scene fixture and effect/action builders.

## Resource loaded for chain scene; reused instead of looking up the file on each call.
const CHAIN_SCENE := preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")


class PendingEffect:
    extends EffectBase

    func apply() -> void:
        # Simulates a presentation operation that never sends completion.
        _begin_apply()


## Runs the encounter state smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    await _test_original_membership()
    await _test_dot_attribution()
    await _test_nested_cancellation()
    await _test_cancellation_while_child_waits()


## Checks original membership using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_original_membership() -> void:
    for outcome in [BattleResult.OUTCOME.VICTORY, BattleResult.OUTCOME.DEFEAT, BattleResult.OUTCOME.DRAW]:
        var f := _fixture(1)
        var foe: BattleUnit = f.foes[0]
        # Both sides can have the same effective team without ending combat.
        foe.add_team_override(self, &"allies")
        foe.add_control_override(self, true)
        assert(not f.scene.flow._finish_if_over())
        foe.remove_team_override(self)
        f.actor.add_team_override(self, &"foes")
        f.actor.add_control_override(self, false)
        assert(not f.scene.flow._finish_if_over())
        # Swap allegiance completely: only deployment membership determines loss.
        foe.add_team_override(self, &"allies")
        if outcome != BattleResult.OUTCOME.DEFEAT:
            foe.get_stat(CombatStats.STATS.Health).decrease_current_flat(100)
        if outcome != BattleResult.OUTCOME.VICTORY:
            f.actor.get_stat(CombatStats.STATS.Health).decrease_current_flat(100)
        assert(f.scene.flow._finish_if_over())
        assert(f.scene.coordinator.current_result.outcome == outcome)
        await _free_fixture(f)


## Checks dot attribution using test objects and assertions. A failed assertion identifies behavior
## that no longer meets the test’s expectation.
func _test_dot_attribution() -> void:
    var f := _fixture(2)
    var source: BattleUnit = f.foes[0]
    var other: BattleUnit = f.foes[1]
    var actor: BattleUnit = f.actor
    # A victim-scaled attack still belongs to its sender, not the victim.
    var scaled := make_scaled_template(&"victim_scaled_dot", CombatStats.STATS.Health, -0.1, CombatDamage.TYPE.True)
    scaled.scales_from_sender = false
    scaled.always_hits = true  # Attribution fixture, not an accuracy test.
    scaled.trigger = CombatEffects.TRIGGER.ROUND_OVER
    scaled.lifetime = EffectTemplate.LIFETIME.ROUNDS
    scaled.duration = 3
    scaled.kind = CombatEffects.KIND.REPEAT
    var dot := actor.add_effect(source, actor, scaled, {"source_id": &"test:dot"})
    var lifecycle := BattleEncounterEffects.new()
    await lifecycle.end_round(f.scene.coordinator.roster, func(): return true)
    assert(actor.last_hit_by == source and dot.sender == source)
    # A later direct attack must not steal attribution from the next DOT tick.
    var hit := _resource(&"intervening_attack", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1)
    actor.add_effect(other, actor, hit)
    assert(actor.last_hit_by == other)
    source.get_stat(CombatStats.STATS.Health).decrease_current_flat(100)
    var kill := _resource(
        &"no_posthumous_kill", CombatEffects.TRIGGER.KILL, CombatActions.TARGET.SELF, -7, CombatStats.STATS.Mana
    )
    source.add_effect(source, source, kill, {"defer_application": true})
    # Flat DOT, like scaled DOT, must retain a defeated source through expiry.
    var lethal := _resource(&"flat_dot", CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.FOE, -100)
    lethal.always_hits = true
    lethal.lifetime = EffectTemplate.LIFETIME.ROUNDS
    lethal.duration = 1
    lethal.kind = CombatEffects.KIND.REPEAT
    actor.add_effect(source, actor, lethal, {"source_id": &"test:flat_dot"})
    await lifecycle.end_round(f.scene.coordinator.roster, func(): return true)
    assert(not actor.is_active and actor.last_hit_by == source)
    assert(
        source.get_stat(CombatStats.STATS.Mana).Current == 100,
        "Posthumous attribution must not execute a defeated source's KILL effects."
    )
    assert(f.scene.flow._finish_if_over() and f.scene.coordinator.current_result.is_defeat())
    await _free_fixture(f)


## Checks cancellation while child waits using test objects and assertions. A failed assertion
## identifies behavior that no longer meets the test’s expectation.
func _test_cancellation_while_child_waits() -> void:
    var f := _fixture(1)
    var foe: BattleUnit = f.foes[0]
    var pending_template := EffectTemplate.new()
    pending_template.id = &"pending_child"
    pending_template.target = CombatActions.TARGET.FOE
    pending_template.trigger = CombatEffects.TRIGGER.TARGETED
    var context := {"source_id": &"test:waiting_chain"}
    # A pre-existing child avoids introducing an artificial authored scene.
    var pending := PendingEffect.new()
    pending.name = &"PendingChild"
    pending.setup(f.actor, foe, pending_template)
    pending.set_chain_context(context)
    foe.effect_manager.before_hit_holder.add_child(pending)
    var damage := _resource(&"after_wait", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -50)
    foe.add_effect(f.actor, foe, _chain(&"waiting_parent", [pending_template, damage]), context)
    var running := {"active": true, "completed": false}
    var resolve := func():
        await foe.resolve_effects(CombatEffects.TRIGGER.DAMAGED, &"cancel_wait", func(): return running.active)
        running.completed = true
    resolve.call()
    await get_tree().process_frame
    assert(pending.applied_this_cycle and not running.completed)
    running.active = false
    for _frame in 10:
        if running.completed:
            break
        await get_tree().process_frame
    assert(running.completed, "Cancellation must release a chain even if its child never completes.")
    assert(foe.get_stat(CombatStats.STATS.Health).Current == 100)
    await _free_fixture(f)


## Sets [code]chain.id[/code] to [code]id[/code]; sets [code]chain.template_scene[/code] to
## [code]CHAIN_SCENE[/code]; sets [code]chain.target[/code] to
## [code]CombatActions.TARGET.FOE[/code]. Returns [code]chain[/code].
func _chain(id: StringName, effects: Array[EffectTemplate]) -> EffectTriggerAnotherEffect:
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = id
    chain.template_scene = CHAIN_SCENE
    chain.target = CombatActions.TARGET.FOE
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.triggers = effects
    return chain


## Checks nested cancellation using test objects and assertions. A failed assertion identifies
## behavior that no longer meets the test’s expectation.
func _test_nested_cancellation() -> void:
    var f := _fixture(1)
    var first := _resource(&"first_nested", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1)
    var second := _resource(&"second_nested", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -50)
    var outer := _chain(&"outer", [_chain(&"inner", [first, second]), second])
    var action := _action(f.actor, [outer])
    var running := {"active": true}
    var health: UnitGenericStat = f.foes[0].get_stat(CombatStats.STATS.Health)
    health.value_changed.connect(func(_stat, _old, _new): running.active = false, CONNECT_ONE_SHOT)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"nested_cancel", f.actor, action, f.foes), func(): return running.active
    )
    assert(not result.success and health.Current == 99, "Cancellation must stop siblings at every chain depth.")
    await _free_fixture(f)
