extends Node
class_name SuperSignal
#region SIGNALS
## Notification for time ran out.
signal time_ran_out
## Notification for tracking finished.
signal tracking_finished
#endregion

#region VARS
## Whether tracking is currently enabled or true.
var tracking: bool
## Seconds remaining before the tracked signal is treated as timed out.
var time_to_wait: float
## Notification currently being watched for completion.
var saved_signal: Signal
#endregion


## On each drawn frame, this function decreases [code]time_to_wait[/code] by [code]delta[/code];
## sets [code]tracking[/code] to false; sends [code]time_ran_out[/code] notifications.
func _process(delta: float) -> void:
    if not tracking:
        return
    time_to_wait -= delta
    if time_to_wait < 0:
        tracking = false
        time_ran_out.emit()


## Starts watching the supplied notification with a timeout; either the signal or elapsed time can
## finish tracking.
func start_tracking_time_or_signal(incoming_signal: Signal, timer: float) -> void:
    tracking = true
    time_to_wait = timer
    saved_signal = incoming_signal
    saved_signal.connect(signal_tracking_finish)
    time_ran_out.connect(signal_tracking_finish)


## Stops tracking the watched signal and announces that tracking finished.
func signal_tracking_finish() -> void:
    tracking_finished.emit()
    saved_signal.disconnect(signal_tracking_finish)
    time_ran_out.disconnect(signal_tracking_finish)
