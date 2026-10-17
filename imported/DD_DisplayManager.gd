## Applies window mode, resolution and monitor settings, and records window information for later
## startup.
class_name DisplayManager extends RefCounted

# available window resolutions
# perhaps this should be an export on a node for easier management
## Window sizes offered by the resolution settings menu, expressed as width and height in pixels.
static var window_resolutions: Array[Vector2i] = [
	Vector2i(1280,720),
	Vector2i(1440,810),
	Vector2i(1600,900),
	Vector2i(1776,900),
	Vector2i(1920,1080),
	Vector2i(1920,1200),
	Vector2i(2048,1152),
	Vector2i(2560,1440),
	Vector2i(3120,1755),
	Vector2i(3840,2160)
]

## Applies the saved display preferences and centers the window when this manager is created.
func _init():
	restore_window()

## Selects windowed, exclusive-fullscreen or fullscreen mode from the dropdown index. Some choices
## first switch through another mode to refresh the window.
func set_window_mode(_value: int):
	match(_value):
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

## Resizes the window to 640 by 360 first, then applies the requested size.
func set_window_resolution(_resolution: Vector2i):
	DisplayServer.window_set_size(Vector2i(640,360))
	DisplayServer.window_set_size(_resolution)

## Moves the game window to the monitor identified by the supplied screen index.
func set_monitor(_monitor: int):
	DisplayServer.window_set_current_screen(_monitor)

## Remembers the current window position and saves it in the application-info resource.
func save_window():
	SM_Globals.game_info.last_window_position = DisplayServer.window_get_position()
	SM_Globals.game_info.save()

## Applies the saved mode, size and valid monitor choice, then centers the window. The current
## implementation overwrites the remembered position rather than restoring it.
func restore_window():
	set_window_mode(SM_Globals.user_prefs.window_mode)
	set_window_resolution(SM_Globals.user_prefs.window_resolution)
	if DisplayServer.get_screen_count() - 1 >= SM_Globals.user_prefs.window_monitor:
		set_monitor(SM_Globals.user_prefs.window_monitor)
	# if we don't have a saved window position
	# or our saved position is off screen
	# center our position
	var screen_size := DisplayServer.screen_get_size()
	var window_size := DisplayServer.window_get_size()
	var last_win_pos :Vector2i= SM_Globals.game_info.last_window_position
	SM_Globals.game_info.last_window_position = screen_size / 2 - window_size / 2
	DisplayServer.window_set_position(SM_Globals.game_info.last_window_position)
