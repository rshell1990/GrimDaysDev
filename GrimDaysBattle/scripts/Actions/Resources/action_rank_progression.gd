extends RefCounted
## Expands authored progression into ordinary rank payloads without mutating shared definitions.

const MAX_EFFECT_DEPTH = 16
const MAX_COST = 2147483647


static func validate(base: RankTemplate, increases: Dictionary, count: int) -> PackedStringArray:
    var errors := PackedStringArray()
    if count < 1 or count > 99:
        errors.append("Generated Action rank count must be between 1 and 99.")
    if not base:
        errors.append("Generated Action ranks require a base rank.")
        return errors
    if base.cooldown_turns < 0:
        errors.append("Generated Action ranks cannot have a negative cooldown.")
    var stats := base.cost.keys()
    for stat in increases:
        if stat not in stats:
            stats.append(stat)
    for stat in stats:
        if stat == CombatStats.STATS.Empty or stat not in CombatStats.STATS.values():
            errors.append("Generated Action cost has an invalid stat.")
        var start: int = base.cost.get(stat, 0)
        var increment: int = increases.get(stat, 0)
        if start < 0 or start > MAX_COST or increment < 0 or increment > MAX_COST:
            errors.append(
                "Generated Action costs and increases must be between 0 and %s." % MAX_COST
            )
        elif count >= 1 and count <= 99 and start + increment * (count - 1) > MAX_COST:
            errors.append("Generated Action cost exceeds the supported range at the final rank.")
    if base.effects:
        for effect in base.effects.all:
            _validate_effect(effect, count, [], errors)
            if effect and effect.trigger == CombatEffects.TRIGGER.EQUIP:
                errors.append("Generated combat Actions cannot contain EQUIP operations.")
    return errors


static func _validate_effect(
    effect: EffectTemplate, count: int, ancestors: Array, errors: PackedStringArray
) -> void:
    if not effect:
        errors.append("Generated Action contains a null effect.")
        return
    if effect in ancestors or ancestors.size() >= MAX_EFFECT_DEPTH:
        errors.append(
            "Generated Action effect chain is cyclic or exceeds %s levels." % MAX_EFFECT_DEPTH
        )
        return
    if effect.id.is_empty() or not effect.template_scene:
        errors.append(
            "Generated Action effect '%s' (%s) requires an ID and runtime scene."
            % [effect.id, effect.resource_path]
        )
    if effect.trigger not in CombatEffects.TRIGGER.values():
        errors.append("Effect %s has an unknown trigger." % effect.id)
    if effect.available_from_rank < 1 or effect.available_from_rank > count:
        errors.append("Effect %s unlock rank is outside the Action's ranks." % effect.id)
    if effect.duration_by_rank.size() > count:
        errors.append("Effect %s has more duration values than Action ranks." % effect.id)
    if effect.duration_by_rank.is_empty():
        if effect.duration < 0 or (
            effect.lifetime == EffectTemplate.LIFETIME.ROUNDS and effect.duration < 1
        ):
            errors.append("Effect %s has an invalid duration." % effect.id)
    else:
        for index in effect.duration_by_rank.size():
            var duration := effect.duration_by_rank[index]
            if duration < 0 or (effect.lifetime == EffectTemplate.LIFETIME.ROUNDS and duration < 1):
                errors.append("Effect %s has an invalid rank duration." % effect.id)
                break
    var field := _potency_field(effect)
    if not field.is_empty():
        var values: PackedFloat64Array = effect.get(field + "_by_rank")
        if values.size() > count:
            errors.append("Effect %s has more potency values than Action ranks." % effect.id)
        if values.is_empty() and not is_finite(float(effect.get(field))):
            errors.append("Effect %s potency must be finite." % effect.id)
        for value in values:
            if not is_finite(value):
                errors.append("Effect %s rank potency must be finite." % effect.id)
                break
    if (
        effect is EffectTriggerAnotherEffect
        and (
            effect.repeat_min < 1
            or effect.repeat_max < effect.repeat_min
            or effect.repeat_max > 99
        )
    ):
        errors.append("Effect %s has invalid sequence repeat bounds." % effect.id)
    for modifier_field in _ranked_modifier_fields(effect):
        var values: Variant = effect.get(modifier_field + "_by_rank")
        if values.size() > count:
            errors.append(
                "Effect %s has more %s values than Action ranks." % [effect.id, modifier_field]
            )
        var checked: Array = [effect.get(modifier_field)] if values.is_empty() else Array(values)
        for value in checked:
            if (
                not is_finite(float(value))
                or (modifier_field == "critical_damage_multiplier" and value < 0)
                or (modifier_field == "chance" and (value < 0 or value > 100))
                or (
                    modifier_field in ["repeat_min", "repeat_max", "action_rank"]
                    and (value < 1 or value > 99)
                )
            ):
                errors.append("Effect %s has an invalid %s value." % [effect.id, modifier_field])
                break
    if effect is EffectTriggerAnotherEffect:
        for number in range(1, count + 1):
            var minimum := _ranked_int(effect, "repeat_min", number)
            var maximum := _ranked_int(effect, "repeat_max", number)
            if minimum < 1 or maximum < minimum or maximum > 99:
                errors.append("Effect %s has invalid rank repeat bounds." % effect.id)
                break
    if effect is EffectForceActionTemplate:
        for number in range(1, count + 1):
            var forced_rank := _ranked_int(effect, "action_rank", number)
            # Avoid recursively resolving another Action graph during validation.
            if (
                not effect.action
                or not effect.action.ranks
                or forced_rank < 1
                or forced_rank > effect.action.ranks.get_rank_count()
            ):
                errors.append("Effect %s has an unavailable forced Action rank." % effect.id)
                break
    var visited := ancestors.duplicate()
    visited.append(effect)
    for children in [effect.effects_on_expiry, effect.effects_on_hit, effect.effects_on_critical]:
        for child in children:
            _validate_effect(child, count, visited, errors)
    if effect is EffectTriggerAnotherEffect:
        for child in effect.triggers:
            _validate_effect(child, count, visited, errors)


## Called only after validation; no cache means Inspector edits are reflected on the next lookup.
static func resolve(base: RankTemplate, increases: Dictionary, number: int) -> RankTemplate:
    var result := base.duplicate(false) as RankTemplate
    result.level = number
    result.cost = base.cost.duplicate()
    for stat in increases:
        result.cost[stat] = base.cost.get(stat, 0) + increases[stat] * (number - 1)
    if base.effects:
        result.effects = base.effects.duplicate(false) as EffectTemplates
        result.effects.all = []
        for effect in base.effects.all:
            if effect.available_from_rank <= number:
                result.effects.all.append(_resolve_effect(effect, number))
    return result


static func _resolve_effect(effect: EffectTemplate, number: int) -> EffectTemplate:
    # Scenes, textures and other immutable assets stay shared;
    # each effect and chain array is private.
    var result := effect.duplicate(false) as EffectTemplate
    if not effect.duration_by_rank.is_empty():
        result.duration = effect.duration_by_rank[mini(number, effect.duration_by_rank.size()) - 1]
    var field := _potency_field(effect)
    if not field.is_empty():
        var values: PackedFloat64Array = effect.get(field + "_by_rank")
        if not values.is_empty():
            result.set(field, values[mini(number, values.size()) - 1])
    for modifier_field in _ranked_modifier_fields(effect):
        var values: Variant = effect.get(modifier_field + "_by_rank")
        if not values.is_empty():
            result.set(modifier_field, values[mini(number, values.size()) - 1])
    if effect is EffectTriggerAnotherEffect:
        var chain := result as EffectTriggerAnotherEffect
        chain.triggers = []
        for child in effect.triggers:
            if child.available_from_rank <= number:
                chain.triggers.append(_resolve_effect(child, number))
    for field_name in ["effects_on_expiry", "effects_on_hit", "effects_on_critical"]:
        var children: Array[EffectTemplate] = []
        for child in effect.get(field_name):
            if child.available_from_rank <= number:
                children.append(_resolve_effect(child, number))
        result.set(field_name, children)
    return result


## Explicit supported fields avoid multiplying unrelated values such as chance, caps or targeting.
static func _potency_field(effect: EffectTemplate) -> String:
    if effect is EffectScalingCombatStatChangeTemplate:
        return "scales_by"
    if effect is EffectResourceChangeTemplate or effect is EffectCappedChangeStatTemplate:
        return "amount"
    if effect is EffectPercentageChangeStatTemplate:
        return "percentage"
    if effect is EffectFlatChangeStatTemplate:
        return "flat_amount"
    return ""


## Independent numeric overrides resolve alongside potency, including nested follow-up graphs.
static func _ranked_modifier_fields(effect: EffectTemplate) -> Array[String]:
    if effect is EffectScalingCombatStatChangeTemplate:
        return ["critical_chance_bonus", "critical_damage_multiplier"]
    if effect is EffectTriggerAnotherEffect:
        return ["chance", "repeat_min", "repeat_max"]
    if effect is EffectForceActionTemplate:
        return ["action_rank"]
    return []


static func _ranked_int(effect: EffectTemplate, field: String, number: int) -> int:
    var values: PackedInt32Array = effect.get(field + "_by_rank")
    return int(effect.get(field)) if values.is_empty() else values[mini(number, values.size()) - 1]
