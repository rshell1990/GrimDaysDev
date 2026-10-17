extends Node
## Shared fixed value for flicker delay.
const FLICKER_DELAY: float = 0.05
## Lowest light brightness allowed during a flicker.
@export_range(0.1, 10.0) var minimum_energy: float = 0.1
## Highest light brightness allowed during a flicker.
@export_range(0.35, 15.0) var maximum_energy: float = 0.35
## Normal light brightness to restore after flickering.
@export_range(0.5, 2.0) var base_energy: float = 0.5
## List of lights used by this script.
var lights: Array[SpotLight3D] = []
## Remaining time before this script performs its next timed update.
var delay = FLICKER_DELAY


## Finds the child lights used by this flicker controller.
func _ready() -> void:
    search_children(self)


## On each drawn frame, this function decreases [code]delay[/code] by [code]delta[/code]; sets
## [code]delay[/code] to [code]FLICKER_DELAY[/code].
func _process(delta):
    delay -= delta
    if delay < 0:
        flicker_lights()
        delay = FLICKER_DELAY


## While outside game initialization, randomly selects lights for flickering using a draw from 0
## through 100.
func flicker_lights() -> void:
    if GameManager.state == GameManagerStates.STATES.Init:
        return
    for light in lights:
        var chance = randi_range(0, 100)
        if chance < 75:
            continue
        do_flicker(light)


## Chooses a brightness between the configured bounds and schedules brightness changes toward it and
## back to the base brightness.
func do_flicker(light: SpotLight3D):
    var new_energy = randf_range(minimum_energy, maximum_energy)
    tween_light(light, new_energy)
    tween_light(light, base_energy)


## Finds child lights and records them for later flicker updates.
func search_children(start):
    if start.get_child_count() < 1:
        return
    var tree = start.get_children()
    for node in tree:
        if node is SpotLight3D:
            lights.append(node)
        if node.get_child_count() > 0:
            search_children(node)


## Smoothly changes the supplied light's brightness toward the requested value.
func tween_light(light: SpotLight3D, amount: float) -> void:
    var tween = create_tween()
    await tween.tween_property(light, "light_energy", amount, 0.025).finished
