extends VBoxContainer
## Notification for start test battle. Supplies [code]template[/code] to connected functions.
signal start_test_battle(template)
## List of panels used by this script.
@export var panels: Array[Panel]
## Lookup table for sprites; keys select the corresponding stored values.
@export var sprites: Dictionary
## Scene control for viewport, used to display or change the related setting.
@export var viewport: SubViewport
## Scene object used for sprite holder.
@export var sprite_holder: Control


## When the node is ready, this function connects responses to [code]option.gui_input[/code],
## [code]option.mouse_entered[/code], [code]option.mouse_exited[/code]; adds [code]sprite[/code] as
## a child of [code]sprite_holder[/code]; sets [code]sprites[option][/code] to [code]sprite[/code].
## It also sets [code]sprite.visible[/code] to false.
func _ready():
    for option in panels:
        option.gui_input.connect(on_input.bind(option))
        option.mouse_entered.connect(on_mouse_enter.bind(option))
        option.mouse_exited.connect(on_mouse_exited.bind(option))
        var sprite = option.fight_info.enemy_template.sprite.instantiate()
        sprites[option] = sprite
        sprite.visible = false
        sprite_holder.add_child(sprite)


## Starts the selected test fight when the dialogue/confirm input action is pressed.
func on_input(event: InputEvent, option_panel):
    if event.is_action_pressed("dialogic_default_action"):
        var template = option_panel.fight_info.enemy_template
        _on_battle_test_pressed(template)


## Sets [code]child.visible[/code] to false.
func on_mouse_enter(option_panel):
    for child in sprite_holder.get_children():
        child.visible = false

    sprites[option_panel].visible = true


## Sets [code]child.visible[/code] to false.
func on_mouse_exited(_option_panel):
    for child in sprite_holder.get_children():
        child.visible = false


## Sends [code]start_test_battle[/code] notifications.
func _on_battle_test_pressed(template) -> void:
    start_test_battle.emit(template)
