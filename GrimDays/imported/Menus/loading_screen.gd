class_name LoadingScreen extends Node

## Used by scene manager to display transitions and loading progress. You won't need to
## modify or work with any of the code in this class but I've annotated in case
## you're curious about the logic

## Notification for load complete.
signal load_complete

## Scene node used for progress bar, found when this node is ready.
@onready var progress_bar: VBoxContainer = %"Progress Container"
## Scene object used for background.
@export var background:ColorRect

## Name of the loading screen's starting animation.
var starting_animation_name:String
## List of progress used by this script.
var progress:Array = []
## File or resource path used for incoming scene path.
var incoming_scene_path:String
## Resource loader's current status code for the requested scene.
var scene_load_status = 0
## Loading helper used to prepare the incoming scene.
var loader
## Whether loaded scene is currently enabled or true.
var loaded_scene:bool

## hides progress bar on startup, we'll reveal it later if loading has taken long
## enough that it's worth showing. The alternative is that when something loads
## quickly it flashes on screen briefly, and I don't like that.
func _ready() -> void:
	progress_bar.visible = true
	background.modulate.a = 0.0
	var tween = create_tween()
	await tween.tween_property(background, "modulate:a", 1.0, AnimationTimes.NEAR_INSTANT).finished

## On each drawn frame, this function updates [code]scene_load_status[/code] using
## [code]ResourceLoader.load_threaded_get_status[/code]; sets [code]loaded_scene[/code] to true.
func _process(_delta):
	if loader == null or loaded_scene:
		#print("Loader returns")
		return
	scene_load_status = ResourceLoader.load_threaded_get_status(incoming_scene_path, progress)
	#print(scene_load_status)
	assert(scene_load_status != ResourceLoader.THREAD_LOAD_FAILED)
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		loaded_scene = true
		switch_scene()

## Smoothly changes opacity over time; sets [code]progress_bar.visible[/code] to false; sends
## [code]load_complete[/code] notifications. It pauses for
## [code]get_tree().create_timer(AnimationTimes.NEAR_INSTANT).timeout[/code] before continuing.
func switch_scene():
	CustomLogger.hint(self, switch_scene, "Preparing to get the loaded incoming scene.",
			CustomLogger.LEVEL.MILD)
	var incoming_scene = ResourceLoader.load_threaded_get(incoming_scene_path)
	get_tree().change_scene_to_packed(incoming_scene)
	progress_bar.visible = false
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 0.0, AnimationTimes.NEAR_INSTANT)
	await get_tree().create_timer(AnimationTimes.NEAR_INSTANT).timeout
	CustomLogger.confirm(self, switch_scene, "Background tweened, about to emit load complete.")
	load_complete.emit(get_tree().current_scene)

## Sets [code]progress_bar.visible[/code] to true; sets [code]incoming_scene_path[/code] to
## [code]incoming_scene[/code]; updates [code]loader[/code] using
## [code]ResourceLoader.load_threaded_request[/code].
func load(incoming_scene:String) -> void:
	print("loading_screen_loads")
	progress_bar.visible = true
	incoming_scene_path = incoming_scene
	loader = ResourceLoader.load_threaded_request(incoming_scene)
	print(loader)
	if not ResourceLoader.exists(incoming_scene) or loader == null:
		printerr("Failed to load, ", incoming_scene)
