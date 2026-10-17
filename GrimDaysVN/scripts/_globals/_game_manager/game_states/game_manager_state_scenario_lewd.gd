extends GameManagerState
## Game-mode script for scenario lewd. Overrides the base state where this mode needs its own
## behavior.
class_name ScenarioLewdState


## Runs the parent script’s version of this function with the supplied arguments.
func _ready() -> void:
    super()


## Runs the parent script’s version of this function with the supplied arguments.
func _process(_delta: float) -> void:
    super(_delta)


## Runs the parent script’s version of this function with the supplied arguments.
func _input(_event: InputEvent) -> void:
    super(_event)


## Runs the parent startup behavior and hides navigation controls while this story mode is active.
func on_start() -> void:
    super()
    UIDirector.hide_navigation()
