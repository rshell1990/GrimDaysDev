extends MarginContainer


# Called when the node enters the scene tree for the first time.
## When the node is ready, this function sets [code]parent.process_mode[/code] to
## [code]PROCESS_MODE_DISABLED[/code]; sets [code]parent.disabled[/code] to true.
func _ready() -> void:
	var parent = get_parent()
	if GameManager.state == GameManagerStates.STATES.BeforeGame:
		parent.process_mode = PROCESS_MODE_DISABLED
		parent.disabled = true
