# Built-game entry to the courtyard and basement story playtest launchers.
extends Control

const COURTYARD = "res://editor_only_debug/scenes/battle/courtyard_story_playtest.tscn"
const BASEMENT = "res://editor_only_debug/scenes/battle/basement_story_playtest.tscn"
const MAIN_MENU = "res://GrimDays/scenes/main_menu.tscn"

var _opening: bool = false


func _ready() -> void:
    $Center/Choices/Courtyard.pressed.connect(_open.bind(COURTYARD))
    $Center/Choices/Basement.pressed.connect(_open.bind(BASEMENT))
    $Center/Choices/Back.pressed.connect(_open.bind(MAIN_MENU))
    $Center/Choices/Courtyard.grab_focus()


func start_scene() -> void:
    UIDirector.reveal_screen()
    UIDirector.fade_flag_hide()


func _open(scene_path: String) -> void:
    if _opening or SceneManager.swapping:
        return
    _opening = true
    SceneManager.swap_scenes(self, self, scene_path)
