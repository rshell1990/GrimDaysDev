extends Control

## Shared fixed value for points per arc.
const POINTS_PER_ARC = 8

## Color used for bg color.
@export var bg_color: Color
## Color used for highlight color.
@export var highlight_color: Color
## Color used for line color.
@export var line_color: Color

## Outer radius in pixels of the radial menu.
@export var outer_radius: int = 256
## Radius in pixels of the radial menu's center area.
@export var inner_radius: float = 256.0
## Width in pixels of the radial menu's outlines.
@export var line_width: float = 6.0

## List of options used by this script.
@export var options: Array
## Lookup table for polygons; keys select the corresponding stored values.
@export var polygons: Dictionary

## Scene object used for collison holder.
@export var collison_holder: Node
## Collision shape used to detect input over the radial menu's center.
@export var center_shape: Shape2D

## Index of the highlighted radial-menu option; a value outside the option range means no normal
## option is selected.
var highlighted_option: int = 9999

## Notification for up.
signal up
## Notification for down.
signal down
## Notification for right.
signal right
## Notification for left.
signal left
## Notification for confirm.
signal confirm


## When the node is ready, this function sets [code]polygons[/code] to [code]{}[/code].
func _ready():
    polygons = {}
    make_polygon_collision_zones()


## Draws the radial menu's rings, segment boundaries and currently highlighted choice.
func _draw():
    draw_circle(Vector2.ZERO, outer_radius, bg_color)
    draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 256, line_color, line_width, true)
    draw_arc(Vector2.ZERO, outer_radius, 0, TAU, 256, line_color, line_width, true)

    for i in range(0, 4):
        var rads = TAU * i / options.size()
        var point = Vector2.from_angle(rads)
        match i:
            0:
                rads = (PI * 5.0) / 4
            1:
                rads = (PI * 7.0) / 4
            2:
                rads = PI / 4
            3:
                rads = (PI * 3.0) / 4

        point = Vector2.from_angle(rads)
        if i == highlighted_option:
            draw_polygon(
                polygons[i][0] + polygons[i][1],
                PackedColorArray([highlight_color]),
            )

        draw_line(point * inner_radius, point * outer_radius, line_color, line_width, true)
        if highlighted_option == 4:
            draw_circle(Vector2.ZERO, inner_radius, highlight_color)


## Requests a redraw each frame so selection highlighting stays current.
func _process(_delta):
    queue_redraw()


## Updates which radial-menu choice is highlighted.
func set_highlight(number: int):
    # #SystemHelpers.print(number)
    highlighted_option = number


## Builds mouse-sensitive shapes for the radial-menu segments and center, then connects their input
## responses.
func make_polygon_collision_zones():
    if not collison_holder:
        return
    for i in range(0, 4):
        var rads = get_rads(i)
        var start_rads = rads[0]
        var end_rads = rads[1]

        var points_inner = PackedVector2Array()
        var points_outer = PackedVector2Array()

        if i == 3:
            for j in range(POINTS_PER_ARC + 1):
                var angle = end_rads + j * (start_rads - end_rads) / POINTS_PER_ARC
                points_inner.append(inner_radius * Vector2.from_angle(TAU - angle))
                points_outer.append(outer_radius * Vector2.from_angle(TAU - angle))
        else:
            for j in range(POINTS_PER_ARC + 1):
                var angle = end_rads + j * (start_rads - end_rads) / POINTS_PER_ARC
                points_inner.append(inner_radius * Vector2.from_angle(PI - angle))
                points_outer.append(outer_radius * Vector2.from_angle(PI - angle))

        points_inner.reverse()

        polygons[i] = [points_inner, points_outer]

        var new_area = Area2D.new()
        new_area.name = "Option-" + str(i)
        collison_holder.add_child(new_area)
        new_area.owner = collison_holder
        var new_polygon = CollisionPolygon2D.new()
        new_polygon.polygon = polygons[i][0] + polygons[i][1]
        new_area.add_child(new_polygon)
        new_polygon.owner = new_area
        new_area.mouse_entered.connect(func(): self.set_highlight(i))
        connect_input(new_area, i)

    var sphere_area = Area2D.new()
    sphere_area.name = "Option-4"
    collison_holder.add_child(sphere_area)
    sphere_area.owner = collison_holder
    var new_circle: CollisionShape2D = CollisionShape2D.new()
    new_circle.shape = center_shape
    sphere_area.add_child(new_circle)
    new_circle.owner = sphere_area
    sphere_area.mouse_entered.connect(func(): self.set_highlight(4))
    sphere_area.input_event.connect(confirm_clicked)


## Clears the current radial-menu highlight when the pointer leaves the selectable area.
func _on_out_of_bounds():
    highlighted_option = 9999


## Returns the two boundary angles, in radians, for one of the four radial-menu segments.
func get_rads(i) -> Array[float]:
    var start_rads
    var end_rads
    match i:
        0:
            start_rads = (PI * 7.0) / 4
            end_rads = (PI * 5.0) / 4
        1:
            start_rads = (PI * 5.0) / 4
            end_rads = (PI * 3.0) / 4
        2:
            start_rads = (PI * 3.0) / 4
            end_rads = PI / 4
        3:
            start_rads = ((PI * 5.0) / 4)
            end_rads = ((PI * 3.0) / 4)
    var rads: Array[float] = [start_rads, end_rads]
    return rads


## Connects this menu to its directional and confirmation input responses.
func connect_input(new_area, i: int) -> void:
    match i:
        0:
            new_area.input_event.connect(up_clicked)
        1:
            new_area.input_event.connect(right_clicked)
        2:
            new_area.input_event.connect(down_clicked)
        3:
            new_area.input_event.connect(left_clicked)


## Selects the radial-menu option assigned to the up direction.
func up_clicked(_viewport, event, _shape_index) -> void:
    if event.is_action_pressed("dialogic_default_action"):
        #SystemHelpers.print("UP")
        InputHelper.rumble_small()
        up.emit()


## Selects the radial-menu option assigned to the down direction.
func down_clicked(_viewport, event, _shape_index) -> void:
    if event.is_action_pressed("dialogic_default_action"):
        #SystemHelpers.print("DOWN")
        InputHelper.rumble_small()
        down.emit()


## Selects the radial-menu option assigned to the left direction.
func left_clicked(_viewport, event, _shape_index) -> void:
    if event.is_action_pressed("dialogic_default_action"):
        #SystemHelpers.print("LEFT")
        InputHelper.rumble_small()
        left.emit()


## Selects the radial-menu option assigned to the right direction.
func right_clicked(_viewport, event, _shape_index) -> void:
    if event.is_action_pressed("dialogic_default_action"):
        #SystemHelpers.print("RIGHT")
        InputHelper.rumble_small()
        right.emit()


## Confirms the currently highlighted radial-menu choice.
func confirm_clicked(_viewport, event, _shape_index) -> void:
    if event.is_action_pressed("dialogic_default_action"):
        #SystemHelpers.print("OK")
        InputHelper.rumble_small()
        confirm.emit()
