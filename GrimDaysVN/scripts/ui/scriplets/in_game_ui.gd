extends Control

## Scene object used for hiding rect.
@export var hiding_rect: ColorRect
## Scene template used to create settings menu.
@export var settings_menu: PackedScene
## Whether reject input is currently enabled or true.
var reject_input: bool = false
## Menu instance currently displayed by this control, or null when none is open.
var active_menu


## Connects responses to [code]Dialogic.timeline_started[/code].
func init_scene():
    CustomLogger.hint(self, self.init_scene, " has been initialized.", CustomLogger.LEVEL.MILD)
    Dialogic.timeline_started.connect(on_timeline_start)


## Sets [code]Dialogic.Inputs.auto_skip.disable_on_unread_text[/code] to false.
func start_scene():
    Dialogic.Inputs.auto_skip.disable_on_unread_text = false
    CustomLogger.hint(self, self.init_scene, " has been started.", CustomLogger.LEVEL.MILD)


## Sets [code]reject_input[/code] to true; sets [code]auto_skip.disable_on_unread_text[/code] to
## [code]!SM_Globals.user_prefs.skip_unread[/code]; sets [code]auto_skip.enabled[/code] to
## [code]!is_auto_skip_enabled[/code].
func _input(event: InputEvent) -> void:
    if reject_input:
        CustomLogger.warn(self, self._input, " input rejected.", CustomLogger.LEVEL.MILD)
        return

    if Input.is_action_just_pressed("toggle_menu"):
        if GameManager.state == GameManagerStates.STATES.Input:
            CustomLogger.warn(self, self._input, " text input box active exiting.", CustomLogger.LEVEL.MILD)
            return
        # if Dialogic.current_timeline == null:
        # 	CustomLogger.warn(self, self.on_right_click, " timeline inactive, right click disabled currently.")
        # 	return
        if GameManager.state == GameManagerStates.STATES.BeforeGame:
            CustomLogger.warn(self, self._input, " not in game yet.", CustomLogger.LEVEL.MILD)
            return
        CustomLogger.confirm(self, self._input, " rejecting future input.", CustomLogger.LEVEL.MILD)
        reject_input = true

        on_right_click()
        unfreeze_input()
    if Input.is_action_just_pressed("toggle_menu_alt"):
        CustomLogger.confirm(self, self._input, " rejecting future input.", CustomLogger.LEVEL.MILD)
        reject_input = true

        on_right_click()
        unfreeze_input()

    if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_MIDDLE:
        CustomLogger.hint(self, self._input, " middle mouse button pressed, toggling fast forward.")
        var auto_skip: DialogicAutoSkip = Dialogic.Inputs.auto_skip
        var is_auto_skip_enabled := auto_skip.enabled

        auto_skip.disable_on_unread_text = !SM_Globals.user_prefs.skip_unread
        auto_skip.enabled = !is_auto_skip_enabled


## Makes the UI hiding rectangle transparent as dialogue begins.
func on_timeline_start() -> void:
    animate_hiding_rect(Basics.TRANSPARENT)


## Restores input processing after the menu transition finishes.
func unfreeze_input() -> void:
    await get_tree().create_timer(VNAnimationTimes.STANDARD).timeout
    CustomLogger.hint(self, self.unfreeze_input, " input will no longer be rejected.", CustomLogger.LEVEL.MILD)
    reject_input = false


## Closes an open menu, or takes a save thumbnail and opens the menu when none is active.
func on_right_click() -> void:
    if active_menu != null:
        CustomLogger.hint(self, self.on_right_click, "Menu screen toggled off.", CustomLogger.LEVEL.MILD)
        fade_out()
    else:
        Dialogic.Save.take_thumbnail()
        CustomLogger.hint(self, self.on_right_click, "Menu screen toggled on.", CustomLogger.LEVEL.MILD)
        fade_in()


## Adds [code]active_menu[/code] as a child node; sets [code]Dialogic.paused[/code] to true; sets
## [code]world_scene.process_mode[/code] to [code]Node.PROCESS_MODE_DISABLED[/code]. It also updates
## [code]active_menu[/code] using [code]settings_menu.instantiate[/code]. It pauses for
## [code]Dialogic.Animations.finished[/code], [code]animate_hiding_rect(alpha_to, on_fade_in)[/code]
## before continuing.
func fade_in(on_fade_in = "save_load") -> void:
    CustomLogger.hint(self, self.fade_in, "Menu screen starting to fade in.", CustomLogger.LEVEL.MILD)
    visible = true
    var alpha_to = 0.85
    if Dialogic.Animations.is_animating():
        await Dialogic.Animations.finished
    CustomLogger.warn(self, self.fade_in, " will pause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true
    var world_scene = get_tree().current_scene
    world_scene.process_mode = Node.PROCESS_MODE_DISABLED

    active_menu = settings_menu.instantiate()
    add_child(active_menu)

    await animate_hiding_rect(alpha_to, on_fade_in)


## Schedules [code]active_menu[/code] for deletion; sets [code]world_scene.process_mode[/code] to
## [code]Node.PROCESS_MODE_INHERIT[/code]; sets [code]Dialogic.paused[/code] to false. It pauses for
## [code]animate_hiding_rect(alpha_to)[/code], [code]Dialogic.Animations.finished[/code] before
## continuing.
func fade_out() -> void:
    CustomLogger.hint(self, self.fade_out, "Menu screen starting to fade out.", CustomLogger.LEVEL.MILD)
    var alpha_to = Basics.TRANSPARENT
    var world_scene = get_tree().current_scene
    world_scene.process_mode = Node.PROCESS_MODE_INHERIT
    active_menu.queue_free()
    active_menu = null
    await animate_hiding_rect(alpha_to)
    visible = false
    CustomLogger.warn(self, self.fade_out, " will unpause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false
    if Dialogic.Animations.is_animating():
        await Dialogic.Animations.finished


## Closes the in-game menu and starts the return to the title scene.
func return_to_title() -> void:
    var alpha_to = Basics.TRANSPARENT
    var world_scene = get_tree().current_scene
    world_scene.process_mode = Node.PROCESS_MODE_INHERIT
    GameManager.change_state(GameManagerStates.STATES.BeforeGame)
    await animate_hiding_rect(alpha_to)
    visible = false


## Fades the menu's screen cover to the requested opacity and runs the supplied completion response.
func animate_hiding_rect(alpha_to, on_fade_in = "save_load") -> void:
    var tween = create_tween().set_ignore_time_scale(true)
    tween.set_ease(Tween.EASE_IN)
    await tween.tween_property(hiding_rect, "modulate:a", alpha_to, VNAnimationTimes.FAST).finished
    if active_menu == null:
        return
    if on_fade_in == "save_load":
        active_menu._on_save___load_pressed()
    elif on_fade_in == "options":
        active_menu._on_options_pressed()
