# Covers owner-only expiry grants, lifetime boundaries, cleanup, and retry.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

const RESOURCE_SCENE = preload("res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn")
const PROGRESSION = preload("res://GrimDaysBattle/scripts/Actions/Resources/action_rank_progression.gd")
const CHAIN_SCENE = preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")


func run() -> void:
    var caster := BattleUnit.create(CELINE_TEMPLATE)
    var holder := BattleUnit.create(CELINE_TEMPLATE)
    add_child(caster)
    add_child(holder)
    var lucidity := holder.get_stat(CombatStats.STATS.Lucidity)
    lucidity.set_base(100)
    lucidity.restore_current(100)
    var original := lucidity.Current
    var lock := EffectFixStatTemplate.new()
    lock.id = &"expiry_lucidity_lock"
    lock.stat = CombatStats.STATS.Lucidity
    lock.value = 7
    lock.lifetime = EffectTemplate.LIFETIME.ROUNDS
    lock.duration = 2
    lock.target = CombatActions.TARGET.FOES
    var drain := EffectResourceChangeTemplate.new()
    drain.id = &"expiry_drain"
    drain.template_scene = RESOURCE_SCENE
    drain.stat = CombatStats.STATS.Lucidity
    drain.amount = -10
    drain.trigger = CombatEffects.TRIGGER.ROUND_OVER
    drain.kind = CombatEffects.KIND.REPEAT
    drain.lifetime = EffectTemplate.LIFETIME.ROUNDS
    drain.duration = 1
    drain.effects_on_expiry = [lock]
    var effect := holder.add_effect(caster, holder, drain)
    await holder.effect_manager.trigger_effects(CombatEffects.TRIGGER.ROUND_OVER)
    assert(lucidity.Current == original - 10)
    holder.effect_manager.advance_round()
    assert(effect.removed and lucidity.Current == 7)
    assert(caster.get_stat(CombatStats.STATS.Lucidity).Current != 7)
    var children := holder.effect_manager.get_effects_from_source(&"expiry:%s:%s" % [effect.source_id, effect.id])
    assert(children.size() == 1 and children[0].duration == 2)
    effect.on_round_end()
    assert(children[0].duration == 2, "Expired parents cannot grant twice.")
    lucidity.decrease_current_flat(100)
    assert(lucidity.Current == 7)
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([holder])
    holder.effect_manager.advance_round()
    assert(lucidity.Current == 7 and children[0].duration == 1)
    holder.effect_manager.advance_round()
    assert(lucidity.Current == original - 10)
    await get_tree().process_frame
    assert(checkpoint.restore())
    assert(lucidity.Current == 7)
    holder.effect_manager.remove_battle_scoped_effects()
    assert(lucidity.Current == original - 10)
    var removed := holder.add_effect(caster, holder, drain)
    removed.remove()
    removed.on_round_end()
    assert(lucidity.Current != 7, "Dispel/removal cannot grant expiry effects.")
    holder.effect_manager.remove_battle_scoped_effects()
    await get_tree().process_frame
    # A nested SELF operation would ordinarily target the caster, but expiry confines it to the holder.
    var nested := EffectTriggerAnotherEffect.new()
    nested.id = &"expiry_nested"
    nested.template_scene = CHAIN_SCENE
    nested.triggers = [lock]
    lock.target = CombatActions.TARGET.SELF
    drain.effects_on_expiry = [nested]
    effect = holder.add_effect(caster, holder, drain)
    holder.effect_manager.advance_round()
    assert(lucidity.Current == 7 and caster.get_stat(CombatStats.STATS.Lucidity).Current != 7)
    holder.effect_manager.remove_battle_scoped_effects()
    await get_tree().process_frame
    # A later holder bucket must not consume the new child's first round at birth.
    lock.trigger = CombatEffects.TRIGGER.PROCESS_OVER
    drain.trigger = CombatEffects.TRIGGER.EQUIP
    drain.effects_on_expiry = [lock]
    effect = holder.add_effect(caster, holder, drain)
    holder.effect_manager.advance_round()
    children = holder.effect_manager.get_effects_from_source(&"expiry:%s:%s" % [effect.source_id, effect.id])
    assert(children.size() == 1 and children[0].duration == 2)
    assert(lucidity.Current != 7, "Event-driven child waits for its authored trigger.")
    await holder.effect_manager.trigger_effects(CombatEffects.TRIGGER.PROCESS_OVER)
    assert(lucidity.Current == 7)
    holder.effect_manager.remove_battle_scoped_effects()
    await get_tree().process_frame
    lock.trigger = CombatEffects.TRIGGER.EQUIP
    effect = holder.add_effect(caster, holder, drain)
    SignalBus.tick.emit(&"legacy_round_boundary")
    children = holder.effect_manager.get_effects_from_source(&"expiry:%s:%s" % [effect.source_id, effect.id])
    assert(children.size() == 1 and children[0].duration == 2)
    holder.queue_free()
    caster.queue_free()
    await get_tree().process_frame
    _test_rank_progression()
    print("EFFECT_EXPIRY_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _test_rank_progression() -> void:
    var parent := EffectResourceChangeTemplate.new()
    parent.id = &"ranked_drain"
    parent.template_scene = RESOURCE_SCENE
    parent.trigger = CombatEffects.TRIGGER.ROUND_OVER
    parent.lifetime = EffectTemplate.LIFETIME.ROUNDS
    parent.duration = 1
    var lock := EffectFixStatTemplate.new()
    lock.id = &"ranked_expiry_lock"
    lock.lifetime = EffectTemplate.LIFETIME.ROUNDS
    lock.duration = 1
    lock.available_from_rank = 2
    lock.duration_by_rank = PackedInt32Array([1, 3])
    parent.effects_on_expiry = [lock]
    var rank := RankTemplate.new()
    rank.effects = EffectTemplates.new()
    rank.effects.all = [parent]
    assert(PROGRESSION.validate(rank, {}, 2).is_empty())
    assert(PROGRESSION.resolve(rank, {}, 1).effects.all[0].effects_on_expiry.is_empty())
    var resolved: EffectTemplate = PROGRESSION.resolve(rank, {}, 2).effects.all[0].effects_on_expiry[0]
    assert(resolved.duration == 3 and lock.duration == 1)
    lock.effects_on_expiry = [parent]
    assert(not PROGRESSION.validate(rank, {}, 2).is_empty())
    lock.effects_on_expiry.clear()
