extends RefCounted
## Coordinates battle unit template validator behavior for the battle system.
class_name BattleUnitTemplateValidator

## Fixed required combat stats value shared by all unit template validator instances.
const REQUIRED_COMBAT_STATS: Array[CombatStats.STATS] = [
    CombatStats.STATS.Health,
    CombatStats.STATS.Energy,
    CombatStats.STATS.Level,
    CombatStats.STATS.PhysicalDamage,
    CombatStats.STATS.MagicDamage,
    CombatStats.STATS.PhysicalResistance,
    CombatStats.STATS.MagicResistance,
    CombatStats.STATS.Accuracy,
    CombatStats.STATS.Evasion,
    CombatStats.STATS.Swiftness,
    CombatStats.STATS.Weight,
    CombatStats.STATS.WeightLimit,
    CombatStats.STATS.Encumberance,
    CombatStats.STATS.CriticalStrike,
    CombatStats.STATS.LuckyEvasion,
    CombatStats.STATS.Luck,
    CombatStats.STATS.DamageModifier,
]


## Validates the data consumed by this unit template validator and returns every discovered error.
static func validate(template: BattleUnitTemplate) -> PackedStringArray:
    var errors := PackedStringArray()
    if not template:
        errors.append("Battle unit template is null.")
        return errors
    if template.id.is_empty():
        errors.append("Battle unit template has no id.")
    if template.experience_reward < 0 or template.experience_reward > 2147483647:
        errors.append("Unit %s has an experience reward outside 0–2147483647." % template.id)
    if not template.stats:
        errors.append("Unit %s has no stat collection." % template.id)
        return errors

    var templates_by_type: Dictionary = {}
    var ids: Dictionary = {}
    for index in template.stats.all.size():
        var stat_template: UnitStatTemplate = template.stats.all[index]
        if not stat_template:
            errors.append("Unit %s has a null stat template at index %s." % [template.id, index])
            continue
        _validate_stat_definition(stat_template, errors)
        if ids.has(stat_template.id):
            errors.append("Unit %s has duplicate stat id %s." % [template.id, stat_template.id])
        else:
            ids[stat_template.id] = true
        if templates_by_type.has(stat_template.type):
            errors.append(
                (
                    "Unit %s has duplicate stat type %s."
                    % [template.id, CombatStats.get_stat_as_string(stat_template.type)]
                )
            )
        else:
            templates_by_type[stat_template.type] = stat_template

    for required_type in REQUIRED_COMBAT_STATS:
        if not templates_by_type.has(required_type):
            errors.append(
                (
                    "Unit %s is missing required combat stat %s."
                    % [template.id, CombatStats.get_stat_as_string(required_type)]
                )
            )

    for stat_template in templates_by_type.values():
        for dependency in get_dependencies(stat_template):
            if dependency == CombatStats.STATS.Empty:
                errors.append("Stat %s has an empty dependency." % stat_template.id)
            elif not templates_by_type.has(dependency):
                errors.append(
                    (
                        "Stat %s requires missing dependency %s."
                        % [stat_template.id, CombatStats.get_stat_as_string(dependency)]
                    )
                )

    if _has_dependency_cycle(templates_by_type):
        errors.append("Unit %s contains a cyclic stat dependency." % template.id)
    if template is MainCharacterTemplate:
        _validate_lucidity_break(template, templates_by_type, errors)
    for action in [template.basic_action_template, template.special_action]:
        if action:
            errors.append_array(action.validate_restrictions())
    _validate_intrinsic_effects(template, errors)
    if template.skill_collection:
        var skill_errors := template.skill_collection.validate()
        errors.append_array(skill_errors)
        if skill_errors.is_empty():
            for tree in template.skill_collection.trees:
                errors.append_array(BattleSkillPayloadValidator.validate(tree.get_nodes()))
                for definition in tree.get_runtime_tiers() + tree.get_nodes():
                    for bounds in [definition.minimum_stats, definition.maximum_stats]:
                        for stat in bounds:
                            if not templates_by_type.has(stat):
                                errors.append(
                                    "Skill requirement stat is missing: %s." % CombatStats.get_stat_as_string(stat)
                                )
    errors.append_array(BattleEquipmentLoadout.plan_starting(template).errors)
    return errors


## Only main characters author automatic empty-Lucidity outcomes.
static func _validate_lucidity_break(
    template: MainCharacterTemplate, stats: Dictionary, errors: PackedStringArray
) -> void:
    var enabled := template.lucidity_break_options.any(func(option): return option != null and option.weight > 0.0)
    if enabled and not stats.has(CombatStats.STATS.Lucidity):
        errors.append("Lucidity breaks require a Lucidity stat.")
    for option in template.lucidity_break_options:
        if not option:
            errors.append("Lucidity break outcomes cannot be null.")
        else:
            errors.append_array(option.validate())


## Validates runtime for this unit template validator.
static func validate_runtime(unit: BattleUnit) -> PackedStringArray:
    var errors := PackedStringArray()
    if not unit:
        errors.append("Constructed battle unit is null.")
        return errors
    for stat in unit.stat_dictionary.values():
        if not (is_finite(stat.Base) and is_finite(stat.Min) and is_finite(stat.Max) and is_finite(stat.Current)):
            errors.append("Runtime stat %s contains a non-finite value." % stat.name)
    return errors


## Returns definitions in dependency order while preserving authored order among
## definitions at the same depth. An empty result indicates a cycle or a missing
## dependency and should only occur after validation has failed.
static func sort_templates(templates: Array[UnitStatTemplate]) -> Array[UnitStatTemplate]:
    var ordered: Array[UnitStatTemplate] = []
    var remaining: Array[UnitStatTemplate] = templates.duplicate()
    var completed: Dictionary = {}
    var available_types: Dictionary = {}
    for stat_template in templates:
        if stat_template:
            available_types[stat_template.type] = true

    while not remaining.is_empty():
        var added_this_pass := false
        var next_remaining: Array[UnitStatTemplate] = []
        for stat_template in remaining:
            var dependencies_ready := true
            for dependency in get_dependencies(stat_template):
                if not available_types.has(dependency) or not completed.has(dependency):
                    dependencies_ready = false
                    break
            if dependencies_ready:
                ordered.append(stat_template)
                completed[stat_template.type] = true
                added_this_pass = true
            else:
                next_remaining.append(stat_template)
        if not added_this_pass:
            return []
        remaining = next_remaining

    return ordered


## Returns dependencies for this unit template validator.
static func get_dependencies(template: UnitStatTemplate) -> Array[CombatStats.STATS]:
    var dependencies: Array[CombatStats.STATS] = []
    if not template:
        return dependencies
    if template.type == CombatStats.STATS.Encumberance:
        return [CombatStats.STATS.Weight, CombatStats.STATS.WeightLimit]
    if template is UnitWeightLimitTemplate:
        dependencies.assign(template.influenced_by)
    elif template is UnitScaleddStatTemplate:
        dependencies.append(template.influenced_by)
        dependencies.append(CombatStats.STATS.Level)
    elif template is UnitCalculatedStatTemplate:
        dependencies.append(template.influenced_by)
    return dependencies


## Validates stat definition for this unit template validator.
static func _validate_stat_definition(template: UnitStatTemplate, errors: PackedStringArray) -> void:
    if template.type == CombatStats.STATS.Empty:
        errors.append("A stat template uses the Empty stat type.")
        return
    var canonical_id := StringName(CombatStats.get_stat_as_string(template.type))
    if template.id != canonical_id:
        errors.append("Stat type %s must use canonical id %s, not %s." % [template.type, canonical_id, template.id])
    if not is_finite(template.starting_amount):
        errors.append("Stat %s has a non-finite starting amount." % template.id)

    if template.type == CombatStats.STATS.WeightLimit:
        if template is not UnitWeightLimitTemplate:
            errors.append("WeightLimit must use UnitWeightLimitTemplate.")
            return
        if template.influenced_by.is_empty():
            errors.append("WeightLimit requires at least one dependency.")
        _validate_curve(template.id, template.growth_curve, errors)
        return

    if template.type == CombatStats.STATS.Encumberance:
        return

    if template.type in CombatStats.SCALED_STATS:
        if template is not UnitScaleddStatTemplate:
            errors.append("Scaled stat %s must use UnitScaleddStatTemplate." % template.id)
            return
        _validate_curve(template.id, template.to_stat_maximum_curve, errors)
        if not is_finite(template.minimum) or not is_finite(template.maximum):
            errors.append("Scaled stat %s has a non-finite range." % template.id)
        elif template.maximum < template.minimum:
            errors.append("Scaled stat %s has maximum below minimum." % template.id)
        return

    if template.type in CombatStats.CALCULATED_STATS:
        if template is not UnitCalculatedStatTemplate:
            errors.append("Calculated stat %s must use UnitCalculatedStatTemplate." % template.id)
            return
        _validate_curve(template.id, template.growth_curve, errors)
        return

    if template.type not in CombatStats.FLAT_STATS:
        errors.append("Stat %s has no supported runtime stat class." % template.id)


## Validates curve for this unit template validator.
static func _validate_curve(stat_id: StringName, curve: Curve, errors: PackedStringArray) -> void:
    if not curve:
        errors.append("Stat %s has no required curve." % stat_id)
    elif curve.point_count < 1:
        errors.append("Stat %s has an empty required curve." % stat_id)


## Validates effects that are reconstructed directly from a unit template.
static func _validate_intrinsic_effects(
    template: BattleUnitTemplate,
    errors: PackedStringArray,
) -> void:
    if template.intrinsic_effects.is_empty():
        return
    var effect_ids: Dictionary = {}
    for index in template.intrinsic_effects.size():
        var effect: EffectTemplate = template.intrinsic_effects[index]
        if not effect:
            errors.append("Unit %s has a null intrinsic effect at index %s." % [template.id, index])
            continue
        if effect.id.is_empty():
            errors.append("Unit %s has an intrinsic effect without a stable id." % template.id)
        elif effect_ids.has(effect.id):
            errors.append("Unit %s repeats intrinsic effect %s." % [template.id, effect.id])
        else:
            effect_ids[effect.id] = true
        if not effect.template_scene:
            errors.append("Intrinsic effect %s has no runtime scene." % effect.id)
        if effect.target != CombatActions.TARGET.SELF:
            errors.append("Intrinsic effect %s must target SELF." % effect.id)
        if effect.lifetime != EffectTemplate.LIFETIME.WHILE_SOURCE_ACTIVE:
            errors.append(
                (
                    "Intrinsic effect %s must use WHILE_SOURCE_ACTIVE; the unit template is its persistence authority."
                    % effect.id
                )
            )


## Returns whether dependency cycle.
static func _has_dependency_cycle(templates_by_type: Dictionary) -> bool:
    var visit_state: Dictionary = {}
    for stat_type in templates_by_type:
        if _visit_dependency(stat_type, templates_by_type, visit_state):
            return true
    return false


## Visits dependency for this unit template validator.
static func _visit_dependency(stat_type: int, templates_by_type: Dictionary, visit_state: Dictionary) -> bool:
    var state: int = visit_state.get(stat_type, 0)
    if state == 1:
        return true
    if state == 2:
        return false
    visit_state[stat_type] = 1
    var stat_template: UnitStatTemplate = templates_by_type[stat_type]
    for dependency in get_dependencies(stat_template):
        if templates_by_type.has(dependency) and _visit_dependency(dependency, templates_by_type, visit_state):
            return true
    visit_state[stat_type] = 2
    return false
