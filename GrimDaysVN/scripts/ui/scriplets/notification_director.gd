extends Node
class_name NotificationDirector
## Shared fixed value for display delay.
const DISPLAY_DELAY: float = 1.33
## Scene template used to create notification template.
@export var notification_template: PackedScene
## Scene template used to create system message template.
@export var system_message_template: PackedScene
## Remaining time before this script performs its next timed update.
var delay: float = DISPLAY_DELAY
## Whether waiting is currently enabled or true.
var waiting: bool = false
## Whether system message active is currently enabled or true.
var system_message_active: bool = false
# func _ready() -> void:
# 	add_notification("This is a test")
# 	add_notification("of the ability to deal with mutliple")
# 	add_notification("notifications in a row.")


## Passes a system message to the notification display.
func add_system_message(message: String) -> void:
    if system_message_active:
        return
    var parent = get_parent()
    var new_system_message = system_message_template.instantiate()
    new_system_message.set_text(message)
    parent.add_child(new_system_message)
    system_message_active = true
    new_system_message.tree_exited.connect(on_system_message_freed)


## Sets [code]system_message_active[/code] to false.
func on_system_message_freed() -> void:
    system_message_active = false


## Passes a player-facing message to the notification display.
func add_notification(message: String) -> void:
    var new_notification = notification_template.instantiate()
    new_notification.set_text(message)
    new_notification.tree_exited.connect(on_notification_exit)
    add_child(new_notification)


## On each physics update, this function decreases [code]delay[/code] by [code]delta[/code]; sets
## [code]waiting[/code] to false; sets [code]waiting[/code] to true. It pauses for
## [code]current_notification.animator.animation_finished[/code] before continuing.
func _physics_process(delta: float) -> void:
    if get_child_count() < 1:
        return
    var current_notification: NotificationOperator = get_child(0)
    if (
        current_notification.animator.current_animation == "enter_screen"
        or current_notification.animator.current_animation == "exit_screen"
    ):
        return
    delay -= delta
    if delay > 0:
        return
    if waiting:
        current_notification.exit()
        waiting = false
    else:
        current_notification.enter()
        waiting = true
    await current_notification.animator.animation_finished
    delay = DISPLAY_DELAY


## Removes the departing notification from the director's tracking.
func on_notification_exit() -> void:
    if get_child_count() < 1:
        return

    var current_notification: NotificationOperator = get_child(0)
    current_notification.enter()
    waiting = true
