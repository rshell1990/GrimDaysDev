extends Sprite2D
## Coordinates unit2 dsprite behavior for the battle system.
class_name Unit2DSprite

## Emitted to notify listeners that colliding occurred.
signal colliding(rays)
## Configures the collision area used by this unit2 dsprite.
@export var collision_area: Area2D
## Configures the raycaster used by this unit2 dsprite.
@export var raycaster: Node2D
## Configures the attack particle used by this unit2 dsprite.
@export var attack_particle: AnimatedSprite2D
## Configures the attack sound used by this unit2 dsprite.
@export_file_path var attack_sound: String
## Configures the hit sound used by this unit2 dsprite.
@export_file_path var hit_sound: String
## Configures the crit sound used by this unit2 dsprite.
@export_file_path var crit_sound: String


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    if not raycaster:
        return
    raycaster.colliding.connect(on_rays_colliding)


## Handles the rays colliding notification for this unit2 dsprite.
func on_rays_colliding(rays: Array[RayCast2D]) -> void:
    colliding.emit(rays)
