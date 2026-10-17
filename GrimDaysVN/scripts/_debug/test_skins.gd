# Editor configuration for test_skins.
@tool
extends Node

## Lookup table for available models; keys select the corresponding stored values.
@export_category("Model Library")
@export var available_models: Dictionary[StringName, SpineSprite]
## Lookup table for default skins; keys select the corresponding stored values.
@export var default_skins: Dictionary[StringName, Array]

## List of skin parts used by this script.
@export_category("Current Model Info")
@export var skin_parts: Array
## Lookup table for animations; keys select the corresponding stored values.
@export var animations: Dictionary[String, Array]

## Model ID selected when the skin-testing controls first open.
@export_category("Other")
@export var starting_model_id: StringName
## Scene object used for skin list.
@export var skin_list: HBoxContainer
## Scene object used for animation list.
@export var animation_list: HBoxContainer
## Scene object used for current model id label.
@export var current_model_id_label: Label

## ID of the model currently selected in the skin test controls.
var current_model_id: StringName
## Skin parts currently selected for the test model.
var current_parts: Array
## Position of the selected model in the test model list.
var current_model_index: int = 0


## When the node is ready, this function sets [code]current_model_id[/code] to
## [code]starting_model_id[/code]; sets [code]current_model_index[/code] to
## [code]model_index[/code]; sets [code]current_model_id_label.text[/code] to
## [code]available_keys[current_model_index][/code].
func _ready() -> void:
    current_model_id = starting_model_id
    var available_keys = available_models.keys()
    var model_index = available_keys.find(current_model_id)
    current_model_index = model_index
    setup_current_model()
    current_model_id_label.text = available_keys[current_model_index]


## Selects a different model in the skin test interface and refreshes its controls.
func change_current_model(new_model) -> void:
    current_model_id = new_model
    setup_current_model()


## Moves to the next test model, wrapping according to the available model list.
func increase_index() -> void:
    var available_keys = available_models.keys()
    current_model_index = clampi(current_model_index + 1, 0, available_keys.size() - 1)
    current_model_id_label.text = available_keys[current_model_index]
    change_current_model(available_keys[current_model_index])


## Moves to the previous test model, wrapping according to the available model list.
func decrease_index() -> void:
    var available_keys = available_models.keys()
    current_model_index = clampi(current_model_index - 1, 0, available_keys.size() - 1)
    current_model_id_label.text = available_keys[current_model_index]
    change_current_model(available_keys[current_model_index])


## Shows the selected model, gathers its skins and animations, and rebuilds the skin/animation
## controls.
func setup_current_model() -> void:
    for model in available_models.values():
        model.visible = false

    for x in range(1, skin_list.get_child_count()):
        skin_list.get_child(x).queue_free()
    for y in range(1, animation_list.get_child_count()):
        animation_list.get_child(y).queue_free()

    skin_parts = []
    var skins = available_models[current_model_id].get_skeleton().get_data().get_skins()
    for skin in skins:
        skin_parts.append(skin.get_name())
    animations = {}
    var all_animations = available_models[current_model_id].get_skeleton().get_data().get_animations()
    for animation in all_animations:
        var split_name = animation.get_name().split("/")
        var category = split_name[1] if split_name.size() > 1 else "body"
        if animations.has(category):
            animations[category].append(animation.get_name())
        else:
            var new_array: Array = []
            animations.set(category, new_array)
            animations[category].append(animation.get_name())

    setup_skin_controls()
    setup_animation_controls()

    if not owner.is_node_ready():
        await owner.ready

    _on_reset_button_up()
    _on_animation_reset_button_up()
    available_models[current_model_id].visible = true


## Changes the visible skin on [code]skeleton[/code]; sets [code]current_parts[/code] to
## [code]new_skin[/code]; sets [code]current_parts[/code] to [code][][/code].
func set_skin(new_skin: Array) -> void:
    var skeleton: SpineSkeleton = available_models[current_model_id].get_skeleton()
    var data = skeleton.get_data()
    var new_appearance = available_models[current_model_id].new_skin(new_skin[0])
    current_parts = new_skin
    for parts in new_skin:
        new_appearance.add_skin(data.find_skin(parts))

    skeleton.set_skin(new_appearance)
    skeleton.set_slots_to_setup_pose()
    if new_skin.size() == 1:
        current_parts = []
        return
    current_parts = new_skin


## Adds [code]new_part[/code] to [code]current_parts[/code]; changes the visible skin on
## [code]skeleton[/code].
func add_skin(new_part) -> void:
    SystemHelpers.print("Adding: ", new_part)
    var skeleton: SpineSkeleton = available_models[current_model_id].get_skeleton()
    var data = skeleton.get_data()
    var new_appearance = available_models[current_model_id].new_skin(new_part)
    var removed_part: String = ""
    for x in range(current_parts.size() - 1, -1, -1):
        var old_part = current_parts[x]
        var split_old_part: Array = old_part.split("/").slice(0, -1)
        var split_new_part: Array = new_part.split("/").slice(0, -1)
        if split_old_part == split_new_part:
            SystemHelpers.print(split_old_part)
            SystemHelpers.print(split_new_part)
            current_parts.remove_at(x)
            removed_part = old_part
            break

    SystemHelpers.print(current_parts)
    for parts in current_parts:
        new_appearance.add_skin(data.find_skin(parts))

    if removed_part != new_part:
        new_appearance.add_skin(data.find_skin(new_part))
        current_parts.append(new_part)

    skeleton.set_skin(new_appearance)
    skeleton.set_slots_to_setup_pose()


## Restores the selected model's default skin parts.
func _on_reset_button_up() -> void:
    set_skin(default_skins[current_model_id])


## Plays confident eye and talking-mouth animations on the selected test model.
func _on_confident_pressed() -> void:
    available_models[current_model_id].get_animation_state().add_animation("expressions/eyes/confident", 0.0, false, 1)
    available_models[current_model_id].get_animation_state().add_animation(
        "expressions/mouth/confident-talk", 0.0, true, 2
    )


## Restores the default body animation and neutral eye and mouth animations.
func _on_animation_reset_button_up() -> void:
    available_models[current_model_id].get_animation_state().set_animation(animations["body"][0], true, 0)
    available_models[current_model_id].get_animation_state().add_animation("expressions/eyes/neutral", 0.0, false, 1)
    available_models[current_model_id].get_animation_state().add_animation("expressions/mouth/neutral-mc", 0.0, true, 2)


## Builds controls for the selected model's available skin parts.
func setup_skin_controls() -> void:
    var skin_list_first_child = skin_list.get_child(0)
    var skin_categories: Dictionary[String, Array] = {}
    for skin in skin_parts:
        var split_name = skin.split("/")
        var category = split_name[1] if split_name.size() > 1 else "body"
        var sub_category = ""
        if split_name.size() > 3:
            for x in range(2, split_name.size() - 1):
                sub_category += split_name[x] + "_"
        if sub_category.ends_with("_"):
            sub_category.trim_suffix("_")
        if split_name[-1].matchn("Default"):
            continue
        if not sub_category.is_empty():
            category += "_" + sub_category
        if skin_categories.has(category):
            skin_categories[category].append(skin)
        else:
            var new_array: Array = []
            skin_categories.set(category, new_array)
            skin_categories[category].append(skin)

    for category: String in skin_categories.keys():
        var new_category = skin_list_first_child.duplicate()
        skin_list.add_child(new_category)
        new_category.visible = true
        new_category.name = category
        var label = new_category.get_child(0)
        label.text = category.capitalize()
        var vbox = new_category.get_child(1)
        for skin in skin_categories[category]:
            var button = Button.new()
            vbox.add_child(button)
            var skin_name = skin.split("/")[-1].capitalize()
            button.text = skin_name
            button.pressed.connect(add_skin.bind(skin))


## Builds controls for the selected model's available animations.
func setup_animation_controls() -> void:
    var animation_list_first_child = animation_list.get_child(0)
    var category_track_index: Dictionary[String, int] = {
        "body": 0,
        "eyes": 1,
        "mouth": 2,
        "blinking": 1,
    }
    for category: String in animations.keys():
        var new_category = animation_list_first_child.duplicate()
        animation_list.add_child(new_category)
        new_category.visible = true
        new_category.name = category
        var label = new_category.get_child(0)
        label.text = category.capitalize()
        var vbox = new_category.get_child(1)
        for animation in animations[category]:
            var button = Button.new()
            vbox.add_child(button)
            var skin_name = animation.split("/")[-1].capitalize()
            button.text = skin_name
            button.pressed.connect(add_animation.bind(animation, category_track_index[category]))


## Queues the named animation on the requested track. Talking animations loop and use the fast blend
## duration; others play once with a 0.05-second blend.
func add_animation(anim_name: String, anim_track: int) -> void:
    var animation_track = available_models[current_model_id].get_animation_state().add_animation(
        anim_name, 0.0, false if anim_name.split("-")[-1] != "talk" else true, anim_track
    )
    if anim_name.split("-")[-1] == "talk":
        animation_track.set_mix_duration(VNAnimationTimes.FAST)
    else:
        animation_track.set_mix_duration(0.05)


## Sets 2D edge smoothing to off for the test viewport.
func _on_twod_aa_off_pressed() -> void:
    RenderingServer.viewport_set_msaa_2d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED
    )


## Sets 2D edge smoothing to 2x for the test viewport.
func _on_twod_aa_tw_ox_button_up() -> void:
    RenderingServer.viewport_set_msaa_2d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X
    )


## Sets 2D edge smoothing to 4x for the test viewport.
func _on_twod_aa_fou_rx_button_up() -> void:
    RenderingServer.viewport_set_msaa_2d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X
    )


## Sets 2D edge smoothing to 8x for the test viewport.
func _on_twod_aa_eigh_tx_button_up() -> void:
    RenderingServer.viewport_set_msaa_2d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_8X
    )


## Sets 3D edge smoothing to off for the test viewport.
func _on_threed_aa_off_button_up() -> void:
    RenderingServer.viewport_set_msaa_3d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED
    )


## Sets 3D edge smoothing to 2x for the test viewport.
func _on_threed_aa_tw_ox_button_up() -> void:
    RenderingServer.viewport_set_msaa_3d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X
    )


## Sets 3D edge smoothing to 4x for the test viewport.
func _on_threed_aa_fou_rx_button_up() -> void:
    RenderingServer.viewport_set_msaa_3d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X
    )


## Sets 3D edge smoothing to 8x for the test viewport.
func _on_threed_aa_eigh_tx_button_up() -> void:
    RenderingServer.viewport_set_msaa_3d(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_8X
    )


## Sets screen-space FXAA edge smoothing to off for the test viewport.
func _on_fxaa_off_button_up() -> void:
    RenderingServer.viewport_set_screen_space_aa(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_SCREEN_SPACE_AA_DISABLED
    )


## Sets screen-space FXAA edge smoothing to on for the test viewport.
func _on_fxaa_on_button_up() -> void:
    RenderingServer.viewport_set_screen_space_aa(
        get_node("/root").get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_SCREEN_SPACE_AA_FXAA
    )
