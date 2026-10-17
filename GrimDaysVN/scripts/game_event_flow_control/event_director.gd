extends Node
## Chooses available story events by location, time, requirements and priority, and tracks repeat
## cooldowns.
class_name EventDirector

## Next eligible dates for repeatable story events, looked up by event ID.
var events_on_cooldown: Dictionary


## When the node is ready, this function connects responses to [code]VNSignalBus.day_passed[/code],
## [code]VNSignalBus.reset_sub_systems[/code].
func _ready() -> void:
    VNSignalBus.day_passed.connect(on_day_passed)
    VNSignalBus.reset_sub_systems.connect(reset)


## Removes cooldown entries whose next eligible date is before the current date.
func on_day_passed(_old_day: Time.Weekday) -> void:
    for id in events_on_cooldown.keys():
        if events_on_cooldown[id].is_before(SystemAdministrators.current_day()):
            events_on_cooldown.erase(id)


## Chooses an available event for the location, weekday and time, preferring higher priority and
## skipping events still on cooldown. Records the next eligible date for limited repeats, or returns
## no event when none qualifies.
func check_for_event(
    location: StringName, day: Time.Weekday, time: TimeAdministrator.TIMES
) -> GameEvent:
    var events_by_location = Repositories.get_info(RepositoryTypes.EVENTS, location)
    var events_by_time = events_by_location[time]
    var all_events: Array = events_by_time[day].duplicate(true)

    if all_events.is_empty():
        return

    for index in range(all_events.size() - 1, -1, -1):
        var event_to_check: GameEvent = all_events[index]
        CustomLogger.hint(
            self,
            self.check_for_event,
            (
                "Checking event:"
                + str(event_to_check.id)
                + "\nSeen: "
                + str(event_to_check.id in GameManager.seen_events)
                + "\nNever Repeats:"
                + str(event_to_check.repeats)
                + "\nOnly Called: "
                + str(all_events[index].only_called)
            ),
            CustomLogger.LEVEL.MILD
        )

        if (
            event_to_check.id in GameManager.seen_events
            and event_to_check.repeats == GameEvent.REPEAT_TYPES.Never
        ):
            all_events.remove_at(index)
            continue
        if event_to_check.only_called:
            all_events.remove_at(index)
            continue
        if not event_to_check.is_available():
            all_events.remove_at(index)
            continue

    CustomLogger.confirm(
        self,
        self.check_for_event,
        "All Events Available:\n" + str(all_events),
        CustomLogger.LEVEL.MILD
    )

    if all_events.is_empty():
        return
    all_events.sort_custom(sort_events)

    var selected_event: GameEvent = all_events[0]

    var index = 0
    while selected_event.id in events_on_cooldown.keys():
        if index == all_events.size():
            selected_event = null
            return
        selected_event = all_events[index]
        index += 1

    if selected_event.repeats not in [GameEvent.REPEAT_TYPES.Never, GameEvent.REPEAT_TYPES.Always]:
        match selected_event.repeats:
            GameEvent.REPEAT_TYPES.Daily:
                var new_date = SystemAdministrators.current_day().duplicate()
                new_date.add_days(1)
                events_on_cooldown[selected_event.id] = new_date
            GameEvent.REPEAT_TYPES.Weekly:
                var new_date = SystemAdministrators.current_day().duplicate()
                new_date.add_days(7)
                events_on_cooldown[selected_event.id] = new_date
            GameEvent.REPEAT_TYPES.Monthly:
                var new_date = SystemAdministrators.current_day().duplicate()
                new_date.add_days(30)
                events_on_cooldown[selected_event.id] = new_date

    return selected_event


## Returns true when the first event has higher priority, so it sorts before the second event.
func sort_events(first_item, second_item) -> bool:
    if first_item.priority > second_item.priority:
        return true
    return false


## Records the event ID as seen if necessary, then starts the event.
func on_event_found(game_event: GameEvent) -> void:
    CustomLogger.confirm(
        self, self.on_event_found, "Starting: " + game_event.id, CustomLogger.LEVEL.MILD
    )

    if game_event.id not in GameManager.seen_events:
        GameManager.seen_events.append(game_event.id)
    game_event.start()


## Clears all remembered event cooldowns.
func reset() -> void:
    CustomLogger.warn(
        self, self.reset, " is resetting, events on cooldown cleared.", CustomLogger.LEVEL.MILD
    )
    events_on_cooldown.clear()
