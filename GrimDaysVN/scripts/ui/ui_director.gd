extends CanvasLayer
## Notification for restored.
signal restored
## Notification for screen uncovered.
signal screen_uncovered
## Scene object used for patch notes.
@export var patch_notes: Control
## Scene node used for fade flag operator, found when this node is ready.
@onready var fade_flag_operator = $"Fade Flag"
## Scene node used for navigation overlay operator, found when this node is ready.
@onready var navigation_overlay_operator = $"Navigation Overlay Operator"
## Scene node used for menu operator, found when this node is ready.
@onready var menu_operator = $"Menu Operator"
## Scene node used for cover operator, found when this node is ready.
@onready var cover_operator = $"Screen Cover"
## Scene node used for time passage ui, found when this node is ready.
@onready var time_passage_ui = %"Time Passage Operator"
## Scene node used for text input layer, found when this node is ready.
@onready var text_input_layer: CanvasLayer = $TextInputLayer
## Scene node used for notification director, found when this node is ready.
@onready var notification_director: Control = %"Notification Director"
## Scene node used for rollback indicator, found when this node is ready.
@onready var rollback_indicator: AnimatedSprite2D = %"Rollback Indicator"
## Key used to identify this script’s data in saved state.
var save_name = "UI_Director"
## Saved state collected from child nodes that support restoration.
var children_state: Dictionary
## Transient modal only; character state remains in the persistent party service.
var party_preparation: BattlePreparationSession


## Navigation inventory entry. Deliberately unavailable in other game states.
func show_party_preparation() -> bool:
    return _get_party_preparation().open(BattleController.party_manager)


## Dialogic Call event: `do UIDirector.show_story_party_preparation()`.
## The session owns continuation of this exact Call event, preventing a cancelled
## visit from advancing a replacement timeline.
func show_story_party_preparation() -> bool:
    return _get_party_preparation().open(BattleController.party_manager, true)


## Explicit story-only full skill respec. Not callable from ordinary preparation.
## Dialogic continues normally after the synchronous reset; no extra continuation
## signal is emitted here. Returns refunded points, or -1 for an invalid context.
func reset_story_skill_trees(unit_id: String) -> int:
    return BattleSkillResetService.reset_from_story(BattleController.party_manager, StringName(unit_id))


## Returns the existing preparation session, creating and adding one when needed.
func _get_party_preparation() -> BattlePreparationSession:
    if not is_instance_valid(party_preparation):
        party_preparation = BattlePreparationSession.new()
        add_child(party_preparation)
    return party_preparation


## Time value used when calculating elapsed play time; see the update and conversion functions in
## this script.
var time_passed: float


## On each physics update, this function increases [code]time_passed[/code] by [code]delta[/code];
## sets [code]time_passed[/code] to [code]0[/code].
func _physics_process(delta) -> void:
    if not Dialogic.current_timeline:
        return
    if not cover_operator.modulate.a > 0.1:
        return
    time_passed += delta
    if time_passed < 30.0:
        return

    reveal_screen()
    time_passed = 0


## Fades in the player display.
func show_player() -> void:
    %Player.fade_in()


## Shows the text-input interface and uses the input game mode while the prompt is active.
func show_text_input() -> void:
    text_input_layer.visible = true


## Hides the text-input interface and restores the remembered game mode.
func hide_text_input() -> void:
    text_input_layer.visible = false


## Passes a player-facing message to the notification display.
func add_notification(message: String) -> void:
    notification_director.add_notification(message)


## Starts the time-passage display for the supplied time change.
func show_time_passage(start_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES, token: int) -> void:
    cover_screen()
    await get_tree().create_timer(VNAnimationTimes.STANDARD).timeout
    if not GameManager.state_manager.owns_state(GameManagerStates.STATES.TimeChanging, token):
        return
    time_passage_ui.visible = true
    time_passage_ui.show_passage(start_time, new_time, token)


## Covers the game view using the screen-cover control.
func cover_screen() -> void:
    CustomLogger.hint(
        self,
        self.cover_screen,
        "[bgcolor=#262][color=#FFF][i]Covering screen...[/i][/color][/bgcolor]",
        CustomLogger.LEVEL.MILD
    )
    var tween = create_tween()
    await tween.tween_property(cover_operator, "modulate:a", Basics.OPAQUE, VNAnimationTimes.FAST).finished


## Reveals the game view by removing the screen cover.
func reveal_screen() -> void:
    CustomLogger.hint(
        self,
        self.reveal_screen,
        "[bgcolor=#262][color=#FFF][i]Revealing screen...[/i][/color][/bgcolor]",
        CustomLogger.LEVEL.MILD
    )
    var tween = create_tween()
    await tween.tween_property(cover_operator, "modulate:a", Basics.TRANSPARENT, VNAnimationTimes.STANDARD).finished
    CustomLogger.confirm(
        self, self.reveal_screen, "[bgcolor=#262][color=#FFF]Screen revealed, emitting signal...[/color][/bgcolor]"
    )
    screen_uncovered.emit()


## Opens the settings section of the in-game menu.
func show_settings_menu() -> void:
    CustomLogger.hint(
        self,
        self.show_settings_menu,
        "[bgcolor=#555][color=#000]Showing settings menu[/color][/bgcolor]",
        CustomLogger.LEVEL.MILD
    )
    menu_operator.fade_in("options")


## Closes the in-game settings menu with its fade-out behavior.
func hide_settings_menu() -> void:
    CustomLogger.hint(
        self,
        self.hide_settings_menu,
        "[bgcolor=#555][color=#000]Hid settings menu[/color][/bgcolor]",
        CustomLogger.LEVEL.MILD
    )
    menu_operator.fade_out()


## Shows the navigation interface.
func show_navigation() -> void:
    navigation_overlay_operator.show()


## Hides the navigation interface.
func hide_navigation() -> void:
    navigation_overlay_operator.hide()


## Prepares the transition cover using a capture of the current view.
func fade_flag_show() -> void:
    Dialogic.paused = true
    CustomLogger.hint(self, fade_flag_show, "Showing the fade_flag... Dialogic paused", CustomLogger.LEVEL.VERBOSE)
    await fade_flag_operator.get_and_set_screen_shot()
    Dialogic.paused = false
    CustomLogger.hint(self, fade_flag_show, "Fade flag shown... Dialogic unpaused", CustomLogger.LEVEL.VERBOSE)


## Fades away the captured transition screenshot and waits for its completion notification.
func fade_flag_hide() -> void:
    fade_flag_operator.fade_screenshot()
    await fade_flag_operator.screen_shot_faded


## Shows the door-peek visual overlay.
func show_door_peek() -> void:
    var tween = create_tween()
    await tween.tween_property($DoorPeek, "modulate:a", Basics.OPAQUE, VNAnimationTimes.FAST).finished


## Hides the door-peek visual overlay.
func hide_door_peek() -> void:
    var tween = create_tween()
    await tween.tween_property($DoorPeek, "modulate:a", Basics.TRANSPARENT, VNAnimationTimes.FAST).finished


## Reveals the patch-notes panel.
func show_patch_notes() -> void:
    patch_notes.unhide()


## Shows the anger visual overlay.
func show_anger() -> void:
    %"Anger Vignete".show()


## Passes the requested shake strength and transition speed to the screen-shake helper.
func shake_screen(strength: float, cycle_transition) -> void:
    ScreenShaker.set_shake_strength(strength, cycle_transition)


## Smoothly changes [code]speed_scale[/code] over time.
func set_anger_speed(amount: float, transition_time: float) -> void:
    var animator: AnimationPlayer = %"Anger Vignete".get_child(0)
    var tween = create_tween()
    tween.tween_property(animator, "speed_scale", amount, transition_time)


## Hides the anger visual overlay.
func hide_anger() -> void:
    %"Anger Vignete".hide()


## Sends the supplied message to the title-card display.
func show_title_card(message: String) -> void:
    %"Title Card".set_message(message)


## Asks the title-card display to hide its current message.
func hide_title_card() -> void:
    %"Title Card".hide_title_card()


## Toggles the indicator shown while a rollback checkpoint is loading.
func toggle_rollback_indicator() -> void:
    rollback_indicator.visible = !rollback_indicator.visible


## Shows the named image through the full-screen image display.
func show_image(image_name: String) -> void:
    %"Full Screen Image".show_image(image_name)


## Requests that the currently displayed image be hidden.
func hide_image(image_name: String) -> void:
    %"Full Screen Image".hide_image(image_name)


## When the node is ready, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _ready() -> void:
    SaveAndLoadSystemManager.add_node(self)


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

    for node in children:
        if not sequenced_state.has(node.name):
            #CustomLogger.warn(self, self.restore, node.name + "not in sequenced state.")
            continue
        if not node.has_method("restore_state"):
            continue
        node.restore_state(sequenced_state[node.name])

    #navigation_overlay_operator.on_restore(TimeAdministrator.TIMES.Morning, SystemAdministrators.current_time())
    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()


## Passes a system message to the notification display.
func add_system_message(message: String) -> void:
    notification_director.add_system_message(message)
