extends MarginContainer

## Starting position of the options panel before its entrance movement.
var start_position = Vector2(1920, -135)
## Notification for first run complete. Supplies [code]emitter[/code], [code]menu[/code],
## [code]holder[/code] to connected functions.
signal first_run_complete(emitter, menu, holder)


## Returns the position where this menu begins before it moves on-screen.
func get_start_position() -> Vector2:
    return start_position


## Connects the first-run completion notification to the local menu handler and starts the
## completion behavior.
func first_run(menu):
    %LocalSignalBus.listen_for(first_run_complete, %LocalSignalBus._on_first_run_completed)
    first_run_completed(menu)


## Sends [code]first_run_complete[/code] notifications.
func first_run_completed(menu):
    first_run_complete.emit(menu, self)
