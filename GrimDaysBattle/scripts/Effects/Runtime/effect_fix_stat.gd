extends EffectBase
## Owns one reversible Current lock; no damage/healing is queued for later replay.
class_name EffectFixStat

var definition: EffectTemplate
var locked_stat: UnitGenericStat
var lock_id: StringName
## Retained by retry and repeated triggers so a Current capture is never rerolled.
var captured: bool = false
var locked_value: float = 0.0


func setup(sent_by: Variant, target_node: Variant, template: Variant) -> void:
    super(sent_by, target_node, template)
    definition = template
    lock_id = StringName("fixed_stat:%s" % get_instance_id())


func apply() -> void:
    if not _begin_apply():
        return
    if targeting is BattleUnit and is_finite(definition.value):
        locked_stat = targeting.get_stat(definition.stat)
        if locked_stat:
            if not captured:
                locked_value = locked_stat.Current if definition.capture_current else definition.value
                captured = true
            locked_stat.add_current_lock(lock_id, locked_value, definition.priority)
    if not locked_stat:
        CustomLogger.error(
            self, apply, "Fixed stat effect requires an existing stat and finite value.", CustomLogger.LEVEL.IMPORTANT
        )
    _finish_apply()


func _revoke() -> void:
    if is_instance_valid(locked_stat):
        locked_stat.remove_current_lock(lock_id)
    locked_stat = null


func _exit_tree() -> void:
    _revoke()


func get_description() -> String:
    return definition.get_description(locked_value) if captured else super()
