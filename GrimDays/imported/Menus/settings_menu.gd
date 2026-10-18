class_name SettingsMenu extends CanvasLayer

# opening this menu pauses the game, so you don't have to worry about blocking input
# from anything underneath it

## Notification for language changed. Supplies [code]language[/code] to connected functions.
signal language_changed(language:Defaults.LANGUAGE)
## Notification for difficulty changed. Supplies [code]difficulty[/code] to connected functions.
signal difficulty_changed(difficulty:Defaults.DIFFICULTY)
## Notification for censoring changed. Supplies [code]censoring[/code] to connected functions.
signal censoring_changed(censoring:Defaults.CENSORING)

## Scene node used for window mode dropdown, found when this node is ready.
@onready var window_mode_dropdown:OptionButton = %WindowModeDropdown
## Scene node used for window resolution dropdown, found when this node is ready.
@onready var window_resolution_dropdown:OptionButton = %WindowResolutionDropdown
## Scene node used for monitor dropdown, found when this node is ready.
@onready var monitor_dropdown:OptionButton = %MonitorDropdown
## Scene node used for music slider, found when this node is ready.
@onready var music_slider:HSlider = %MusicSlider as HSlider
## Scene node used for sfx slider, found when this node is ready.
@onready var sfx_slider:HSlider = %SFXSlider as HSlider
## Scene node used for master slider, found when this node is ready.
@onready var master_slider:HSlider = %MasterSlider as HSlider
## Scene node used for ambient slider, found when this node is ready.
@onready var ambient_slider:HSlider = %AmbientSlider as HSlider
## Scene node used for dynamic slider, found when this node is ready.
@onready var dynamic_slider:HSlider = %DynamicSlider as HSlider

## Scene node used for language dropdown, found when this node is ready.
@onready var language_dropdown:OptionButton = %LanguageDropdown as OptionButton
## Index of the SFX audio bus, used to read or change its volume.
@onready var sfx_bus_id = AudioServer.get_bus_index("SFX")
## Index of the Music audio bus, used to read or change its volume.
@onready var music_bus_id = AudioServer.get_bus_index("Music")
## Index of the Master audio bus, used to read or change its volume.
@onready var master_bus_id = AudioServer.get_bus_index("Master")
## Index of the Effect Ambient audio bus, used to read or change its volume.
@onready var ambient_bus_id = AudioServer.get_bus_index("Effect Ambient")
## Index of the Ovani audio bus, used to read or change its volume.
@onready var dynamic_bus_id = AudioServer.get_bus_index("Ovani")
## Scene node used for options holder, found when this node is ready.
@onready var options_holder = %Options
## Scene node used for save load holder, found when this node is ready.
@onready var save_load_holder = %"Save Page Holder"

## Scene node used for options controls, found when this node is ready.
@onready var options_controls = %"Options Tab Controls"
## Scene node used for save controls, found when this node is ready.
@onready var save_controls = %"Save Tab Controls"
## Scene node used for local signal bus, found when this node is ready.
@onready var local_signal_bus = %LocalSignalBus

## Shared fixed value for menu start position.
const MENU_START_POSITION:Vector2 = Vector2(1920,1010)

## Menu instance currently displayed by this control, or null when none is open.
var active_menu = null
## Settings category currently selected for display.
var active_category = null

## When the node is ready, this function sets [code]music_slider.value[/code] to
## [code]SM_Globals.user_prefs.music_volume[/code]; sets [code]sfx_slider.value[/code] to
## [code]SM_Globals.user_prefs.sfx_volume[/code]; sets [code]master_slider.value[/code] to
## [code]SM_Globals.user_prefs.master_volume[/code].
func _ready():
	if OS.get_name() in ["Web", "iOS", "Android"]:
		pass
	elif OS.get_name() == "macOS":
		# MacOS borderless fullscreen behaves the same as fullscreen
		window_mode_dropdown.remove_item(2)

	for res in DisplayManager.window_resolutions:
		window_resolution_dropdown.add_item("%dx%d" % [res.x, res.y])

	for screen_idx in range(DisplayServer.get_screen_count()):
		monitor_dropdown.add_item("Monitor %d" % screen_idx)

	# load (or create) file with these saved preferences


	# set saved values (will be default values if first load)
	if music_slider:
		music_slider.value = SM_Globals.user_prefs.music_volume
	if sfx_slider:
		sfx_slider.value = SM_Globals.user_prefs.sfx_volume
	if master_slider:
		master_slider.value = SM_Globals.user_prefs.master_volume
	if ambient_slider:
		ambient_slider.value = SM_Globals.user_prefs.ambient_volume
	if dynamic_slider:
		dynamic_slider.value = SM_Globals.user_prefs.dynamic_volume

	if language_dropdown:
		language_dropdown.selected = SM_Globals.user_prefs.language
	if window_mode_dropdown:
		window_mode_dropdown.selected = SM_Globals.user_prefs.window_mode
	if window_resolution_dropdown:
		var saved_res := SM_Globals.user_prefs.window_resolution
		for idx: int in range(window_resolution_dropdown.item_count):
			var item_text := window_resolution_dropdown.get_item_text(idx)
			if item_text == "%dx%d" % [saved_res.x, saved_res.y]:
				window_resolution_dropdown.selected = idx

	var difficulty_dropdown := get_node(
		"Categories/Options/Option Panels/Gameplay/VBoxContainer/GridContainer/"
		+ "Battle Difficulty Dropdown"
	)
	difficulty_dropdown.selected = SM_Globals.user_prefs.difficulty


## Responds to the cancel action by asking the parent menu to handle its close/toggle behavior.
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_parent().on_right_click()


## Applies the selected window mode and remembers it in user preferences.
func _on_window_mode_option_selected(_value):
	SM_Globals.user_prefs.window_mode = Defaults.WINDOWMODE_OPTIONS[_value]
	SM_Globals.display_manager.set_window_mode(_value)

## Applies the selected resolution and remembers it in user preferences.
func _on_window_resolution_option_selected(_value):
	SM_Globals.user_prefs.window_resolution = DisplayManager.window_resolutions[_value]
	SM_Globals.display_manager.set_window_resolution(DisplayManager.window_resolutions[_value])

## Moves the window to the selected monitor and remembers the choice.
func _on_monitor_option_selected(_value: int):
	SM_Globals.user_prefs.window_monitor = _value
	SM_Globals.display_manager.set_monitor(_value)

## Changes the music audio volume from the slider value and stores the preference.
func _on_music_slider_value_changed(_value):
	AudioServer.set_bus_volume_db(music_bus_id, linear_to_db(_value))
	AudioServer.set_bus_mute(music_bus_id, _value < .05)
	SM_Globals.user_prefs.music_volume = _value
	SM_Globals.user_prefs.save()
	music_slider.get_child(0).text = str(_value * 100) + "%"

## Changes the sfx audio volume from the slider value and stores the preference.
func _on_sfx_slider_value_changed(_value):
	AudioServer.set_bus_volume_db(sfx_bus_id, linear_to_db(_value))
	AudioServer.set_bus_mute(sfx_bus_id, _value < .05)
	SM_Globals.user_prefs.sfx_volume = _value
	SM_Globals.user_prefs.save()
	sfx_slider.get_child(0).text = str(_value * 100) + "%"

## Remembers the selected language and announces the setting change.
func _on_language_dropdown_item_selected(_index):
	SM_Globals.user_prefs.language = Defaults.LANGUAGE_OPTIONS[_index]
	language_changed.emit(Defaults.LANGUAGE_OPTIONS[_index])

## Saves user preferences when the matching application notification is received.
func _notification(what):
	match what:
		NOTIFICATION_EXIT_TREE:
			SM_Globals.user_prefs.save()




## Moves the current settings category out of view before introducing the requested category and
## controls.
func move_active_offscreen(holder, menu) -> void:
	if active_category == null and active_menu == null:
		SystemHelpers.print("None active.")
		_on_move_offscreen(holder, menu)
		return
	if active_category.get_child(0).get_child_count() > 1:
		for child in active_category.get_child(0).get_children():
			if child.position.x > 0:
				child.visible = false

	tween_to_left(active_category)
	tween_to_left(active_menu)

	if active_category.get_child(0).get_child_count() > 1:
		for child in active_category.get_child(0).get_children():
			child.visible = false
	elif active_category.get_child(0).get_child_count() == 1:
		active_category.get_child(0).get_child(0).visible = false


	await SystemHelpers.start_timer(AnimationTimes.FAST)
	_on_move_offscreen(holder, menu)

## Smoothly moves the supplied menu node toward its left-side target position.
func tween_to_left(node) -> void:
	var tween = create_tween()
	var new_position = node.global_position.x - 1920
	tween.tween_property(node, "global_position:x", new_position,AnimationTimes.FAST)
	SystemHelpers.print(node, ' position ', node.global_position)



## Finishes switching menu categories after the outgoing menu has moved away.
func _on_move_offscreen(holder, menu):
	#SystemHelpers.print("After moving offscreen.")
	local_signal_bus.first_run_complete.connect(_on_first_run_completed, CONNECT_ONE_SHOT)
	holder.first_run(menu)


## Waits for a timer through [code]SystemHelpers[/code]; sets [code]child.visible[/code] to true;
## updates [code]holder.global_position[/code] using [code]holder.get_start_position[/code]. It also
## sets [code]menu.global_position[/code] to [code]MENU_START_POSITION[/code]. It pauses for
## [code]SystemHelpers.start_timer(AnimationTimes.FAST)[/code] before continuing.
func _on_first_run_completed(menu, holder) -> void:
	#SystemHelpers.print("After first run.")
	if holder.get_child(0).get_child_count() > 1:
		for child in holder.get_child(0).get_children():
			child.visible = true

	holder.global_position = holder.get_start_position()
	menu.global_position = MENU_START_POSITION
	#SystemHelpers.print(menu, ' position ', menu.global_position)

	tween_to_left(holder)
	tween_to_left(menu)
	await SystemHelpers.start_timer(AnimationTimes.FAST)
	active_category = holder
	active_menu = menu

## Switches to the options category unless it is already the active category.
func _on_options_pressed() -> void:
	if options_holder == active_category:
		return
	_on_category_selected(options_holder, options_controls)

## Switches to the save/load category, removing its existing first child before rebuilding it.
func _on_save___load_pressed():
	if save_load_holder == active_category:
		return
	if save_load_holder.get_child_count() > 0:
		save_load_holder.get_child(0).free()
	_on_category_selected(save_load_holder, save_controls)

## Starts moving the current menu off-screen before showing the requested category.
func _on_category_selected(holder, menu) -> void:
	move_active_offscreen(holder, menu)


## Fades out the parent menu when it supports that operation and is not a Window.
func _on_return_pressed():
	if get_parent() is Window or (get_parent() is Node and not get_parent().has_method("fade_out")):
		return
	get_parent().fade_out()


## Shows a confirmation prompt and quits only if the player confirms.
func _on_quit_pressed():
	ConfirmationModal.customize(
		"Are you sure?",
		"Any unsaved progress will be lost.",
		"Yes",
		"No")

	var confirmed = await ConfirmationModal.prompt(true)

	if confirmed:
		_quit_confirmed()


## Asks Godot to quit after the player has confirmed the request.
func _quit_confirmed():
	get_tree().quit()


## Handles the return-to-title request, including the confirmation and scene/menu transition defined
## here.
func _on_title_pressed():
	var confirmed = false
	if GameManager.state != GameManagerStates.STATES.BeforeGame:
		ConfirmationModal.customize(
			"Return to the title screen?",
			"Any unsaved progress will be lost.",
			"Yes",
			"No")
		confirmed = await ConfirmationModal.prompt(true)

		if confirmed:
			GameManager.change_state(GameManagerStates.STATES.Other)
			Dialogic.end_timeline()
			Dialogic.clear()
			Dialogic.paused = false
			UIDirector.cover_screen()
			await get_tree().create_timer(AnimationTimes.STANDARD).timeout
			var parent = get_parent()
			await parent.return_to_title()
			visible = false
			SceneManager.swap_scenes(self, SceneManager.get_tree().current_scene,
					Repositories.kinds.SystemScenes.main_menu)
			queue_free()

	else:
		await fade_out_all()
		var parent = get_parent()
		await parent.return_to_title()
		visible = false
		queue_free()


## Fades each menu section out in sequence, waiting for each fade before starting the next.
func fade_out_all():
	await fade_out($"Category Menu")
	await fade_out($"Top Line")
	await fade_out($Categories)
	await fade_out($"Bottom Line")
	await fade_out($"Category Tabs")
	await fade_out($"Dimming Panel")

## Smoothly changes opacity over time. It pauses for [code]tween.tween_property(object,
## "modulate:a", Basics.TRANSPARENT, AnimationTimes.FAST / 3.0).finished[/code] before continuing.
func fade_out(object):
	var tween = create_tween()
	await tween.tween_property(object, "modulate:a", Basics.TRANSPARENT,
			AnimationTimes.FAST / 3.0).finished


## Remembers the selected battle difficulty and announces the setting change.
func _on_battle_difficulty_dropdown_item_selected(index: int) -> void:
	SM_Globals.user_prefs.difficulty = Defaults.DIFFICULTY_OPTIONS[index]
	difficulty_changed.emit(Defaults.DIFFICULTY_OPTIONS[index])


## Remembers the selected censoring preference and announces the setting change.
func _on_censoring_dropdown_item_selected(index: int) -> void:
	SM_Globals.user_prefs.censoring = Defaults.CENSORING_OPTIONS[index]
	censoring_changed.emit(Defaults.CENSORING_OPTIONS[index])


## Changes the ambient audio volume from the slider value and stores the preference.
func _on_ambient_slider_value_changed(_value: float) -> void:
	AudioServer.set_bus_volume_db(ambient_bus_id, linear_to_db(_value))
	AudioServer.set_bus_mute(ambient_bus_id, _value < .05)
	SM_Globals.user_prefs.ambient_volume = _value
	SM_Globals.user_prefs.save()
	ambient_slider.get_child(0).text = str(_value * 100) + "%"

## Changes the dynamic audio volume from the slider value and stores the preference.
func _on_dynamic_slider_value_changed(_value: float) -> void:
	AudioServer.set_bus_volume_db(dynamic_bus_id, linear_to_db(_value))
	AudioServer.set_bus_mute(dynamic_bus_id, _value < .05)
	SM_Globals.user_prefs.dynamic_volume = _value
	SM_Globals.user_prefs.save()
	dynamic_slider.get_child(0).text = str(_value * 100) + "%"


## Changes the master audio volume from the slider value and stores the preference.
func _on_master_slider_value_changed(_value: float) -> void:
	AudioServer.set_bus_volume_db(master_bus_id, linear_to_db(_value))
	AudioServer.set_bus_mute(master_bus_id, _value < .05)
	SM_Globals.user_prefs.master_volume = _value
	SM_Globals.user_prefs.save()
	master_slider.get_child(0).text = str(_value * 100) + "%"
