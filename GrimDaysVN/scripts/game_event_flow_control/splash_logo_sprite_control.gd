extends SpineSprite


## Loads the studio-logo Spine skeleton when this node enters the scene.
func _enter_tree() -> void:
    skeleton_data_res = ResourceLoader.load(
        "res://GrimDaysVN/resources/spine/sdg_logo.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
    )


## Releases the Spine skeleton resource reference when this node leaves the scene.
func _exit_tree() -> void:
    skeleton_data_res = null


## Starts the looping logo animation on track zero.
func _ready():
    var animation_state = get_animation_state()
    animation_state.add_animation("Loop", 0, true, 0)


## Queues a single ear-flick animation on track one.
func flick_ear():
    var animation_state = get_animation_state()
    animation_state.add_animation("Ear", 0, false, 1)
