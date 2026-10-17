extends Node
## Recreates characters on display layers and applies saved character settings.
class_name LoadCharactersOperation
## Notification for loaded.
signal loaded


## Sends [code]loaded[/code] notifications. It pauses for [code]add_template_to_depth(args,
## depth)[/code] before continuing.
func execute(args) -> void:
    for depth in args.state:
        reset_characters_on_depth(args, depth)
        for id in args.state[depth]:
            SystemHelpers.print_rich("[b][color=#F72]RESTORING: " + id)
            var restored_character: CharacterOperator = await add_template_to_depth(args, depth)
            #await get_tree().create_timer(0.01).timeout
            SystemHelpers.print_rich("[b][color=#F72]CONFIGURING: " + id)
            config_restored_character(restored_character, args, depth, id)

    loaded.emit()


## Resets the named character display layer if it is present in the supplied layer lookup.
func reset_characters_on_depth(args, depth) -> void:
    if not args.depths.has(depth):
        return
    args.depths[depth].reset_depth()


## Creates a character from the supplied template. If the target layer exists, schedules attachment,
## waits for a child to enter, then transfers the character to that layer; returns the character
## either way.
func add_template_to_depth(args, depth) -> CharacterOperator:
    var template = args.template.instantiate()
    var depth_node: Node = args.depths[depth] if args.depths.has(depth) else null
    #assert(depth_node)
    if depth_node == null:
        return template
    depth_node.add_child.call_deferred(template)
    await depth_node.child_entered_tree
    depth_node.transfer_to(template)

    return template


## Applies the saved character ID, layer and visual settings to a recreated character.
func config_restored_character(template: CharacterOperator, args: Dictionary, depth: String, id: String) -> void:
    assert(not args.depths.is_empty())
    template.flip_h = args.state[depth][id].flipped
    template.name = id
    template.on_init(id)
    template.position = args.state[depth][id].location
    template.rotation = args.state[depth][id].rotation
    template.layers = args.depths[depth].layers
    if not template.sprite:
        await template.outer_view.child_entered_tree
        template.sprite = template.outer_view.get_child(0)
    template.sprite.restore_layers(args.state[depth][id].active_layers)
