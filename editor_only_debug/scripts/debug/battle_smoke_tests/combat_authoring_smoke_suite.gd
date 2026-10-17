# Integration checks for weapon requirements, strike-local procs, critical modifiers and repetition.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/per_effect_hit_smoke_suite.gd"

const CHAIN_SCENE = preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")
const PROGRESSION = preload("res://GrimDaysBattle/scripts/Actions/Resources/action_rank_progression.gd")


func run() -> void:
    await _test_equipment_requirements()
    await _test_strike_followups()
    await _test_multitarget_followups()
    await _test_repeated_sequence()
    _test_authoring_graph()
    await _test_ranked_combat_modifiers()
    print("COMBAT_AUTHORING_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _test_equipment_requirements() -> void:
    var f := _fixture(1)
    var action := _action(
        f.actor, [_resource(&"weapon_damage", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -1)]
    )
    var requirement := ActionEquipmentRequirement.new()
    action.equipment_requirements = [requirement]
    assert(f.actor.can_use_action(action))
    var root := BattleSkillActionNode.new()
    root.id = &"equipment_root"
    root.action = action
    var tip := BattleSkillActionNode.new()
    tip.id = &"equipment_tip"
    tip.action = action.duplicate() as ActionTemplate
    tip.action.equipment_requirements = []
    var ledger := BattleSkillInvestment.new()
    ledger._ranks = {root.id: 1, tip.id: 1}
    var errors := PackedStringArray()
    var components: Array[BattleSkillNode] = [root, tip]
    var compiled := tip._compile_action(&"requirement_chain", components, ledger, errors)
    assert(errors.is_empty() and compiled.equipment_requirements == [requirement])
    var hand: UnitEquipmentSlot
    for child in f.actor.get_children():
        if child is UnitEquipmentSlot and child.slot == UnitEquipmentSlot.SLOT.RightHand:
            hand = child
    assert(hand != null)
    var blade := EquipmentWeaponTemplate.new()
    blade.id = &"test_blade"
    blade.equips_to = [UnitEquipmentSlot.SLOT.RightHand]
    blade.weapon_tags = [&"bladed"]
    await hand.equip(f.actor, blade)
    assert(not f.actor.can_use_action(action))
    var blocked: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"unarmed_block", f.actor, action, f.foes)
    )
    assert(not blocked.success)
    requirement.mode = ActionEquipmentRequirement.MODE.WEAPON_TAG
    assert(f.actor.can_use_action(action))
    requirement.weapon_tag = &"blunt"
    assert(not f.actor.can_use_action(action))
    requirement.weapon_tag = &"bladed"
    var stale := BattleActionRequest.new(&"removed_weapon", f.actor, action, f.foes)
    await hand.unequip()
    blocked = await f.resolver.resolve(stale)
    assert(not blocked.success)
    var forced := EffectForceActionTemplate.new()
    forced.id = &"forced_weapon_action"
    forced.action = action
    f.actor.add_effect(f.actor, f.actor, forced)
    var forced_request := BattleActionRequest.new(&"forced_weapon_block", f.actor, action, f.foes)
    assert(forced_request.forced_action)
    blocked = await f.resolver.resolve(forced_request)
    assert(not blocked.success)
    await _free_fixture(f)


func _strike(id: StringName) -> EffectScalingCombatStatChangeTemplate:
    var effect := (
        BASIC_ATTACK.get_rank_template(1).effects.all[0].duplicate(true) as EffectScalingCombatStatChangeTemplate
    )
    effect.id = id
    effect.scales_from_sender = true
    effect.scales_with = CombatStats.STATS.PhysicalDamage
    effect.scales_by = -1
    effect.scales_with_damage = false
    effect.damage_type = CombatDamage.TYPE.True
    effect.always_hits = true
    return effect


func _test_strike_followups() -> void:
    var f := _fixture(1)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 10)
    var first := _strike(&"critical_uppercut")
    first.critical_chance_bonus = 100
    first.critical_damage_multiplier = 3
    var bleed := _resource(&"stab_bleed", CombatEffects.TRIGGER.ROUND_OVER, CombatActions.TARGET.FOE, -2)
    bleed.lifetime = EffectTemplate.LIFETIME.ROUNDS
    bleed.duration = 2
    bleed.kind = CombatEffects.KIND.REPEAT
    var stun := EffectStunTemplate.new()
    stun.id = &"uppercut_stun"
    stun.target = CombatActions.TARGET.FOE
    first.effects_on_critical = [stun]
    var second := _strike(&"normal_stab")
    second.effects_on_hit = [bleed]
    var action := _action(f.actor, [first, second])
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"local_procs", f.actor, action, f.foes)
    )
    assert(result.success, result.error)
    assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 2)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 60)
    assert(f.foes[0].is_stunned() and not f.actor.is_stunned())
    assert(f.actor.get_stat(CombatStats.STATS.CriticalStrike).Current == 0)
    var captured := BattleRetryCheckpoint.new()
    captured.capture(f.foes)
    f.foes[0].effect_manager.advance_round()
    assert(not f.foes[0].is_stunned())
    assert(captured.restore() and f.foes[0].is_stunned())
    f.foes[0].effect_manager.remove_battle_scoped_effects()
    # Missed operations produce neither hit nor critical children.
    _override_stat(f.actor, CombatStats.STATS.Accuracy, 0)
    first.always_hits = false
    first.effects_on_hit = [stun]
    action.always_hits = false
    action.get_rank_template(1).effects.all = [first]
    result = await f.resolver.resolve(BattleActionRequest.new(&"miss_no_proc", f.actor, action, f.foes))
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.MISS).size() == 1)
    assert(not f.foes[0].is_stunned())
    await _free_fixture(f)


func _test_repeated_sequence() -> void:
    var f := _fixture(1)
    _prepare(f)
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"repeated_combo"
    chain.template_scene = CHAIN_SCENE
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.target = CombatActions.TARGET.FOE
    chain.repeat_min = 3
    chain.repeat_max = 3
    chain.triggers = [
        _resource(&"combo_jab", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -2),
        _resource(&"combo_punch", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOE, -3)
    ]
    var action := _action(f.actor, [chain])
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"fixed_repeat", f.actor, action, f.foes)
    )
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == 6)
    assert(result.get_events(BattleCombatEvent.TYPE.COST_PAID).size() == 1)
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == 85)
    chain.repeat_min = 2
    chain.repeat_max = 5
    var random := RandomNumberGenerator.new()
    random.seed = 42
    var expected := random.randi_range(2, 5)
    f.actor.randomizer.set_seed(42)
    result = await f.resolver.resolve(BattleActionRequest.new(&"random_repeat", f.actor, action, f.foes))
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == expected * 2)
    chain.chance = 0
    result = await f.resolver.resolve(BattleActionRequest.new(&"no_repeat", f.actor, action, f.foes))
    assert(result.success and result.get_events(BattleCombatEvent.TYPE.DAMAGE).is_empty())
    # Continuation must stop remaining iterations after the first primitive.
    chain.chance = 100
    var allowed := [true]
    f.foes[0].resource_operation_resolved.connect(func(_data): allowed[0] = false, CONNECT_ONE_SHOT)
    var before: float = f.foes[0].get_stat(CombatStats.STATS.Health).Current
    await f.resolver.resolve(
        BattleActionRequest.new(&"cancel_repeat", f.actor, action, f.foes), func(): return allowed[0]
    )
    assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == before - 2)
    await _free_fixture(f)


func _test_authoring_graph() -> void:
    var strike := _strike(&"ranked_strike")
    var child := EffectStunTemplate.new()
    child.id = &"ranked_stun"
    child.duration_by_rank = PackedInt32Array([1, 2])
    strike.effects_on_critical = [child]
    var rank := RankTemplate.new()
    rank.effects = EffectTemplates.new()
    rank.effects.all = [strike]
    assert(PROGRESSION.validate(rank, {}, 2).is_empty())
    var resolved: EffectTemplate = PROGRESSION.resolve(rank, {}, 2).effects.all[0]
    assert(resolved.effects_on_critical[0].duration == 2 and child.duration == 1)
    child.effects_on_hit = [strike]
    assert(not PROGRESSION.validate(rank, {}, 2).is_empty())
    child.effects_on_hit.clear()


func _test_multitarget_followups() -> void:
    var f := _fixture(2)
    _prepare(f)
    var strike := _resource(&"area_strike", CombatEffects.TRIGGER.DAMAGED, CombatActions.TARGET.FOES, -1)
    var child := EffectFixStatTemplate.new()
    child.id = &"hit_recipient_lock"
    child.stat = CombatStats.STATS.Lucidity
    child.value = 13
    child.target = CombatActions.TARGET.FOE
    strike.effects_on_hit = [child]
    var action := _action(f.actor, [strike])
    var result: BattleActionResolution = await f.resolver.resolve(
        BattleActionRequest.new(&"area_followups", f.actor, action, f.foes)
    )
    assert(result.success)
    for foe in f.foes:
        assert(foe.get_stat(CombatStats.STATS.Lucidity).Current == 13)
    assert(f.actor.get_stat(CombatStats.STATS.Lucidity).Current != 13)
    await _free_fixture(f)


func _test_ranked_combat_modifiers() -> void:
    var f := _fixture(1)
    _prepare(f)
    _override_stat(f.actor, CombatStats.STATS.PhysicalDamage, 10)
    var strike := _strike(&"ranked_critical")
    strike.critical_chance_bonus = -5
    strike.critical_damage_multiplier = 2
    strike.critical_chance_bonus_by_rank = PackedFloat64Array([0, 100])
    strike.critical_damage_multiplier_by_rank = PackedFloat64Array([2, 3])
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"ranked_chance"
    chain.template_scene = CHAIN_SCENE
    chain.trigger = CombatEffects.TRIGGER.DAMAGED
    chain.target = CombatActions.TARGET.FOE
    chain.chance = 27
    chain.chance_by_rank = PackedInt32Array([0, 100])
    chain.triggers = [strike]
    var action := _action(f.actor, [chain])
    action.ranks.base_rank = action.ranks.all[0]
    action.ranks.generated = true
    action.ranks.rank_count = 3
    assert(action.ranks.validate_progression().is_empty())
    for number in range(1, 4):
        assert(f.actor.grant_action_from_source(&"ranked_modifiers", action, number))
        var resolved: EffectTriggerAnotherEffect = action.get_rank_template(number).effects.all[0]
        assert(resolved.chance == (0 if number == 1 else 100))
        assert(resolved.triggers[0].critical_chance_bonus == (0 if number == 1 else 100))
        assert(resolved.triggers[0].critical_damage_multiplier == (2 if number == 1 else 3))
        f.foes[0].get_stat(CombatStats.STATS.Health).restore_current(100)
        var result: BattleActionResolution = await f.resolver.resolve(
            BattleActionRequest.new(StringName("ranked_modifiers_%s" % number), f.actor, action, f.foes)
        )
        assert(result.success, result.error)
        assert(result.get_events(BattleCombatEvent.TYPE.CRITICAL).size() == (0 if number == 1 else 1))
        assert(f.foes[0].get_stat(CombatStats.STATS.Health).Current == (100 if number == 1 else 70))
    assert(chain.chance == 27 and strike.critical_chance_bonus == -5 and strike.critical_damage_multiplier == 2)
    # The same graph traversal covers hit, critical and expiry descendants.
    var parent := _strike(&"ranked_parent")
    parent.effects_on_hit = [chain]
    parent.effects_on_critical = [strike]
    parent.effects_on_expiry = [chain]
    action.ranks.base_rank.effects.all = [parent]
    var snapshot: EffectTemplate = action.get_rank_template(3).effects.all[0]
    assert(snapshot.effects_on_hit[0].chance == 100 and snapshot.effects_on_expiry[0].chance == 100)
    assert(snapshot.effects_on_critical[0].critical_damage_multiplier == 3)
    # Reject invalid arrays before an Action can resolve a generated rank.
    strike.critical_chance_bonus_by_rank = PackedFloat64Array([NAN])
    assert(not action.ranks.validate_progression().is_empty())
    strike.critical_chance_bonus_by_rank = PackedFloat64Array([0, 1, 2, 3])
    assert(not action.ranks.validate_progression().is_empty())
    strike.critical_chance_bonus_by_rank = PackedFloat64Array()
    strike.critical_damage_multiplier_by_rank = PackedFloat64Array([-1])
    assert(not action.ranks.validate_progression().is_empty())
    strike.critical_damage_multiplier_by_rank = PackedFloat64Array([INF])
    assert(not action.ranks.validate_progression().is_empty())
    strike.critical_damage_multiplier_by_rank = PackedFloat64Array()
    chain.chance_by_rank = PackedInt32Array([101])
    assert(not action.ranks.validate_progression().is_empty())
    chain.chance_by_rank = PackedInt32Array([-1])
    assert(not action.ranks.validate_progression().is_empty())
    chain.chance_by_rank = PackedInt32Array()
    assert(action.ranks.validate_progression().is_empty())
    snapshot = action.get_rank_template(3).effects.all[0]
    assert(snapshot.effects_on_hit[0].chance == 27)
    assert(snapshot.effects_on_critical[0].critical_chance_bonus == -5)
    assert(snapshot.effects_on_critical[0].critical_damage_multiplier == 2)
    await _free_fixture(f)
