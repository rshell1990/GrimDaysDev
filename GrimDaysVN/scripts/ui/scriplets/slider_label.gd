extends Label
class_name SliderPercentLabel
## Parent slider whose changes are displayed used by this node.
var parent: HSlider


## When the node is ready, this function connects responses to [code]parent.value_changed[/code];
## sets [code]parent[/code] to [code]get_parent()[/code].
func _ready() -> void:
    parent = get_parent()
    parent.value_changed.connect(on_value_changed)


## Displays the slider's fractional value as a percentage.
func on_value_changed(value: float) -> void:
    text = str(value * 100) + "%"
