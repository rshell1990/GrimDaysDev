extends AnimationPlayer


## Chooses an animation speed multiplier between 0.7 and 1.1 when entering the scene.
func _enter_tree() -> void:
    speed_scale = randf_range(0.7, 1.1)
