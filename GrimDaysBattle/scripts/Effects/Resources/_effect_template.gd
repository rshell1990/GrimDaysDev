extends ResourceTemplate
#region EFFECT
## The base template for an effect, is inherited by specific types of effects to add specific logic for the effect type.
##
##
class_name EffectTemplate
#endregion

## Enumerates the supported lifetime values.
enum LIFETIME {
    ## Apply once, complete, and leave no active effect instance behind.
    INSTANT,
    ## Remain active for [member duration] completed battle rounds.
    ROUNDS,
    ## Remain active until battle-result cleanup.
    UNTIL_BATTLE_END,
    ## Remain active while the granting equipment, passive, or other source exists.
    WHILE_SOURCE_ACTIVE,
    ## Remain part of character progression and be reconstructed from saved state.
    PERSISTENT,
}

## Policy for another effect with the same ID/source in the same trigger holder.
enum STACKING { DISCARD, REFRESH, COMBINE, MULTIPLE, REPLACE }

#region BASIC VARS
@export_group("Basics")
## How long this effect lasts.
@export var duration: int = 0
## Granted to the attached unit only when a ROUNDS lifetime expires, not on removal or cleanup.
## Child triggers remain authored: EQUIP applies immediately; other triggers wait for their event.
# Self-typed member defaults retain this script in Godot. Type each instance's
# array instead; keep the same Inspector element type and serialized properties.
@export_custom(PROPERTY_HINT_TYPE_STRING, "24/17:EffectTemplate") var effects_on_expiry: Array = []:
    set(value):
        effects_on_expiry = _typed_followups(value)
## Immediate follow-up sequences for this individual damaging operation after a successful hit.
## Hit children run first, then critical children. Healing and misses never run these lists.
@export_custom(PROPERTY_HINT_TYPE_STRING, "24/17:EffectTemplate") var effects_on_hit: Array = []:
    set(value):
        effects_on_hit = _typed_followups(value)
@export_custom(PROPERTY_HINT_TYPE_STRING, "24/17:EffectTemplate") var effects_on_critical: Array = []:
    set(value):
        effects_on_critical = _typed_followups(value)
## Refresh preserves the former non-stacking default.
@export var stacking: STACKING = STACKING.REFRESH
## Opt-in shared status: identical IDs in this holder share one stack across casters/sources.
## Refresh retains the original magnitude and ownership, just like ordinary same-source refresh.
@export var stacking_across_sources: bool = false
## Controls removal independently from when and how the effect is triggered.
@export var lifetime: LIFETIME = LIFETIME.INSTANT
## Compatibility storage for resources authored before explicit lifetimes.
## New content should use [member lifetime].
@export_storage var permanent: bool = false:
    set(value):
        permanent = value
        if value and lifetime == LIFETIME.INSTANT:
            lifetime = LIFETIME.UNTIL_BATTLE_END
#endregion

#region ADVANCED VARS
@export_group("Advanced")
## Who this effect targets.
@export var target: CombatActions.TARGET
## Whether this effect is beneficial to a unit, or a penalty on the unit.
@export var kind: CombatEffects.KIND
## The damage type.
@export var damage_type: CombatDamage.TYPE
## Damage ignores Physical/Magic resistance; accuracy, variance and critical rules are unchanged.
@export var bypass_mitigation: bool = false
## The category this effect belongs to.
@export var tag: CombatEffects.TAG = CombatEffects.TAG.DAMAGE
## The triggering circumstance to apply this effect.
@export var trigger: CombatEffects.TRIGGER
## Immediate damaging action operations roll accuracy independently. This flag
## bypasses that operation's miss/evasion checks, not other operations in the cast.
@export var always_hits: bool = false
#endregion

#region DISPLAY VARS
@export_group("UI Information.")
## The icon for the effect.
@export var icon: Texture2D
## Standalone lowercase x is replaced with the resolved potency magnitude for display.
@export_multiline var description: String
#endregion

#region TEMPLATE VAR
@export_group("Creating")
## The scene to instantiate when adding this effect to the scene tree.
@export var template_scene: PackedScene
#endregion

@export_group("Action rank progression")
## Only interpreted by generated Action ranks; other effect sources use scalar values.
@export_range(1, 99, 1) var available_from_rank: int = 1
## Absolute Action-rank durations. Empty uses duration; a short list holds its final value.
@export var duration_by_rank: PackedInt32Array


func _init() -> void:
    effects_on_expiry = []
    effects_on_hit = []
    effects_on_critical = []


static func _typed_followups(value: Array) -> Array[EffectTemplate]:
    if value.is_typed() and value.get_typed_script() == EffectTemplate:
        return value
    return Array(value, TYPE_OBJECT, &"Resource", EffectTemplate)


## Format on read so shared authored descriptions remain reusable across generated ranks.
## Direction comes from the prose (for example, "lose x%"); ordinary words retain their x.
func get_description(resolved_value: Variant = null) -> String:
    var result := description
    var pattern := RegEx.create_from_string("\\bx\\b")
    var matches := pattern.search_all(description)
    for index in range(matches.size() - 1, -1, -1):
        var placeholder: RegExMatch = matches[index]
        var end := placeholder.get_end()
        var as_percent := end < description.length() and description.substr(end, 1) == "%"
        var value: Variant = (
            resolved_value if resolved_value != null and not as_percent else _get_description_value(as_percent)
        )
        if value == null or not is_finite(float(value)):
            continue
        var number := String.num(absf(float(value)), 6).trim_suffix(".0")
        result = result.substr(0, placeholder.get_start()) + number + result.substr(end)
    return result


## Effects without a single numeric potency leave the placeholder unchanged.
func _get_description_value(_as_percent: bool) -> Variant:
    return null


## Read legacy serialized resources without exposing the old boolean in the Inspector.
func _set(property: StringName, value: Variant) -> bool:
    if property == &"stacks" and value is bool:
        stacking = STACKING.MULTIPLE if value else STACKING.REFRESH
        return true
    return false
