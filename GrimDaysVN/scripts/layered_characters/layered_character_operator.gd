# Editor configuration for LayeredCharacterOperator.
@icon("res://GrimDays/assets/visuals/at-icons/node2d/human.svg")
extends CanvasGroup
class_name LayeredCharacterOperator
## Starting visual layer selected for each character layer group.
@export var default_layers: Dictionary[StringName,StringName]
## Scene nodes containing the available layers for each character group.
@export var groups: Dictionary[StringName, Node2D]
## Lookup table for layers; keys select the corresponding stored values.
var layers: Dictionary[StringName, Dictionary]
## Currently selected visual layer for each character layer group.
var active_layers: Dictionary[StringName,StringName]


## Builds the available character-layer lookup and selects the configured default layers.
func _ready() -> void:
    for group in groups.keys():
        var layers_in_group: Dictionary = {}
        for layer in groups[group].get_children():
            layers_in_group.set(layer.name, layer)
        layers.set(group, layers_in_group)


## Shows the character's currently selected visual layers.
func reveal() -> void:
    for group in default_layers.keys():
        on_layer_change(group, default_layers[group])


## Restores the previously selected visual layer in each character group.
func restore_layers(old_layers: Dictionary) -> void:
    active_layers = {}
    for group in old_layers.keys():
        on_layer_change(group, old_layers[group])


## Selects the requested layer within a character group, updating the remembered selection and
## visibility.
func on_layer_change(group: StringName, layer: StringName):
    if layers.is_empty() and not is_node_ready():
        await ready
    CustomLogger.hint(
        self,
        on_layer_change,
        "Changing skin in group:" + group + " - to: " + layer,
        CustomLogger.LEVEL.IMPORTANT
    )
    var current_layer_name: StringName = &""
    if active_layers.has(group):
        current_layer_name = active_layers[group]
    var tween = create_tween()
    active_layers.set(group, layer)
    if not current_layer_name.is_empty():
        tween.set_parallel(true)
        CustomLogger.warn(
            self,
            on_layer_change,
            "Existing layer:" + current_layer_name + " in group: " + group + " to be hidden",
            CustomLogger.LEVEL.VERBOSE
        )
        tween.tween_property(
            layers[group][current_layer_name], "modulate:a", 0.0, AnimationTimes.FAST
        )
    await tween.tween_property(
        layers[group][layer], "modulate:a", 1.0, AnimationTimes.STANDARD
    ).finished
