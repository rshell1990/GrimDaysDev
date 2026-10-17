extends Control
## Scene object used for title hiding color rect.
@export var title_hiding_color_rect: ColorRect
## Button used for quit button.
@export var quit_button: Button
## Button used for options button.
@export var options_button: Button
## Button used for extra button.
@export var extra_button: Button
## Button used for load button.
@export var load_button: Button
## Button used for new button.
@export var new_button: Button
## Button used for continue button.
@export var continue_button: Button

## Animated Spine logo shown on the title screen.
@export var title_logo: SpineSprite
## Story event selected when the player starts a new game.
@export var starting_event: GameEventSequence

## Animation player used for animator.
@export var animator: AnimationPlayer

## List of buttons used by this script.
var buttons: Array[Button]
## List of button locations used by this script.
var button_locations: Array[Vector2]


## Reveals the screen; sets [code]buttons[/code] to [code][quit_button, options_button,
## extra_button, load_button, new_button, continue_button][/code]; increases
## [code]button.position.x[/code] by [code]button.size.x + 300[/code]. It also sets
## [code]continue_button.process_mode[/code] to [code]PROCESS_MODE_INHERIT[/code].
func init_scene():
    buttons = [quit_button, options_button, extra_button, load_button, new_button, continue_button]

    button_locations = [
        buttons[0].position,
        buttons[1].position,
        buttons[2].position,
        buttons[3].position,
        buttons[4].position,
        buttons[5].position
    ]

    for button in buttons:
        button.position.x += button.size.x + 300

    SoundManager.stop_music(0.01)
    UIDirector.fade_flag_hide()
    UIDirector.reveal_screen()
    if Dialogic.Save.has_slot(Dialogic.Save.get_global_info("last_hard_save", "")):
        continue_button.process_mode = PROCESS_MODE_INHERIT
        continue_button.disabled = false


## Starts playback on [code]animator[/code]; starts playback on [code]animator[/code]. It pauses for
## [code]get_tree().create_timer(VNAnimationTimes.LONG).timeout[/code] before continuing.
func start_scene():
    title_logo.get_animation_state().set_animation("LogoLoop", true, 0)
    await get_tree().create_timer(VNAnimationTimes.LONG).timeout
    if GameManager.saw_title:
        animator.play("revealed_title")
        _play_theme()
    else:
        animator.play("intro")


## Shows the configured major, minor and patch version numbers in the title screen's version label.
func _ready() -> void:
    %"Version Label".text = (
        Defaults.VERSION_MAJOR + "." + Defaults.VERSION_MINOR + "." + Defaults.VERSION_PATCH
    )


## Sets [code]title_logo.visible[/code] to [code]!title_logo.visible[/code]; sets
## [code]button.visible[/code] to [code]!button.visible[/code].
func _unhandled_input(event: InputEvent) -> void:
    #SystemHelpers.print(event)
    if not event is InputEventKey:
        return
    if Input.is_action_just_released("hide_textbox"):
        title_logo.visible = !title_logo.visible
        for button in buttons:
            button.visible = !button.visible


## Starts the title screen's theme music.
func _play_theme() -> void:
    SoundManager.play_music(Repositories.get_info(RepositoryTypes.MUSIC, "theme"))


## Plays the sound used by the title-screen spotlight animation.
func _play_spotlight_sound() -> void:
    SoundManager.play_sound(Repositories.get_info(RepositoryTypes.SOUNDS, "spotlight-on"))


## Reveals and animates the title logo.
func _logo_appears():
    var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_property(title_logo, "modulate:a", 1.0, 5.5)
    title_logo.turn_shader_off()
    await get_tree().create_timer(6.5).timeout
    _menu_appears()


## Moves the title-screen buttons into their visible menu positions.
func _menu_appears():
    for x in range(buttons.size()):
        await move_buttons(x, button_locations[x])
    title_hiding_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    await get_tree().create_timer(VNAnimationTimes.SLOW).timeout
    %"Patch Notes Button".visible = true
    GameManager.saw_title = true


## Moves the selected menu button toward its target position.
func move_buttons(index, target):
    var tween = create_tween().set_ease(Tween.EASE_IN)
    await tween.tween_property(buttons[index], "position", target, VNAnimationTimes.FAST).finished


## Covers the title screen, resets game systems, selects the starting location and mode, and
## requests the configured starting event.
func _on_new_game_pressed():
    VNSignalBus.reset_sub_systems.emit()
    %"New Game Sound".play()
    title_hiding_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    var tween = create_tween().set_ease(Tween.EASE_IN)
    await tween.tween_property(
        title_hiding_color_rect, "color:a", 1.0, VNAnimationTimes.STANDARD
    ).finished
    SoundManager.stop_all()
    await get_tree().create_timer(VNAnimationTimes.SLOW).timeout

    if starting_event != null:
        VNSignalBus.event_found.emit(starting_event)
        return

    GameManager.change_state(GameManagerStates.STATES.Navigation)
    SceneManager.swap_scenes(
        self, self, Repositories.get_resource_path(RepositoryTypes.SCENES, "navigation_location")
    )


## Returns the configured starting event for the scene that follows the title screen.
func pass_data_to_next_scene() -> Dictionary:
    var data = {"found_event": starting_event}
    return data


## Continues from the latest normal save, not a newer rollback checkpoint.
## The manager validates before fading or changing game state.
func _on_continue_pressed():
    var slot_name: String = Dialogic.Save.get_global_info("last_hard_save", "")
    SaveAndLoadSystemManager.load_game(slot_name)


## Opens the settings menu from the title screen.
func _on_options_pressed():
    var in_game_menu = get_node("/root/UIDirector/Menu Operator")
    in_game_menu.fade_in("options")


## Asks the application to quit through its normal quit helper.
func _on_quit_button_up() -> void:
    get_tree().quit()


## Opens the save/load menu from the title screen.
func _on_load_button_up() -> void:
    var in_game_menu = get_node("/root/UIDirector/Menu Operator")
    in_game_menu.fade_in()


## Calls the extras-menu helper; the helper determines what is currently available.
func _on_extras_button_up() -> void:
    SoundManager.stop_music(VNAnimationTimes.FAST)
    await get_tree().create_timer(VNAnimationTimes.SLOW).timeout
    SceneManager.swap_scenes(
        self, self, Repositories.get_resource_path(RepositoryTypes.SCENES, "battle_testing")
    )
