extends Timer

## Stored randomizer used by this script’s update and input handling.
var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
## Threshold compared with a random draw when deciding whether to blink.
var chance_to_blink: int = 45
## Character object controlled or observed by this helper.
var character: Variant
## Shortest delay in seconds before another blink check.
var min_time_to_blink: float = 1.5
## Longest delay in seconds before another blink check.
var max_time_to_blink: float = 5.0


## When the node is ready, this function sets [code]character[/code] to [code]get_parent()[/code].
func _ready():
    character = get_parent()
    if character.sprite == null:
        return


## Selects a Spine animation on [code]animation_state[/code]; sets [code]chance_to_blink[/code] to
## [code]0[/code]; increases [code]chance_to_blink[/code] by [code]15[/code]. It also sets
## [code]chance_to_blink[/code] to [code]clampi(chance_to_blink, 0, 100)[/code].
func _on_timeout() -> void:
    if character.id == "":
        return

    if not Repositories.get_info(RepositoryTypes.CHARACTER_ANIMATIONS, character.id).has("blink"):
        process_mode = Node.PROCESS_MODE_DISABLED
        return

    var blink_info = (
        Repositories.get_info(RepositoryTypes.CHARACTER_ANIMATIONS, character.id)["blink"]
    )
    var animation_name = blink_info.animation_name

    if random_blink_chance(chance_to_blink):
        chance_to_blink = 0
        wait_time = randomizer.randf_range(min_time_to_blink, max_time_to_blink)
        var animation_state = character.sprite.get_animation_state()
        animation_state.set_animation(animation_name, blink_info.will_loop, blink_info.track)
    else:
        chance_to_blink += 15

    chance_to_blink = clampi(chance_to_blink, 0, 100)


## Returns false if the blink is already active; otherwise compares a random integer from 0 through
## 100 against the supplied chance.
func random_blink_chance(chance) -> bool:
    var animation_state = character.sprite.get_animation_state()

    var animation_name = (
        Repositories
        .get_info(RepositoryTypes.CHARACTER_ANIMATIONS, character.id)["blink"]
        .animation_name
    )

    if animation_name in animation_state:
        return false
    var random: int = randomizer.randi_range(0, 100)
    var success: bool = true if random <= chance else false

    return success
