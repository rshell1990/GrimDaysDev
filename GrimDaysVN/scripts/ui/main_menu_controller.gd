# Main menu for the story build: scene plumbing plus the menu-button responses.
extends Node3D

## Multiplier applied to [member anim_player] while the player skips the intro animation.
const INTRO_SKIP_SPEED_SCALE: float = 20.0
## Normal playback speed restored once the skipped intro animation finishes.
const INTRO_NORMAL_SPEED_SCALE: float = 1.0
## Path of the debug battle-selection scene reached from the menu's battle-test button.
const BATTLE_TEST_SELECTOR_SCENE: String = (
    "res://editor_only_debug/scenes/battle/battle_playtest_selector.tscn"
)

## Animation player running the menu's intro animation.
@export var anim_player: AnimationPlayer
## Story event requested when the player starts a new game.
@export var starting_event: GameEventSequence


## Resets the intro animation to its normal playback speed when the scene is ready.
func _ready() -> void:
    anim_player.speed_scale = INTRO_NORMAL_SPEED_SCALE


## Speeds the intro animation up while the player holds the accept action, so the menu becomes
## interactive without waiting for the full reveal.
func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed("accept"):
        return
    if not anim_player.is_playing():
        return
    if not anim_player.animation_finished.is_connected(_on_anim_player_animation_finished):
        anim_player.animation_finished.connect(_on_anim_player_animation_finished)
    anim_player.speed_scale = INTRO_SKIP_SPEED_SCALE


## Restores the normal animation speed and releases the skip handler once the intro finishes.
func _on_anim_player_animation_finished(_animation_name: StringName) -> void:
    anim_player.speed_scale = INTRO_NORMAL_SPEED_SCALE
    if anim_player.animation_finished.is_connected(_on_anim_player_animation_finished):
        anim_player.animation_finished.disconnect(_on_anim_player_animation_finished)


## Hides the transition screenshot and reveals the screen as this scene enters the tree.
func _enter_tree() -> void:
    UIDirector.fade_flag_hide()
    UIDirector.reveal_screen()


## Requests the configured starting event, which begins a new game.
func _on_new_game_button_up() -> void:
    VNSignalBus.event_found.emit(starting_event)


## Opens the save/load section of the in-game menu.
func _on_load_game_button_up() -> void:
    UIDirector.menu_operator.fade_in()


## Opens the settings section of the in-game menu.
func _on_options_button_up() -> void:
    UIDirector.menu_operator.fade_in("options")


## Placeholder for the not-yet-implemented extras menu.
func _on_extras_button_up() -> void:
    pass


## Asks the player to confirm quitting, then quits when they accept.
func _on_quit_button_up() -> void:
    ConfirmationModal.customize(
        "Are you sure?",
        "Any unsaved progress will be lost.",
        "Yes",
        "No"
    )
    var confirmed: bool = await ConfirmationModal.prompt(true)
    if not confirmed:
        return
    get_tree().quit()


## Opens the debug battle-selection scene, ignoring clicks while a scene change is running.
func _on_test_battles_button_up() -> void:
    if SceneManager.swapping:
        return
    SceneManager.swap_scenes(self, self, BATTLE_TEST_SELECTOR_SCENE)
