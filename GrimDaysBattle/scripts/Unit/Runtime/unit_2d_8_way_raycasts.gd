extends Node
## Coordinates eight-way unit raycaster behavior for the battle system.
class_name Unit2D8WayRayCasts

## Fixed time till update value shared by all eight-way unit raycaster instances.
const TIME_TILL_UPDATE: float = 2.0

## Configures the west used by this eight-way unit raycaster.
@export var west: RayCast2D
## Configures the east used by this eight-way unit raycaster.
@export var east: RayCast2D
## Configures the north used by this eight-way unit raycaster.
@export var north: RayCast2D
## Configures the south used by this eight-way unit raycaster.
@export var south: RayCast2D
## Configures the north west used by this eight-way unit raycaster.
@export var north_west: RayCast2D
## Configures the south west used by this eight-way unit raycaster.
@export var south_west: RayCast2D
## Configures the north east used by this eight-way unit raycaster.
@export var north_east: RayCast2D
## Configures the south east used by this eight-way unit raycaster.
@export var south_east: RayCast2D

## Cached reference to the parent node, resolved when this node becomes ready.
@onready var parent: Unit2DSprite = get_parent()

## Ordered runtime collection of rays.
var rays: Array[RayCast2D]
## Ordered runtime collection of rays colliding.
var rays_colliding: Array[RayCast2D]
## Whether the checking rays condition currently holds.
var checking_rays: bool
## Runtime time since last check state used by this eight-way unit raycaster.
var time_since_last_check: float = TIME_TILL_UPDATE

## Emitted to notify listeners that colliding occurred.
signal colliding(colliding_rays)


## Caches dependencies and connects runtime signals after the node becomes ready.
func _ready() -> void:
    CustomLogger.hint(self, _ready, "Registering collision rays.", CustomLogger.LEVEL.VERY_VERBOSE)
    rays.append(west)
    rays.append(east)
    rays.append(north)
    rays.append(south)
    rays.append(north_west)
    rays.append(north_east)
    rays.append(south_east)
    rays.append(south_west)
    for ray in rays:
        ray.add_exception(parent.collision_area)


## Updates eight-way unit raycaster state for the current frame.
func _physics_process(delta: float) -> void:
    if checking_rays:
        return
    time_since_last_check += delta
    if time_since_last_check < TIME_TILL_UPDATE:
        return
    update_collisions()
    time_since_last_check = 0


## Updates collisions for this eight-way unit raycaster.
func update_collisions() -> void:
    CustomLogger.hint(self, update_collisions, "Updating ray collisions.", CustomLogger.LEVEL.VERY_VERBOSE)
    checking_rays = true
    var disabled_rays: int = 0
    for ray in rays:
        if not ray.enabled:
            disabled_rays += 1
        if ray.is_colliding():
            if not ray in rays_colliding:
                rays_colliding.append(ray)
        else:
            if ray in rays_colliding:
                var ray_position = rays_colliding.find(ray)
                rays_colliding.remove_at(ray_position)
    if disabled_rays == rays.size():
        CustomLogger.confirm(
            self, update_collisions, "All rays disabled; stopping collision checks.", CustomLogger.LEVEL.VERBOSE
        )
        process_mode = Node.PROCESS_MODE_DISABLED
    CustomLogger.hint(
        self, update_collisions, "Colliding rays: " + str(rays_colliding), CustomLogger.LEVEL.VERY_VERBOSE
    )
    if rays_colliding.size() > 1:
        colliding.emit(rays_colliding)
    checking_rays = false
