extends Node
## Notification for on category shown.
signal on_category_shown
## Notification for sub function finished. Supplies [code]menu[/code] to connected functions.
signal sub_function_finished(menu)
## Notification for first run complete. Supplies [code]menu[/code], [code]holder[/code] to connected
## functions.
signal first_run_complete(menu, holder)


## Connects the supplied notification to its response function, using the connection checks in this
## helper.
func listen_for(sent_signal: Signal, sent_callable: Callable):
    if sent_signal.is_connected(sent_callable):
        sent_signal.disconnect(sent_callable)

    sent_signal.connect(sent_callable, CONNECT_ONE_SHOT)


## Forwards the supplied event as [signal on_category_shown] so connected systems can respond.
func _on_category_shown():
    ##SystemHelpers.print("LSB category shown.")
    on_category_shown.emit()


## Forwards the supplied event as [signal sub_function_finished] so connected systems can respond.
func _on_sub_function_finished(menu):
    ##SystemHelpers.print("LSB sub function finished")
    sub_function_finished.emit(menu)


## Forwards the supplied event as [signal first_run_complete] so connected systems can respond.
func _on_first_run_completed(menu, holder):
    ##SystemHelpers.print("LSB first run complete")
    first_run_complete.emit(menu, holder)
