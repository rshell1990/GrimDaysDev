## Advances weekday state and announces when the day changes.
class_name CalendarOperator
extends Node

## Notification for change day. Supplies [code]new_day[/code] to connected functions.
signal change_day(new_day: Time.Weekday)
## Notification for updated day.
signal updated_day


## When the node is ready, this function connects responses to [code]VNSignalBus.day_passed[/code].
func _ready() -> void:
    VNSignalBus.day_passed.connect(advance_to_next_day)
    VNSignalBus.listen_for(updated_day, VNSignalBus.on_day_updated)


## Moves the calendar to the next weekday and announces the change.
func advance_to_next_day(current_day: Time.Weekday) -> void:
    match current_day:
        Time.Weekday.WEEKDAY_MONDAY:
            change_day.emit(Time.Weekday.WEEKDAY_TUESDAY)
        Time.Weekday.WEEKDAY_TUESDAY:
            change_day.emit(Time.Weekday.WEEKDAY_WEDNESDAY)
        Time.Weekday.WEEKDAY_WEDNESDAY:
            change_day.emit(Time.Weekday.WEEKDAY_THURSDAY)
        Time.Weekday.WEEKDAY_THURSDAY:
            change_day.emit(Time.Weekday.WEEKDAY_FRIDAY)
        Time.Weekday.WEEKDAY_FRIDAY:
            change_day.emit(Time.Weekday.WEEKDAY_SATURDAY)
        Time.Weekday.WEEKDAY_SATURDAY:
            change_day.emit(Time.Weekday.WEEKDAY_SUNDAY)
        Time.Weekday.WEEKDAY_SUNDAY:
            change_day.emit(Time.Weekday.WEEKDAY_MONDAY)

    await get_tree().create_timer(0.03).timeout
    updated_day.emit()
