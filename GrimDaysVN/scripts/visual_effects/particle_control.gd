extends GPUParticles3D


## Schedules this completed particle effect for deletion.
func _on_finished() -> void:
    var tween = create_tween()
    await tween.tween_property(self, "speed_scale", 30.0, VNAnimationTimes.FAST).finished
    visible = false
    queue_free()
