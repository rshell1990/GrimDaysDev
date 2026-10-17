## Keeps the current date and time of day and restores them from saved data.
class_name TimeDirector
extends Node

## Notification for restored.
signal restored

## Key used to identify this script’s data in saved state.
var save_name: String = "in_game_time"
## Stored time operator used by this script’s update and input handling.
var time_operator: TimeOperator
## Stored calendar operator used by this script’s update and input handling.
var calendar_operator: CalendarOperator
## Stored full calendar used by this script’s update and input handling.
var full_calendar: Calendar = Calendar.new()

## Stored day id used by this script’s update and input handling.
var day_id: Time.Weekday = Time.Weekday.WEEKDAY_FRIDAY
## Stored time id used by this script’s update and input handling.
var time_id: TimeAdministrator.TIMES = TimeAdministrator.TIMES.Dawn
## Stored date used by this script’s update and input handling.
var date: Calendar.Date

## Stored week used by this script’s update and input handling.
var week:
    get():
        if date == null:
            return 1
        return full_calendar.get_week_number(date.year, date.month, date.day)


## Returns the day of the month followed by its suffix, such as 1st or 22nd.
func get_date_string() -> String:
    var date_string = ""

    date_string = str(date.day) + get_day_ending(date.day)

    return date_string


## Returns the weekday name corresponding to the supplied calendar date.
@warning_ignore("shadowed_variable")
func get_day_name_from_date(date: Calendar.Date) -> String:
    return full_calendar.get_weekday_formatted(date.year, date.month, date.day)


## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)


## When the node is ready, this function connects responses to [code]VNSignalBus.on_load[/code],
## [code]VNSignalBus.time_passed[/code], [code]calendar_operator.change_day[/code],
## [code]VNSignalBus.reset_sub_systems[/code]; sets [code]time_operator[/code] to
## [code]get_child(0)[/code]; sets [code]calendar_operator[/code] to [code]get_child(1)[/code].
func _ready() -> void:
    date = Calendar.Date.new(
        TimeAdministrator.STARTING_DATE.year, TimeAdministrator.STARTING_DATE.month, TimeAdministrator.STARTING_DATE.day
    )
    time_operator = get_child(0)
    calendar_operator = get_child(1)
    VNSignalBus.on_load.connect(on_load)
    VNSignalBus.time_passed.connect(on_time_changed)
    calendar_operator.change_day.connect(on_day_changed)
    VNSignalBus.reset_sub_systems.connect(reset)


## Passes the requested time-of-day value to the game-clock system.
func jump_to_time(new_time: Variant) -> void:
    time_operator.jump_to_time(new_time)


## Asks the game-clock system to move to the next time period.
func advance_time():
    time_operator.advance_time()


## Remembers the newly selected time of day.
func on_time_changed(_old_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES) -> void:
    time_id = new_time


## Remembers the new weekday and advances the calendar date by one day.
func on_day_changed(new_day: Time.Weekday) -> void:
    day_id = new_day
    date.add_days(1)


## Returns the readable weekday name for the current calendar date.
func get_day_as_string() -> String:
    return full_calendar.get_weekday_formatted(date.year, date.month, date.day)


## Returns the date suffix, such as "st" for 1, or an empty string when the day has no entry.
func get_day_ending(day: int) -> String:
    for ending in DAY_ENDINGS.keys():
        if day in DAY_ENDINGS[ending]:
            return ending

    return ""


#region SAVE / LOAD
## Returns the current calendar date, weekday and time-of-day choice for saving.
func _get_state() -> Dictionary:
    var split_date: Dictionary = {"year": date.year, "month": date.month, "day": date.day}
    var state = {"date": split_date, "day_id": day_id, "time_id": time_id}
    CustomLogger.confirm(self, _get_state, "is returning state: " + str(state), CustomLogger.LEVEL.MILD)
    return state


## Reads the saved weekday and time-of-day choice. This path currently does not restore the calendar
## date or notify the time operator.
@warning_ignore("unused_parameter")
func on_load(saved_data: Dictionary) -> void:
    SystemHelpers.print_rich("[b][u]TIME DIRECTOR LOADING: ")
    #var split_date = saved_data.info[save_name].date.split("-")
    #date = Calendar.Date.new(int(split_date[0]),int(split_date[1]),int(split_date[2]))
    #

    day_id = saved_data.info[save_name].day_id
    # SystemHelpers.print("Saved Time: ", saved_data.info[save_name].time_id)
    # time_operator.jump_to_time(saved_data.info[save_name].time_id)
    time_id = saved_data.info[save_name].time_id


## Restores the saved date and time directly without advancing the calendar or playing time passage.
## Broadcasts an unchanged-time refresh so existing backgrounds, lights and UI show the restored time.
func restore(data: Dictionary) -> void:
    if data.date is Dictionary:
        date = Calendar.Date.new(data.date.year, data.date.month, data.date.day)
    day_id = data.day_id
    time_id = data.time_id
    VNSignalBus.time_passed.emit(time_id, time_id)
    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()


#endregion

## Shared fixed value for day endings.
const DAY_ENDINGS = {
    "st": [1, 21, 31],
    "nd": [2, 22],
    "rd": [3, 23],
    "th": [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 24, 25, 26, 27, 28, 29, 30]
}


## Sets [code]day_id[/code] to [code]Time.Weekday.WEEKDAY_FRIDAY[/code]; sets [code]time_id[/code]
## to [code]TimeAdministrator.TIMES.Dawn[/code].
func reset() -> void:
    CustomLogger.warn(
        self, self.reset, " is resetting - date, day_id, and time_id will be set to default.", CustomLogger.LEVEL.MILD
    )
    date = Calendar.Date.new(
        TimeAdministrator.STARTING_DATE.year, TimeAdministrator.STARTING_DATE.month, TimeAdministrator.STARTING_DATE.day
    )
    day_id = Time.Weekday.WEEKDAY_FRIDAY
    time_id = TimeAdministrator.TIMES.Dawn
