## Provides access to the game clock and routes time-related commands.
class_name TimeAdministrator
extends Node

## Lookup table for starting date; keys select the corresponding stored values.
const STARTING_DATE: Dictionary = {"year": 2006, "month": 10, "day": 13}

## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary
## Helper responsible for carrying out this system’s requests.
var director: TimeDirector


## Finds the time director and returns its current time-of-day choice.
func current_time() -> TIMES:
    get_director()
    return director.time_id


## Finds the time director and returns its current date object.
func current_day() -> Calendar.Date:
    get_director()
    return director.date


## Finds the time director and returns its formatted day number and suffix.
func date_string() -> String:
    get_director()
    return director.get_date_string()


## Finds the time director and returns its current weekday choice.
func current_day_id() -> Time.Weekday:
    get_director()
    return director.day_id


## Finds the time director and returns the current week number.
func current_week() -> int:
    get_director()
    return director.week


## Finds the time director used to read or change the game clock.
func get_director() -> void:
    if director == null:
        director = get_child(0)


## Waits for any dialogue animation, then dispatches the named time command to its handler.
func command(args: Variant) -> void:
    var type = args[Basics.FIRST].split(Basics.COLON)[Basics.FIRST].to_lower()
    if Dialogic.Animations.is_animating():
        await Dialogic.Animations.finished
    handle_command_by_type[type].call(args)


## Passes the requested time-of-day value to the game-clock system.
func jump_to_time(new_time: Variant) -> void:
    director.jump_to_time(new_time)


## Asks the game-clock system to move to the next time period.
func advance_time() -> void:
    get_director()
    director.advance_time()


## Finds the time director and forwards the saved data in the second argument.
func on_load(args: Array[Variant]) -> void:
    get_director()
    director.on_load(args[1])


## Finds this system’s helper nodes, registers its command handlers and connects the notifications
## it responds to.
func _ready() -> void:
    get_director()
    handle_command_by_type = {
        SystemHeadquarters.LOADING: on_load,
    }


## Returns the current weekday's readable name through the time director.
func get_day_as_string() -> String:
    get_director()
    return director.get_day_as_string()


## Returns the weekday name for the supplied date through the time director.
func get_day_name_from_date(date: Calendar.Date) -> String:
    get_director()
    return director.get_day_name_from_date(date)


## Named choices for times: [code]Dawn[/code], [code]Morning[/code], [code]Afternoon[/code],
## [code]Evening[/code], [code]Night[/code], [code]Bedtime[/code].
enum TIMES { Dawn, Morning, Afternoon, Evening, Night, Bedtime }

## Lookup table for times to string; keys select the corresponding stored values.
const TIMES_TO_STRING: Dictionary = {
    TIMES.Dawn: "Dawn",
    TIMES.Morning: "Morning",
    TIMES.Afternoon: "Afternoon",
    TIMES.Evening: "Evening",
    TIMES.Night: "Night",
    TIMES.Bedtime: "Bedtime"
}


## Returns the readable name for the supplied time-of-day choice, or "Invalid" if it has no mapping.
static func get_time_string(time: TIMES) -> String:
    if TIMES_TO_STRING.has(time):
        return TIMES_TO_STRING[time]

    return "Invalid"


## Converts a time name case-insensitively; unknown names fall back to Dawn.
static func time_string_to_id(string_id: String) -> TIMES:
    var id: String = string_id.capitalize()
    match id:
        "Morning":
            return TIMES.Morning
        "Afternoon":
            return TIMES.Afternoon
        "Evening":
            return TIMES.Evening
        "Night":
            return TIMES.Night
        "Bedtime":
            return TIMES.Bedtime
    return TIMES.Dawn


## List of days used by this script.
const DAYS: Array[Time.Weekday] = [
    Time.Weekday.WEEKDAY_SUNDAY,
    Time.Weekday.WEEKDAY_MONDAY,
    Time.Weekday.WEEKDAY_TUESDAY,
    Time.Weekday.WEEKDAY_WEDNESDAY,
    Time.Weekday.WEEKDAY_THURSDAY,
    Time.Weekday.WEEKDAY_FRIDAY,
    Time.Weekday.WEEKDAY_SATURDAY,
]
