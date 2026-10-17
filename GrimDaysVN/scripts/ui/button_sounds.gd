extends AudioStreamPlayer

## Node that is used for playing sound effects on hover/focus/press of sibling DialogicNode_ChoiceButtons.

## Sound to be played if one of the sibling ChoiceButtons is pressed.
## If sibling ChoiceButton has a sound_pressed set, that is prioritized.
@export var sound_pressed: AudioStream
## Sound to be played on hover. See [sound_pressed] for more.
@export var sound_hover: AudioStream
## Sound to be played on focus. See [sound_pressed] for more.
@export var sound_focus: AudioStream


## Finds buttons and connects their input notifications to the sound handlers.
func _ready() -> void:
    _connect_all_buttons()


#basic play sound
## Requests playback of the configured button sound.
func play_sound(sound) -> void:
    if sound == null:
        return
    SoundManager.play_ui_sound_with_pitch(sound, randf_range(0.75, 1.5))


## Finds the relevant buttons and connects their press, hover and focus notifications to sound
## playback.
func _connect_all_buttons() -> void:
    for child in get_parent().get_children():
        if child is Button:
            child.button_up.connect(_on_pressed.bind(null))
            child.mouse_entered.connect(_on_hover.bind(null))
            child.focus_entered.connect(_on_focus.bind(null))


#the custom_sound argument comes from the specifec button and get used
#if none are found, it uses the above sounds


## Plays the configured sound when the button is pressed.
func _on_pressed(custom_sound) -> void:
    if custom_sound != null:
        play_sound(custom_sound)
    else:
        play_sound(sound_pressed)


## Plays the configured sound when the button is hovered.
func _on_hover(custom_sound) -> void:
    if custom_sound != null:
        play_sound(custom_sound)
    else:
        play_sound(sound_hover)


## Plays the configured sound when the button is focused.
func _on_focus(custom_sound) -> void:
    if custom_sound != null:
        play_sound(custom_sound)
    else:
        play_sound(sound_focus)
