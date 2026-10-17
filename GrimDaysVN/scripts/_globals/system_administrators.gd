extends Node
class_name SystemAdministratorsBase
#region SYSTEM ADMINS
## Autoloaded script to provide access to the functions of the various administrators to the
## other scripts.
#endregion

## Story place names available even before their navigation scenes are authored.
const STORY_LOCATION_NAMES: Dictionary[StringName, String] = {
    &"Gerano": "Gerano",
    &"Novaras": "Novaras",
    &"Puran": "Puran",
    &"Hamun": "Hamun",
    &"HamunPaleDragon": "Pale Dragon",
    &"HamunArena": "Hamun Arena",
    &"NovarasGreedyCat": "Greedy Cat",
    &"OrasomoreIslands": "Orasomore Islands"
}

#region VARS
## Administrator that handles location and dimension requests.
var navigation_admin: NavigationAdministrator
## Administrator that handles game-clock and calendar requests.
var time_admin: TimeAdministrator
## Administrator that finds and starts story events.
var game_event_admin: EventAdministrator
## Administrator that looks up and updates quests.
var quest_admin: QuestAdministrator
## Administrator that selects and controls dynamic songs.
var song_admin: OvaniSongsAdministrator
## Administrator that places and updates story characters.
var character_admin: CharacterSpriteAdministrator
## Administrator that handles dialogue checkpoint and rollback requests.
var rollback_admin: RollbackAdministrator
## Administrator that routes scene camera requests.
var camera_admin: CameraAdministrator
#endregion


## TODO: Add more functions that may change and be required in multiple parts
## of the script as part of the refactoring process.
func set_admins() -> void:
    navigation_admin = SystemHeadquarters.get_admin(AdministratorTypes.NAVIGATION)
    time_admin = SystemHeadquarters.get_admin(AdministratorTypes.TIME)
    game_event_admin = SystemHeadquarters.get_admin(AdministratorTypes.EVENTS)
    quest_admin = SystemHeadquarters.get_admin(AdministratorTypes.QUEST)
    song_admin = SystemHeadquarters.get_admin(AdministratorTypes.SONG)
    character_admin = SystemHeadquarters.get_admin(AdministratorTypes.CHARACTER)
    rollback_admin = SystemHeadquarters.get_admin(AdministratorTypes.ROLLBACK)
    camera_admin = SystemHeadquarters.get_admin(AdministratorTypes.CAMERA)


#region ROLLBACK ADMIN


## Passes the current state to the rollback system to remember for a later restore.
func set_current_rollback_data(new_data: Dictionary) -> void:
    rollback_admin.set_current_rollback_data(new_data)


## Returns the state currently remembered by the rollback system.
func get_current_rollback_data() -> Dictionary:
    return rollback_admin.get_current_rollback_data()


#endregion


#region CHARACTER SPRITE ADMIN
## Registers a named character display layer with the character system.
func add_depths(depth_name: String, sent_depth: DepthOperator) -> void:
    if not character_admin:
        return
    character_admin.add_depths(depth_name, sent_depth)


## Removes a named character display layer from the character system's lookup.
func remove_depths(depth_name: String) -> void:
    character_admin.remove_depths(depth_name)


#endregion


#region NAVIGATION ADMIN
## Returns the current navigation location ID.
func current_location() -> StringName:
    return navigation_admin.current_location()


## Changes the current location through [code]navigation_admin[/code].
func set_location(id: StringName) -> void:
    navigation_admin.set_location(id)


## Uses authored display names first, then story names and readable legacy navigation IDs.
func get_location_as_string(location: StringName) -> String:
    var info: NavigationLocation = Repositories.get_info(RepositoryTypes.LOCATIONS, location)
    if info:
        return info.display_name
    if STORY_LOCATION_NAMES.has(location):
        return STORY_LOCATION_NAMES[location]
    if location in NavigationAdministrator.LOCATIONS:
        return String(location).capitalize()
    CustomLogger.warn(
        self,
        get_location_as_string,
        "Unknown location ID: %s" % location,
        CustomLogger.LEVEL.IMPORTANT
    )
    return "Unknown location"


## Resolves IDs or display names, ignoring case and surrounding whitespace.
## Unknown aliases are logged.
func get_location_from_alias(alias: String) -> StringName:
    var repository: Dictionary = Repositories.get_repository(RepositoryTypes.LOCATIONS).master
    var normalized := alias.strip_edges()
    if not normalized.is_empty():
        for info: NavigationLocation in repository.values():
            if (
                normalized.nocasecmp_to(String(info.id)) == 0
                or normalized.nocasecmp_to(info.display_name) == 0
            ):
                return info.id
        for id: StringName in STORY_LOCATION_NAMES:
            if (
                normalized.nocasecmp_to(String(id)) == 0
                or normalized.nocasecmp_to(STORY_LOCATION_NAMES[id]) == 0
            ):
                return id
        for id: StringName in NavigationAdministrator.LOCATIONS:
            if (
                normalized.nocasecmp_to(String(id)) == 0
                or normalized.nocasecmp_to(String(id).capitalize()) == 0
            ):
                return id
    CustomLogger.warn(
        self,
        get_location_from_alias,
        "Unknown location alias: '%s'." % alias,
        CustomLogger.LEVEL.IMPORTANT
    )
    return &""


## Returns the Dark dimension for the exact name "Dark"; all other names select Prime.
func get_dimension_from_alias(alias: String) -> NavigationAdministrator.DIMENSIONS:
    if alias == "Dark":
        return NavigationAdministrator.DIMENSIONS.DARK

    return NavigationAdministrator.DIMENSIONS.PRIME


## Creates and returns the background scene for the current location.
func get_background() -> Node:
    var location: NavigationLocation = Repositories.get_info(
        RepositoryTypes.LOCATIONS, current_location()
    )
    var background: Node = location.background.instantiate()

    return background


## Returns the foreground scene templates listed for the current location.
func get_foreground_objects() -> Array[PackedScene]:
    var location: NavigationLocation = Repositories.get_info(
        RepositoryTypes.LOCATIONS, current_location()
    )
    return location.foreground_objects


## Returns the current dimension as the DIMENSIONS enum.
func current_dimension() -> NavigationAdministrator.DIMENSIONS:
    if not navigation_admin:
        set_admins()
    assert(navigation_admin)
    return navigation_admin.current_dimension()


#endregion


#region TIME ADMIN
## Returns the current time period, Dawn/Morning/etc, as the TIMES enum.
func current_time() -> TimeAdministrator.TIMES:
    return time_admin.current_time()


## Returns the current day, Monday/Tuesday/etc, as the DAYS enum.
func current_day() -> Calendar.Date:
    return time_admin.current_day()


## Returns the current weekday choice through the time administrator.
func current_day_id() -> Time.Weekday:
    return time_admin.current_day_id()


## Returns the formatted current date through the time administrator.
func date_string() -> String:
    return time_admin.date_string()


## Returns the name of the day from the supplied date.
func get_day_name(date: Calendar.Date) -> String:
    return time_admin.get_day_name_from_date(date)


## Returns the current day as a string.
func get_day_as_string() -> String:
    return time_admin.get_day_as_string()


## Returns the number of in-game days that have passed since the start of the game.
func current_days() -> int:
    return time_admin.current_days()


## Returns the number of in-game weeks that have passed since the start of the game as an integer.
func current_week() -> int:
    return time_admin.current_week()


## Returns the number of in-game weeks passed since the start of the game as a string.
func get_week_as_string() -> String:
    return str(time_admin.current_week())


## Passes the requested time-of-day value to the game-clock system.
func jump_to_time(new_time: Variant) -> void:
    time_admin.jump_to_time(new_time)


## Asks the game-clock system to move to the next time period.
func advance_time() -> void:
    time_admin.advance_time()


## Advances the game-clock system toward the supplied time-of-day choice.
func advance_to_time(new_time) -> void:
    time_admin.jump_to_time(new_time)


#endregion


#region GAME EVENT ADMIN
## Returns [code]game_event_admin.check_for_event(target_location)[/code].
func check_for_event(target_location) -> GameEvent:
    return game_event_admin.check_for_event(target_location)


## Finds a story event by ID in the event repository and asserts that the result exists.
func find_event_by_id(id: String) -> GameEvent:
    var event_repository: Dictionary = Repositories.get_repository(RepositoryTypes.EVENTS).master
    var event: GameEvent = null
    if event_repository.has(id):
        event = event_repository[id]
    assert(event != null)
    return event


#endregion


#region GAME QUEST ADMIN
## Returns [code]quest_admin.has_quest(id)[/code].
func has_quest(id: StringName) -> bool:
    return quest_admin.has_quest(id)


## Returns the quest's current step when the quest is present; otherwise uses this helper's fallback
## result.
func get_quest_step(id: StringName) -> int:
    if not quest_admin.has_quest(id):
        return -1

    return quest_admin.get_quest_step(id)


## Passes the quest definition to the quest system to create an active quest.
func add_quest(quest: GameQuest) -> void:
    quest_admin.add_quest(quest)


#endregion

#region CAMERA ADMIN


## Asks the camera director to find and reconnect the current scene's cameras.
func reconnect_camera() -> void:
    camera_admin.director.reconnect_cameras()


#endregion


#region SONG ADMIN
## Requests playback of the song identified by the supplied name.
func play_song(id: String) -> void:
    song_admin.play_song(id)


## Finds the song administrator if needed, then asks it to mute every song player.
func silence_all_songs() -> void:
    if not song_admin:
        set_admins()
    song_admin.mute_all()


## Queues the named song after the active player's current song.
func queue_song(id: String) -> void:
    song_admin.queue_song(id)


## Passes the requested song volume and transition duration to the song administrator.
func set_song_volume(volume: float, transition_time: float) -> void:
    song_admin.set_volume(volume, transition_time)


## Passes the requested song intensity and transition duration to the song administrator.
func set_song_intensity(intensity: float, transition_time: float) -> void:
    song_admin.set_intensity(intensity, transition_time)


## Fades the active song toward silence over the supplied transition duration.
func mute_active_song(transition_time: float) -> void:
    song_admin.mute_active(transition_time)

#endregion
