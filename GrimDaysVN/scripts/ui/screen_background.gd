extends Control
## Whether appeared is currently enabled or true.
var appeared: bool = false


## Plays the RESET animation to put the background in its starting state.
func _ready():
    $AnimationPlayer.play("RESET")


## Sets [code]appeared[/code] to [code]!appeared[/code].
func play_anim():
    if not appeared:
        $AnimationPlayer.play("appear")
    else:
        $AnimationPlayer.play_backwards("appear")
    appeared = !appeared
