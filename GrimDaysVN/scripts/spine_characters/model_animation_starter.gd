extends SpineSprite


## Starts a looping idle animation on track zero if a Spine skeleton resource is assigned.
func _enter_tree() -> void:
    if skeleton_data_res != null:
        get_animation_state().set_animation("idle", true, 0)
