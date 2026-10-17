extends EffectBase
## A retained action mandate. Grants no learned action or saved action ownership.
class_name EffectForceAction

static var _serial: int = 0
var definition: EffectTemplate
var affected_unit: BattleUnit
var active: bool = false
## Saved by runtime retry so priority ties keep their original application order.
var activation_order: int = 0


func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    definition = template


func apply() -> void:
    if not _begin_apply():
        return
    if (
        targeting is not BattleUnit
        or not definition.action
        or not definition.action.get_rank_template(definition.action_rank)
    ):
        CustomLogger.error(
            self, apply, "Forced action requires a unit and a valid authored action rank.", CustomLogger.LEVEL.IMPORTANT
        )
        _finish_apply()
        return
    affected_unit = targeting
    if not active:
        _serial += 1
        activation_order = _serial
        active = true
        affected_unit.add_control_override(self, false)
        affected_unit.forced_action_changed.emit()
    _finish_apply()


func _revoke() -> void:
    var unit := affected_unit
    active = false
    affected_unit = null
    if is_instance_valid(unit):
        unit.remove_control_override(self)
        unit.forced_action_changed.emit()


func _exit_tree() -> void:
    _revoke()
