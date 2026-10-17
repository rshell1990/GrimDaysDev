extends Label


# Called when the node enters the scene tree for the first time.
## When the node is ready, this function connects responses to [code]Dialogic.state_changed[/code].
func _ready() -> void:
    Dialogic.state_changed.connect(on_dialogic_state_change)


## Updates the debug label with Dialogic's current state value.
func on_dialogic_state_change(new_state) -> void:
    text = "Dialogic State: " + str(new_state)
