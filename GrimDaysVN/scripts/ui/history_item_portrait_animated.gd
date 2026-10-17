extends SpineSprite


## When the node is ready, this function selects a Spine animation on [code]animation_state[/code].
func _ready() -> void:
    var animation_state = get_animation_state()
    animation_state.set_animation("idle", true, 0)
