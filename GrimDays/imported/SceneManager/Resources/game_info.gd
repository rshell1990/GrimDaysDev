class_name GameInfo extends Resource

# could save stats, telemetry, etc

## Coordinates used for last window position.
@export var last_window_position: Vector2i

## Shared fixed value for game info path.
const GAME_INFO_PATH:String = "user://game_info.tres"

## Writes this resource to its configured user-data file.
func save() -> void:
	ResourceSaver.save(self, GAME_INFO_PATH)
	
## Loads the resource from its user-data file if it exists; otherwise returns a new resource with
## default values.
static func load_or_create() -> GameInfo:
	var res:GameInfo
	if FileAccess.file_exists(GAME_INFO_PATH):
		res = load(GAME_INFO_PATH) as GameInfo
	else:
		res = GameInfo.new()
	return res
