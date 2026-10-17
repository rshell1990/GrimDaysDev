extends RefCounted
## Dispatches payload validation to each node strategy; does not mutate definitions.
class_name BattleSkillPayloadValidator


static func validate(nodes: Array[BattleSkillNode]) -> PackedStringArray:
    var errors := PackedStringArray()
    for node in nodes:
        if not node:
            errors.append("Skill payload validation requires a non-null node.")
        else:
            node.validate_payload(errors)
    return errors


## Shared effect identity checks; each strategy owns its target/lifetime/trigger rules.
static func validate_effect(effect: EffectTemplate, node_id: StringName, errors: PackedStringArray) -> void:
    if not effect or effect.id.is_empty() or not effect.template_scene:
        errors.append("Skill node %s has an invalid effect definition." % node_id)
        return
    if effect.trigger not in CombatEffects.TRIGGER.values():
        errors.append("Skill node %s has an unknown effect trigger." % node_id)
