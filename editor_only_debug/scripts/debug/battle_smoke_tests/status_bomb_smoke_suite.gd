## Executes every authored status bomb through inventory-backed production action resolution.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

const BOMBS: Array[ConsumableTemplate] = [
    preload("res://GrimDaysBattle/resources/items/catalog/fire_bomb.tres"),
    preload("res://GrimDaysBattle/resources/items/catalog/fire_bomb_area.tres"),
    preload("res://GrimDaysBattle/resources/items/catalog/ice_bomb.tres"),
    preload("res://GrimDaysBattle/resources/items/catalog/ice_bomb_area.tres"),
    preload("res://GrimDaysBattle/resources/items/catalog/lightning_bomb.tres"),
    preload("res://GrimDaysBattle/resources/items/catalog/lightning_bomb_area.tres"),
    preload("res://GrimDaysBattle/resources/items/catalog/poison_bomb.tres"),
    preload("res://GrimDaysBattle/resources/items/catalog/poison_bomb_area.tres"),
]
const VN_ITEMS = preload("res://GrimDaysVN/resources/items/imported/all_items.tres")

var completed_bombs: int = 0


class IsolatedParty:
    extends BattlePartyManager

    func _ready() -> void:
        pass


func run() -> void:
    for bomb in BOMBS:
        await _check_bomb(bomb)


func _check_bomb(bomb: ConsumableTemplate) -> void:
    var area := String(bomb.id).ends_with("_area")
    var definition: ActionTemplate = bomb.battle_actions[0]
    var damage := definition.get_rank_template(1).effects.all[0] as EffectResourceChangeTemplate
    var status: EffectTemplate = damage.effects_on_hit[0]
    assert(definition.target == (CombatActions.TARGET.FOES if area else CombatActions.TARGET.FOE))
    assert(damage.target == CombatActions.TARGET.DEFAULT and status.target == CombatActions.TARGET.DEFAULT)
    assert(damage.amount == (-12 if area else -18) and damage.always_hits)
    assert(status.lifetime == EffectTemplate.LIFETIME.ROUNDS and status.stacking_across_sources)
    assert(status.stacking == EffectTemplate.STACKING.REFRESH)
    assert(_check_vn_metadata(bomb, definition, damage, status))
    var party := IsolatedParty.new()
    add_child(party)
    var actor := BattleUnit.create(CELINE_TEMPLATE)
    party.add_child(actor)
    party.runtime_units[CELINE_TEMPLATE.id] = actor
    party.active_party_ids.assign([CELINE_TEMPLATE.id])
    var roster := BattleEncounterRoster.new()
    add_child(roster)
    assert(roster.deploy(party, [CELINE_TEMPLATE, CELINE_TEMPLATE]))
    var resolver := BattleActionResolver.new()
    add_child(resolver)
    var foes := roster.get_foes()
    for unit in roster.get_participants():
        _override(unit, CombatStats.STATS.Health, 500)
        _override(unit, CombatStats.STATS.PhysicalResistance, 0)
        _override(unit, CombatStats.STATS.MagicResistance, 0)
        unit.get_stat(CombatStats.STATS.Health).restore_current(500)
    assert(actor.inventory.add_item(ItemBase.create(bomb, 3)))
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture(roster.get_participants())
    var choice: BattleItemAction = BattleItemAction.available(actor)[0]
    var automatic: Array = CombatActions.set_targets(choice, actor).targets
    assert(automatic == foes if area else automatic.is_empty())
    var rejected: BattleActionResolution = await resolver.resolve(
        BattleActionRequest.new(&"bomb_invalid_target", actor, choice, [actor])
    )
    assert(not rejected.success and choice.remaining_count() == 3)
    var targets: Array[BattleUnit] = []
    targets.assign(foes if area else [foes[0]])
    var energy := actor.get_stat(CombatStats.STATS.Energy).Current
    var result: BattleActionResolution = await resolver.resolve(
        BattleActionRequest.new(&"bomb_first", actor, choice, targets)
    )
    assert(result.success and choice.remaining_count() == 2)
    assert(result.get_events(BattleCombatEvent.TYPE.ITEM_USED).size() == 1)
    assert(result.get_events(BattleCombatEvent.TYPE.DAMAGE).size() == targets.size())
    assert(actor.get_stat(CombatStats.STATS.Energy).Current == energy)
    assert(actor.get_stat(CombatStats.STATS.Health).Current == 500)
    assert(_statuses(actor, status.id).is_empty())
    for foe in foes:
        if foe not in targets:
            assert(foe.get_stat(CombatStats.STATS.Health).Current == 500)
            assert(_statuses(foe, status.id).is_empty())
            continue
        var loss: float = 500 - foe.get_stat(CombatStats.STATS.Health).Current
        var minimum := 0.7 if damage.damage_type == CombatDamage.TYPE.Magic else 0.85
        var maximum := 1.3 if damage.damage_type == CombatDamage.TYPE.Magic else 1.15
        assert(loss >= roundf(absf(damage.amount) * minimum) and loss <= roundf(absf(damage.amount) * maximum))
        assert(foe.last_hit_by == actor)
        assert(_statuses(foe, status.id).size() == 1)
        assert(foe.is_stunned() == (status is EffectStunTemplate))
        if status is EffectStunTemplate:
            assert(not foe.can_use_action(foe.get_basic_action()))
    var replay: BattleActionResolution = await resolver.resolve(
        BattleActionRequest.new(&"bomb_replay", actor, choice, targets)
    )
    assert(not replay.success and choice.remaining_count() == 2)
    # Retry restores both inventory and effects without retaining invalid item choices.
    assert(checkpoint.restore())
    assert(not choice.can_use(actor))
    for foe in foes:
        assert(_statuses(foe, status.id).is_empty() and not foe.is_stunned())
        assert(foe.get_stat(CombatStats.STATS.Health).Current == 500)
    choice = BattleItemAction.available(actor)[0]
    assert(choice.remaining_count() == 3)
    result = await resolver.resolve(BattleActionRequest.new(&"bomb_after_retry", actor, choice, targets))
    assert(result.success)
    await get_tree().process_frame
    if status.duration > 1:
        await foes[0].effect_manager.trigger_effects(CombatEffects.TRIGGER.ROUND_OVER)
        foes[0].effect_manager.advance_round()
        assert(_statuses(foes[0], status.id)[0].duration == status.duration - 1)
    var original: EffectBase = _statuses(foes[0], status.id)[0]
    var refreshed := foes[0].add_effect(
        foes[1], foes[0], status, {"source_id": &"test:other_bomb_caster", "defer_application": true}
    )
    assert(refreshed == original and refreshed.duration == status.duration)
    # Reapplication refreshes one shared status, including across single/burst item sources.
    var sibling: ConsumableTemplate = BOMBS[BOMBS.find(bomb) ^ 1]
    assert(actor.inventory.add_item(ItemBase.create(sibling)))
    var sibling_choice: BattleItemAction
    for available: BattleItemAction in BattleItemAction.available(actor):
        if available.item == sibling:
            sibling_choice = available
    var sibling_targets: Array[BattleUnit] = []
    sibling_targets.assign(foes if not area else [foes[0]])
    result = await resolver.resolve(
        BattleActionRequest.new(&"bomb_shared_status", actor, sibling_choice, sibling_targets)
    )
    assert(result.success)
    for foe in foes:
        assert(_statuses(foe, status.id).size() == 1)
        assert(_statuses(foe, status.id)[0].duration == status.duration)
    if status.damage_type == CombatDamage.TYPE.True:
        for foe in foes:
            _override(foe, CombatStats.STATS.PhysicalResistance, 100)
            _override(foe, CombatStats.STATS.MagicResistance, 100)
    assert(await _check_rounds(foes, status))
    for foe in foes:
        _override(foe, CombatStats.STATS.PhysicalResistance, 0)
        _override(foe, CombatStats.STATS.MagicResistance, 0)
    # A fresh application is removed by encounter cleanup before its next tick.
    choice = BattleItemAction.available(actor)[0]
    result = await resolver.resolve(BattleActionRequest.new(&"bomb_cleanup", actor, choice, targets))
    assert(result.success)
    for foe in foes:
        foe.effect_manager.remove_battle_scoped_effects()
        var before := foe.get_stat(CombatStats.STATS.Health).Current
        await foe.effect_manager.trigger_effects(CombatEffects.TRIGGER.ROUND_OVER)
        assert(foe.get_stat(CombatStats.STATS.Health).Current == before and not foe.is_stunned())
        assert(_statuses(foe, status.id).is_empty())
    choice = BattleItemAction.available(actor)[0]
    for foe in targets:
        foe.get_stat(CombatStats.STATS.Health).restore_current(1)
    result = await resolver.resolve(BattleActionRequest.new(&"bomb_lethal", actor, choice, targets))
    assert(result.success and choice.remaining_count() == 0)
    for foe in targets:
        assert(not foe.is_active and _statuses(foe, status.id).is_empty(), "No retained status on lethal hits.")
    roster.release()
    await free_node(resolver)
    await free_node(roster)
    await free_node(party)
    completed_bombs += 1


func _check_rounds(foes: Array[BattleUnit], status: EffectTemplate) -> bool:
    for round_index in status.duration:
        for foe in foes:
            var before := foe.get_stat(CombatStats.STATS.Health).Current
            await foe.effect_manager.trigger_effects(CombatEffects.TRIGGER.ROUND_OVER)
            var after := foe.get_stat(CombatStats.STATS.Health).Current
            if status is EffectResourceChangeTemplate:
                var amount := absf((status as EffectResourceChangeTemplate).amount)
                var true_damage := status.damage_type == CombatDamage.TYPE.True
                assert(before - after >= roundf(amount * (1.0 if true_damage else 0.7)))
                assert(before - after <= roundf(amount * (1.0 if true_damage else 1.3)))
            else:
                assert(after == before and foe.is_stunned())
            await foe.effect_manager.trigger_effects(CombatEffects.TRIGGER.ROUND_OVER)
            assert(foe.get_stat(CombatStats.STATS.Health).Current == after, "One DOT tick per round.")
            foe.effect_manager.advance_round()
            var remaining := status.duration - round_index - 1
            assert(_statuses(foe, status.id).size() == (1 if remaining > 0 else 0))
    for foe in foes:
        var before := foe.get_stat(CombatStats.STATS.Health).Current
        await foe.effect_manager.trigger_effects(CombatEffects.TRIGGER.ROUND_OVER)
        assert(foe.get_stat(CombatStats.STATS.Health).Current == before and not foe.is_stunned())
        assert(foe.can_use_action(foe.get_basic_action()))
    return true


func _check_vn_metadata(
    bomb: ConsumableTemplate, action: ActionTemplate, damage: EffectResourceChangeTemplate, status: EffectTemplate
) -> bool:
    var item: VNItemTemplate = VN_ITEMS.get_item(bomb.id)
    assert(item != null and item.description == bomb.description)
    assert(item.use_effects.size() == 2)
    assert(item.use_effects[0].target == action.target and item.use_effects[0].amount == absf(damage.amount))
    assert(item.use_effects[0].damage_type == damage.damage_type)
    assert(item.use_effects[1].id == String(status.id) and item.use_effects[1].duration == status.duration)
    assert(item.use_effects[1].target == action.target)
    if status is EffectResourceChangeTemplate:
        assert(item.use_effects[1].amount == absf((status as EffectResourceChangeTemplate).amount))
        assert(item.use_effects[1].damage_type == status.damage_type)
    return true


func _statuses(unit: BattleUnit, id: StringName) -> Array[EffectBase]:
    var found: Array[EffectBase] = []
    for holder: EffectDirectors in unit.effect_manager.triggers_to_holders.values():
        for effect in holder.get_children():
            if effect is EffectBase and effect.id == id and not effect.removed and not effect.is_queued_for_deletion():
                found.append(effect)
    return found


func _override(unit: BattleUnit, stat: CombatStats.STATS, amount: float) -> void:
    unit.get_stat(stat).add_modifier(
        UnitStatModifier.create(
            StringName("bomb_test:%s" % stat), &"test:status_bombs", stat, UnitStatModifier.OPERATION.OVERRIDE, amount
        )
    )
