extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"
## Isolated player-facing skill preview checks. No legacy smoke suite is executed.

const PANEL = preload("res://GrimDaysBattle/scenes/ui/party_management.tscn")


class PreviewParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass  # Private fixture; never registers with the save system.


func _ready() -> void:
    var passed := await _test_unit_previews()
    if passed:
        passed = await _test_straight_punch_investment()
    set_meta(&"preview_tests_passed", passed)
    if passed:
        print("SKILL_PAYLOAD_PREVIEW_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
    if not EngineDebugger.is_active():
        get_tree().quit(0 if passed else 1)


## Outcome previews use each selected unit without consuming RNG or mutating stats/templates.
func _test_unit_previews() -> bool:
    var preview = BattleSkillPreparationView.PAYLOAD_PREVIEW
    var first := create_unit()
    var second := create_unit()
    create_flat_stat(first, CombatStats.STATS.PhysicalDamage, 100.0)
    create_flat_stat(second, CombatStats.STATS.PhysicalDamage, 200.0)
    create_flat_stat(first, CombatStats.STATS.DamageModifier, 1.3)
    create_flat_stat(first, CombatStats.STATS.CriticalStrike, 25.0)
    create_flat_stat(first, CombatStats.STATS.Health, 200.0)
    var damage := make_scaled_template(&"preview", CombatStats.STATS.PhysicalDamage, -1.0, CombatDamage.TYPE.Physical)
    damage.target = CombatActions.TARGET.FOE
    var seed_before := first.randomizer.random_number_generator.state
    var text: String = preview.effect_text(damage, 0, [], first)
    assert(text == "Damage: 85-115", text)
    assert(preview.effect_text(damage, 0, [], second) == "Damage: 170-230")
    damage.scales_with_damage = true
    damage.can_critical = true
    text = preview.effect_text(damage, 0, [], first)
    assert(text == "Damage: 110-149", text)
    damage.critical_damage_multiplier = 2.5
    assert(preview.effect_text(damage, 0, [], first) == "Damage: 110-149 (critical damage: 2.5x)")
    damage.critical_damage_multiplier = 1.5
    assert(preview.effect_text(damage, 0, [], first) == "Damage: 110-149")
    damage.critical_damage_multiplier = 2.5
    damage.can_critical = false
    assert(preview.effect_text(damage, 0, [], first) == "Damage: 110-149")
    damage.scales_with_damage = false
    damage.can_critical = false
    damage.damage_type = CombatDamage.TYPE.Magic
    assert(preview.effect_text(damage, 0, [], first) == "Damage: 70-130")
    damage.damage_type = CombatDamage.TYPE.True
    assert(preview.effect_text(damage, 0, [], first) == "Damage: 100")
    damage.scales_by = -0.109
    assert(preview.effect_text(damage, 0, [], first) == "Damage: 10")
    damage.scales_by = 0.5
    assert(preview.effect_text(damage, 0, [], first) == "Healing: 50")
    damage.scales_from_sender = false
    assert("the target's Physical Damage" in preview.effect_text(damage, 0, [], first))
    damage.target = CombatActions.TARGET.SELF
    assert(preview.effect_text(damage, 0, [], first) == "Self: Healing: 50")
    assert(first.get_stat(CombatStats.STATS.PhysicalDamage).Current == 100.0)
    assert(first.randomizer.random_number_generator.state == seed_before)
    assert(damage.scales_by == 0.5)
    var buff := EffectPercentageChangeStatTemplate.new()
    buff.stat = CombatStats.STATS.Strength
    buff.percentage = 0.3
    buff.lifetime = EffectTemplate.LIFETIME.ROUNDS
    buff.duration = 1
    assert(preview.effect_text(buff) == "Self: Strength: +30%")
    buff.duration = 3
    assert(preview.effect_text(buff) == "Self: Strength: +30% (for 3 rounds)")
    var grant := BattleSkillTreeStatGrant.new()
    grant.stat = CombatStats.STATS.PhysicalDamage
    grant.operation = UnitStatModifier.OPERATION.MULTIPLY
    grant.amounts_by_rank = PackedFloat32Array([1.3, 1.5])
    var passive := BattleSkillPassiveNode.new()
    passive.maximum_rank = 2
    passive.passive_stat_modifiers = [grant]
    assert(preview.passive_text(passive, 1) == "Physical Damage: 130% of normal")
    assert(preview.next_text(passive, 1) == "Physical Damage: 130% of normal -> 150% of normal")
    var drain := EffectResourceChangeTemplate.new()
    drain.stat = CombatStats.STATS.Health
    drain.amount_mode = EffectResourceChangeTemplate.AMOUNT_MODE.PERCENT_MAX
    drain.amount = -0.25
    drain.damage_type = CombatDamage.TYPE.True
    assert(preview.effect_text(drain, 0, [], first) == "Self: Damage: 50")
    drain.target = CombatActions.TARGET.FOE
    assert(preview.effect_text(drain, 0, [], first) == "Damage: 25% of the target's maximum Health")
    var chain := EffectTriggerAnotherEffect.new()
    chain.target = CombatActions.TARGET.FOE
    chain.chance = 35
    chain.repeat_min = 2
    chain.repeat_max = 4
    chain.triggers = [damage]
    text = preview.effect_text(chain, 0, [], first)
    assert("35% chance" in text and "2-4 times, each" in text and "Healing: 50" in text)
    chain.triggers.append(chain)
    assert(preview.effect_text(chain, 0, [], first) == text)
    chain.triggers.clear()
    var action := ActionTemplate.new()
    action.id = &"preview_action"
    action.ranks = RanksTemplate.new()
    for potency in [-0.1, -0.2]:
        var rank := RankTemplate.new()
        rank.effects = EffectTemplates.new()
        var strike := make_scaled_template(
            &"preview_strike", CombatStats.STATS.PhysicalDamage, potency, CombatDamage.TYPE.Physical
        )
        strike.target = CombatActions.TARGET.FOE
        rank.effects.all = [strike]
        action.ranks.all.append(rank)
    action.ranks.all[1].effects.all[0].scales_by = -0.2
    var node := BattleSkillActionNode.new()
    node.id = &"preview_node"
    node.action = action
    node.maximum_rank = 2
    text = preview.next_text(node, 1, first)
    assert("Damage: 8-11" in text and "Damage: 17-23" in text, text)
    for internal in ["Scaling", "multiplier", "priority", "Effect type", "Stacking", "Amount", "payload"]:
        assert(internal not in text, text)
    assert(preview.action_text(action, 1, first) == "Damage: 8-11")
    assert(preview.action_text(action, 1, second) == "Damage: 17-23")
    var tier := BattleSkillTier.new()
    tier.nodes = [node]
    var tree := BattleSkillTree.new()
    tree.id = &"preview_tree"
    tree.tiers = [tier]
    var collection := BattleSkillTreeCollection.new()
    collection.trees = [tree]
    var ledger := BattleSkillInvestment.new()
    assert(ledger.configure(collection).is_empty())
    assert(ledger.purchase({node.id: 1}, 2, {}, ledger.revision).is_empty())
    assert(preview.final_text(node, ledger, first) == "Damage: 8-11")
    assert(ledger.get_rank(node.id) == 1)
    # Generated potency must be resolved before calculating a unit's damage range.
    action.ranks.generated = true
    action.ranks.rank_count = 2
    action.ranks.base_rank = action.ranks.all[0]
    action.ranks.all = []
    action.ranks.base_rank.effects.all[0].scales_by_by_rank = PackedFloat64Array([-1.0, -1.5])
    assert(preview.action_text(action, 2, first) == "Damage: 127-172")
    assert(action.ranks.base_rank.effects.all[0].scales_by == -0.1)
    var stun := EffectStunTemplate.new()
    stun.id = &"preview_stun"
    stun.target = CombatActions.TARGET.FOE
    stun.duration = 2
    action.ranks.base_rank.effects.all[0].effects_on_hit = [stun]
    text = preview.action_text(action, 2, first)
    assert("On hit: Stuns the target (for 2 rounds)" in text, text)
    var cosmetic := EffectTriggerSoundTemplate.new()
    cosmetic.tag = CombatEffects.TAG.AUDIO
    cosmetic.description = "Internal sound cue"
    assert(preview.effect_text(cosmetic).is_empty())
    var unknown := EffectTemplate.new()
    unknown.description = "Protects the target"
    assert(preview.effect_text(unknown) == "Self: Protects the target")
    await free_node(first)
    await free_node(second)
    return true


## Reproduces the production Invest click with a private Celine and no save writes.
func _test_straight_punch_investment() -> bool:
    var template := CELINE_TEMPLATE.duplicate() as BattleUnitTemplate
    template.level = 3
    var party := PreviewParty.new()
    add_child(party)
    var unit := BattleUnit.create(template)
    party.add_child(unit)
    party.runtime_units[template.id] = unit
    var lease_owner := Node.new()
    add_child(lease_owner)
    assert(party.acquire_preparation(lease_owner))
    var panel := PANEL.instantiate() as BattlePreparationPanel
    add_child(panel)
    panel.present(party, lease_owner)
    panel._show_talents(true)
    var view: BattleSkillPreparationView = panel._project_skills
    var id := &"straight_punch_node"
    assert(view._nodes.has(id))
    var purchased := unit.skills.ledger.get_rank(id)
    assert(purchased == 0)
    # Preparation pauses the world while its overlay continues processing.
    panel.process_mode = Node.PROCESS_MODE_ALWAYS
    var was_paused := get_tree().paused
    get_tree().paused = true
    for frame in 3:
        await get_tree().process_frame
    for cycle in 3:
        for rank in range(1, 6):
            await _click_button(view._nodes[id].invest)
            assert(view._draft.get(id, 0) == rank)
            assert(view._ledger.get_rank(id) == rank)
            assert(unit.skills.ledger.get_rank(id) == purchased)
            assert(view._final.visible and "Damage:" in view._final.text)
            assert("Damage:" in view._next.text if rank < 5 else view._next.text == "(MAX RANK)")
        await _click_button(view._clear)
        assert(view._draft.is_empty())
        assert(unit.skills.ledger.get_rank(id) == purchased)
    get_tree().paused = was_paused
    print("STRAIGHT_PUNCH_INVESTMENT: PASS") # lint:ignore debug-print -- Required test/CLI output.
    panel.dismiss()
    party.release_preparation(lease_owner)
    await free_node(panel)
    await free_node(party)
    await free_node(lease_owner)
    return true


## Deliver a real GUI press/release, including focus, hover and rendered layout updates.
func _click_button(button: Button) -> void:
    assert(not button.disabled and button.is_visible_in_tree())
    var position := button.get_global_rect().get_center()
    var motion := InputEventMouseMotion.new()
    motion.position = position
    get_viewport().push_input(motion, true)
    await get_tree().process_frame
    var click := InputEventMouseButton.new()
    click.position = position
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    get_viewport().push_input(click, true)
    await get_tree().process_frame
    click = click.duplicate()
    click.pressed = false
    get_viewport().push_input(click, true)
    for frame in 3:
        await get_tree().process_frame
