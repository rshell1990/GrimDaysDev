extends Node

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
## User preference resource containing the chosen display, audio and text settings.
var user_prefs:UserPrefs
## Remembered application information, including the last window position.
var game_info: GameInfo


## Helper that applies and remembers window settings.
var display_manager: DisplayManager

## When the node is ready, this function updates [code]user_prefs[/code] using
## [code]UserPrefs.load_or_create[/code]; updates [code]game_info[/code] using
## [code]GameInfo.load_or_create[/code]; updates [code]display_manager[/code] using
## [code]DisplayManager.new[/code].
func _ready():
	# setup so that we can intercept quit
	get_tree().set_auto_accept_quit(false)
	
	user_prefs = UserPrefs.load_or_create()
	game_info = GameInfo.load_or_create()
	
	display_manager = DisplayManager.new()
	
## Lookup table for languages; keys select the corresponding stored values.
const LANGUAGES:Dictionary = {
	0:"en-US",
	1:"es-LAT"
}

## Returns the language code selected in user preferences, falling back to the first language if
## that entry is empty.
func get_selected_language() -> String:
	var s:String = LANGUAGES[user_prefs.language]
	if s:
		return s
	return LANGUAGES[0]

## Remembers the current window position, then asks Godot to quit the application.
func quit():
	display_manager.save_window()
	get_tree().quit() # default behavior

## Handles an operating-system window-close request through the same quit path used by the game.
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()
