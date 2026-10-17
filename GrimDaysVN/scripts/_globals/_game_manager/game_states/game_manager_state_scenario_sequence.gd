extends GameManagerState
## Game-mode script for scenario sequence. Overrides the base state where this mode needs its own
## behavior.
class_name ScenarioSequenceState
## Shared fixed value for wait time.
const WAIT_TIME: float = 50.0
## Remaining delay before this script's timeout handling runs.
var timeout: float = WAIT_TIME


## Runs the parent script’s version of this function with the supplied arguments.
func _ready() -> void:
    super()


## When in the scenario state, but no timeline has been running for WAIT_TIME, this triggers to restart the current
## event.
func on_timeout() -> void:
    CustomLogger.error(self, self.on_timeout, "No timeline after 50 seconds.", 2)
    UIDirector.add_system_message("Lost next event, restarting current event to fix or open menu if no event is found.")
    if GameManager.current_event:
        GameManager.restart_event()
    else:
        UIDirector.menu_operator.fade_in()
    timeout = WAIT_TIME


## On each drawn frame, this function sets [code]timeout[/code] to [code]WAIT_TIME[/code]; decreases
## [code]timeout[/code] by [code]_delta[/code].
func _process(_delta: float) -> void:
    super(_delta)
    if (
        UIDirector.menu_operator.visible
        or (
            get_tree().current_scene is SequencedSceneOperator
            and get_tree().current_scene.animator
            and not get_tree().current_scene.animator.is_playing()
        )
    ):
        timeout = WAIT_TIME
        return
    timeout -= _delta
    if timeout < 1:
        on_timeout()


## Runs the parent script’s version of this function with the supplied arguments.
func _input(_event: InputEvent) -> void:
    super(_event)


## Runs the parent startup behavior and hides navigation controls while this story mode is active.
func on_start() -> void:
    super()
    UIDirector.hide_navigation()
