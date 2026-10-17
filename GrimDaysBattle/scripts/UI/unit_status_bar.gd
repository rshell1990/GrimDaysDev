extends Control
## Controls the unit status bar presentation used by the battle interface.
class_name UnitStatusBar

## Configures the name label used by this unit status bar.
@export var name_label: Label
## Configures the health bar used by this unit status bar.
@export var health_bar: TextureProgressBar
## Runtime unit reference state used by this unit status bar.
var unit_reference: BattleUnit
## Runtime health resource state used by this unit status bar.
var health_resource: UnitGenericStat
## Ordered runtime collection of active tweens.
var active_tweens: Array[Tween]


## Initializes initialize for this unit status bar.
func initialize(unit: BattleUnit) -> void:
    _disconnect_health_resource()
    _stop_tweens()
    unit_reference = unit
    health_resource = unit_reference.get_stat(CombatStats.STATS.Health) if unit_reference else null
    if not health_resource:
        health_bar.visible = false
        return
    health_bar.visible = true
    health_bar.min_value = 0.0
    health_bar.max_value = 1.0
    health_bar.step = 0.001
    health_bar.value = health_resource.ratio
    health_resource.value_changed.connect(on_health_resource_change)
    name_label.text = unit_reference.template_resource.display_name


## Handles the health resource change notification for this unit status bar.
func on_health_resource_change(stat: UnitGenericStat, _old_value: float, _new_value: float) -> void:
    if stat != health_resource:
        return
    _stop_tweens()
    var tween = create_tween()
    active_tweens.append(tween)
    tween.tween_property(health_bar, "value", stat.ratio, AnimationTimes.STANDARD)


## Stops tweens for this unit status bar.
func _stop_tweens() -> void:
    for x in range(active_tweens.size() - 1, -1, -1):
        if active_tweens[x] and active_tweens[x].is_valid():
            active_tweens[x].kill()
        active_tweens.remove_at(x)


## Disconnects health resource for this unit status bar.
func _disconnect_health_resource() -> void:
    if health_resource and health_resource.value_changed.is_connected(on_health_resource_change):
        health_resource.value_changed.disconnect(on_health_resource_change)
    health_resource = null


## Releases owned state and signal-driven effects before this node leaves the scene tree.
func _exit_tree() -> void:
    _disconnect_health_resource()
    _stop_tweens()
