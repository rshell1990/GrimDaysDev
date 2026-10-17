extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/damage_reaction_smoke_suite.gd"
## Substitution changes live targeting before any incoming operation is attached.

const SUBSTITUTION_SCENE = preload(
    "res://GrimDaysBattle/scenes/battle/effects/effect_target_substitution.tscn"
)


func run() -> void:
    await _test_current_target_and_attachment()
    await _test_precedence_and_invalid_binding()
    await _test_group_and_new_selection()
    await _test_defeat_and_retry()
    await _test_authored_binding_action()


func _bind(owner: BattleUnit, replacement: BattleUnit, binding_id: StringName) -> EffectTargetSubstitution:
    var definition := EffectTargetSubstitutionTemplate.new()
    definition.id = binding_id
    definition.trigger = CombatEffects.TRIGGER.TARGETED
    definition.kind = CombatEffects.KIND.REPEAT
    definition.lifetime = EffectTemplate.LIFETIME.UNTIL_BATTLE_END
    definition.template_scene = SUBSTITUTION_SCENE
    return owner.add_effect(
        owner, owner, definition, {"source_id": binding_id, "selected_target": replacement, "defer_application": true}
    )


func _test_current_target_and_attachment() -> void:
    var f := _fixture(3)
    var original: BattleUnit = f.foes[0]
    var replacement: BattleUnit = f.foes[1]
    var third: BattleUnit = f.foes[2]
    var binding := _bind(original, replacement, &"redirect")
    _bind(replacement, third, &"must_not_cascade")
    var existing := _grant(
        original,
        _resource(&"existing", CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.SELF, 0, CombatStats.STATS.Mana)
    )
    var previous_parent := existing.get_parent()
    var attachments: Array[Dictionary] = []
    for unit: BattleUnit in f.foes:
        for holder: EffectDirectors in unit.effect_manager.triggers_to_holders.values():
            holder.child_entered_tree.connect(
                func(effect):
                    if effect is EffectBase:
                        attachments.append({"unit": unit, "effect_id": effect.id})
            )
    var action := _two_hits(f.actor)
    action.ranks.all[0].effects.all.append(
        _resource(
            &"completion", CombatEffects.TRIGGER.PROCESS_OVER, CombatActions.TARGET.FOE, -1, CombatStats.STATS.Mana
        )
    )
    var request := BattleActionRequest.new(&"substitution", f.actor, action, [original])
    var result: BattleActionResolution = await f.resolver.resolve(request)
    assert(result.success)
    assert(request.targets == [original], "Original selection is preserved only as request history.")
    assert(original.get_stat(CombatStats.STATS.Health).Current == 100)
    assert(replacement.get_stat(CombatStats.STATS.Health).Current == 80)
    assert(third.get_stat(CombatStats.STATS.Health).Current == 100)
    assert(original.get_stat(CombatStats.STATS.Mana).Current == 100)
    assert(replacement.get_stat(CombatStats.STATS.Mana).Current == 99, "Action completion uses the current target too.")
    assert(existing.get_parent() == previous_parent and binding.get_attached() == original)
    for entry in attachments:
        if entry.effect_id in [&"first", &"second", &"completion"]:
            assert(entry.unit == replacement, "Incoming effects attach only to the unit they affect.")
    assert(attachments.filter(func(entry): return entry.effect_id in [&"first", &"second", &"completion"]).size() == 3)
    var targeted := result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED)
    assert(targeted.size() == 1 and targeted[0].target == original)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).all(func(event): return event.target == replacement))
    assert(f.actor.last_target == replacement)
    var substitutions := result.get_events(BattleCombatEvent.TYPE.TARGET_SUBSTITUTED)
    assert(substitutions.size() == 1 and substitutions[0].target == replacement)
    assert(substitutions[0].data.original_selection == original)
    await _free_fixture(f)


func _test_precedence_and_invalid_binding() -> void:
    for invalid in [false, true]:
        var f := _fixture(3)
        _bind(f.foes[0], f.foes[1], &"older")
        _bind(f.foes[0], f.foes[2], &"newer")
        if invalid:
            f.foes[2].get_stat(CombatStats.STATS.Health).restore_current(0)
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(&"competing", f.actor, _two_hits(f.actor), [f.foes[0]])
        )
        var recipient: BattleUnit = f.foes[1] if invalid else f.foes[2]
        assert(result.success and recipient.get_stat(CombatStats.STATS.Health).Current == 80)
        assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 100)
        await _free_fixture(f)


func _test_group_and_new_selection() -> void:
    var f := _fixture(3)
    _bind(f.foes[0], f.foes[1], &"redirect")
    _bind(f.foes[1], f.foes[2], &"redirect_new_selection")
    var group := _two_hits(f.actor)
    group.target = CombatActions.TARGET.FOES
    var group_result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"group", f.actor, group, f.foes)
    )
    assert(group_result.success and group_result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED).is_empty())
    for foe: BattleUnit in f.foes:
        assert(foe.get_stat(CombatStats.STATS.Health).Current == 80)
    var rng := RandomNumberGenerator.new()
    for seed_value in range(1, 1000):
        rng.seed = seed_value
        if rng.randi_range(0, 2) == 1:
            f.actor.randomizer.set_seed(seed_value)
            break
    var switch_action := _action(
        f.actor,
        [
            _resource(&"initial", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
            _resource(&"new_selection", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.RANDOM_FOE, -10),
            _resource(&"continue_current", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -10),
        ]
    )
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"switch", f.actor, switch_action, [f.foes[0]])
    )
    assert(result.success)
    var selections := result.get_events(BattleCombatEvent.TYPE.BEFORE_TARGETED)
    assert(selections.size() == 2 and selections[0].target == f.foes[0] and selections[1].target == f.foes[1])
    var damage := result.get_events(BattleCombatEvent.TYPE.DAMAGE)
    assert(damage.size() == 3 and damage[0].target == f.foes[1])
    assert(damage[1].target == f.foes[2] and damage[2].target == f.foes[2])
    assert(result.events.find(damage[0]) < result.events.find(selections[1]))
    await _free_fixture(f)


func _test_defeat_and_retry() -> void:
    var f := _fixture(2)
    var original: BattleUnit = f.foes[0]
    var replacement: BattleUnit = f.foes[1]
    var binding := _bind(original, replacement, &"survive_rescue")
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([f.actor, original, replacement])
    var revival := _grant(replacement, _resource(&"rescue", CombatEffects.TRIGGER.DEFEAT, CombatActions.TARGET.SELF, 5))
    revival.kind = CombatEffects.KIND.ONCE
    var action := _action(
        f.actor, [_resource(&"lethal", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -100)]
    )
    assert((await f.resolver.resolve(BattleActionRequest.new(&"revival", f.actor, action, [replacement]))).success)
    assert(replacement.is_active and not binding.removed and binding.bound_unit == replacement)
    assert((await f.resolver.resolve(BattleActionRequest.new(&"final_defeat", f.actor, action, [replacement]))).success)
    assert(not replacement.is_active and binding.removed and binding.bound_unit == null)
    assert(checkpoint.restore())
    var restored: Array = original.effect_manager.before_hit_holder.get_children().filter(
        func(effect): return effect is EffectTargetSubstitution and not effect.removed
    )
    assert(restored.size() == 1 and restored[0].bound_unit == replacement and replacement.is_active)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"after_retry", f.actor, _two_hits(f.actor), [original])
    )
    assert(result.success and replacement.get_stat(CombatStats.STATS.Health).Current == 80)
    f.scene.coordinator.roster.remove_battle_effects()
    assert(restored[0].removed and restored[0].bound_unit == null)
    await _free_fixture(f)


func _test_authored_binding_action() -> void:
    var f := _fixture(2)
    var caster: BattleUnit = f.foes[0]
    var ally: BattleUnit = f.foes[1]
    var definition := EffectTargetSubstitutionTemplate.new()
    definition.id = &"authored_binding"
    definition.target = CombatActions.TARGET.SELF
    definition.trigger = CombatEffects.TRIGGER.TARGETED
    definition.kind = CombatEffects.KIND.REPEAT
    definition.lifetime = EffectTemplate.LIFETIME.UNTIL_BATTLE_END
    definition.template_scene = SUBSTITUTION_SCENE
    var cast := _action(caster, [definition])
    cast.target = CombatActions.TARGET.ALLY
    assert((await f.resolver.resolve(BattleActionRequest.new(&"bind_ally", caster, cast, [ally]))).success)
    var bindings := caster.effect_manager.before_hit_holder.get_children().filter(
        func(effect): return effect is EffectTargetSubstitution and not effect.removed
    )
    assert(bindings.size() == 1 and bindings[0].bound_unit == ally)
    assert(ally.effect_manager.before_hit_holder.get_child_count() == 0)
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"use_authored_binding", f.actor, _two_hits(f.actor), [caster])
    )
    assert(result.success and ally.get_stat(CombatStats.STATS.Health).Current == 80)
    assert(caster.get_stat(CombatStats.STATS.Health).Current == 100)
    await _free_fixture(f)
