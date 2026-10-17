# Editor configuration for SelectionUI.
@icon("res://GrimDays/assets/visuals/class_icons/targeted.svg")
extends Node
## Controls the selection ui presentation used by the battle interface.
class_name SelectionUI
## Fixed transparent value shared by all selection ui instances.
const TRANSPARENT: float = 0.0
## Fixed opaque value shared by all selection ui instances.
const OPAQUE: float = 1.0
## Fixed alpha property value shared by all selection ui instances.
const ALPHA_PROPERTY: String = "modulate:a"


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    SignalBus.battle_action_select.connect(on_selection_active)
    SignalBus.battle_action_selected.connect(on_selection_disable)


## Handles the selection active notification for this selection ui.
func on_selection_active() -> void:
    var tween = create_tween()
    tween.tween_property(self, ALPHA_PROPERTY, OPAQUE, AnimationTimes.STANDARD)


## Handles the selection disable notification for this selection ui.
func on_selection_disable() -> void:
    var tween = create_tween()
    tween.tween_property(self, ALPHA_PROPERTY, TRANSPARENT, AnimationTimes.STANDARD)
