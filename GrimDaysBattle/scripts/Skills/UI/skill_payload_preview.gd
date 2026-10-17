extends RefCounted
## Read-only player summaries using the selected unit's current stats. Never executes effects.

const MAX_EFFECT_DEPTH = 16


static func action_text(action: ActionTemplate, number: int, unit: BattleUnit = null) -> String:
    var rank := action.get_rank_template(number) if action else null
    if not rank:
        return ""
    var lines := PackedStringArray()
    if rank.effects:
        for effect in rank.effects.all:
            _append_text(lines, effect_text(effect, 0, [], unit))
    var costs := PackedStringArray()
    for stat in rank.cost:
        if rank.cost[stat] != 0:
            costs.append("%s %s" % [rank.cost[stat], _stat_name(stat)])
    if not costs.is_empty():
        lines.append("Cost: " + ", ".join(costs))
    if rank.cooldown_turns > 0:
        lines.append("Cooldown: %s %s" % [rank.cooldown_turns, "turn" if rank.cooldown_turns == 1 else "turns"])
    for requirement in action.equipment_requirements:
        if requirement:
            var label := "Unarmed" if requirement.mode == ActionEquipmentRequirement.MODE.UNARMED else "Equipped weapon"
            if requirement.mode == ActionEquipmentRequirement.MODE.WEAPON_TAG:
                label = "%s weapon" % String(requirement.weapon_tag).capitalize()
            lines.append("Requires: " + label)
    return "\n".join(lines)


static func passive_text(node: BattleSkillPassiveNode, number: int, unit: BattleUnit = null) -> String:
    var lines := PackedStringArray()
    for modifier in node.passive_stat_modifiers:
        lines.append(
            (
                "%s: %s"
                % [
                    _stat_name(modifier.stat),
                    _modifier_value(modifier.operation, modifier.get_amount(number), modifier.stat)
                ]
            )
        )
    for effect in _passive_effects(node, number):
        _append_text(lines, effect_text(effect, 0, [], unit))
    return "\n".join(lines)


static func _number(value: float) -> String:
    return String.num(value, 2).trim_suffix(".0")


static func _signed(value: float) -> String:
    return ("+" if value >= 0.0 else "-") + _number(absf(value))


static func _stat_name(stat: CombatStats.STATS) -> String:
    return CombatStats.get_stat_as_string(stat).capitalize()


static func _modifier_value(operation: int, amount: float, stat: CombatStats.STATS = CombatStats.STATS.Empty) -> String:
    match operation:
        UnitStatModifier.OPERATION.PERCENT_ADD:
            return _signed(amount * 100.0) + "%"
        UnitStatModifier.OPERATION.MULTIPLY:
            return _number(amount * 100.0) + "% of normal"
        UnitStatModifier.OPERATION.OVERRIDE:
            return (
                "set to "
                + (_number(amount * 100.0) + "%" if stat == CombatStats.STATS.DamageModifier else _number(amount))
            )
    if stat == CombatStats.STATS.DamageModifier:
        return _signed(amount * 100.0) + " percentage points"
    return _signed(amount)


## Known effects expose outcomes only. Unknown types may supply authored player-facing prose.
## Keep chance, repeated hits and conditional follow-ups without exposing the resource graph.
static func effect_text(
    effect: EffectTemplate, depth: int = 0, ancestors: Array = [], unit: BattleUnit = null
) -> String:
    if not effect or depth >= MAX_EFFECT_DEPTH or effect in ancestors:
        return ""
    if effect.tag in [CombatEffects.TAG.VISUAL, CombatEffects.TAG.AUDIO]:
        return ""
    var visited := ancestors.duplicate()
    visited.append(effect)
    var summary := ""
    if effect is EffectTriggerAnotherEffect:
        if effect.chance <= 0:
            return ""
        var children := PackedStringArray()
        for child in effect.triggers:
            _append_text(children, effect_text(child, depth + 1, visited, unit))
        summary = "\n".join(children)
        if not summary.is_empty():
            if effect.repeat_max > 1:
                var count := (
                    str(effect.repeat_min)
                    if effect.repeat_min == effect.repeat_max
                    else "%s-%s" % [effect.repeat_min, effect.repeat_max]
                )
                summary = "%s times, each:\n%s" % [count, summary]
            if effect.chance < 100:
                summary = "%s%% chance:\n%s" % [effect.chance, summary]
    else:
        summary = _effect_summary(effect, unit)
    if not summary.is_empty():
        if effect.lifetime == EffectTemplate.LIFETIME.ROUNDS and effect.duration > 1:
            summary += " (for %s rounds)" % effect.duration
        # Instant action effects use triggers internally to route execution, not as player conditions.
        if effect.lifetime != EffectTemplate.LIFETIME.INSTANT:
            var when := _trigger_text(effect.trigger)
            if not when.is_empty():
                summary = when + ": " + summary
        if effect.target == CombatActions.TARGET.SELF:
            summary = "Self: " + summary
    var lines := PackedStringArray()
    _append_text(lines, summary)
    for field in ["effects_on_hit", "effects_on_critical", "effects_on_expiry"]:
        var label: String = {
            "effects_on_hit": "On hit", "effects_on_critical": "On critical hit", "effects_on_expiry": "When it ends"
        }[field]
        for child in effect.get(field):
            var text := effect_text(child, depth + 1, visited, unit)
            if not text.is_empty():
                lines.append(label + ": " + text)
    return "\n".join(lines)


static func _effect_summary(effect: EffectTemplate, unit: BattleUnit) -> String:
    if effect is EffectScalingCombatStatChangeTemplate:
        return _scaled_text(effect, unit)
    if effect is EffectResourceChangeTemplate:
        return _resource_text(effect, unit)
    if effect is EffectPercentageChangeStatTemplate:
        return (
            "%s: %s"
            % [
                _stat_name(effect.stat),
                _modifier_value(UnitStatModifier.OPERATION.PERCENT_ADD, effect.percentage, effect.stat)
            ]
        )
    if effect is EffectFlatChangeStatTemplate:
        return (
            "%s: %s"
            % [
                _stat_name(effect.stat),
                _modifier_value(UnitStatModifier.OPERATION.FLAT_ADD, effect.flat_amount, effect.stat)
            ]
        )
    if effect is EffectCappedChangeStatTemplate:
        return "%s: %s (up to %s)" % [_stat_name(effect.stat), _signed(effect.amount), _number(effect.contribution_cap)]
    if effect is EffectFixStatTemplate:
        return (
            "%s: %s"
            % [
                _stat_name(effect.stat),
                (
                    "held at its current value"
                    if effect.capture_current
                    else _modifier_value(UnitStatModifier.OPERATION.OVERRIDE, effect.value, effect.stat)
                )
            ]
        )
    if effect is EffectStunTemplate:
        return "Stuns the target"
    if effect is EffectDelayTurnTemplate:
        return "Delays the target's turn"
    if effect is EffectForceActionTemplate and effect.action:
        return "Forces " + effect.action.display_name
    if effect is EffectTargetSubstitutionTemplate:
        return (
            "Intercepts attacks against the selected ally"
            if effect.bound_unit == EffectTargetSubstitutionTemplate.BOUND_UNIT.APPLIER
            else "The selected ally intercepts attacks against you"
        )
    return effect.get_description()


## Recipient-scaled effects cannot use the caster's stats unless they target the caster.
static func _scaled_text(effect: EffectScalingCombatStatChangeTemplate, unit: BattleUnit) -> String:
    var stat: UnitGenericStat
    if is_instance_valid(unit) and (effect.scales_from_sender or effect.target == CombatActions.TARGET.SELF):
        stat = unit.get_stat(effect.scales_with)
    if not stat:
        return (
            _change_label(effect.stat, effect.scales_by)
            + (
                ": %s%% of %s %s"
                % [
                    _number(absf(effect.scales_by) * 100.0),
                    "your" if effect.scales_from_sender else "the target's",
                    _stat_name(effect.scales_with)
                ]
            )
        )
    var amount := stat.Current * effect.scales_by
    if effect.scales_with_damage:
        var modifier := unit.get_stat(CombatStats.STATS.DamageModifier)
        if not modifier:
            return _change_label(effect.stat, amount) + ": depends on damage bonus"
        amount *= modifier.Current
    if amount < 0.0:
        return _damage_text(effect, absf(amount))
    return "%s: %s" % [_change_label(effect.stat, amount), _number(amount)]


static func _resource_text(effect: EffectResourceChangeTemplate, unit: BattleUnit) -> String:
    var amount := effect.amount
    if effect.amount_mode != EffectResourceChangeTemplate.AMOUNT_MODE.FLAT:
        var stat := (
            unit.get_stat(effect.stat)
            if is_instance_valid(unit) and effect.target == CombatActions.TARGET.SELF
            else null
        )
        if not stat:
            return (
                "%s: %s%% of the target's %s %s"
                % [
                    _change_label(effect.stat, amount),
                    _number(absf(amount) * 100.0),
                    (
                        "maximum"
                        if effect.amount_mode == EffectResourceChangeTemplate.AMOUNT_MODE.PERCENT_MAX
                        else "current"
                    ),
                    _stat_name(effect.stat)
                ]
            )
        var use_max := effect.amount_mode == EffectResourceChangeTemplate.AMOUNT_MODE.PERCENT_MAX
        amount *= stat.Max if use_max else stat.Current
    if amount < 0.0 and effect.stat == CombatStats.STATS.Health:
        return _damage_text(effect, absf(amount))
    return "%s: %s" % [_change_label(effect.stat, amount), _number(absf(amount))]


static func _change_label(stat: CombatStats.STATS, amount: float) -> String:
    if stat == CombatStats.STATS.Health:
        return "Damage" if amount < 0.0 else "Healing"
    return _stat_name(stat) + (" lost" if amount < 0.0 else " gained")


## Show on-hit ranges before enemy resistance. No rolls, effects or stat mutations are performed.
static func _damage_text(effect: EffectChangeStatTemplate, amount: float) -> String:
    var low := amount
    var high := amount
    match effect.damage_type:
        CombatDamage.TYPE.Physical:
            low *= CombatDamage.PHYSICAL_DAMAGE_MIN_MODIFIER
            high *= CombatDamage.PHYSICAL_DAMAGE_MAX_MODIFIER
        CombatDamage.TYPE.Magic:
            low *= CombatDamage.MAGICAL_DAMAGE_MIN_MODIFIER
            high *= CombatDamage.MAGICAL_DAMAGE_MAX_MODIFIER
    var text := "%s: %s" % [_change_label(effect.stat, -1.0), _range_text(low, high)]
    if (
        effect is EffectScalingCombatStatChangeTemplate
        and effect.can_critical
        and effect.critical_damage_multiplier > 2.0
    ):
        text += " (critical damage: %sx)" % _number(effect.critical_damage_multiplier)
    return text


static func _range_text(low: float, high: float) -> String:
    # Remove floating-point multiplication noise at integer boundaries before flooring.
    var minimum := floori(snappedf(low, 0.000000001))
    var maximum := floori(snappedf(high, 0.000000001))
    return str(minimum) if minimum == maximum else "%s-%s" % [minimum, maximum]


static func _trigger_text(trigger: CombatEffects.TRIGGER) -> String:
    return (
        {
            CombatEffects.TRIGGER.TARGETED: "When targeted",
            CombatEffects.TRIGGER.DAMAGED: "When hit",
            CombatEffects.TRIGGER.ATTACKING: "When attacking",
            CombatEffects.TRIGGER.AFTER_HITTING: "After hitting",
            CombatEffects.TRIGGER.DEFEAT: "When defeated",
            CombatEffects.TRIGGER.KILL: "After defeating an enemy",
            CombatEffects.TRIGGER.ROUND_OVER: "Each round",
            CombatEffects.TRIGGER.BEFORE_DAMAGE: "Before dealing damage",
        }
        . get(trigger, "")
    )


static func _append_text(lines: PackedStringArray, text: String) -> void:
    if not text.is_empty():
        lines.append(text)


static func node_text(node: BattleSkillNode, number: int, unit: BattleUnit = null) -> String:
    if node is BattleSkillActionNode:
        return action_text(node.action, number, unit)
    if node is BattleSkillPassiveNode:
        return passive_text(node, number, unit)
    return node.get_payload_label()


static func compiled_text(node_id: StringName, plan: Dictionary, unit: BattleUnit = null) -> String:
    for entry: Dictionary in plan.actions.values():
        if entry.tip == node_id:
            return action_text(entry.action, entry.rank, unit)
    return ""


static func final_text(node: BattleSkillNode, ledger: BattleSkillInvestment, unit: BattleUnit = null) -> String:
    if ledger.get_rank(node.id) == 0:
        return ""
    var plan := BattleSkillChainResolver.preview_node(node.id, ledger)
    if not plan.errors.is_empty():
        return "Unable to preview this skill."
    if node is BattleSkillActionNode:
        return compiled_text(node.id, plan, unit)
    var lines := PackedStringArray()
    for entry: Dictionary in plan.passives.values():
        _append_text(lines, passive_text(entry.node, entry.rank, unit))
    return "\n".join(lines)


## Gate failures are explained separately. A later available chain node supersedes this tip.
static func is_suppressed(node: BattleSkillNode, ledger: BattleSkillInvestment, values: Dictionary) -> bool:
    var by_id: Dictionary = {}
    for candidate in ledger.get_nodes():
        by_id[candidate.id] = candidate
    for candidate in ledger.get_nodes():
        if not ledger.is_available(candidate.id, values):
            continue
        var cursor := candidate
        while not cursor.previous_node.is_empty():
            if cursor.previous_node == node.id:
                return true
            cursor = by_id[cursor.previous_node]
    return false


## Compare player-visible outcomes at the next local rank, excluding retained predecessors.
static func next_text(node: BattleSkillNode, current: int, unit: BattleUnit = null) -> String:
    if current >= node.maximum_rank:
        return "(MAX RANK)"
    if current == 0:
        return "First rank:\n" + node_text(node, 1, unit)
    var lines := PackedStringArray()
    if node is BattleSkillPassiveNode:
        for modifier in node.passive_stat_modifiers:
            var before: float = modifier.get_amount(current)
            var after: float = modifier.get_amount(current + 1)
            if not is_equal_approx(before, after):
                lines.append(
                    (
                        "%s: %s -> %s"
                        % [
                            _stat_name(modifier.stat),
                            _modifier_value(modifier.operation, before, modifier.stat),
                            _modifier_value(modifier.operation, after, modifier.stat)
                        ]
                    )
                )
        lines.append_array(_effects_delta(_passive_effects(node, current), _passive_effects(node, current + 1), unit))
    elif node is BattleSkillActionNode:
        var before: RankTemplate = node.action.get_rank_template(current)
        var after: RankTemplate = node.action.get_rank_template(current + 1)
        if not before or not after:
            return ""
        lines.append_array(
            _effects_delta(
                before.effects.all if before.effects else [], after.effects.all if after.effects else [], unit
            )
        )
        var stats := before.cost.keys()
        for stat in after.cost:
            if stat not in stats:
                stats.append(stat)
        for stat in stats:
            var old_cost: int = before.cost.get(stat, 0)
            var new_cost: int = after.cost.get(stat, 0)
            if old_cost != new_cost:
                lines.append("Cost: %s -> %s %s" % [old_cost, new_cost, _stat_name(stat)])
        if before.cooldown_turns != after.cooldown_turns:
            lines.append("Cooldown: %s -> %s turns" % [before.cooldown_turns, after.cooldown_turns])
    return "\n".join(lines) if not lines.is_empty() else "No change at the next rank."


static func _passive_effects(node: BattleSkillPassiveNode, number: int) -> Array[EffectTemplate]:
    if number > 0 and number <= node.passive_effects_by_rank.size():
        var effects := node.passive_effects_by_rank[number - 1]
        if effects:
            return effects.all
    return []


static func _effects_delta(before: Array, after: Array, unit: BattleUnit = null) -> PackedStringArray:
    var lines := PackedStringArray()
    for index in range(maxi(before.size(), after.size())):
        var old := effect_text(before[index], 0, [], unit) if index < before.size() else ""
        var next := effect_text(after[index], 0, [], unit) if index < after.size() else ""
        if old == next:
            continue
        if old.is_empty():
            _append_text(lines, next)
        elif next.is_empty():
            lines.append("No longer: " + old)
        else:
            lines.append(old + " -> " + next)
    return lines
