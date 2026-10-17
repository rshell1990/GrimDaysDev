## Advances between named times of day and announces time/day changes.
class_name TimeOperator
extends Node

## Emitted when the time changes.
signal time_changed(old_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES)

## Emitted when day changes to dawn.
signal day_passed

## Stored old time used by this script’s update and input handling.
var old_time: TimeAdministrator.TIMES = TimeAdministrator.TIMES.Dawn


## Connects local day/time changes to the shared notifications other systems listen for.
func _ready() -> void:
    VNSignalBus.listen_for(day_passed, VNSignalBus.on_day_passed)
    VNSignalBus.listen_for(time_changed, VNSignalBus.on_time_change)


## Based upon the current time, advances to the time that follows after.
func advance_time() -> void:
    SystemHelpers.print("ADVANCE")
    old_time = SystemAdministrators.current_time()
    SystemHelpers.print(old_time)
    match old_time:
        TimeAdministrator.TIMES.Dawn:
            advance_to_morning()
        TimeAdministrator.TIMES.Morning:
            advance_to_afternoon()
        TimeAdministrator.TIMES.Afternoon:
            advance_to_evening()
        TimeAdministrator.TIMES.Evening:
            advance_to_night()
        TimeAdministrator.TIMES.Night:
            advance_to_bedtime()
        TimeAdministrator.TIMES.Bedtime:
            advance_to_dawn()


## Changes the time to the specified period of the day.
func jump_to_time(new_time: Variant) -> void:
    old_time = SystemAdministrators.current_time()
    var new_time_id = TimeAdministrator.time_string_to_id(new_time) if new_time is String else new_time
    match new_time_id:
        TimeAdministrator.TIMES.Dawn:
            advance_to_dawn()
        TimeAdministrator.TIMES.Morning:
            advance_to_morning()
        TimeAdministrator.TIMES.Afternoon:
            advance_to_afternoon()
        TimeAdministrator.TIMES.Evening:
            advance_to_evening()
        TimeAdministrator.TIMES.Night:
            advance_to_night()
        TimeAdministrator.TIMES.Bedtime:
            advance_to_bedtime()


## Announces a change from the current time of day to Dawn.
func advance_to_dawn() -> void:
    day_passed.emit()
    time_changed.emit(old_time, TimeAdministrator.TIMES.Dawn)


## Announces a change from the current time of day to Morning.
func advance_to_morning() -> void:
    time_changed.emit(old_time, TimeAdministrator.TIMES.Morning)


## Announces a change from the current time of day to Afternoon.
func advance_to_afternoon() -> void:
    time_changed.emit(old_time, TimeAdministrator.TIMES.Afternoon)


## Announces a change from the current time of day to Evening.
func advance_to_evening() -> void:
    time_changed.emit(old_time, TimeAdministrator.TIMES.Evening)


## Announces a change from the current time of day to Night.
func advance_to_night() -> void:
    time_changed.emit(old_time, TimeAdministrator.TIMES.Night)


## Announces a change from the current time of day to Bedtime.
func advance_to_bedtime() -> void:
    time_changed.emit(old_time, TimeAdministrator.TIMES.Bedtime)
