# Editor configuration for Unit2DParty.
@icon("res://GrimDays/assets/visuals/class_icons/cavalry.svg")
extends UnitParty
## Coordinates 2D unit party behavior for the battle system.
class_name Unit2DParty

## Configures the unit display template used by this 2D unit party.
@export var unit_display_template: PackedScene
## Configures the face right used by this 2D unit party.
@export var face_right: bool


## Adds to party for this 2D unit party.
func add_to_party(template: BattleUnitTemplate, bounds: CollisionShape2D) -> void:
    var new_unit: Unit2DDisplay = unit_display_template.instantiate()
    new_unit.initialize(template, bounds)
    new_unit.position = Vector2.ZERO
    add_child(new_unit)
    set_unit_position(new_unit)


## Sets unit position for this 2D unit party.
func set_unit_position(new_unit) -> void:
    var units: Array = get_children()
    if units.size() < 2:
        return
    if new_unit.repositioned:
        return
    new_unit.repositioned = true
    if not units[0].repositioned:
        set_unit_position(units[0])
    var unit_index: int = units.find(new_unit)
    match unit_index:
        0:
            if face_right:
                new_unit.translate(Vector2(250, -130))
            else:
                new_unit.translate(Vector2(-175, -130))
            #new_unit.name = "0"
        1:
            if face_right:
                new_unit.translate(Vector2(125, 130))
            else:
                new_unit.translate(Vector2(-175, 130))
            #new_unit.z_index = 1
            #new_unit.name = "1"
        2:
            if face_right:
                new_unit.translate(Vector2(-100, -130))
            else:
                new_unit.translate(Vector2(175, -130))
            #new_unit.name = "2"
        3:
            if face_right:
                new_unit.translate(Vector2(-225, 130))
            else:
                new_unit.translate(Vector2(175, 130))
            #new_unit.name = "3"
    new_unit.original_position = new_unit.global_position


## Returns whether child.
func is_child(node: Variant) -> bool:
    var result := false

    for x in range(0, get_child_count()):
        if get_child(x) == node:
            result = true
            break

    return result


## Handles the ray collision notification for this 2D unit party.
func on_ray_collision(emitter: Variant, rays: Array[RayCast2D]) -> void:
    CustomLogger.hint(
        self, on_ray_collision, "Emitter %s collided on rays %s." % [emitter, rays], CustomLogger.LEVEL.VERY_VERBOSE
    )
    if emitter.repositioned:
        return
    var others: Array = []
    for ray in rays:
        var other = ray.get_collider().get_parent().get_parent().get_parent()
        if other.repositioned:
            return
        if other not in others:
            others.append(other)

    for collided_with in others:
        on_party_first_collision(emitter, collided_with)


## Handles the party first collision notification for this 2D unit party.
func on_party_first_collision(emitter: Variant, other: Variant) -> void:
    if emitter.repositioned:
        return
    if other.repositioned:
        return

    reposition(emitter)


## Handles reposition for this 2D unit party.
func reposition(unit: Variant) -> void:
    CustomLogger.hint(self, reposition, "Repositioning party member.", CustomLogger.LEVEL.VERY_VERBOSE)
    var prefer_back: bool = false
    var party_size = get_child_count()
    if party_size > 2:
        prefer_back = true

    if face_right:
        reposition_left_side(unit, prefer_back)
        return

    reposition_right_side(unit, prefer_back)


## Handles left side for this 2D unit party.
func reposition_left_side(unit: Variant, prefer_back: bool) -> void:
    CustomLogger.hint(
        self, reposition_left_side, "Repositioning left-side party member.", CustomLogger.LEVEL.VERY_VERBOSE
    )
    unit.repositioned = true


## Handles back left for this 2D unit party.
func reposition_back_left(unit: Variant) -> void:
    var incoming_unit = unit as Node2D
    incoming_unit.move_local_x(-130.0)


## Handles right side for this 2D unit party.
func reposition_right_side(unit: Variant, prefer_back: bool) -> void:
    pass
