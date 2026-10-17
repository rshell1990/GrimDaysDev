extends Control
## Coordinates used for start position.
var start_position: Vector2 = Vector2(1920, 0)
## Notification for first run complete. Supplies [code]emitter[/code], [code]menu[/code],
## [code]holder[/code] to connected functions.
signal first_run_complete(emitter, menu, holder)


## Returns the position where this menu begins before it moves on-screen.
func get_start_position() -> Vector2:
    return start_position


## Connects responses to [code]LocalSignalBus.sub_function_finished[/code]; sets
## [code]menu.input_caller[/code] to [code]menu[/code].
func first_run(menu):
    %LocalSignalBus.listen_for(first_run_complete, %LocalSignalBus._on_first_run_completed)
    %LocalSignalBus.sub_function_finished.connect(first_run_completed, CONNECT_ONE_SHOT)

    menu.input_caller = menu
    menu.on_input("1")


## Sends [code]first_run_complete[/code] notifications.
func first_run_completed(menu):
    first_run_complete.emit(menu, self)
