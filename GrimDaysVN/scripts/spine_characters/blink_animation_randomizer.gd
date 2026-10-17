extends Timer
## Animation player used for animator.
@export var animator: AnimationPlayer

## Shared fixed value for starting blink chance.
const STARTING_BLINK_CHANCE = 50
## Shared fixed value for increasing chance.
const INCREASING_CHANCE = 10

## Chance used for the next blink attempt, increased when attempts do not blink.
var current_blink_chance: int = STARTING_BLINK_CHANCE


## When the node is ready, this function connects responses to [code]timeout[/code].
func _ready() -> void:
    timeout.connect(on_timeout)


## Starts playback on [code]animator[/code]; increases [code]current_blink_chance[/code] by
## [code]INCREASING_CHANCE[/code]; sets [code]current_blink_chance[/code] to
## [code]STARTING_BLINK_CHANCE[/code].
func on_timeout() -> void:
    if animator.is_playing():
        return
    var random_roll: int = randi_range(0, 400)
    if random_roll > current_blink_chance:
        current_blink_chance += INCREASING_CHANCE
        return
    animator.play("blink")
    current_blink_chance = STARTING_BLINK_CHANCE
