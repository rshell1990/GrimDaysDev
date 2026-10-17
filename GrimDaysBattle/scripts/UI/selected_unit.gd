# Editor configuration for UnitSelectedDisplay.
@tool
extends Control
## Controls the unit selected display presentation used by the battle interface.
class_name UnitSelectedDisplay
## Fixed size value shared by all unit selected display instances.
const SIZE: Vector2 = Vector2(3840, 384)
## Fixed portrait size value shared by all unit selected display instances.
const PORTRAIT_SIZE: Vector2 = Vector2(340, 340)
## Fixed default position value shared by all unit selected display instances.
const DEFAULT_POSITION: Vector2 = Vector2(0, 0)

## Emitted to notify listeners that remove occurred.
signal remove(id)

## Configures the portrait used by this unit selected display.
@export var portrait: TextureRect
## Configures the name shadow used by this unit selected display.
@export var name_shadow: Label
## Configures the name foreground used by this unit selected display.
@export var name_foreground: Label

## Runtime index state used by this unit selected display.
var index


## Initializes this unit selected display from the supplied runtime dependencies.
func setup(template: BattleUnitTemplate) -> void:
    portrait.texture = template.portrait
    name_shadow.text = template.display_name
    name_foreground.text = template.display_name
    name = template.id
    if not is_node_ready():
        await ready
    set_deferred("size", SIZE)
    portrait.set_deferred("size", PORTRAIT_SIZE)
    set_deferred("position", DEFAULT_POSITION)


## Handles the mouse entered notification for this unit selected display.
func _on_mouse_entered() -> void:
    name_foreground.modulate = Color.CRIMSON


## Handles the mouse exited notification for this unit selected display.
func _on_mouse_exited() -> void:
    name_foreground.modulate = Color.WHITE


## Handles the button up notification for this unit selected display.
func _on_button_up() -> void:
    remove.emit(index)
