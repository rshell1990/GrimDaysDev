extends ResourceTemplate
## Shared authored action definition with ranked payloads and effect-based
## availability restrictions.
class_name ActionTemplate

@export_group("Display Parameters")
## Configures the display name used by this action template.
@export var display_name: String
@export_multiline var description: String
## Configures the icon used by this action template.
@export var icon: Texture2D

@export_group("Animation Details")
## Optional production wind-up animation. Cosmetic only; missing assets skip safely.
@export var attack_animation: StringName
## Whether this animation is intended for Spine playback.
@export var use_spine: bool = false
## Whether this animation should repeat.
@export var loop: bool = false
## Spine animation track used for this animation.
@export var track_number: int = 0

@export_group("Battle & AI Parameters")
## Any matching attached effect on the actor makes this action unavailable.
@export var disabled_by_effects: Array[StringName] = []
## Every requirement must pass at selection and execution, including forced actions.
@export var equipment_requirements: Array[ActionEquipmentRequirement] = []
## Configures the target used by this action template.
@export var target: CombatActions.TARGET
## Allows manual ALLY actions to select their caster as well as another living ally.
@export var include_self: bool = false
## Configures the target amount used by this action template.
@export var target_amount: int
## Configures the type used by this action template.
@export var type: CombatActions.TYPE
## Configures the always hits used by this action template.
@export var always_hits: bool
## Configures the risk reward used by this action template.
@export var risk_reward: CombatActions.RISK_FACTOR

@export_group("Rank payloads")
## Ordered rank definitions; execution rank belongs to the runtime grant/source.
@export var ranks: RanksTemplate


## Returns the one-based rank payload, or null when ranks are missing or out of range.
func get_rank_template(rank: int) -> RankTemplate:
    return ranks.get_rank(rank) if ranks else null


func get_rank_count() -> int:
    return ranks.get_rank_count() if ranks else 0


## Returns this rank's explicit or generated effect definitions matching the trigger.
func get_effects_by_rank_and_trigger(
    rank: int, trigger: CombatEffects.TRIGGER
) -> Array[EffectTemplate]:
    var rank_template := get_rank_template(rank)
    if not rank_template or not rank_template.effects:
        return []
    var organized_effects := rank_template.effects.get_organized_effects()
    if not organized_effects.has(trigger):
        return []
    var matching: Array[EffectTemplate]
    matching.assign(organized_effects[trigger])
    return matching


## Reject malformed restriction IDs without requiring a global effect registry.
func validate_restrictions() -> PackedStringArray:
    var errors := PackedStringArray()
    for effect_id in disabled_by_effects:
        if effect_id.is_empty():
            errors.append("Action %s contains an empty disabled effect ID." % id)
            break
    for requirement in equipment_requirements:
        if (
            not requirement
            or requirement.mode not in ActionEquipmentRequirement.MODE.values()
            or (
                requirement.mode == ActionEquipmentRequirement.MODE.WEAPON_TAG
                and requirement.weapon_tag.is_empty()
            )
        ):
            errors.append("Action %s has an invalid equipment requirement." % id)
    return errors


func get_equipment_unavailable_reason(unit: BattleUnit) -> String:
    for requirement in equipment_requirements:
        if not requirement:
            return "Invalid equipment requirement."
        var reason := requirement.get_unavailable_reason(unit)
        if not reason.is_empty():
            return reason
    return ""
