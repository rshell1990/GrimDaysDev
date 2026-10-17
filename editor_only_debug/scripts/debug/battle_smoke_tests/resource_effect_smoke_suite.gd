extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for resource effect script; reused instead of looking up the file on each call.
const RESOURCE_EFFECT_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Runtime/effect_change_resource.gd"
)
## Script loaded for resource template script; reused instead of looking up the file on each call.
const RESOURCE_TEMPLATE_SCRIPT := preload(
    "res://GrimDaysBattle/scripts/Effects/Resources/effect_change_resource.gd"
)


## Runs the resource effect smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var attacker := create_unit()
    attacker.randomizer.set_seed(4321)
    var expected_rng := RandomNumberGenerator.new()
    expected_rng.seed = 4321
    var expected_damage := roundf(30.0 * expected_rng.randf_range(0.85, 1.15))
    var target := create_unit()
    var health := create_flat_stat(target, CombatStats.STATS.Health, 100.0)
    var energy := create_flat_stat(target, CombatStats.STATS.Energy, 40.0)
    create_flat_stat(target, CombatStats.STATS.PhysicalResistance, 25.0)

    var effect = _apply_resource_effect(
        attacker,
        target,
        _make_template(
            &"flat_resource_damage",
            CombatStats.STATS.Health,
            -40.0,
            RESOURCE_TEMPLATE_SCRIPT.AMOUNT_MODE.FLAT,
            CombatDamage.TYPE.Physical,
        )
    )
    assert(is_equal_approx(effect.raw_change, -40.0))
    assert(is_equal_approx(effect.resolved_change, expected_damage))
    assert(is_equal_approx(health.Current, 100.0 - expected_damage))
    assert(target.last_hit_by == attacker)
    await _remove_effect(effect)
    health.restore_current(70.0)

    effect = _apply_resource_effect(
        attacker,
        target,
        _make_template(
            &"current_percent_damage",
            CombatStats.STATS.Health,
            -0.5,
            RESOURCE_TEMPLATE_SCRIPT.AMOUNT_MODE.PERCENT_CURRENT,
            CombatDamage.TYPE.True,
        )
    )
    assert(is_equal_approx(effect.raw_change, -35.0))
    assert(is_equal_approx(health.Current, 35.0))
    await _remove_effect(effect)

    effect = _apply_resource_effect(
        attacker,
        target,
        _make_template(
            &"maximum_percent_heal",
            CombatStats.STATS.Health,
            0.25,
            RESOURCE_TEMPLATE_SCRIPT.AMOUNT_MODE.PERCENT_MAX,
            CombatDamage.TYPE.None,
        )
    )
    assert(is_equal_approx(effect.resolved_change, 25.0))
    assert(is_equal_approx(health.Current, 60.0))
    await _remove_effect(effect)

    effect = _apply_resource_effect(
        attacker,
        target,
        _make_template(
            &"energy_cost",
            CombatStats.STATS.Energy,
            -0.25,
            RESOURCE_TEMPLATE_SCRIPT.AMOUNT_MODE.PERCENT_MAX,
            CombatDamage.TYPE.None,
        )
    )
    assert(is_equal_approx(effect.resolved_change, 10.0))
    assert(is_equal_approx(energy.Current, 30.0), "Non-health resource costs must not require damage typing.")
    await _remove_effect(effect)
    await free_node(target)
    await free_node(attacker)


## Sets [code]template.id[/code] to [code]id[/code]; sets [code]template.stat[/code] to
## [code]stat[/code]; sets [code]template.amount[/code] to [code]amount[/code]. Returns
## [code]template[/code].
func _make_template(
    id: StringName,
    stat: CombatStats.STATS,
    amount: float,
    mode: int,
    damage_type: CombatDamage.TYPE,
):
    var template = RESOURCE_TEMPLATE_SCRIPT.new()
    template.id = id
    template.stat = stat
    template.amount = amount
    template.amount_mode = mode
    template.damage_type = damage_type
    return template


## Adds [code]effect[/code] as a child node; sets [code]effect.name[/code] to
## [code]template.id[/code]. Returns [code]effect[/code].
func _apply_resource_effect(
    sender: BattleUnit,
    target: BattleUnit,
    template,
):
    var effect = RESOURCE_EFFECT_SCRIPT.new()
    effect.name = template.id
    effect.setup(sender, target, template)
    add_child(effect)
    effect.apply()
    assert(effect.finished)
    return effect


## Removes the effect and waits until its node leaves the scene tree.
func _remove_effect(effect: EffectBase) -> void:
    effect.remove()
    await effect.tree_exited
