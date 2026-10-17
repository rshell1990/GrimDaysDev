class_name JSONLoader extends Node
# https://docs.godotengine.org/en/stable/classes/class_json.html


## File or resource path used for save path.
const SAVE_PATH: String = "user://user_save.json"
## Shared fixed value for default save file.
const DEFAULT_SAVE_FILE: String = "res://Resources/default_save_file.json"
## Data read from or prepared for the configured save file.
var data = {}

## Writes the supplied data as JSON to the configured save file, replacing its previous contents.
func write_save(data_to_save):
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data_to_save))
	file.close()
	file = null
	
## Reads the configured JSON save file and stores its decoded data in this loader.
func read_save():
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())
	data = save_data
	return data
	
## Sets [code]data[/code] to [code]default_data[/code].
func load_or_create():
	if FileAccess.file_exists(SAVE_PATH):
		return read_save()
	var file = FileAccess.open(default_save_file, FileAccess.READ)
	var default_data = JSON.parse_string(file.get_as_text())
	data = default_data
	write_save(default_data)
	return data
		
## Replaces the current save data with the configured defaults.
func clear_save():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(default_save_file, FileAccess.READ)
		var default_data = JSON.parse_string(file.get_as_text())
		data = default_data
		write_save(default_data)
		
## Loads existing JSON save data or creates it from the configured defaults.
func _ready() -> void:
	load_or_create()
	##SystemHelpers.print(data.level_progress["level0"])
	##SystemHelpers.print(data.level_progress["level1"])
	##SystemHelpers.print(data.level_progress["level2"])
	##SystemHelpers.print(data.level_progress["level3"])
	#data.level_progress["level0"] = 1
	#write_save(data)
	
#class_name JSONLoader extends Node2D
#
#@export var json_file:String
#
#func get_json():
	#assert(FileAccess.file_exists(json_file),"File '%s' does not exist" % [json_file])
	#
	#var file := FileAccess.open(json_file, FileAccess.READ)
	#var content:String = file.get_as_text()
	#var data = JSON.parse_string(content)
	#
##	#SystemHelpers.print(data.lang["en-US"].convo01[0].text)
	#return data
