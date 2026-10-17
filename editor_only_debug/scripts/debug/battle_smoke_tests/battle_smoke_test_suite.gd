extends Node

## Resource loaded for stat effect scene; reused instead of looking up the file on each call.
const STAT_EFFECT_SCENE := preload("res://GrimDaysBattle/scenes/battle/effects/effect_stat_change.tscn")
## Resource loaded for scaled stat effect scene; reused instead of looking up the file on each call.
const SCALED_STAT_EFFECT_SCENE := preload(
    "res://GrimDaysBattle/scenes/battle/effects/effect_scaled_stat_change.tscn"
)
## Resource loaded for unit scene; reused instead of looking up the file on each call.
const UNIT_SCENE := preload("res://GrimDaysBattle/scenes/battle/unit.tscn")
## Resource loaded for basic attack; reused instead of looking up the file on each call.
const BASIC_ATTACK: ActionTemplate = preload(
    "res://GrimDaysBattle/resources/actions/_basic/_basic_attack/basic_attack.tres"
)
## Resource loaded for celine template; reused instead of looking up the file on each call.
const CELINE_TEMPLATE: BattleUnitTemplate = preload(
    "res://GrimDaysBattle/resources/units/celine_teen/celine_battle_unit_template.tres"
)


## Adds [code]unit[/code] as a child node; sets [code]unit.template_resource[/code] to
## [code]template[/code]. Returns [code]unit[/code].
func create_unit(template: BattleUnitTemplate = null) -> BattleUnit:
    var unit: BattleUnit = UNIT_SCENE.instantiate()
    add_child(unit)
    if template:
        unit.template_resource = template
    return unit


## Sets [code]template.type[/code] to [code]type[/code]; updates [code]template.id[/code] using
## [code]CombatStats.get_stat_as_string[/code]; sets [code]template.starting_amount[/code] to
## [code]amount[/code]. Returns [code]stat[/code].
func create_flat_stat(unit: BattleUnit, type: CombatStats.STATS, amount: float) -> UnitGenericStat:
    var template := UnitStatTemplate.new()
    template.type = type
    template.id = CombatStats.get_stat_as_string(type)
    template.starting_amount = amount
    var stat := UnitGenericStat.new()
    stat.setup(template, unit)
    unit.stat_dictionary[template.id] = stat
    return stat


## Sets [code]curve.min_domain[/code] to [code]0.0[/code]; sets [code]curve.max_domain[/code] to
## [code]30.0[/code]; sets [code]curve.min_value[/code] to [code]0.0[/code]. Returns
## [code]stat[/code].
func create_calculated_stat(unit: BattleUnit, starting_amount: float = 0.0) -> UnitGenericCalculatedStat:
    var curve := Curve.new()
    curve.min_domain = 0.0
    curve.max_domain = 30.0
    curve.min_value = 0.0
    curve.max_value = 300.0
    # Ten Health per Strength point keeps general pool fixtures proportional.
    # Nonconstant gains are covered explicitly in stat_model_smoke_suite.
    curve.add_point(Vector2(0.0, 10.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
    curve.add_point(Vector2(30.0, 10.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
    var template := UnitCalculatedStatTemplate.new()
    template.type = CombatStats.STATS.Health
    template.starting_amount = starting_amount
    template.id = &"Health"
    template.influenced_by = CombatStats.STATS.Strength
    template.growth_curve = curve
    var stat := UnitGenericCalculatedStat.new()
    stat.setup(template, unit)
    unit.stat_dictionary[template.id] = stat
    return stat


## Sets [code]threshold_curve.min_domain[/code] to [code]0.0[/code]; sets
## [code]threshold_curve.max_domain[/code] to [code]10.0[/code]; sets
## [code]threshold_curve.min_value[/code] to [code]0.0[/code]. Returns [code]stat[/code].
func create_scaled_stat(unit: BattleUnit) -> UnitGenericScalingStat:
    create_flat_stat(unit, CombatStats.STATS.Endurance, 5.0)
    var threshold_curve := Curve.new()
    threshold_curve.min_domain = 0.0
    threshold_curve.max_domain = 10.0
    threshold_curve.min_value = 0.0
    threshold_curve.max_value = 20.0
    threshold_curve.add_point(Vector2(0.0, 10.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
    threshold_curve.add_point(Vector2(10.0, 20.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
    var template := UnitScaleddStatTemplate.new()
    template.type = CombatStats.STATS.PhysicalResistance
    template.id = &"PhysicalResistance"
    template.influenced_by = CombatStats.STATS.Endurance
    template.to_stat_maximum_curve = threshold_curve
    template.minimum = 0.0
    template.maximum = 75.0
    var stat := UnitGenericScalingStat.new()
    stat.setup(template, unit)
    unit.stat_dictionary[template.id] = stat
    return stat


## Sets [code]template.id[/code] to [code]id[/code]; sets [code]template.stat[/code] to
## [code]CombatStats.STATS.Health[/code]; sets [code]template.scales_from_sender[/code] to true.
## Returns [code]template[/code].
func make_scaled_template(
    id: StringName,
    scaling_stat: CombatStats.STATS,
    scale: float,
    damage_type: CombatDamage.TYPE,
) -> EffectScalingCombatStatChangeTemplate:
    var template := EffectScalingCombatStatChangeTemplate.new()
    template.id = id
    template.stat = CombatStats.STATS.Health
    template.scales_from_sender = true
    template.scales_with = scaling_stat
    template.scales_by = scale
    template.damage_type = damage_type
    template.can_critical = false
    template.kind = CombatEffects.KIND.ONCE
    template.trigger = CombatEffects.TRIGGER.TARGETED
    template.template_scene = SCALED_STAT_EFFECT_SCENE
    return template


## Adds [code]effect[/code] as a child node; sets [code]effect.name[/code] to
## [code]template.id[/code]. Returns [code]effect[/code].
func apply_scaled_effect(
    sender: BattleUnit,
    target: BattleUnit,
    template: EffectScalingCombatStatChangeTemplate,
) -> EffectScaledStatChange:
    var effect := EffectScaledStatChange.new()
    effect.name = template.id
    effect.setup(sender, target, template)
    add_child(effect)
    effect.apply()
    assert(effect.finished, "Scaled stat changes must complete synchronously.")
    return effect


## Schedules a test node for deletion and waits until it leaves the scene.
func free_node(node: Node) -> void:
    if not is_instance_valid(node):
        return
    node.queue_free()
    await node.tree_exited
