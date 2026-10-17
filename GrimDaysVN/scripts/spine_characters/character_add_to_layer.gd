extends Node
## Creates a character on a requested display layer and applies its starting appearance.
class_name AddToDepthOperation


## Smoothly changes opacity over time; adds [code]new_character[/code] as a child of
## [code]data.depth[/code]; sets [code]new_character.name[/code] to [code]data.id[/code]. It also
## sets [code]new_character.flip_h[/code] to true. It pauses for
## [code]new_character.tree_entered[/code], [code]tween.tween_property(new_character, "modulate:a",
## 1.0, VNAnimationTimes.STANDARD).finished[/code] before continuing. Returns
## [code]new_character[/code].
static func execute(data: Dictionary, start_hidden: bool) -> CharacterOperator:
    CustomLogger.hint(
        AddToDepthOperation,
        execute,
        "Starting process to add: " + data.id + " to depth:" + data.depth.name,
        CustomLogger.LEVEL.MILD
    )
    var flipped = DialogicUtil.str_to_bool(data.flipped)

    var new_character: CharacterOperator = data.template.instantiate()
    new_character.name = data.id
    new_character.on_init(data.id)
    new_character.modulate.a = 0.0
    if flipped:
        new_character.flip_h = true

    data.depth.add_child(new_character)
    if not new_character.is_inside_tree():
        await new_character.tree_entered

    new_character.layers = data.depth.layers
    new_character.sorting_offset = data.depth.sorting_offset

    var start = Vector3(data.start.to_float(), 0.0, 0.0)

    new_character.position = start
    new_character.scale = Vector3(0.2, 0.2, 0.2)

    if not start_hidden:
        var tween = SystemHelpers.create_tween()
        await tween.tween_property(new_character, "modulate:a", 1.0, VNAnimationTimes.STANDARD).finished
    return new_character
