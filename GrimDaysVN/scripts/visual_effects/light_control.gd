extends Node
## Light node whose brightness this effect changes.
@export var light: OmniLight3D


## Handles the particle effect ending by updating its associated light effect.
func _on_gpu_particles_3d_finished() -> void:
    light.visible = false
