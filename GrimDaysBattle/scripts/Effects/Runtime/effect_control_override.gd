extends EffectBase
## Implements the runtime effect control override behavior used by the battle effect pipeline.
class_name EffectControlOverride

## Runtime effect template state used by this effect control override.
var effect_template: EffectControlOverrideTemplate
## Runtime affected unit state used by this effect control override.
var affected_unit: BattleUnit


## Initializes this effect control override from the supplied runtime dependencies.
func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    effect_template = template


## Applies this effect control override's configured behavior to its current target.
func apply() -> void:
    if not _begin_apply():
        return
    affected_unit = targeting as BattleUnit
    if not affected_unit or not effect_template:
        CustomLogger.error(
            self, apply, "Control override requires a BattleUnit and valid template.", CustomLogger.LEVEL.IMPORTANT
        )
        _finish_apply()
        return
    affected_unit.add_control_override(self, effect_template.player_controlled)
    _finish_apply()


## Reverses revoke for this effect control override.
func _revoke() -> void:
    if affected_unit:
        affected_unit.remove_control_override(self)
    affected_unit = null


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _revoke()
