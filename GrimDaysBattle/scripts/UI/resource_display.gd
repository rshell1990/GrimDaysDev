extends TextureProgressBar
## Controls the battle resource display presentation used by the battle interface.
class_name BattleResourceDisplay

## Runtime resource state used by this resource display.
var resource: UnitGenericStat
## Runtime active tween state used by this resource display.
var active_tween: Tween


## Binds resource for this resource display.
func bind_resource(new_resource: UnitGenericStat) -> void:
    _disconnect_resource()
    _stop_tween()
    resource = new_resource
    visible = resource != null
    if not resource:
        return

    min_value = resource.Min
    max_value = resource.Max
    value = resource.Current
    _update_labels()
    resource.value_changed.connect(on_resource_change)


## Handles the resource change notification for this resource display.
func on_resource_change(stat: UnitGenericStat, _old_value: float, new_value: float) -> void:
    if stat != resource:
        return
    min_value = stat.Min
    max_value = stat.Max
    _update_labels()
    _stop_tween()
    active_tween = create_tween()
    active_tween.tween_property(self, "value", new_value, AnimationTimes.FAST)


## Updates labels for this resource display.
func _update_labels() -> void:
    var display_current_shadow: Label = get_node("./MarginContainer/HBoxContainer/Current")
    var display_current: Label = get_node_or_null("./MarginContainer/HBoxContainer/Current/Current2")
    var display_max_shadow: Label = get_node("./MarginContainer/HBoxContainer/Max")
    var display_max: Label = get_node_or_null("./MarginContainer/HBoxContainer/Max/Max2")
    var current_text := str(roundi(resource.Current))
    var max_text := str(roundi(resource.Max))
    display_current_shadow.text = current_text
    if display_current:
        display_current.text = current_text
    display_max_shadow.text = max_text
    if display_max:
        display_max.text = max_text


## Stops tween for this resource display.
func _stop_tween() -> void:
    if active_tween and active_tween.is_valid():
        active_tween.kill()
    active_tween = null


## Disconnects resource for this resource display.
func _disconnect_resource() -> void:
    if resource and resource.value_changed.is_connected(on_resource_change):
        resource.value_changed.disconnect(on_resource_change)


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _disconnect_resource()
    _stop_tween()
