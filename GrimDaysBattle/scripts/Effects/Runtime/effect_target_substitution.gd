extends EffectBase
## A retained binding stays on its owner; substitution never moves existing effect nodes.
class_name EffectTargetSubstitution

var bound_unit: BattleUnit
var definition: EffectTargetSubstitutionTemplate
var _binding_initialized: bool


func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    definition = template


## Capture the ally at installation, never from an incoming attack's target selection.
func set_chain_context(context: Dictionary) -> void:
    if not _binding_initialized and definition:
        bound_unit = (
            sender
            if definition.bound_unit == EffectTargetSubstitutionTemplate.BOUND_UNIT.APPLIER
            else context.get("selected_target")
        )
        _binding_initialized = true
    var scoped := context.duplicate(true)
    scoped["action_operation"] = false
    super(scoped)


func apply() -> void:
    if not _begin_apply():
        return
    var execution: BattleActionContext = get_meta(CHAIN_CONTEXT_META, {}).get("action_context")
    if execution:
        execution.substitute(bound_unit)
    _finish_apply()


func _revoke() -> void:
    bound_unit = null


## Removal is distinct from temporary zero Health; final-defeat cleanup is synchronous.
func _process(_delta: float) -> void:
    if _binding_initialized and (not is_instance_valid(bound_unit) or not bound_unit.is_inside_tree()):
        remove()
