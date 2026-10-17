# Editor configuration for SequencedSceneOperator.
@icon("res://GrimDays/assets/visuals/at-icons/node3d/clapperboard.svg")
extends Node
class_name SequencedSceneOperator
## Notification for restored.
signal restored
## Scene control for animator, used to display or change the related setting.
@export var animator: SequenceAnimator
## Actions to run when the sequence reaches its ending.
@export var ending_actions: Array[GameAction]
## Controls hidden when dialogue starts in this sequence.
@export var ui_to_hide_on_timeline_start: Array[Control]
## Saved state collected from child nodes that support restoration.
var children_state: Dictionary
## Story event most recently supplied to this scene.
var found_event: GameEvent
## Key used to identify this script’s data in saved state.
var save_name: String
#region SCENE MANAGEMENT
## Setup the scene, before starting it.


## When the node enters the scene, this function connects responses to
## [code]VNSignalBus.event_found[/code], [code]Dialogic.timeline_started[/code]; registers
## [code]self[/code] with [code]SaveAndLoadSystemManager[/code]; starts playback on
## [code]animator[/code]. It also sets [code]save_name[/code] to [code]name[/code]. It pauses for
## [code]SystemAdministrators.ready[/code], [code]animator.animation_finished[/code] before
## continuing.
func _enter_tree() -> void:
    if GameManager.state == GameManagerStates.STATES.Init:
        return
    VNSignalBus.event_found.connect(on_event_found)
    Dialogic.timeline_started.connect(on_timeline_start)
    save_name = name
    SaveAndLoadSystemManager.add_node(self)

    if GameManager.state == GameManagerStates.STATES.BeforeGame:
        if animator.has_animation("RESET"):
            if not SystemAdministrators.is_node_ready():
                CustomLogger.hint(
                    self, self._enter_tree, "Awaiting System Administrator...", CustomLogger.LEVEL.VERBOSE
                )
                await SystemAdministrators.ready
            CustomLogger.hint(self, self._enter_tree, "Calling Reset and then start...", CustomLogger.LEVEL.MILD)
            animator.play("RESET")
            await animator.animation_finished
            SystemAdministrators.reconnect_camera()
            if animator.has_animation("start"):
                animator.play("start")
                await animator.animation_finished
            else:
                for anim in animator.get_animation_list():
                    if "start" in anim:
                        animator.play(anim)
                        await animator.animation_finished
                        break
    CustomLogger.hint(
        self, self._enter_tree, "[color=#FF0]" + name + " finished entering the tree.[/color]", CustomLogger.LEVEL.MILD
    )


## Changes the mouse pointer image.
func init_scene() -> void:
    Input.set_custom_mouse_cursor(null)


## After init, make this scene available.
func start_scene() -> void:
    CustomLogger.hint(self, self.start_scene, "[color=#0FF]" + name + " is starting.[/color]", CustomLogger.LEVEL.MILD)
    UIDirector.hide_navigation()
    UIDirector.fade_flag_hide()
    if GameManager.state != GameManagerStates.STATES.ScenarioSequence:
        GameManager.change_state(GameManagerStates.STATES.ScenarioSequence)
    if animator and not SaveAndLoadSystemManager.restoring_data and animator.has_animation("RESET"):
        animator.play("RESET")
        await animator.animation_finished
        animator.play("start")
    if not animator:
        Dialogic.start(GameManager.current_event.timeline)


## Enters the sequenced story mode when its timeline starts.
func on_timeline_start() -> void:
    if GameManager.state != GameManagerStates.STATES.ScenarioSequence:
        GameManager.change_state(GameManagerStates.STATES.ScenarioSequence)
    if ui_to_hide_on_timeline_start.is_empty():
        return
    for ui in ui_to_hide_on_timeline_start:
        if ui.modulate.a > 0.0:
            hide_ui(ui)


## Sets [code]found_event[/code] to [code]game_event[/code].
func on_event_found(game_event: GameEvent) -> void:
    CustomLogger.confirm(self, self.on_event_found, "Event found: " + game_event.id, CustomLogger.LEVEL.MILD)
    found_event = game_event


## Recieve data from the last scene.
@warning_ignore("unused_parameter")
func get_data_from_last_scene(data) -> void:
    CustomLogger.confirm(self, self.get_data_from_last_scene, "Recieved data: " + str(data), CustomLogger.LEVEL.MILD)
    #given_data = data


## Before the current scene becomes inactive, pass this data to the next scene.
func pass_data_to_next_scene() -> Dictionary:
    CustomLogger.confirm(self, self.pass_data_to_next_scene, "passing data to next scene.", CustomLogger.LEVEL.MILD)
    var data: Dictionary = {"found_event": found_event}
    return data


## Collects this object’s current display and resource settings into a dictionary for saving or
## restoration.
func _get_state() -> Dictionary:
    var state: Dictionary
    children_state.clear()
    SystemHelpers.get_state_of_children(find_children("*", "", true, false), children_state)
    state.set(save_name, children_state)
    #SystemHelpers.pretty_print_dict(state[save_name])

    return state


## Waits for a timer through [code]SystemHelpers[/code]; sends [code]restored[/code] notifications.
## It pauses for [code]SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)[/code] before
## continuing.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    var sequenced_state = data[save_name] if not data[save_name].has(save_name) else data[save_name][save_name]
    var children = find_children("*", "", true, false)
    var child_dict = {}
    for node_name in sequenced_state:
        var child = find_child(node_name, true, false)
        if not child:
            continue
        child.restore_state(sequenced_state[node_name])

    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()


## Fades the supplied interface control out of view.
func hide_ui(ui: Control) -> void:
    var tween = create_tween()
    tween.tween_property(ui, "modulate:a", 0.0, VNAnimationTimes.FAST)


## Provide a way to execute code when this scene is exited. Useful for scenarios that don't involve a timeline /
## animation.
func exit_scene() -> void:
    if ending_actions.is_empty():
        return

    for action in ending_actions:
        action.execute()

#endregion
