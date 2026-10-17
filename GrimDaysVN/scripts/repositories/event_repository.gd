## Builds lookup entries for event resources so other scripts can find them by ID.
class_name GameEventsRepository
extends Node

## Source resource containing the entries this repository loads.
@export var resource: GameEventsMaster

## Lookup table built from this repository’s source resources for other systems to query.
var master: Dictionary = {}


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready() -> void:
    if resource == null:
        return
    for event in resource.called_events:
        master[event.id] = event
    for location in NavigationAdministrator.LOCATIONS:
        master[location] = {}
        for time_period in TimeAdministrator.TIMES.values():
            master[location][time_period] = {}
            for day_of_the_week in TimeAdministrator.DAYS:
                master[location][time_period][day_of_the_week] = []

    for locations in resource.all:
        #SystemHelpers.print(locations.all)
        for event in locations.all:
            #SystemHelpers.print(event.id)
            for time in event.times:
                for day in event.days:
                    master[locations.location][time][day].append(event)
                    if not master.has(event.id):
                        #SystemHelpers.print("Adding: ", event.id, " to repository.")
                        master[event.id] = event
