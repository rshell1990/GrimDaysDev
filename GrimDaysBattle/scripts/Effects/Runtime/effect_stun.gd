extends EffectBase
## Prevents new actions; resolving actions finish. Normal lifetime/removal releases the stun.
class_name EffectStun

var active: bool = false


func apply() -> void:
    if not _begin_apply():
        return
    active = targeting is BattleUnit
    if active:
        targeting.forced_action_changed.emit()
    _finish_apply()


func _revoke() -> void:
    active = false
    if is_instance_valid(targeting) and targeting is BattleUnit:
        targeting.forced_action_changed.emit()


func _exit_tree() -> void:
    _revoke()
