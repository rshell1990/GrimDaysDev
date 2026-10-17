extends Node
class_name SystemMessageOperator

## Scene object used for shadow label.
@export var shadow_label: RichTextLabel
## Scene object used for message label.
@export var message_label: RichTextLabel


## When the node enters the scene, this function waits for a timer through
## [code]SystemHelpers[/code]; schedules this node for deletion. It pauses for
## [code]fade_in()[/code], [code]SystemHelpers.start_timer(2.5)[/code] before continuing.
func _enter_tree() -> void:
    await fade_in()
    await SystemHelpers.start_timer(2.5)
    await fade_out()
    queue_free()


## Sets the text displayed by this notification or system-message control.
func set_text(message: String) -> void:
    shadow_label.text = "[center]" + message + "[/center]"
    message_label.text = "[center]" + message + "[/center]"


## Smoothly changes opacity over time. It pauses for [code]tween.tween_property(self, "modulate:a",
## 1.0, VNAnimationTimes.FAST).finished[/code] before continuing.
func fade_in() -> void:
    var tween = create_tween()
    if not tween:
        tween = create_tween()
    await tween.tween_property(self, "modulate:a", 1.0, VNAnimationTimes.FAST).finished


## Smoothly changes opacity over time. It pauses for [code]tween.tween_property(self, "modulate:a",
## 0.0, VNAnimationTimes.FAST).finished[/code] before continuing.
func fade_out() -> void:
    var tween = create_tween()
    if not tween:
        tween = create_tween()
    await tween.tween_property(self, "modulate:a", 0.0, VNAnimationTimes.FAST).finished
