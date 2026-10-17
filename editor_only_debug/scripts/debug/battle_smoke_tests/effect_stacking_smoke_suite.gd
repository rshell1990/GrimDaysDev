# Checks duplicate policies, source isolation, expiry aftermaths and legacy resource loading.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

const EFFECT_SCRIPT_PATH = "res://GrimDaysBattle/scripts/Effects/Resources/_effect_template.gd"


func run() -> void:
    var unit := BattleUnit.create(CELINE_TEMPLATE)
    add_child(unit)
    for mode in EffectTemplate.STACKING.values():
        var definition := EffectFixStatTemplate.new()
        definition.id = &"stacking_probe"
        definition.stat = CombatStats.STATS.Lucidity
        definition.value = 7
        definition.duration = 3
        definition.lifetime = EffectTemplate.LIFETIME.ROUNDS
        definition.stacking = mode
        var context := {"source_id": &"stacking_source"}
        var first := unit.add_effect(unit, unit, definition, context)
        unit.effect_manager.advance_round()
        assert(first.duration == 2)
        var incoming := definition.duplicate() as EffectFixStatTemplate
        incoming.duration = 9
        incoming.value = 99
        # Existing policy governs even when the incoming definition asks for a different one.
        incoming.stacking = EffectTemplate.STACKING.MULTIPLE
        var second := unit.add_effect(unit, unit, incoming, context)
        match mode:
            EffectTemplate.STACKING.DISCARD:
                assert(second == null and first.duration == 2)
                assert(unit.get_stat(CombatStats.STATS.Lucidity).Current == 7)
            EffectTemplate.STACKING.REFRESH:
                assert(second == first and first.duration == 3 and first.max_duration == 3)
                assert(unit.get_stat(CombatStats.STATS.Lucidity).Current == 7)
            EffectTemplate.STACKING.COMBINE:
                assert(second == first and first.duration == 5 and first.max_duration == 3)
                assert(unit.get_stat(CombatStats.STATS.Lucidity).Current == 7)
                unit.add_effect(unit, unit, incoming, context)
                assert(first.duration == 8)
            EffectTemplate.STACKING.MULTIPLE:
                assert(second != first and first.duration == 2 and second.duration == 9)
                assert(unit.get_stat(CombatStats.STATS.Lucidity).Current == 99)
        var other_source := unit.add_effect(unit, unit, definition, {"source_id": &"other_source"})
        assert(other_source != null and other_source != first)
        var other_trigger := definition.duplicate() as EffectFixStatTemplate
        other_trigger.trigger = CombatEffects.TRIGGER.PROCESS_OVER
        assert(unit.add_effect(unit, unit, other_trigger, context) != first)
        unit.effect_manager.remove_battle_scoped_effects()
        # Queued/removed instances must not block replacement grants.
        var replacement := unit.add_effect(unit, unit, definition, context)
        assert(replacement != null and replacement != first)
        unit.effect_manager.remove_battle_scoped_effects()
        await get_tree().process_frame
    await _test_combined_expiry(unit)
    unit.queue_free()
    await unit.tree_exited
    _test_legacy_loading()
    print("EFFECT_STACKING_SMOKE_SUITE: PASS") # lint:ignore debug-print -- Required test/CLI output.


func _test_combined_expiry(unit: BattleUnit) -> void:
    var parent := EffectFixStatTemplate.new()
    parent.id = &"combined_parent"
    parent.stat = CombatStats.STATS.Lucidity
    parent.value = 5
    parent.duration = 2
    parent.lifetime = EffectTemplate.LIFETIME.ROUNDS
    parent.stacking = EffectTemplate.STACKING.COMBINE
    var child := EffectFixStatTemplate.new()
    child.id = &"combined_aftermath"
    child.stat = CombatStats.STATS.Lucidity
    child.value = 8
    child.lifetime = EffectTemplate.LIFETIME.ROUNDS
    child.duration = 2
    parent.effects_on_expiry = [child]
    var first := unit.add_effect(unit, unit, parent)
    var source_id := first.source_id
    unit.effect_manager.advance_round()
    unit.add_effect(unit, unit, parent)
    assert(first.duration == 3)
    var checkpoint := BattleRetryCheckpoint.new()
    checkpoint.capture([unit])
    for index in 2:
        unit.effect_manager.advance_round()
        assert(unit.get_stat(CombatStats.STATS.Lucidity).Current == 5)
    unit.effect_manager.advance_round()
    assert(unit.get_stat(CombatStats.STATS.Lucidity).Current == 8)
    assert(checkpoint.restore())
    var restored := unit.effect_manager.get_effects_from_source(source_id)
    assert(restored.size() == 1 and restored[0].duration == 3)
    assert(restored[0].stacking == EffectTemplate.STACKING.COMBINE)
    unit.effect_manager.remove_battle_scoped_effects()
    await get_tree().process_frame


func _test_legacy_loading() -> void:
    var path := "user://effect_stacking_legacy_probe.tres"
    for old_value in [false, true]:
        var file := FileAccess.open(path, FileAccess.WRITE)
        file.store_string(
            (
                '[gd_resource type="Resource" load_steps=2 format=3]\n'
                + '[ext_resource type="Script" path="%s" id="1"]\n' % EFFECT_SCRIPT_PATH
                + '[resource]\nscript = ExtResource("1")\nstacks = %s\n' % str(old_value)
            )
        )
        file.close()
        var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EffectTemplate
        assert(loaded != null)
        assert(loaded.stacking == (EffectTemplate.STACKING.MULTIPLE if old_value else EffectTemplate.STACKING.REFRESH))
    DirAccess.remove_absolute(path)
