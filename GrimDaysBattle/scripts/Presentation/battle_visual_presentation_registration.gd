extends Sprite2D
## Registers the debug battle scene's visual nodes with the battle controller for
## exactly the lifetime of this scene.

## Visual adapter registered with the debug battle controller while this node is present.
var presentation_adapter: BattleVisualPresentationAdapter


## When the node is ready, this function sets [code]presentation_adapter[/code] to
## [code]BattleVisualPresentationAdapter.new([/code].
func _ready() -> void:
    presentation_adapter = (
        BattleVisualPresentationAdapter
        . new(
            $Battlefield/Allies,
            $Battlefield/Foes,
            $"Camera Bounds/Camera Bounding Shape",
        )
    )
    BattleController.set_presentation_adapter(presentation_adapter)


## Unregisters this visual presentation adapter from the debug battle controller when the node
## leaves the scene.
func _exit_tree() -> void:
    BattleController.clear_presentation_adapter(presentation_adapter)
