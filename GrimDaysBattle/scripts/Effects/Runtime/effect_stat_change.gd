extends EffectBase
## Implements the runtime effect stat change behavior used by the battle effect pipeline.
class_name EffectStatChange

## Runtime effect template state used by this effect stat change.
var effect_template: EffectChangeStatTemplate
## Runtime modifier id state used by this effect stat change.
var modifier_id: StringName
## Runtime modified stat state used by this effect stat change.
var modified_stat: UnitGenericStat


## Initializes this effect stat change from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template


## Applies this effect stat change's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    if not effect_template:
        _finish_with_error("Stat-change effect %s has no valid template." % id)
        return
    if targeting is not BattleUnit:
        _finish_with_error("Stat-change effect %s requires a BattleUnit target." % id)
        return

    modified_stat = targeting.get_stat(effect_template.stat)
    if not modified_stat:
        _finish_with_error(
            (
                "Effect %s could not find stat %s on %s."
                % [id, CombatStats.get_stat_as_string(effect_template.stat), targeting.name]
            )
        )
        return

    var operation: int
    var amount: float
    if effect_template is EffectCappedChangeStatTemplate:
        operation = UnitStatModifier.OPERATION.CAPPED_ADD
        amount = effect_template.amount
    elif effect_template is EffectFlatChangeStatTemplate:
        operation = UnitStatModifier.OPERATION.FLAT_ADD
        amount = effect_template.flat_amount
    elif effect_template is EffectPercentageChangeStatTemplate:
        operation = UnitStatModifier.OPERATION.PERCENT_ADD
        amount = effect_template.percentage
    else:
        _finish_with_error("Effect %s uses an unsupported stat-change template." % id)
        return

    modifier_id = StringName("%s:%s" % [id, get_instance_id()])
    var modifier_lifetime := (
        UnitStatModifier.LIFETIME.PERSISTENT
        if self.lifetime == EffectTemplate.LIFETIME.PERSISTENT
        else UnitStatModifier.LIFETIME.WHILE_SOURCE_ACTIVE
    )
    var modifier := (
        UnitStatModifier
        . create(
            modifier_id,
            source_id,
            effect_template.stat,
            operation,
            amount,
            modifier_lifetime,
        )
    )
    if effect_template is EffectCappedChangeStatTemplate:
        modifier.contribution_cap = effect_template.contribution_cap
    modified_stat.add_modifier(modifier)
    _finish_apply()


## Finishes with error for this effect stat change.
func _finish_with_error(message: String) -> void:
    push_error(message)
    _finish_apply()


## Reverses revoke for this effect stat change.
func _revoke() -> void:
    if modified_stat and not modifier_id.is_empty():
        modified_stat.remove_modifier(modifier_id)
    modified_stat = null
    modifier_id = &""


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _revoke()
