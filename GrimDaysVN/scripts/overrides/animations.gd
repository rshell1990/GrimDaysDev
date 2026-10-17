extends AnimationPlayer

## A custom script/node that adds some animations to the textbox.

# Careful: Sync these with the ones in the root script!
## Named choices for animations in: [code]NONE[/code], [code]POP_IN[/code], [code]FADE_UP[/code].
enum AnimationsIn { NONE, POP_IN, FADE_UP }
## Named choices for animations out: [code]NONE[/code], [code]POP_OUT[/code],
## [code]FADE_DOWN[/code].
enum AnimationsOut { NONE, POP_OUT, FADE_DOWN }
## Named choices for animations new text: [code]NONE[/code], [code]WIGGLE[/code].
enum AnimationsNewText { NONE, WIGGLE }

## Animation chosen when the dialogue box appears.
var animation_in: AnimationsIn
## Animation chosen when the dialogue box disappears.
var animation_out: AnimationsOut
## Animation chosen when new dialogue text arrives.
var animation_new_text: AnimationsNewText

## Whether the animation controller performs its full textbox reset.
var full_clear := true


## Returns the dialogue panel node that these animation helpers operate on.
func get_text_panel() -> PanelContainer:
    return %DialogTextPanel


## Returns the dialogue-text node used by these animation helpers.
func get_dialog() -> DialogicNode_DialogText:
    return %DialogicNode_DialogText


## When the node is ready, this function connects responses to [code]text_system[/code],
## [code]animation_system[/code].
func _ready() -> void:
    var text_system: Node = DialogicUtil.autoload().get(&"Text")
    text_system.connect(&"animation_textbox_hide", _on_textbox_hide)
    text_system.connect(&"animation_textbox_show", _on_textbox_show)
    text_system.connect(&"animation_textbox_new_text", _on_textbox_new_text)
    text_system.connect(&"about_to_show_text", _on_about_to_show_text)
    var animation_system: Node = DialogicUtil.autoload().get(&"Animations")
    animation_system.connect(&"animation_interrupted", _on_animation_interrupted)


## Plays the configured appearance animation for the dialogue box.
func _on_textbox_show() -> void:
    if animation_in == AnimationsIn.NONE:
        return
    play("RESET")
    var animation_system: Node = DialogicUtil.autoload().get(&"Animations")
    animation_system.call(&"start_animating")
    get_text_panel().get_parent().get_parent().set(&"modulate", Color.TRANSPARENT)
    get_dialog().text = ""
    match animation_in:
        AnimationsIn.POP_IN:
            play("textbox_pop")
        AnimationsIn.FADE_UP:
            play("textbox_fade_up")
    if not animation_finished.is_connected(Callable(animation_system, &"animation_finished")):
        animation_finished.connect(
            Callable(animation_system, &"animation_finished"), CONNECT_ONE_SHOT
        )


## Plays the configured disappearance animation for the dialogue box.
func _on_textbox_hide() -> void:
    if animation_out == AnimationsOut.NONE:
        return
    play("RESET")
    var animation_system: Node = DialogicUtil.autoload().get(&"Animations")
    animation_system.call(&"start_animating")
    match animation_out:
        AnimationsOut.POP_OUT:
            play_backwards("textbox_pop")
        AnimationsOut.FADE_DOWN:
            play_backwards("textbox_fade_up")

    if not animation_finished.is_connected(Callable(animation_system, &"animation_finished")):
        animation_finished.connect(
            Callable(animation_system, &"animation_finished"), CONNECT_ONE_SHOT
        )


## Prepares the textbox animation state for the next dialogue text.
func _on_about_to_show_text(info: Dictionary) -> void:
    full_clear = !info.append


## Plays the selected new-text animation and coordinates its start/end with Dialogic.
func _on_textbox_new_text() -> void:
    if DialogicUtil.autoload().Inputs.auto_skip.enabled:
        return

    if animation_new_text == AnimationsNewText.NONE:
        return

    var animation_system: Node = DialogicUtil.autoload().get(&"Animations")
    animation_system.call(&"start_animating")
    if full_clear:
        get_dialog().text = ""
    match animation_new_text:
        AnimationsNewText.WIGGLE:
            play("new_text")

            if not animation_finished.is_connected(
                Callable(animation_system, &"animation_finished")
            ):
                animation_finished.connect(
                    Callable(animation_system, &"animation_finished"), CONNECT_ONE_SHOT
                )


## Stops the current animation if one is playing.
func _on_animation_interrupted() -> void:
    if is_playing():
        stop()
