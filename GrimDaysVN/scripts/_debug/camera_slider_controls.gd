extends HSlider
## File or resource path used for camera value path.
@export var camera_value_path: String


## When the node is ready, this function connects responses to [code]value_changed[/code].
func _ready() -> void:
    value_changed.connect(on_value_changed)
    on_value_changed(value)


## Smoothly changes the configured test-camera property to the slider’s new value.
func on_value_changed(new_value) -> void:
    var node_path = camera_value_path as NodePath
    var tween = create_tween()
    tween.tween_property(%"Test Camera", node_path, new_value, VNAnimationTimes.FAST)
