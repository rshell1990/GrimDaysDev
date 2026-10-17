extends LoadableCanvasLayer


## Updates the screen-shake effect's strength and optional transition speed.
func set_shake_strength(value: float, cycle_speed: float = 0.0) -> void:
    %ShakeShader.set_shake_strength(value, cycle_speed)
