extends Node
class_name NotificationOperator

## Scene object used for label.
@export var label: RichTextLabel
## Scene node used for animator, found when this node is ready.
@onready var animator: AnimationPlayer = %Animator


## Sets the text displayed by this notification or system-message control.
func set_text(message: String) -> void:
    label.text = message


## Starts playback on [code]animator[/code].
func enter() -> void:
    animator.play("enter_screen")


## Starts playback on [code]animator[/code]; schedules this node for deletion. It pauses for
## [code]animator.animation_finished[/code] before continuing.
func exit() -> void:
    animator.play("exit_screen")
    await animator.animation_finished
    queue_free()
