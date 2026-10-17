@tool
extends DialogicLayoutLayer

## A layer that holds a full-screen input catcher.
func _ready() -> void:
	Dialogic.Choices.question_shown.connect(on_questions_shown)
	Dialogic.Choices.choice_selected.connect(on_choice_selected)
	
func on_questions_shown(_info) -> void:
	get_child(0).visible = false

func on_choice_selected(_info) -> void:
	get_child(0).visible = true
