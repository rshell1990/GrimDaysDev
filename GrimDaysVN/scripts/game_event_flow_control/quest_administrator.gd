extends Node
class_name QuestAdministrator

## Helper responsible for carrying out this system’s requests.
var director: QuestDirector


## Finds the quest director when this administrator is ready.
func _ready() -> void:
    set_director()


## Finds and stores the quest director used for subsequent quest requests.
func set_director() -> void:
    if director != null:
        return
    director = get_child(0)


## Asks the quest director whether the given ID belongs to an active quest.
func has_quest(id: StringName) -> bool:
    set_director()
    return director.has_quest(id)


## Returns the requested quest's current step through the quest administrator.
func get_quest_step(id: StringName) -> int:
    set_director()
    return director.get_quest_step(id)


## Passes the quest definition to the quest system to create an active quest.
func add_quest(quest: GameQuest) -> void:
    set_director()
    director.add_quest(quest)


## Finds the active quest and asks it to advance to its next step.
func advance_quest(id: StringName) -> void:
    set_director()
    director.advance_quest(id)
