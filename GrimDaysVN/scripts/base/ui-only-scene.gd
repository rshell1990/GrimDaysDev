extends Control
class_name UISceneOperator

## Data received from the last active scene.
var given_data: Dictionary
## When a game event is found, store it to pass to the next scene loaded.
var found_event: GameEvent


## Connects responses to [code]VNSignalBus.event_found[/code].
func init_scene() -> void:
    VNSignalBus.event_found.connect(on_event_found)
    # if GameManager.state != GameManagerStates.STATES.Other:
    # 	GameManager.change_state(GameManagerStates.STATES.Other)


## Fades away the scene-transition cover so the new scene can be seen.
func start_scene() -> void:
    UIDirector.fade_flag_hide()


## Sets [code]found_event[/code] to [code]game_event[/code].
func on_event_found(game_event: GameEvent) -> void:
    CustomLogger.confirm(self, self.on_event_found, "Event found: " + game_event.id, CustomLogger.LEVEL.MILD)
    found_event = game_event


## Recieve data from the last scene.
func get_data_from_last_scene(data) -> void:
    CustomLogger.confirm(self, self.get_data_from_last_scene, "received data.", CustomLogger.LEVEL.MILD)
    given_data = data


## Before the current scene becomes inactive, pass this data to the next scene.
func pass_data_to_next_scene() -> Dictionary:
    var data: Dictionary = {"found_event": found_event}
    return data
