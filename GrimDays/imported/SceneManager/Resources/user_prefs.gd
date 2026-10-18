class_name UserPrefs 
extends Resource

## Gameplay options
@export var censoring:Defaults.CENSORING = Defaults.DEFAULT_CENSORING
## Language selected by the player for supported interface/dialogue localization.
@export var language:Defaults.LANGUAGE = Defaults.DEFAULT_LANGUAGE
## Battle difficulty selected in the settings menu.
@export var difficulty:Defaults.DIFFICULTY = Defaults.DEFAULT_DIFFICULTY

## Sound Options
@export_range(0,1,.05) var master_volume: float = Defaults.DEFAULT_VOLUME
## Volume setting for background ambience, from 0 to 1.
@export_range(0,1,.05) var ambient_volume: float = Defaults.DEFAULT_VOLUME
## Volume setting for dynamic Ovani music, from 0 to 1.
@export_range(0,1,.05) var dynamic_volume: float = Defaults.DEFAULT_VOLUME
## Volume setting for normal music playback, from 0 to 1.
@export_range(0,1,.05) var music_volume: float = Defaults.DEFAULT_VOLUME
## Volume setting for sound effects, from 0 to 1.
@export_range(0,1,.05) var sfx_volume: float = Defaults.DEFAULT_VOLUME

## UI Appearance
@export var normal_base_color:String = Defaults.PRIME_BASE_COLOR
## Base color used by the dark interface palette.
@export var dark_base_color:String = Defaults.DARK_BASE_COLOR

## Text color used for the normal UI palette.
@export var normal_text_color:String = Defaults.PRIME_TEXT_COLOR
## Text color used for the dark UI palette.
@export var dark_text_color:String = Defaults.DARK_TEXT_COLOR

## Text outline color used for the normal UI palette.
@export var normal_outline_color:String = Defaults.PRIME_OUTLINE_COLOR
## Text outline color used for the dark UI palette.
@export var dark_outline_color:String = Defaults.DARK_OUTLINE_COLOR

## Background opacity: 0 is transparent and 1 is fully opaque.
@export_range(0,1,.05) var background_alpha:float = Defaults.DEFAULT_ALPHA
## Amount used when darkening the background color.
@export_range(0,1,.05) var background_darkened:float = Defaults.BACKGROUND_DARKENED_BY
## Amount used to shift the background hue.
@export_range(0,1,.05) var background_shift:float = Defaults.BACKGROUND_HUE_SHIFTED_BY

## Amount used when brightening the frame color.
@export_range(0,1,.05) var frame_brightened:float = Defaults.FRAME_BRIGHTENED_BY
## Amount used to shift the frame hue.
@export_range(0,1,.05) var frame_shift:float = Defaults.FRAME_HUE_SHIFTED_BY

## Choice of how accent colors are applied to backgrounds and frames.
@export var color_scheme:Defaults.COLOR_SCHEME = Defaults.COLOR_SCHEME.FRAME_ONLY

## Display Options
@export var window_mode:Defaults.WINDOWMODE = Defaults.DEFAULT_WINDOWMODE
## Saved window width and height in pixels.
@export var window_resolution: Vector2i = Defaults.RESOLUTION
## Index of the monitor selected for the game window.
@export var window_monitor: int = Defaults.DEFAULT_MONITOR

## Text Options
@export var display_font:Defaults.FONTS = Defaults.DEFAULT_FONT
## Multiplier applied to the interface text size.
@export var font_scale:float = Defaults.DEFAULT_FONT_SCALE
## Player-selected dialogue text reveal speed.
@export var text_speed:float = 1.0
## Player-selected speed for automatically advancing dialogue.
@export var auto_speed:float = 1.0
## Whether dialogue skipping is allowed to pass text the player has not read.
@export var skip_unread:bool = true
## Whether skipping should resume when dialogue continues.
@export var resume_skipping:bool = false

## Index of the selected primary font.
@export var primary_font:int = 0
## Index of the selected secondary font.
@export var secondary_font:int = 3
## Index of the selected tertiary font.
@export var tertiary_font:int = 5

## Writes this resource to its configured user-data file.
func save() -> void:
	ResourceSaver.save(self, Defaults.USER_PREFS_PATH)
	
## Loads the resource from its user-data file if it exists; otherwise returns a new resource with
## default values.
static func load_or_create() -> UserPrefs:
	var res:UserPrefs
	if FileAccess.file_exists(Defaults.USER_PREFS_PATH):
		res = load(Defaults.USER_PREFS_PATH) as UserPrefs
	else:
		res = UserPrefs.new()
	return res
