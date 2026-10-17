# Editor configuration for SpineViewportLoader.
@icon("res://GrimDays/assets/visuals/editor_icons/vr-headset.svg")
extends SubViewport
class_name SpineViewportLoader
## File or resource path used for skeleton data path.
@export_file() var skeleton_data_path: String
## Coordinates used for loaded size.
@export var loaded_size: Vector2
## Lookup ID used to find this entry in the relevant resource collection.
@export var id: StringName
## Stored sprite used by this script’s update and input handling.
var sprite: SpineSprite


## When the node enters the scene, this function sets [code]sprite[/code] to
## [code]get_child(0)[/code]; updates [code]sprite.skeleton_data_res[/code] using
## [code]ResourceLoader.load[/code].
func _enter_tree() -> void:
    sprite = get_child(0)
    sprite.skeleton_data_res = ResourceLoader.load(
        skeleton_data_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
    )
    size = loaded_size


## When the node leaves the scene, this function sets [code]sprite[/code] to null.
func _exit_tree() -> void:
    sprite = null
    size = Vector2(2, 2)


## When the node is ready, this function adds [code]animation_info.called[/code] to
## [code]default_animation_list[/code].
func _ready() -> void:
    var default_animation_list = ["idle"]
    if id.is_empty():
        return
    var character_repository = Repositories.get_repository(
        RepositoryTypes.CHARACTER_ANIMATIONS
    ) as SpineAnimationsRepository
    if character_repository.default_expression.has(id):
        for animation_info in character_repository.default_expression[id]:
            default_animation_list.append(animation_info.called)
    on_expression_change({"id": id, "animation_list": default_animation_list})
    on_skin_change({"id": id, "skin": "default"})


## Adds [code]sprite.get_animation_state().get_current(x).get_animation().get_name()[/code] to
## [code]current_animations[/code]; selects a Spine animation on [code]animation_state[/code].
func on_expression_change(args):
    var animation_state = sprite.get_animation_state()
    if not animation_state:
        return
    var current_animations = []
    for x in range(0, sprite.get_animation_state().get_num_tracks()):
        current_animations.append(
            sprite.get_animation_state().get_current(x).get_animation().get_name()
        )

    for animation in args.animation_list:
        if animation in current_animations:
            continue
        var character = Repositories.get_info(RepositoryTypes.CHARACTER_ANIMATIONS, args.id)
        if not character.has(animation):
            continue
        var anim = character[animation]
        animation_state.set_animation(anim.animation_name, anim.will_loop, anim.track)


## Changes the visible skin on [code]skeleton[/code].
func on_skin_change(args):
    if not sprite.skeleton_data_res:
        return
    var data = sprite.get_skeleton().get_data()
    var new_appearance = sprite.new_skin(args.skin)
    var character_parts = Repositories.get_info(RepositoryTypes.SKINS, args.id)
    for parts in character_parts[args.skin]:
        new_appearance.add_skin(data.find_skin(parts))

    var skeleton = sprite.get_skeleton()
    skeleton.set_skin(new_appearance)
    skeleton.set_slots_to_setup_pose()
