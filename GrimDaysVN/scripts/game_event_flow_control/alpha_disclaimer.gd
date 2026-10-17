extends Control
## Shared fixed value for transfer delay.
const TRANSFER_DELAY: float = 6.0
## Scene object used for disclaimer hiding color rect.
@export var disclaimer_hiding_color_rect: ColorRect
## Scene object used for disclaimer message one.
@export var disclaimer_message_one: MarginContainer
## Scene object used for disclaimer message two.
@export var disclaimer_message_two: MarginContainer


## Changes whether an audio bus is muted; changes the game mode through [code]GameManager[/code].
func init_scene() -> void:
    AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
    GameManager.change_state(GameManagerStates.STATES.BeforeGame)
    UIDirector.fade_flag_hide()


# Called when the node enters the scene tree for the first time.
## Sets [code]SM_Globals.user_prefs.color_scheme[/code] to
## [code]Defaults.COLOR_SCHEME.FRAME_ONLY[/code]. It pauses for
## [code]get_tree().create_timer(VNAnimationTimes.SLOW).timeout[/code] before continuing.
func start_scene():
    CustomLogger.hint(self, self.start_scene, " is starting.", CustomLogger.LEVEL.MILD)
    SM_Globals.user_prefs.color_scheme = Defaults.COLOR_SCHEME.FRAME_ONLY
    var saw_disclaimer = Dialogic.Save.get_global_info("read_disclaimer_one", false)
    if saw_disclaimer:
        end_scene()
        return
    await get_tree().create_timer(VNAnimationTimes.SLOW).timeout
    _disclaimer_appears()


## Reveals the disclaimer through a timed fade.
func _disclaimer_appears() -> void:
    var tween = create_tween().set_ease(Tween.EASE_IN)
    tween.tween_property(disclaimer_hiding_color_rect, "color:a", 0.0, VNAnimationTimes.STANDARD)
    await get_tree().create_timer(VNAnimationTimes.SLOW).timeout
    disclaimer_hiding_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fades out the disclaimer, waits for its display delay, then starts the extra messages.
func _handle_disclaimer() -> void:
    tween_message_out($"True Disclaimer")
    await get_tree().create_timer(VNAnimationTimes.SLOW * TRANSFER_DELAY).timeout
    _handle_messages()


## Shows the two disclaimer messages in order with timed fades, records that they were read, then
## advances to the next scene.
func _handle_messages() -> void:
    await tween_message_in(disclaimer_message_one)
    await get_tree().create_timer(VNAnimationTimes.SLOW * TRANSFER_DELAY).timeout
    await tween_message_out(disclaimer_message_one)
    await tween_message_in(disclaimer_message_two)
    await get_tree().create_timer(VNAnimationTimes.SLOW * TRANSFER_DELAY).timeout
    await tween_message_out(disclaimer_message_two)
    await get_tree().create_timer(VNAnimationTimes.LONG + VNAnimationTimes.SLOW).timeout
    Dialogic.Save.set_global_info("read_disclaimer_one", true)
    end_scene()


## Replaces the disclaimer with the studio-logo splash scene.
func end_scene() -> void:
    CustomLogger.hint(self, self.start_scene, " is ending.", CustomLogger.LEVEL.MILD)
    SceneManager.swap_scenes(
        self,
        get_node("."),
        Repositories.get_resource_path(RepositoryTypes.SCENES, "studio_logo_splash")
    )


## Fades the supplied disclaimer message out over the configured animation duration.
func tween_message_out(message: MarginContainer) -> void:
    var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
    tween.tween_property(message, "position:x", -1920.0, VNAnimationTimes.LONG)
    await get_tree().create_timer(VNAnimationTimes.LONG + VNAnimationTimes.SLOW).timeout


## Fades the supplied disclaimer message in over the configured animation duration.
func tween_message_in(message: MarginContainer) -> void:
    var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
    tween.tween_property(message, "position:x", 0.0, VNAnimationTimes.LONG)
    await get_tree().create_timer(VNAnimationTimes.LONG + VNAnimationTimes.SLOW).timeout


## When the node leaves the scene, this function schedules [code]disclaimer_message_one[/code] for
## deletion; schedules [code]disclaimer_hiding_color_rect[/code] for deletion.
func _exit_tree():
    if disclaimer_message_one:
        disclaimer_message_one.queue_free()
    if disclaimer_hiding_color_rect:
        disclaimer_hiding_color_rect.queue_free()


## Hides the answer buttons and continues the disclaimer sequence after acceptance.
func _on_yes_pressed() -> void:
    $HBoxContainer.visible = false
    _handle_disclaimer()


## Quits the application when the player declines the disclaimer.
func _on_no_pressed() -> void:
    SM_Globals.quit()
