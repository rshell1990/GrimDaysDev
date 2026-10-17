# Editor configuration for SelectableUnitDisplay.
@tool
extends Control
## Controls the selectable unit display presentation used by the battle interface.
class_name SelectableUnitDisplay
## Fixed default position value shared by all selectable unit display instances.
const DEFAULT_POSITION: Vector2 = Vector2(0, 0)
## Fixed size value shared by all selectable unit display instances.
const SIZE: Vector2 = Vector2(384, 384)
## Fixed portrait size value shared by all selectable unit display instances.
const PORTRAIT_SIZE: Vector2 = Vector2(340, 340)

## Emitted to notify listeners that add occurred.
signal add(id)

## Configures the idle background used by this selectable unit display.
@export var idle_background: Texture
## Configures the hover background used by this selectable unit display.
@export var hover_background: Texture
## Configures the background used by this selectable unit display.
@export var background: TextureRect
## Configures the portrait used by this selectable unit display.
@export var portrait: TextureRect


## Initializes this selectable unit display from the supplied runtime dependencies.
func setup(template: BattleUnitTemplate) -> void:
    portrait.texture = template.portrait
    name = template.id
    if not is_node_ready():
        await ready
    set_deferred("size", SIZE)
    portrait.set_deferred("size", PORTRAIT_SIZE)
    set_deferred("position", DEFAULT_POSITION)


## Handles the mouse entered notification for this selectable unit display.
func _on_mouse_entered() -> void:
    background.texture = hover_background


## Handles the mouse exited notification for this selectable unit display.
func _on_mouse_exited() -> void:
    background.texture = idle_background


## Handles the button up notification for this selectable unit display.
func _on_button_up() -> void:
    add.emit(name)
