extends Node
## An Autoloaded class that contains general methods that may be needed to be accessed
## by other parts of the code, without providing awareness of the exact workings to the
## parts calling them. This class is where changes for how these functions are accessed
## will be made.
#region CONSTANTS

## Shared fixed value for player node path.
const PLAYER_NODE_PATH: String = "/root/UIDirector/Player"
#endregion


#region UI FUNCTIONS
## Given two control nodes, using the set accent color, they are modulated to colorize
## them based upon those colors.
func color_self(user, frame):
    match SM_Globals.user_prefs.color_scheme:
        Defaults.COLOR_SCHEME.MONOCHROME:
            monochrome_color(user, frame)
        Defaults.COLOR_SCHEME.MONOCHROME_DARK:
            monochrome_dark_color(user, frame)
        Defaults.COLOR_SCHEME.FRAME_ONLY:
            frame_only_color(user, frame)
        Defaults.COLOR_SCHEME.TWO_TONE:
            monochrome_color(user, frame)
        Defaults.COLOR_SCHEME.TWO_TONE_DARK:
            monochrome_color(user, frame)


## Applies the normal monochrome color scheme to the supplied background and frame.
func monochrome_color(user, frame) -> void:
    var accent_color: Color = current_accent_color()
    var bg_color: Color = accent_color
    bg_color.a = SM_Globals.user_prefs.background_alpha
    bg_color.h = clamp(bg_color.h + ColorCodes.HUE_SHIFT, 0.0, 1.0)
    bg_color = bg_color.darkened(ColorCodes.DARKEN_BY)
    user.self_modulate = bg_color

    if frame == null:
        return

    var frame_color: Color = accent_color
    frame_color.h = clamp(bg_color.h - ColorCodes.HUE_SHIFT, 0.0, 1.0)
    frame_color = frame_color.lightened(ColorCodes.LIGHTEN_BY)
    frame.self_modulate = frame_color


## Applies the dark monochrome color scheme to the supplied background and frame.
func monochrome_dark_color(user, frame) -> void:
    var accent_color: Color = current_accent_color()
    var bg_color: Color = accent_color
    bg_color.a = SM_Globals.user_prefs.background_alpha
    bg_color.h = clamp(bg_color.h + ColorCodes.HUE_SHIFT, 0.0, 1.0)
    bg_color = bg_color.darkened(ColorCodes.DARKEN_BY * 2.0)
    user.self_modulate = bg_color

    if frame == null:
        return

    var frame_color: Color = accent_color
    frame_color.h = clamp(bg_color.h - ColorCodes.HUE_SHIFT, 0.0, 1.0)
    frame_color = frame_color.lightened(ColorCodes.LIGHTEN_BY)
    frame.self_modulate = frame_color


## Applies the chosen accent to the frame while setting the background according to the frame-only
## scheme.
func frame_only_color(user, frame) -> void:
    var accent_color: Color = current_accent_color()
    var bg_color: Color = Color.from_string("#353535", Defaults.PRIME_BASE_COLOR)
    if user.self_modulate.a < 0.05 or user.self_modulate.a > 0.98:
        bg_color.a = SM_Globals.user_prefs.background_alpha
    else:
        bg_color.a = user.self_modulate.a
    user.self_modulate = bg_color

    if frame == null:
        return

    var frame_color: Color = accent_color
    frame.self_modulate = frame_color


## Return the current accent color to be used by the UI based upon the current dimension.
func current_accent_color() -> Color:
    var base_color: Color = Color.from_string(
        SM_Globals.user_prefs.normal_base_color,
        Defaults.PRIME_BASE_COLOR
    )

    if SystemAdministrators.current_dimension() == NavigationAdministrator.DIMENSIONS.DARK:
        base_color = Color.from_string(
            SM_Globals.user_prefs.dark_base_color,
            Defaults.DARK_BASE_COLOR
        )

    return base_color


## Returns the current text color to be used by the UI based upon the current dimension.
func current_text_color() -> Color:
    var base_color: Color = Color.from_string(
        SM_Globals.user_prefs.normal_text_color,
        Defaults.PRIME_TEXT_COLOR
    )

    if SystemAdministrators.current_dimension() == NavigationAdministrator.DIMENSIONS.DARK:
        base_color = Color.from_string(
            SM_Globals.user_prefs.dark_text_color,
            Defaults.DARK_TEXT_COLOR
        )

    return base_color


## Returns the current text outline color to be used by the UI based upon the current dimension.
func current_outline_color() -> Color:
    var base_color: Color = Color.from_string(
        SM_Globals.user_prefs.normal_outline_color,
        Defaults.PRIME_OUTLINE_COLOR
    )

    if SystemAdministrators.current_dimension() == NavigationAdministrator.DIMENSIONS.DARK:
        base_color = Color.from_string(
            SM_Globals.user_prefs.dark_outline_color,
            Defaults.DARK_OUTLINE_COLOR
        )

    return base_color


#endregion
#region MISC FUNCTIONS


## Prints nested dictionaries and arrays once each, using two spaces per indentation level.
func pretty_print_dict(dictionary: Dictionary, indent_level: int = 0) -> void:
    if not OS.is_debug_build():
        return
    _pretty_print_value(dictionary, maxi(indent_level, 0))


func _pretty_print_value(value: Variant, indent_level: int) -> void:
    var indent_str: String = "  ".repeat(indent_level + 1)
    var next_indent_str: String = indent_str + "  "
    if value is Dictionary:
        print_rich(indent_str + "[color=#FF0]{[/color]")
        for key: Variant in value:
            var item: Variant = value[key]
            if item is Dictionary or item is Array:
                print_rich(next_indent_str + str(key) + ":")
                _pretty_print_value(item, indent_level + 1)
            else:
                print_rich(next_indent_str + str(key) + ": " + str(item))
        print_rich(indent_str + "[color=#FF0]}[/color]")
    elif value is Array:
        print_rich(indent_str + "[color=#0FF][[/color]")
        for item: Variant in value:
            _pretty_print_value(item, indent_level + 1)
        print_rich(indent_str + "[color=#0FF]][/color]")
    else:
        print_rich(indent_str + str(value))


## Parses named Dialogic arguments, preserving everything after the first colon as the value.
## Bare command tokens are ignored; repeated keys keep their last value.
func args_to_dict(args: Variant) -> Dictionary:
    var data: Dictionary = {}
    if not (args is Array or args is PackedStringArray):
        CustomLogger.warn(
            self, args_to_dict,
            "Expected an array of command arguments.",
            CustomLogger.LEVEL.IMPORTANT
        )
        return data
    for arg: Variant in args:
        if not (arg is String or arg is StringName):
            CustomLogger.warn(
                self, args_to_dict,
                "Command arguments must be strings.",
                CustomLogger.LEVEL.IMPORTANT
            )
            continue
        var split_by_colon: PackedStringArray = String(arg).split(Basics.COLON, true, 1)
        if split_by_colon.size() < 2:
            continue
        var key: String = split_by_colon[Basics.FIRST].strip_edges().to_lower()
        if key.is_empty():
            CustomLogger.warn(
                self, args_to_dict,
                "Command argument has an empty key.",
                CustomLogger.LEVEL.IMPORTANT
            )
            continue
        data[key] = split_by_colon[1]

    return data


## Creates a save prefix that helps to highlight what version the game was originally created under.
func set_prefix_if_empty() -> void:
    if not Dialogic.VAR.prefix.is_empty():
        return
    var prefix_info: Dictionary = Time.get_datetime_dict_from_system()
    prefix_info["major"] = Dialogic.VAR.version_major
    prefix_info["minor"] = Dialogic.VAR.version_minor
    prefix_info["patch"] = Dialogic.VAR.version_patch
    var prefix_to_format: String = (
        "{year}_{month}_{day}___{hour}_{minute}_{second}"
        + "___{major}.{minor}-{patch}"
    )
    Dialogic.VAR.prefix = prefix_to_format.format(prefix_info)


## Gets the root node.
func get_game_root() -> Variant:
    return $"/root"


## Waits for a scene timer to expire after the supplied number of seconds.
func start_timer(time: float) -> void:
    var root = get_game_root()
    await root.get_tree().create_timer(time).timeout


#endregion


#region STATES
## Asks children that provide get_state for their state and stores it by child name in the supplied
## dictionary.
func get_state_of_children(nodes: Array, children_state: Dictionary) -> void:
    for child: Node in nodes:
        if not child.has_method("get_state"):
            #CustomLogger.warn(self, get_state_of_children,
            #child.name + " missing get get_state function.")
            continue
        var childs_state: Dictionary = child.get_state()
        #CustomLogger.hint(self, get_state_of_children, str(childs_state))
        children_state.set(child.name, childs_state)


## Increases the remembered dialogue-line count used for rollback checkpoints.
func increment_lines_read() -> void:
    var slot_name_to_format: String = "{prefix}___rollback-save___{number}"
    var slot_name: String = slot_name_to_format.format(
        {
            "prefix": Dialogic.VAR.prefix,
            "number": Dialogic.VAR.lines_read % SystemLimits.CHECKPOINTS,
        }
    )
    if not Dialogic.Save.has_slot(slot_name):
        CustomLogger.hint(
            self,
            self.increment_lines_read,
            "[color=#F33][u]Checkpoint not made for current lines_read, "
            + "so not incrementing lines_read.[/u][/color]"
        )
        return

    Dialogic.VAR.lines_read += 1


## Connects responses to [code]UIDirector.screen_uncovered[/code]; disconnects responses from
## [code]SaveAndLoadSystemManager.task_queue.queue_finished[/code]; reveals the screen.
func on_load_finished() -> void:
    CustomLogger.confirm(self, self.on_load_finished, "Save loaded.", CustomLogger.LEVEL.MILD)
    SaveAndLoadSystemManager.task_queue.queue_finished.disconnect(on_load_finished)
    UIDirector.screen_uncovered.connect(on_screen_uncovered)
    UIDirector.reveal_screen()


## Disconnects responses from [code]UIDirector.screen_uncovered[/code]. It pauses for
## [code]SaveAndLoadSystemManager.checkpoint_saved[/code] before continuing.
func on_screen_uncovered() -> void:
    UIDirector.screen_uncovered.disconnect(on_screen_uncovered)
    SystemHeadquarters.call("_on_text_finished", {})
    await SaveAndLoadSystemManager.checkpoint_saved
    increment_lines_read()


#endregion


#region MATH FUNCTIONS
## Takes an array of numbers and returns their sum.
func sum(array: Array) -> int:
    var total: int = 0

    for number in array:
        total += number

    return total


## Returns half of the value as a float.
func halff(value: float) -> float:
    return value * 0.5


## Returns half of the value as an int.
func halfi(value: int) -> int:
    return int(value * 0.5)


## Checks if a value is an even number.
func is_even(value: int) -> bool:
    if value % 2 == 0:
        return true

    return false


## Returns a random number between 1 and 100.
func roll_the_dice() -> int:
    return randi_range(1, 100)


#endregion


## Prints the combined values with rich-text formatting only in a debug build.
func print_rich(
    message: Variant,
    extra_a: Variant = "",
    extra_b: Variant = "",
    extra_c: Variant = "",
    extra_d: Variant = "",
    extra_e: Variant = "",
    extra_f: Variant = "",
    extra_g: Variant = ""
) -> void:
    if not OS.is_debug_build():
        return
    print_rich(message, extra_a, extra_b, extra_c, extra_d, extra_e, extra_f, extra_g)


## Prints the combined values only in a debug build.
func print(
    message: Variant,
    extra_a: Variant = "",
    extra_b: Variant = "",
    extra_c: Variant = "",
    extra_d: Variant = "",
    extra_e: Variant = "",
    extra_f: Variant = "",
    extra_g: Variant = ""
) -> void:
    if not OS.is_debug_build():
        return
    print( # lint:ignore debug-print -- Debug-build logging helper.
        message, extra_a, extra_b, extra_c, extra_d, extra_e, extra_f, extra_g
    )
