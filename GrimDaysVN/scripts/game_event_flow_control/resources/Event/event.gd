# Editor configuration for GameEvent.
@icon("res://GrimDays/assets/visuals/editor_icons/falling-leaf.svg")
extends Resource
## Base story-event definition with availability rules and start/finish behavior.
class_name GameEvent

@export_category("Event Basics")
## An identifier for the event, so that it is unique.
@export var id: StringName
## The type of event this is, used when deciding what template scene to swap with the current scene.
@export var scenario_type: SCENARIO_TYPES
## Will show up in the replay gallery.
@export var replayable: bool
## The gallery name of the event.
@export var gallery_name: String
## This event can only be called by systems besides the EventDirector.
@export var only_called: bool

@export_category("Event Triggers")
## The time periods an event can occur in.
@export var times: Array[TimeAdministrator.TIMES]
## The days of the week that an event can occur.
@export var days: Array[Time.Weekday] = TimeAdministrator.DAYS
## All the requirements for the event to be available to be chosen.
@export var requirements: Array[VNRequirement]

@export_category("Event Parameters")
## If the event can be called more than once, and if so how often in terms of game time.
@export var repeats: REPEAT_TYPES
## A way to sort events so that events that can occur at the same time and place will have an order of operations for
## them occuring.
@export var priority: int
## The dialogic timeline that will be autostarted when the event is triggered, null when timeline starting is controlled
## by an AnimationPlayer.
@export var timeline: DialogicTimeline
## The dialogic timeline that ends the event, and will start the next event in a sequence or send the player to
## navigaiton.
@export var finishing_timeline: DialogicTimeline
## The actions taken when the event ends.
@export var finishing_actions: Array[GameAction]

## Flags whether this event should prevent loading a new area.
@export var blocks_swap: bool


## Returns true only when every configured event requirement passes. An event with no requirements
## is available.
func is_available() -> bool:
    for requirement in requirements:
        if !requirement.has_requirement():
            CustomLogger.warn(
                self,
                self.is_available,
                "Missing requirement: " + str(requirement.resource_name),
                CustomLogger.LEVEL.MILD
            )
            return false
    return true


## How to start the event.
func start() -> void:
    await SystemHelpers.get_game_root().get_tree().create_timer(VNAnimationTimes.NEAR_INSTANT).timeout
    if blocks_swap:
        Dialogic.start(timeline)
        return


## When an event is finished, runs finishing actions subclasses will add their own spins.
func finish() -> void:
    CustomLogger.hint(self, self.finish, "has started.", 3)
    if GameManager.state == GameManagerStates.STATES.Other:
        return
    for action in finishing_actions:
        CustomLogger.hint(self, self.finish, " is executing: [color=#63F]" + str(action) + "[/color]", 3)
        action.execute()
    CustomLogger.confirm(self, self.finish, " has completed.", 3)


## How often a game event can be seen.
enum REPEAT_TYPES {
    ## Unique Events, that only are ever seen once.
    Never,
    ## Daily Events, that can only be seen once an in-game day.
    Daily,
    ## Weekly Events, that can only be seen once an in-game week.
    Weekly,
    ## Montly Events, that can only be seen once an in-game month.
    Monthly,
    ## Events that can occur multiple times without cooldown.
    Always,
}

## Named choices for scenario types: [code]Normal[/code], [code]Lewd[/code], [code]Sequence[/code],
## [code]Navigation[/code], [code]Battle[/code].
enum SCENARIO_TYPES { Normal, Lewd, Sequence, Navigation, Battle }
