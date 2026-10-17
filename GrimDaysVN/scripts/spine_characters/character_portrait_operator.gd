extends SpineSprite
## Updates the appearance and animations of a character portrait.
class_name PortraitOperator

## Stored sprite used by this script’s update and input handling.
var sprite = self
## Lookup ID used to find this entry in the relevant resource collection.
@export var id: String


## Makes Spine update the portrait animation during physics updates.
func _ready() -> void:
    update_mode = SpineConstant.UpdateMode_Physics


## Adds [code]sprite.get_animation_state().get_current(x).get_animation().get_name()[/code] to
## [code]current_animations[/code]; selects a Spine animation on [code]animation_state[/code].
func on_expression_change(args):
    var animation_state = sprite.get_animation_state()
    var current_animations = []
    for x in range(0, sprite.get_animation_state().get_num_tracks()):
        current_animations.append(sprite.get_animation_state().get_current(x).get_animation().get_name())

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
    var data = sprite.get_skeleton().get_data()
    var new_appearance = sprite.new_skin(args.skin)
    var character_parts = Repositories.get_info(RepositoryTypes.SKINS, args.id)
    for parts in character_parts[args.skin]:
        new_appearance.add_skin(data.find_skin(parts))

    var skeleton = sprite.get_skeleton()
    skeleton.set_skin(new_appearance)
    skeleton.set_slots_to_setup_pose()


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func on_leave():
    pass


## Adds [code]animation_info.called[/code] to [code]default_animation_list[/code]; sets
## [code]sprite.skeleton_data_res[/code] to [code]a_skeleton[/code]; sets [code]id[/code] to
## [code]a_id[/code].
func on_init(a_id, a_skeleton):
    sprite.skeleton_data_res = a_skeleton
    id = a_id
    var default_animation_list = ["idle"]
    var character_repository = (
        Repositories.get_repository(RepositoryTypes.CHARACTER_ANIMATIONS) as SpineAnimationsRepository
    )
    if character_repository.default_expression.has(a_id):
        for animation_info in character_repository.default_expression[a_id]:
            default_animation_list.append(animation_info.called)
    on_expression_change({"id": a_id, "animation_list": default_animation_list})
    id = a_id
    on_skin_change({"id": id, "skin": "default"})


## Adds [code]self.sprite.get_animation_state().get_current(x).get_animation().get_name()[/code] to
## [code]current_animations[/code]. Returns [code]info[/code].
func get_character_info():
    var info: Dictionary = {}
    info["location"] = position
    info["rotation"] = rotation
    var current_animations = []
    for x in range(0, self.sprite.get_animation_state().get_num_tracks()):
        current_animations.append(self.sprite.get_animation_state().get_current(x).get_animation().get_name())

    info["animation"] = current_animations
    if sprite.get_skeleton().get_skin() != null:
        info["skins"] = sprite.get_skeleton().get_skin().get_name()
    else:
        info["skins"] = "default"
    return info
