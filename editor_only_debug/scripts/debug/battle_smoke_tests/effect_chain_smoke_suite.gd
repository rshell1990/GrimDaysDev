extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Resource loaded for chain effect script; reused instead of looking up the file on each call.
const CHAIN_EFFECT_SCRIPT := preload("uid://maqemp7xiac3")
## Resource loaded for chain effect scene; reused instead of looking up the file on each call.
const CHAIN_EFFECT_SCENE := preload("res://GrimDaysBattle/scenes/battle/effects/effect_trigger_chain.tscn")
## Resource loaded for resource effect scene; reused instead of looking up the file on each call.
const RESOURCE_EFFECT_SCENE := preload(
    "res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn"
)
## Resource loaded for resource template script; reused instead of looking up the file on each call.
const RESOURCE_TEMPLATE_SCRIPT := preload("uid://dmeovq5uuuuy5")


## Runs the effect chain smoke checks. Creates or uses test objects and stops on failed assertions.
func run() -> void:
    var attacker := create_unit()
    var target := create_unit()
    attacker.randomizer.set_seed(314159)
    create_flat_stat(attacker, CombatStats.STATS.Health, 100.0)
    var health := create_flat_stat(target, CombatStats.STATS.Health, 100.0)

    var damage = RESOURCE_TEMPLATE_SCRIPT.new()
    damage.id = &"chained_true_damage"
    damage.stat = CombatStats.STATS.Health
    damage.amount = -10.0
    damage.damage_type = CombatDamage.TYPE.True
    damage.target = CombatActions.TARGET.FOE
    damage.trigger = CombatEffects.TRIGGER.TARGETED
    damage.kind = CombatEffects.KIND.ONCE
    damage.duration = 1
    damage.template_scene = RESOURCE_EFFECT_SCENE
    var chain := EffectTriggerAnotherEffect.new()
    chain.id = &"damage_chain"
    chain.triggers = [damage]
    var runtime = CHAIN_EFFECT_SCRIPT.new()
    runtime.name = &"damage_chain_runtime"
    runtime.setup(attacker, target, chain)
    add_child(runtime)
    runtime.apply()
    assert(runtime.finished)
    assert(is_equal_approx(health.Current, 90.0), "A chain must resolve its nested effect immediately.")
    await get_tree().process_frame
    runtime.remove()
    await runtime.tree_exited

    var skipped_chain := EffectTriggerAnotherEffect.new()
    skipped_chain.id = &"skipped_chain"
    skipped_chain.chance = 0
    skipped_chain.triggers = [damage]
    var skipped_runtime = CHAIN_EFFECT_SCRIPT.new()
    skipped_runtime.name = &"skipped_chain_runtime"
    skipped_runtime.setup(attacker, target, skipped_chain)
    add_child(skipped_runtime)
    skipped_runtime.apply()
    assert(skipped_runtime.finished)
    assert(is_equal_approx(health.Current, 90.0), "A failed chain chance must not resolve nested effects.")
    skipped_runtime.remove()
    await skipped_runtime.tree_exited

    var cycle := EffectTriggerAnotherEffect.new()
    cycle.id = &"cycle"
    cycle.target = CombatActions.TARGET.FOE
    cycle.trigger = CombatEffects.TRIGGER.TARGETED
    cycle.kind = CombatEffects.KIND.ONCE
    cycle.duration = 1
    cycle.template_scene = CHAIN_EFFECT_SCENE
    cycle.triggers = [cycle]
    var cyclic_runtime = CHAIN_EFFECT_SCRIPT.new()
    cyclic_runtime.name = &"cyclic_chain_runtime"
    cyclic_runtime.setup(attacker, target, cycle)
    add_child(cyclic_runtime)
    cyclic_runtime.apply()
    assert(cyclic_runtime.finished, "Cyclic chains must terminate instead of recursing.")
    assert(is_equal_approx(health.Current, 90.0))
    cyclic_runtime.remove()
    await cyclic_runtime.tree_exited
    await free_node(target)
    await free_node(attacker)
