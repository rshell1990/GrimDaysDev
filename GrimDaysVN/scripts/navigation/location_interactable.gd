extends Node3D
## Controls when a scene interaction is visible and tracks pointer entry and exit.
class_name NavigationInteractable

## Notification for activated. Supplies [code]target[/code] to connected functions.
signal activated(target)

## Scene object used for area.
@export var area: CollisionObject3D
## Scene object used for extra area.
@export var extra_area: CollisionObject3D
## Whether to show this interaction without restricting it to the configured days and times.
@export var always_visible: bool = true
## Times of day at which this interaction is allowed to appear.
@export var times_visible: Array[TimeAdministrator.TIMES]
## Weekdays on which this interaction is allowed to appear.
@export var days_visible: Array[Time.Weekday]
## Additional requirements that must be met for this interaction to be available.
@export var other_conditions: Array[VNRequirement]

## Whether active is currently enabled or true.
@export var active: bool = false


## When the node is ready, this function connects responses to [code]area.mouse_entered[/code],
## [code]area.mouse_exited[/code], [code]extra_area.mouse_entered[/code],
## [code]extra_area.mouse_exited[/code].
func _ready():
    if !_get_is_visible():
        visible = false
        return
    visible = true
    area.mouse_entered.connect(_on_area_3d_mouse_entered)
    area.mouse_exited.connect(_on_area_3d_mouse_exited)
    if extra_area == null:
        return
    extra_area.mouse_entered.connect(_on_area_3d_mouse_entered)
    extra_area.mouse_exited.connect(_on_area_3d_mouse_exited)


## Returns true when always-visible is enabled, or when the day, time and every extra requirement
## allow this interaction.
func _get_is_visible() -> bool:
    if always_visible:
        return true

    if check_correct_time() and check_correct_day() and check_correct_conditions():
        return true

    return false


## Returns whether the current time of day appears in the allowed times.
func check_correct_time() -> bool:
    for time in times_visible:
        if time == SystemAdministrators.current_time():
            return true
    CustomLogger.hint(self, check_correct_time, "Incorrect time to display interactable.",
            CustomLogger.LEVEL.MILD)
    return false


## Returns whether the current weekday appears in the allowed days.
func check_correct_day() -> bool:
    if SystemAdministrators.current_day_id() in days_visible:
        return true
    CustomLogger.hint(self, check_correct_day, "Incorrect day to display interactable.",
            CustomLogger.LEVEL.MILD)
    return false


## Returns true only when every configured extra requirement is met. An empty requirement list
## passes.
func check_correct_conditions() -> bool:
    for condition in other_conditions:
        if not condition.has_requirement():
            CustomLogger.hint(self, check_correct_conditions, str(condition) + " is not met.",
                    CustomLogger.LEVEL.MILD)
            return false
    return true


## Runs the interaction area's pointer-entry behavior and marks this interaction active.
func _on_area_3d_mouse_entered(_hit = null) -> void:
    area.on_enter()
    active = true


## Runs the interaction area's pointer-exit behavior and marks this interaction inactive.
func _on_area_3d_mouse_exited(_hit = null) -> void:
    area.on_exit()
    active = false
