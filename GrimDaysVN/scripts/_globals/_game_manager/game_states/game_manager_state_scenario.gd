extends GameManagerState
## Game-mode script for scenario. Overrides the base state where this mode needs its own behavior.
class_name ScenarioState

## Shared fixed value for wait time.
const WAIT_TIME: float = 50.0
## Remaining delay before this script's timeout handling runs.
var timeout: float = WAIT_TIME


## Runs the parent script’s version of this function with the supplied arguments.
func _ready() -> void:
    super()


## Checks that this game mode is active before allowing its input or update handling to continue.
func _process(_delta: float) -> void:
    if _guard_clause():
        return


## Checks that this game mode is active before allowing its input or update handling to continue.
func _input(_event: InputEvent) -> void:
    if _guard_clause():
        return


## Runs the parent startup behavior and hides navigation controls while this story mode is active.
func on_start() -> void:
    super()
    UIDirector.hide_navigation()


## Runs the parent script’s version of this function with the supplied arguments.
func on_end() -> void:
    super()
