extends Label


## Shows the selected font scale as a percentage, with 1 displayed as 100%.
func _on_h_slider_value_changed(value: float) -> void:
    text = str(value * 100) + "%" if value != 1 else "100%"
