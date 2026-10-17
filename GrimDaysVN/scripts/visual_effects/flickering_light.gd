# Editor configuration for flickering_light.
@tool
@icon("res://GrimDays/assets/visuals/editor_icons/expanded-rays.svg")
extends LoadableOmniLight
## Lowest light brightness allowed during a flicker.
@export_range(0.1, 10.0) var minimum_energy: float = 0.1
## Highest light brightness allowed during a flicker.
@export_range(0.35, 15.0) var maximum_energy: float = 0.35


## Outside game initialization, runs and waits for one flicker operation.
func _process(_delta):
    if GameManager.state == GameManagerStates.STATES.Init:
        return
    await do_flicker()


## Smoothly changes [code]light_energy[/code] over time. It pauses for
## [code]tween.tween_property(self, "light_energy", new_energy,
## VNAnimationTimes.STANDARD).finished[/code] before continuing.
func do_flicker():
    var new_energy = randf_range(minimum_energy, maximum_energy)
    var tween = create_tween()
    await tween.tween_property(self, "light_energy", new_energy, VNAnimationTimes.STANDARD).finished
