#region PLAYTIME MANAGER
extends PersistentSystemManager
#class_name PlaytimeSystemManager
#endregion
## Time value used when calculating elapsed play time; see the update and conversion functions in
## this script.
var start_ticks: int
## Time value used when calculating elapsed play time; see the update and conversion functions in
## this script.
var time_passed

## Key used to identify this script’s data in saved state.
var save_name: String = "playtime_manager"

## Elapsed play time expressed in seconds.
var seconds_passed:
    get():
        return (time_passed + start_ticks) / 1000
## Elapsed play time expressed in minutes.
var minutes_passed:
    get():
        return seconds_passed / 60
## Elapsed play time expressed in hours.
var hours_passed:
    get():
        return minutes_passed / 60


## On each physics update, this function updates [code]time_passed[/code] using
## [code]Time.get_ticks_msec[/code].
func _physics_process(_delta: float) -> void:
    time_passed = Time.get_ticks_msec()


## Returns total elapsed play time under the playtime key for saving.
func _get_state() -> Dictionary:
    var data: Dictionary = {
        "playtime": time_passed + start_ticks,
    }
    return data
