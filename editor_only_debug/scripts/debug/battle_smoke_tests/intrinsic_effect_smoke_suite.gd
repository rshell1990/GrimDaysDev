extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

## Script loaded for template validator; reused instead of looking up the file on each call.
const TEMPLATE_VALIDATOR := preload(
    "res://GrimDaysBattle/scripts/Unit/Resources/battle_unit_template_validator.gd"
)
## Resource loaded for resource effect scene; reused instead of looking up the file on each call.
const RESOURCE_EFFECT_SCENE := preload(
    "res://GrimDaysBattle/scenes/battle/effects/effect_change_resource.tscn"
)


## Runs the intrinsic effect smoke checks. Creates or uses test objects and stops on failed
## assertions.
func run() -> void:
    var template: BattleUnitTemplate = CELINE_TEMPLATE.duplicate()
    template.id = &"IntrinsicEffectTestUnit"
    template.intrinsic_effects = [
        _make_lucidity_drain(&"lucidity_drain_when_hit", CombatEffects.TRIGGER.DAMAGED, -5.0),
        _make_lucidity_drain(&"lucidity_drain_each_turn", CombatEffects.TRIGGER.PROCESS_OVER, -3.0),
    ]
    var validation_errors := TEMPLATE_VALIDATOR.validate(template)
    assert(validation_errors.is_empty(), "Intrinsic effects must pass template validation: %s" % validation_errors)

    var unit := BattleUnit.create(template)
    assert(unit, "A unit with valid intrinsic effects must construct.")
    create_flat_stat(unit, CombatStats.STATS.Lucidity, 100.0)
    add_child(unit)
    var lucidity: UnitGenericStat = unit.get_stat(CombatStats.STATS.Lucidity)
    assert(lucidity, "The intrinsic resource test requires Celine's Lucidity pool.")
    var starting_lucidity := lucidity.Current
    var source_id := StringName("intrinsic:%s" % template.id)
    assert(unit.effect_manager.get_effects_from_source(source_id).size() == 2)

    await unit.resolve_effects(CombatEffects.TRIGGER.DAMAGED, &"intrinsic:first_hit")
    assert(is_equal_approx(lucidity.Current, starting_lucidity - 5.0))
    await unit.resolve_effects(CombatEffects.TRIGGER.DAMAGED, &"intrinsic:second_hit")
    assert(
        is_equal_approx(lucidity.Current, starting_lucidity - 10.0),
        "A repeating intrinsic reaction must run for every distinct hit.",
    )
    await unit.resolve_effects(CombatEffects.TRIGGER.PROCESS_OVER, &"intrinsic:first_turn")
    assert(is_equal_approx(lucidity.Current, starting_lucidity - 13.0))
    await unit.resolve_effects(CombatEffects.TRIGGER.PROCESS_OVER, &"intrinsic:second_turn")
    assert(
        is_equal_approx(lucidity.Current, starting_lucidity - 16.0),
        "A repeating intrinsic turn effect must run for every completed turn.",
    )

    unit.template_resource = CELINE_TEMPLATE
    await get_tree().process_frame
    assert(
        unit.effect_manager.get_effects_from_source(source_id).is_empty(),
        "Replacing a unit template must remove the old template's intrinsic effects.",
    )
    await free_node(unit)


## Sets [code]effect.id[/code] to [code]id[/code]; sets [code]effect.stat[/code] to
## [code]CombatStats.STATS.Lucidity[/code]; sets [code]effect.amount[/code] to [code]amount[/code].
## Returns [code]effect[/code].
func _make_lucidity_drain(
    id: StringName,
    trigger: CombatEffects.TRIGGER,
    amount: float,
) -> EffectResourceChangeTemplate:
    var effect := EffectResourceChangeTemplate.new()
    effect.id = id
    effect.stat = CombatStats.STATS.Lucidity
    effect.amount = amount
    effect.amount_mode = EffectResourceChangeTemplate.AMOUNT_MODE.FLAT
    effect.target = CombatActions.TARGET.SELF
    effect.kind = CombatEffects.KIND.REPEAT
    effect.trigger = trigger
    effect.lifetime = EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE
    effect.template_scene = RESOURCE_EFFECT_SCENE
    return effect
