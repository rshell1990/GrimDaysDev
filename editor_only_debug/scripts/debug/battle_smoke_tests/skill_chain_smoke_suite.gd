extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Pure chain plans plus real-unit source reconciliation. No production tree switch.


func run() -> void:
    _test_plans()
    await _test_runtime_grants()


## Builds two four-tier action/passive chains and a cross-row prerequisite branch, then purchases a
## valid fixture ledger.
func _fixture() -> Dictionary:
    var collection := BattleSkillTreeCollection.new()
    var tree := BattleSkillTree.new()
    tree.id = &"test_chain"
    collection.trees = [tree]
    for column in range(4):
        var tier := BattleSkillTier.new()
        tier.column = column
        tier.minimum_stats[CombatStats.STATS.Level] = column + 1
        if column >= 2:
            tier.maximum_stats[CombatStats.STATS.Sanity] = 50 if column == 2 else 25
        tree.tiers.append(tier)
    for row in range(2):
        for column in range(4):
            var node: BattleSkillNode = BattleSkillActionNode.new() if row == 0 else BattleSkillPassiveNode.new()
            node.id = StringName("%s%s" % ["a" if row == 0 else "p", column])
            node.row = row
            node.maximum_rank = 3 if column == 0 else 1
            if column > 0:
                node.previous_node = StringName("%s%s" % ["a" if row == 0 else "p", column - 1])
                node.composite = column != 2
            if row == 0:
                (node as BattleSkillActionNode).action = _action(node.id, node.maximum_rank, column)
            else:
                var modifier := BattleSkillTreeStatGrant.new()
                modifier.modifier_id = &"resistance"
                modifier.stat = CombatStats.STATS.PhysicalResistance
                modifier.amounts_by_rank = PackedFloat32Array([10.0, 20.0, 30.0])
                (node as BattleSkillPassiveNode).passive_stat_modifiers = [modifier]
                for number in node.maximum_rank:
                    var collection_of_effects := EffectTemplates.new()
                    var effect := EffectFlatChangeStatTemplate.new()
                    effect.id = StringName("%s_effect_%s" % [node.id, number])
                    effect.stat = CombatStats.STATS.PhysicalResistance
                    effect.flat_amount = 3
                    effect.target = CombatActions.TARGET.SELF
                    effect.trigger = CombatEffects.TRIGGER.EQUIP
                    effect.kind = CombatEffects.KIND.BUFF
                    effect.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
                    effect.template_scene = STAT_EFFECT_SCENE
                    collection_of_effects.all = [effect]
                    (node as BattleSkillPassiveNode).passive_effects_by_rank.append(collection_of_effects)
            tree.tiers[column].nodes.append(node)
    # This prerequisite must not contribute damage/costs or hide its parent row.
    var branch := BattleSkillActionNode.new()
    branch.id = &"branch"
    branch.row = 2
    branch.prerequisites[&"a1"] = 1
    branch.action = _action(branch.id, 1, 0)
    tree.tiers[0].nodes.append(branch)
    var ledger := BattleSkillInvestment.new()
    assert(ledger.configure(collection).is_empty())
    var values := {CombatStats.STATS.Level: 4, CombatStats.STATS.Sanity: 10}
    assert(
        (
            ledger
            . purchase(
                {&"a0": 2, &"a1": 1, &"a2": 1, &"a3": 1, &"p0": 2, &"p1": 1, &"p2": 1, &"p3": 1, &"branch": 1},
                20,
                values,
                ledger.revision
            )
            . is_empty()
        )
    )
    return {"collection": collection, "ledger": ledger, "values": values}


## Authors a ranked damage action whose costs, cooldown, animation and target count identify its
## chain column.
func _action(id: StringName, count: int, column: int) -> ActionTemplate:
    var action := ActionTemplate.new()
    action.id = id
    action.disabled_by_effects = [StringName("block_%s" % id), &"common_block"]
    action.display_name = String(id)
    action.target = CombatActions.TARGET.FOE
    action.target_amount = column + 1
    action.attack_animation = StringName("animation_%s" % id)
    action.use_spine = column % 2 == 0
    action.loop = column == 0
    action.track_number = column + 1
    action.always_hits = true
    action.ranks = RanksTemplate.new()
    for number in range(1, count + 1):
        var rank := RankTemplate.new()
        rank.cost[CombatStats.STATS.Energy] = number * 10
        rank.cooldown_turns = column + 1
        rank.effects = EffectTemplates.new()
        var damage := EffectScalingCombatStatChangeTemplate.new()
        damage.id = StringName("%s_damage_%s" % [id, number])
        damage.stat = CombatStats.STATS.Health
        damage.scales_from_sender = true
        damage.scales_with = CombatStats.STATS.PhysicalDamage
        damage.scales_by = -0.1
        damage.damage_type = CombatDamage.TYPE.Physical
        damage.target = CombatActions.TARGET.FOE
        damage.trigger = CombatEffects.TRIGGER.DAMAGED
        damage.kind = CombatEffects.KIND.ONCE
        damage.template_scene = SCALED_STAT_EFFECT_SCENE
        rank.effects.all = [damage]
        action.ranks.all.append(rank)
    return action


## Returns the compiled action entry with the requested tip ID, or an empty dictionary.
func _tip(plan: Dictionary, id: StringName) -> Dictionary:
    for entry in plan.actions.values():
        if entry.tip == id:
            return entry
    return {}


## Checks composition, replacement, gate fallback, rank payloads and rejection of invalid effects
## or overflowing costs without mutating authored definitions.
func _test_plans() -> void:
    var f := _fixture()
    var before: Dictionary = f.ledger.capture()
    var plan := BattleSkillChainResolver.resolve(f.ledger, f.values)
    assert(plan.errors.is_empty() and plan.actions.size() == 2 and plan.passives.size() == 2)
    var d := _tip(plan, &"a3")
    var rank: RankTemplate = d.action.get_rank_template(d.rank)
    assert(d.action.disabled_by_effects == [&"block_a2", &"common_block", &"block_a3"])
    assert(d.signature == [[&"a2", 1], [&"a3", 1]])
    assert(rank.cost[CombatStats.STATS.Energy] == 20 and rank.cooldown_turns == 4)
    assert(d.action.attack_animation == &"animation_a2" and d.action.target_amount == 4)
    assert(d.action.use_spine and not d.action.loop and d.action.track_number == 3)
    assert(rank.effects.all[0].id == &"a2_damage_1" and rank.effects.all[1].id == &"a3_damage_1")
    assert(_tip(plan, &"branch").signature == [[&"branch", 1]])
    f.values[CombatStats.STATS.Sanity] = 40
    var c := _tip(BattleSkillChainResolver.resolve(f.ledger, f.values), &"a2")
    assert(c.action.disabled_by_effects == [&"block_a2", &"common_block"])
    assert(c.signature == [[&"a2", 1]] and c.action.id == d.action.id)
    f.values[CombatStats.STATS.Sanity] = 70
    plan = BattleSkillChainResolver.resolve(f.ledger, f.values)
    var b := _tip(plan, &"a1")
    assert(b.action.disabled_by_effects == [&"block_a0", &"common_block", &"block_a1"])
    b.action.disabled_by_effects.clear()
    assert(f.collection.trees[0].tiers[0].nodes[0].action.disabled_by_effects.size() == 2)
    assert(b.signature == [[&"a0", 2], [&"a1", 1]])
    assert(b.action.get_rank_template(b.rank).cost[CombatStats.STATS.Energy] == 30)
    assert(b.action.attack_animation == &"animation_a0" and b.action.target_amount == 2)
    assert(b.action.use_spine and b.action.loop and b.action.track_number == 1)
    assert(b.action.get_rank_template(1).effects.all[0].id == &"a0_damage_2")
    f.values[CombatStats.STATS.Level] = 1
    var a := _tip(BattleSkillChainResolver.resolve(f.ledger, f.values), &"a0")
    assert(a.rank == 2 and a.action.get_rank_template(2).cost[CombatStats.STATS.Energy] == 20)
    f.values[CombatStats.STATS.Level] = 4
    assert(f.ledger.capture() == before)
    # Compiled containers must not modify the source ranks or the next resolution.
    b.action.get_rank_template(b.rank).cost[CombatStats.STATS.Energy] = 999
    assert(f.collection.trees[0].tiers[0].nodes[0].action.get_rank_template(2).cost[CombatStats.STATS.Energy] == 20)
    assert(
        (
            _tip(BattleSkillChainResolver.resolve(f.ledger, f.values), &"a1").action.get_rank_template(1).cost[
                CombatStats.STATS.Energy
            ]
            == 30
        )
    )
    var broken := _fixture()
    broken.collection.trees[0].tiers[0].nodes[0].action.ranks.all.resize(1)
    var rejected := BattleSkillChainResolver.resolve(broken.ledger, broken.values)
    assert(not rejected.errors.is_empty() and rejected.actions.is_empty() and rejected.passives.is_empty())
    broken = _fixture()
    broken.collection.trees[0].tiers[0].nodes[1].passive_effects_by_rank[0].all[0].lifetime = (
        EffectTemplate.LIFETIME.INSTANT
    )
    assert(not BattleSkillChainResolver.resolve(broken.ledger, broken.values).errors.is_empty())
    broken = _fixture()
    broken.collection.trees[0].tiers[2].nodes[0].action.get_rank_template(1).cost[CombatStats.STATS.Energy] = 2147483647
    assert(not BattleSkillChainResolver.resolve(broken.ledger, broken.values).errors.is_empty())


## Returns a dictionary of the fixture unit's current stats for ledger gate evaluation.
func _values(unit: BattleUnit) -> Dictionary:
    var values: Dictionary = {}
    for stat: UnitGenericStat in unit.stat_dictionary.values():
        values[stat.id] = stat.Current
    return values


## Checks reconciliation, independent sources, retained passive instances/cooldowns, real action
## execution and idempotent cleanup on runtime units.
func _test_runtime_grants() -> void:
    var f := _fixture()
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    unit.get_stat(CombatStats.STATS.Level).set_base(4)
    # Production starts at 100; exercise the lower-Sanity fixture tiers explicitly.
    unit.get_stat(CombatStats.STATS.Sanity).set_base(10)
    var stat := unit.get_stat(CombatStats.STATS.PhysicalResistance)
    var baseline: float = stat.Current
    stat.add_modifier(
        UnitStatModifier.create(&"gear", &"equipment:test", stat.id, UnitStatModifier.OPERATION.FLAT_ADD, 5)
    )
    stat.add_modifier(UnitStatModifier.create(&"story", &"story:test", stat.id, UnitStatModifier.OPERATION.FLAT_ADD, 7))
    assert(unit.learn_action(BASIC_ATTACK))
    var grants := BattleSkillGrantReconciler.new()
    var probe := {"rejections": 0}
    var reenter := func(_stat, _old, _new):
        if not grants.reconcile(unit, f.ledger, _values(unit)).is_empty():
            probe.rejections += 1
    stat.value_changed.connect(reenter)
    assert(grants.reconcile(unit, f.ledger, _values(unit)).is_empty())
    stat.value_changed.disconnect(reenter)
    assert(probe.rejections > 0 and is_equal_approx(stat.Current, baseline + 38))
    var active := _tip(BattleSkillChainResolver.resolve(f.ledger, _values(unit)), &"a3")
    var action: ActionTemplate = unit._owned_actions[active.action.id]
    var first_effects: Dictionary = {}
    for source in grants._passives:
        first_effects[source] = unit.effect_manager.get_effects_from_source(source)[0]
    assert(grants.reconcile(unit, f.ledger, _values(unit)).is_empty())
    assert(unit._owned_actions[action.id] == action)
    for source in first_effects:
        assert(unit.effect_manager.get_effects_from_source(source)[0] == first_effects[source])
    var competing := BattleSkillGrantReconciler.new()
    assert(not competing.reconcile(unit, f.ledger, _values(unit)).is_empty())
    assert(competing.clear() and unit.get_action_rank(action) == 1)
    # A malformed new payload rejects before revoking any existing grants.
    var original_max: int = f.collection.trees[0].tiers[0].nodes[0].maximum_rank
    f.collection.trees[0].tiers[0].nodes[0].maximum_rank = 4
    assert(not grants.reconcile(unit, f.ledger, _values(unit)).is_empty())
    assert(unit._owned_actions[action.id] == action and is_equal_approx(stat.Current, baseline + 38))
    f.collection.trees[0].tiers[0].nodes[0].maximum_rank = original_max
    # Compiled action runs through real cost/effect routing (legacy hit gate for now).
    var target := BattleUnit.create(CELINE_TEMPLATE)
    add_child(target)
    unit.team_id = &"allies"
    target.team_id = &"foes"
    unit.get_stat(CombatStats.STATS.Energy).set_base(1000)
    var energy_before: float = unit.get_stat(CombatStats.STATS.Energy).Current
    var health_before: float = target.get_stat(CombatStats.STATS.Health).Current
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    var result = await resolver.resolve(BattleActionRequest.new(&"compiled_chain", unit, action, [target]))
    assert(result.success and target.get_stat(CombatStats.STATS.Health).Current < health_before)
    var damage_events: Array = result.events.filter(func(event): return event.type == BattleCombatEvent.TYPE.DAMAGE)
    assert(damage_events.size() == 2, "Replacement C plus composite D executes two damage operations.")
    assert(unit.get_stat(CombatStats.STATS.Energy).Current == energy_before - 20)
    var cooldown: int = unit._action_cooldowns[action.id]
    unit.get_stat(CombatStats.STATS.Sanity).set_base(70)
    assert(grants.reconcile(unit, f.ledger, _values(unit)).is_empty())
    assert(unit.get_action_rank(action) == 0, "Stale compiled actions must not remain usable.")
    assert(unit._action_cooldowns[action.id] == cooldown)
    assert(is_equal_approx(stat.Current, baseline + 48))
    assert(f.ledger.get_rank(&"a3") == 1)
    # Replacing a passive rank changes its contribution, not its source count.
    assert(f.ledger.purchase({&"p0": 1, &"a0": 1}, 20, _values(unit), f.ledger.revision).is_empty())
    var before_rank: ActionTemplate = unit._owned_actions[action.id]
    assert(grants.reconcile(unit, f.ledger, _values(unit)).is_empty())
    assert(is_equal_approx(stat.Current, baseline + 58) and grants._passives.size() == 2)
    assert(unit.get_action_rank(before_rank) == 0 and unit._action_cooldowns[action.id] == cooldown)
    assert(unit._owned_actions[action.id].get_rank_template(1).cost[CombatStats.STATS.Energy] == 40)
    unit.get_stat(CombatStats.STATS.Level).set_base(0)
    assert(grants.reconcile(unit, f.ledger, _values(unit)).is_empty())
    assert(unit._action_cooldowns[action.id] == cooldown)
    unit.on_turn_started()
    assert(unit._action_cooldowns[action.id] == cooldown - 1)
    assert(is_equal_approx(stat.Current, stat.Base + 12), "Only external grants survive unavailable tiers.")
    unit.get_stat(CombatStats.STATS.Level).set_base(4)
    unit.get_stat(CombatStats.STATS.Sanity).set_base(10)
    assert(grants.reconcile(unit, f.ledger, _values(unit)).is_empty())
    assert(unit._action_cooldowns[action.id] == cooldown - 1 and is_equal_approx(stat.Current, baseline + 38))
    assert(
        unit.serialize_action_state().action_grants.size() == 1,
        "Generated actions are derived, not Resource-path saves."
    )
    assert(grants.clear() and grants.clear())
    assert(
        (
            is_equal_approx(stat.Current, baseline + 12)
            and unit._action_grants_by_source.has(StringName("learned:%s" % BASIC_ATTACK.id))
        )
    )
    assert(not unit._action_cooldowns.has(action.id))
    await free_node(resolver)
    await free_node(target)
    await free_node(unit)
