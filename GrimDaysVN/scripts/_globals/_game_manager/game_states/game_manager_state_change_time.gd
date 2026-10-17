extends GameManagerState
## Game-mode script for change time. Overrides the base state where this mode needs its own
## behavior.
class_name TimeChangeState

## Time of day shown before the time-change transition begins.
var start_time: TimeAdministrator.TIMES = TimeAdministrator.TIMES.Dawn
var _was_paused: bool = false


## Runs the parent script’s version of this function with the supplied arguments.
func _ready() -> void:
    super()


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _process(_delta: float) -> void:
    pass


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _input(_event: InputEvent) -> void:
    pass


## Covers the screen; sets [code]Dialogic.paused[/code] to true.
func on_start() -> void:
    super()
    CustomLogger.warn(self, self.on_start, " is pausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    _was_paused = Dialogic.paused
    Dialogic.paused = true
    UIDirector.show_time_passage(start_time, SystemAdministrators.current_time(), parent.revision)


## Cancels this visit's visuals and restores its prior pause; never changes state.
func on_end() -> void:
    super()
    UIDirector.time_passage_ui.cancel_passage()
    Dialogic.paused = _was_paused
