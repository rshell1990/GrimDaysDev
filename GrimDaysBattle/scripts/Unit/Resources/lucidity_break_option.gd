## One weighted automatic response to empty Lucidity. Assign exactly one payload.
extends Resource
class_name LucidityBreakOption

## Relative selection weight. Zero disables this entry; weights need not total 100.
@export_range(0.0, 1000000.0, 0.1) var weight: float = 1.0
## Applied to the character using this effect's authored lifetime and duration.
@export var effect: EffectTemplate
## Executes at the unit's turn start through the normal resolver, using automatic targeting without costs or cooldowns.
## Authored combat actions are ActionTemplates; no permanent learned grant is created.
@export var action: ActionTemplate
## Minimum execution rank; an existing higher learned rank remains authoritative.
@export_range(1, 99, 1) var action_rank: int = 1


## Definition errors are also used to exclude malformed entries from runtime rolls.
func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if not is_finite(weight) or weight < 0.0 or weight > 1000000.0:
        errors.append("Lucidity outcome weight must be finite and between 0 and 1000000.")
    if (effect == null) == (action == null):
        errors.append("Lucidity outcomes require exactly one effect or action.")
    if effect:
        if effect.id.is_empty() or not effect.template_scene:
            errors.append("Lucidity break effects require an id and runtime scene.")
        if effect.target != CombatActions.TARGET.SELF:
            errors.append("Lucidity break effects must target SELF.")
        if effect.lifetime not in [EffectTemplate.LIFETIME.INSTANT, EffectTemplate.LIFETIME.ROUNDS]:
            errors.append("Lucidity break effects must use INSTANT or ROUNDS lifetime.")
        if effect.lifetime == EffectTemplate.LIFETIME.ROUNDS and effect.duration < 1:
            errors.append("Round-based Lucidity break effects require a positive duration.")
    if action:
        if action.id.is_empty() or not action.get_rank_template(action_rank):
            errors.append("Lucidity break actions require an id and a valid rank.")
        errors.append_array(action.validate_restrictions())
    return errors
