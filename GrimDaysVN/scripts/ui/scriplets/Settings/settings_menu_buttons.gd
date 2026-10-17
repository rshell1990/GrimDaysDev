extends HBoxContainer
## Scene object used for gameplay panel.
@export var gameplay_panel: MarginContainer
## Scene object used for audio panel.
@export var audio_panel: MarginContainer
## Scene object used for display panel.
@export var display_panel: MarginContainer
## Scene object used for colors panel.
@export var colors_panel: MarginContainer
## Scene control for text panel, used to display or change the related setting.
@export var text_panel: ScrollContainer

## Scene object used for options panels container.
@export var options_panels_container: MarginContainer


## Moves the settings container to show the gameplay panel.
func _on_gameplay_pressed():
    move_panel(gameplay_panel.position.x * -1.0)


## Moves the settings container to show the audio panel.
func _on_audio_pressed():
    move_panel(audio_panel.position.x * -1.0)


## Moves the settings container to show the display panel.
func _on_display_pressed():
    move_panel(display_panel.position.x * -1.0)


## Moves the settings container to show the colors panel.
func _on_colors_pressed():
    move_panel(colors_panel.position.x * -1.0)


## Moves the settings container to show the text panel.
func _on_text_pressed():
    move_panel(text_panel.position.x * -1.0)


## Smoothly changes [code]position:x[/code] over time.
func move_panel(a_target_position):
    var tween = create_tween()
    await (
        tween.tween_property(options_panels_container, "position:x", a_target_position, VNAnimationTimes.FAST).finished
    )
