extends Label


# Called when the node enters the scene tree for the first time.
## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _ready() -> void:
    pass  # Replace with function body.


## Updates the label with the game manager's formatted elapsed play time.
func _physics_process(_delta: float) -> void:
    text = GameManager.get_time_played()
