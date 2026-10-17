extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/skill_chain_smoke_suite.gd"
## Reuses the chain fixtures to exercise permanent-unit integration, not just the
## opt-in compiler. Test definitions never alter Celine's authored resources.


class TestParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass  # Local fixture, not the autoload's repository/save registration.


## Checks unit-owned purchases, leases, gate fallback, JSON/retry restoration, hidden cooldowns and
## independent grants without modifying production definitions.
func run() -> void:
    var f := _fixture()
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.skill_collection = f.collection
    template.level = 4
    # Lock the entire chain at this value to verify hidden cooldown persistence.
    f.collection.trees[0].tiers[0].maximum_stats[CombatStats.STATS.Sanity] = 100
    var party := TestParty.new()
    add_child(party)
    var unit := BattleUnit.create(template)
    assert(unit)
    party.add_child(unit)
    assert(unit.get_stat(CombatStats.STATS.Sanity).Current == 100)
    unit.get_stat(CombatStats.STATS.Sanity).set_base(10)
    party.runtime_units[template.id] = unit
    var skills := unit.skills
    assert(skills and skills.ledger.spent_points() == 0)
    var lease_owner := Node.new()
    var stale_owner := Node.new()
    add_child(lease_owner)
    add_child(stale_owner)
    var ranks: Dictionary = f.ledger.capture().ranks
    assert(not party.purchase_skills(template.id, ranks, skills.revision, lease_owner).is_empty())
    assert(party.acquire_preparation(lease_owner))
    assert(not party.purchase_skills(template.id, ranks, skills.revision, stale_owner).is_empty())
    var old_revision := skills.revision
    assert(party.purchase_skills(template.id, ranks, old_revision, lease_owner).is_empty())
    assert(skills.ledger.spent_points() == 11)
    assert(party.get_attribute_points(template.id).available.skill == skills.earned_points() - 11)
    assert(not party.purchase_skills(template.id, {&"a0": 1}, old_revision, lease_owner).is_empty())
    assert(skills.ledger.get_rank(&"a0") == 2)
    var plan := BattleSkillChainResolver.resolve(skills.ledger, skills.stat_values())
    var chain_id: StringName = _tip(plan, &"a3").action.id
    var passive_source: StringName = plan.passives.keys()[0]
    var effect: EffectBase = unit.effect_manager.get_effects_from_source(passive_source)[0]
    assert(skills.refresh().is_empty())
    assert(unit.effect_manager.get_effects_from_source(passive_source)[0] == effect)
    unit._action_cooldowns[chain_id] = 4
    unit.get_stat(CombatStats.STATS.Sanity).set_base(70)
    assert(unit._owned_actions[chain_id].attack_animation == &"animation_a0")
    assert(unit._action_cooldowns[chain_id] == 4 and skills.ledger.spent_points() == 11)
    unit.get_stat(CombatStats.STATS.Sanity).set_base(101)
    assert(not unit._owned_actions.has(chain_id) and unit._action_cooldowns[chain_id] == 4)
    unit.get_stat(CombatStats.STATS.Health).restore_current(13)
    assert(unit.learn_action(BASIC_ATTACK))
    var saved: Dictionary = JSON.parse_string(JSON.stringify(party._serialize_unit(unit)))
    assert(saved.skill_investment.ranks.size() == ranks.size())
    var restored := BattleUnit.create(template)
    party.add_child(restored)
    party._restore_unit(restored, saved)
    assert(restored.skills.ledger.capture() == skills.ledger.capture())
    assert(restored.skills.owns_chain(chain_id) and not restored._owned_actions.has(chain_id))
    assert(restored._action_cooldowns[chain_id] == 4)
    assert(restored.get_stat(CombatStats.STATS.Health).Current == 13)
    assert(restored.is_action_learned(BASIC_ATTACK))
    restored.on_turn_started()
    assert(restored._action_cooldowns[chain_id] == 3)
    restored.get_stat(CombatStats.STATS.Sanity).set_base(10)
    assert(restored._owned_actions[chain_id].attack_animation == &"animation_a2")
    assert(restored._action_cooldowns[chain_id] == 3)
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([restored])
    var before_stat: float = restored.get_stat(CombatStats.STATS.PhysicalResistance).Current
    var before_revision: int = restored.skills.revision
    restored.get_stat(CombatStats.STATS.Sanity).set_base(101)
    assert(checkpoint.restore())
    assert(restored.skills.revision > before_revision)
    assert(restored.skills.refresh().is_empty())
    assert(restored.get_stat(CombatStats.STATS.PhysicalResistance).Current == before_stat)
    assert(restored.effect_manager.get_effects_from_source(passive_source).size() == 1)
    assert(restored._action_cooldowns[chain_id] == 3)
    assert(checkpoint.restore() and restored.skills.refresh().is_empty())
    assert(restored.effect_manager.get_effects_from_source(passive_source).size() == 1)
    party.release_preparation(lease_owner)
    assert(party.acquire_encounter(lease_owner))
    assert(not party.purchase_skills(template.id, {&"a0": 1}, skills.revision, lease_owner).is_empty())
    party.release_encounter(lease_owner)
    # Malformed persisted payloads clear all purchases; unknown cooldowns cannot be
    # legitimized merely by claiming the generated source prefix in a save.
    var unknown := skills.capture()
    unknown.ranks = {"unknown": 1}
    assert(not skills.restore(unknown).is_empty())
    assert(skills.ledger.spent_points() == 0)
    assert(skills.snapshot().available == skills.earned_points())
    assert(unit.is_action_learned(BASIC_ATTACK))
    unit.restore_action_cooldowns({"project_skill:unknown": 99})
    assert(unit._action_cooldowns.is_empty())
    var allowance := restored.skills.earned_points()
    var valid := restored.skills.capture()
    for invalid in [
        null,
        [],
        {},
        {"version": 2, "ranks": {}},
        {"version": 1, "ranks": {&"a0": 99}},
        {"version": 1, "ranks": {&"a1": 1}},
        {"version": 1, "ranks": {&"a0": true}}
    ]:
        # Reach rank/schema validation rather than the legacy-signature refund path.
        if invalid is Dictionary:
            invalid["definition_signature"] = valid.definition_signature
        assert(restored.skills.restore(valid).is_empty())
        assert(not restored.skills.restore(invalid).is_empty())
        assert(restored.skills.ledger.spent_points() == 0)
        assert(restored.skills.snapshot().available == allowance)
        assert(not restored._owned_actions.has(chain_id))
        assert(restored.effect_manager.get_effects_from_source(passive_source).is_empty())
        assert(restored.is_action_learned(BASIC_ATTACK))
        assert(not restored.skills.restore(invalid).is_empty())
        assert(restored.skills.snapshot().available == allowance)
    # Checkpoint restoration can reintroduce old grants before the skill adapter runs.
    # Recovery must remove those too, including on repeated retries.
    checkpoint._units[0].skills.investment = {"version": 1, "ranks": {&"unknown": 1}}
    for attempt in 2:
        assert(checkpoint.restore())
        assert(restored.skills.ledger.spent_points() == 0)
        assert(restored.skills.snapshot().available == allowance)
        assert(not restored._owned_actions.has(chain_id))
        assert(not restored._action_cooldowns.has(chain_id))
        assert(restored.effect_manager.get_effects_from_source(passive_source).is_empty())
        assert(restored.is_action_learned(BASIC_ATTACK))
    await free_node(party)
    await free_node(lease_owner)
    await free_node(stale_owner)
    await _test_feedback_rejection()


## Checks an oscillating passive gate rejects the purchase without spent points, leaked effects or
## unbounded refresh recursion.
func _test_feedback_rejection() -> void:
    var f := _fixture()
    f.collection.trees[0].tiers[0].maximum_stats[CombatStats.STATS.Sanity] = 50
    # This grant locks its own tier, revokes itself, unlocks, and repeats. Reject
    # this authored loop without charging points or leaking its companion effect.
    var modifier: BattleSkillTreeStatGrant = f.collection.trees[0].tiers[0].nodes[1].passive_stat_modifiers[0]
    modifier.stat = CombatStats.STATS.Sanity
    modifier.amounts_by_rank = PackedFloat32Array([100, 100, 100])
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.skill_collection = f.collection
    template.level = 4
    var unit := BattleUnit.create(template)
    add_child(unit)
    unit.get_stat(CombatStats.STATS.Sanity).set_base(10)
    var base: float = unit.get_stat(CombatStats.STATS.PhysicalResistance).Current
    assert(not unit.skills.purchase({&"p0": 1}, unit.skills.revision).is_empty())
    assert(unit.skills.ledger.spent_points() == 0)
    assert(unit.get_stat(CombatStats.STATS.Sanity).Current == 10)
    assert(unit.get_stat(CombatStats.STATS.PhysicalResistance).Current == base)
    await free_node(unit)
