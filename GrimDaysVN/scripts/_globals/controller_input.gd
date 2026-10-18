extends Node
## Routes standard gamepad input through the existing mouse and UI interactions.

## Speed applied to the left stick when it moves the virtual mouse cursor.
const CURSOR_SPEED: float = 900.0
## Left-stick values below this threshold do not move the cursor.
const CURSOR_DEADZONE: float = 0.2

## Gamepad currently driving the virtual mouse cursor, or -1 when inactive.
var _controller_id: int = -1
## Whether gamepad input currently owns mouse-cursor movement.
var _controller_active: bool = false
## Prevents the mouse events generated for one controller press from recursively being handled.
var _sending_virtual_click: bool = false
## Distinguishes cursor motion produced by warping from physical mouse movement.
var _expected_cursor_position: Vector2 = Vector2.ZERO
var _cursor_warp_pending: bool = false


## Activates controller input, sends controller A as a mouse click, and gives D-pad input an
## initial focus target when the current scene has no focused control.
func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var is_controller_warp: bool = (
            _controller_active
            and _cursor_warp_pending
            and event.position.is_equal_approx(_expected_cursor_position)
        )
        _cursor_warp_pending = false
        if is_controller_warp:
            return

    if event is InputEventMouseMotion or event is InputEventMouseButton:
        var is_controller_click := (
            event is InputEventMouseButton
            and _controller_active
            and event.device == _controller_id
        )
        if not _sending_virtual_click and not is_controller_click:
            _controller_active = false
            _controller_id = -1
        return

    if event is not InputEventJoypadButton and event is not InputEventJoypadMotion:
        return

    _controller_id = event.device
    _controller_active = true

    if event is InputEventJoypadButton and event.pressed:
        if event.button_index == JOY_BUTTON_A:
            call_deferred("_send_virtual_click")
            get_viewport().set_input_as_handled()
            return

        if _is_ui_direction(event) and get_viewport().gui_get_focus_owner() == null:
            _focus_first_control()
            get_viewport().set_input_as_handled()


## Moves the operating-system cursor while a controller is active.
func _process(delta: float) -> void:
    if not _controller_active:
        return
    if not Input.get_connected_joypads().has(_controller_id):
        _controller_active = false
        _controller_id = -1
        return

    var stick := Vector2(
        Input.get_joy_axis(_controller_id, JOY_AXIS_LEFT_X),
        Input.get_joy_axis(_controller_id, JOY_AXIS_LEFT_Y)
    )
    var strength := stick.length()
    if strength <= CURSOR_DEADZONE:
        return

    var adjusted_strength := minf(
        (strength - CURSOR_DEADZONE) / (1.0 - CURSOR_DEADZONE), 1.0
    )
    var cursor_position := get_viewport().get_mouse_position()
    cursor_position += stick / strength * CURSOR_SPEED * adjusted_strength * delta
    cursor_position = cursor_position.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size)
    get_viewport().warp_mouse(cursor_position)
    _expected_cursor_position = cursor_position
    _cursor_warp_pending = true


## Emits a mouse click at the current cursor position for controls and world interactions.
func _send_virtual_click() -> void:
    if not _controller_active or not is_instance_valid(get_viewport()):
        return

    var cursor_position := get_viewport().get_mouse_position()
    var press := InputEventMouseButton.new()
    press.device = _controller_id
    press.position = cursor_position
    press.global_position = cursor_position
    press.button_index = MOUSE_BUTTON_LEFT
    press.button_mask = MOUSE_BUTTON_MASK_LEFT
    press.pressed = true

    var release := press.duplicate() as InputEventMouseButton
    release.button_mask = 0
    release.pressed = false

    _sending_virtual_click = true
    Input.parse_input_event(press)
    Input.parse_input_event(release)
    _sending_virtual_click = false


## Returns true when the supplied gamepad button navigates the standard UI focus actions.
func _is_ui_direction(event: InputEventJoypadButton) -> bool:
    return (
        event.is_action_pressed("ui_up")
        or event.is_action_pressed("ui_down")
        or event.is_action_pressed("ui_left")
        or event.is_action_pressed("ui_right")
    )


## Gives focus to the first visible, enabled focusable control in the active scene.
func _focus_first_control() -> void:
    var current_scene := get_tree().current_scene
    if current_scene == null:
        return

    for node in current_scene.find_children("*", "Control", true, false):
        var control := node as Control
        if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
            continue
        if control is BaseButton and control.disabled:
            continue
        control.grab_focus()
        return
