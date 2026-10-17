extends SpineSprite


## When the node enters the scene, this function selects a Spine animation on
## [code]animations[/code].
func _enter_tree() -> void:
    var animations = get_animation_state()
    animations.set_animation("Loop2")
