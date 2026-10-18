extends Node
#region SIGNALS
## Notification for load start. Supplies [code]loading_screen[/code] to connected functions.
signal load_start(loading_screen)
## Notification for load complete. Supplies [code]loaded_scene[/code] to connected functions.
signal load_complete(loaded_scene)
## Notification for data received.
signal data_received()
## Notification for active node set.
signal active_node_set()
#endegion
#region VARIABLES
## Resource loaded for loading screen scene; reused instead of looking up the file on each call.
var _loading_screen_scene:PackedScene = preload(
	"res://GrimDays/imported/Menus/loading_canvass.tscn")
## Information collected from the outgoing scene to pass to its replacement.
var outgoing_scene_data:Dictionary
## Loading-screen node used while the replacement scene is being prepared.
var loading_screen:Node
## Scene node currently managed by this scene-switching helper.
var active_node:Node
## Path of the outgoing scene from the most recent scene change.
var last_swapped_scene:String
## Whether a scene change is currently in progress.
var swapping:bool = false
#endregion

#region SWAP SCENES
## Begins replacing the outgoing scene with the requested scene, passing available scene data
## through the loading screen.
func swap_scenes(caller, outgoing_scene, incoming_scene) -> void:
	assert(not incoming_scene.is_empty())
	CustomLogger.hint(self, self.swap_scenes,
		str(caller) + " called to swap: " + str(outgoing_scene) + "and\n" + str(incoming_scene),
		CustomLogger.LEVEL.SEVERE)
	if swapping:
		print_rich("[b]IS SWAPPING[/b]")
		await get_tree().create_timer(0.1).timeout
		swap_scenes(self, outgoing_scene, incoming_scene)
		return
	if outgoing_scene:
		CustomLogger.hint(self, self.swap_scenes,
			"Swapping: " + outgoing_scene.name + " with " + str(incoming_scene),
			CustomLogger.LEVEL.VERBOSE)
	swapping = true
	VNSignalBus.on_tooltip_hide.emit()
	outgoing_scene_data = {}
	CustomLogger.hint(self, self.swap_scenes,"Await process frame.",CustomLogger.LEVEL.MILD)
	await get_tree().process_frame
	CustomLogger.hint(self, self.swap_scenes,
		"Check for pass_data_to_next_scene method.", CustomLogger.LEVEL.MILD)
	if outgoing_scene.has_method("pass_data_to_next_scene"):
		CustomLogger.hint(self, self.swap_scenes,
			": Calling " + outgoing_scene.name
			+ " to set the data that will be passed to the incoming scene.",
			CustomLogger.LEVEL.VERBOSE)
		outgoing_scene_data = outgoing_scene.pass_data_to_next_scene()
	CustomLogger.hint(self, self.swap_scenes,"Await frame post draw.",CustomLogger.LEVEL.MILD)
	await RenderingServer.frame_post_draw
	CustomLogger.hint(self, self.swap_scenes,"Frame post draw finished.",CustomLogger.LEVEL.MILD)
	UIDirector.fade_flag_show()
	CustomLogger.hint(self, self.swap_scenes,
		"instantiating Loading Screen.", CustomLogger.LEVEL.MILD)
	loading_screen = _loading_screen_scene.instantiate()

	#loading_screen.background.texture = ImageTexture.create_from_image(
		#Dialogic.Save.latest_thumbnail)
	loading_screen.load_complete.connect(_on_content_finished_loading)
	get_node("/root").add_child.call_deferred(loading_screen)
	if not loading_screen.is_node_ready():
		CustomLogger.hint(self, self.swap_scenes,
			"Loading screen not ready, awaiting ready signal.")
		await loading_screen.ready
	last_swapped_scene = outgoing_scene.name
	CustomLogger.confirm(self, self.swap_scenes,
		"Load: " + str(incoming_scene), CustomLogger.LEVEL.VERBOSE)
	loading_screen.load.call_deferred(incoming_scene)
#endregion
#region CONTENT LOADING FINISHED
## Sets up the loaded scene and passes it the outgoing scene's data before scene initialization
## finishes.
func _on_content_finished_loading(incoming_scene) -> void:
	CustomLogger.confirm(self, self.swap_scenes,
		"Load completed for:" + str(incoming_scene), CustomLogger.LEVEL.MILD)
	if incoming_scene.has_signal("intialized_scene"):
		incoming_scene.intialized_scene.connect(on_scene_init)
	if incoming_scene.has_method("get_data_from_last_scene"):
		CustomLogger.hint(self, self.swap_scenes,
			"Incoming Scene can receive data.", CustomLogger.LEVEL.VERBOSE)
		incoming_scene.get_data_from_last_scene(outgoing_scene_data)
	data_received.emit()
	await get_tree().create_timer(AnimationTimes.NEAR_INSTANT).timeout
	if incoming_scene.has_method("init_scene"):
		CustomLogger.hint(self, self.swap_scenes,
			"Incoming Scene has init method.", CustomLogger.LEVEL.VERBOSE)
		incoming_scene.init_scene()

	CustomLogger.hint(self, self.swap_scenes,
		"Looking for signal initialized_scene.", CustomLogger.LEVEL.MILD)
	if incoming_scene.has_signal("intialized_scene"):
		CustomLogger.hint(self, self.swap_scenes,
			"Has intialized_scene, exiting current function; "
			+ "the rest will continue after the signal is emitted.",
			CustomLogger.LEVEL.MILD)
		return
	on_scene_init(incoming_scene)
#endregion
#region INCOMING SCENE INTIALIZED
## Makes the initialized scene active, releases the loading screen, and announces that the scene
## change is complete.
func on_scene_init(incoming_scene) -> void:
	if incoming_scene.has_method("start_scene"):
		CustomLogger.hint(self, self.swap_scenes,
			"Incoming scene has start method.", CustomLogger.LEVEL.VERBOSE)
		incoming_scene.start_scene()

	active_node = incoming_scene
	active_node_set.emit()
	await get_tree().create_timer(AnimationTimes.NEAR_INSTANT).timeout
	loading_screen.queue_free()
	await loading_screen.tree_exited
	load_complete.emit(active_node)
	CustomLogger.confirm(self, self.swap_scenes,
		"Swap completed for:" + str(incoming_scene), CustomLogger.LEVEL.SEVERE)
	swapping = false
#endregion
