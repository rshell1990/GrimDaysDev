#region CustomLogger
class_name CustomLogger
extends RefCounted
## Static CustomLogger
##
## Provides pretty print logging in a static fashion.
#endregion

#region CONFIRM LOGGING
## Confirms are green. A confirm informs you a function was called, and was successful.
@warning_ignore("untyped_declaration")
static func confirm(emitter: Object, function: Callable, message:String = "",
		level:int = 1) -> void:
	var do_log: bool = true
	if APP_CONFIG:
		do_log = APP_CONFIG.log_confirms

	if not do_log:
		return

	if not GameManager.is_node_ready():
		await GameManager.ready

	if level == 1 and not APP_CONFIG.log_confirms_1:
		return
	if level == 2 and not APP_CONFIG.log_confirms_2:
		return
	if level == 3 and not APP_CONFIG.log_confirms_3:
		return
	if level == 4 and not APP_CONFIG.log_confirms_4:
		return
	if level == 5 and not APP_CONFIG.log_confirms_5:
		return
	var time_passed: float = snappedf(
		Time.get_unix_time_from_system() - GameManager.program_start, 0.00000000000001)

	var msg: String = _get_message(emitter, function, str(message))
	var string: String = "[bgcolor=#000][color=#f78437][font_size=25][" \
		+ "%0.14f" % time_passed + "][/font_size][/color][/bgcolor] - " \
		+ "[color=#00ff5e][b][CONFIRM][" + str(level) + "]:[/b][/color] " \
		+ CONFIRM_STARTS[level] + "%s" % msg + CONFIRM_ENDS[level]
	print_rich(string)
#endregion
#region HINT LOGGING
## Hints are grey. A hint informs you a function was called, but not if it completed.
@warning_ignore("untyped_declaration")
static func hint(emitter: Object, function: Callable, message:String = "", level:int = 1) -> void:
	var do_log: bool = true
	if APP_CONFIG:
		do_log = APP_CONFIG.log_hints

	if not do_log:
		return

	if not GameManager.is_node_ready():
		await GameManager.ready

	if level == 1 and not APP_CONFIG.log_hints_1:
		return
	if level == 2 and not APP_CONFIG.log_hints_2:
		return
	if level == 3 and not APP_CONFIG.log_hints_3:
		return
	if level == 4 and not APP_CONFIG.log_hints_4:
		return
	if level == 5 and not APP_CONFIG.log_hints_5:
		return
	var time_passed: float = snappedf(
		Time.get_unix_time_from_system() - GameManager.program_start, 0.00000000000001
	)

	var msg: String = _get_message(emitter, function, str(message))
	var string: String = (
		"[bgcolor=#000][color=#f78437][font_size=25][" + "%0.14f" % time_passed
		+ "][/font_size][/color][/bgcolor] - "
		+ "   [color=#0088ff][b][HINT][" + str(level) + "]:[/b][/color] "
		+ HINT_STARTS[level] + "%s" % msg + HINT_ENDS[level]
	)
	print_rich(string)
#endregion
#region WARNING LOGGING
## Warnings are yellow. A warning indicates execution continued despite a problem.
@warning_ignore("untyped_declaration")
static func warn(emitter: Object, function: Callable, message:String = "", level:int = 1) -> void:
	var do_log: bool = true
	if APP_CONFIG:
		do_log = APP_CONFIG.log_warnings

	if not do_log:
		return

	if not GameManager.is_node_ready():
		await GameManager.ready

	if level == 1 and not APP_CONFIG.log_warnings_1:
		return
	if level == 2 and not APP_CONFIG.log_warnings_2:
		return
	if level == 3 and not APP_CONFIG.log_warnings_3:
		return
	if level == 4 and not APP_CONFIG.log_warnings_4:
		return
	if level == 5 and not APP_CONFIG.log_warnings_5:
		return
	var time_passed:float= snappedf(
		Time.get_unix_time_from_system() - GameManager.program_start, 0.00000000000001
	)

	var msg: String = _get_message(emitter, function, str(message))
	var string: String = (
		"[bgcolor=#000][color=#f78437][font_size=25]["
		+ "%0.14f" % time_passed
		+ "][/font_size][/color][/bgcolor] - "
		+ "   [color=#ff5100][b][WARN]["
		+ str(level)
		+ "][/b][/color]: "
		+ WARN_STARTS[level]
		+ "%s" % msg
		+ WARN_ENDS[level]
	)
	print_rich(string)
	#"#00ff5e"
	if level < 4:
		return
	push_warning(msg)
#endregion
#region ERROR LOGGING
## Errors are red. An error indicates that execution was stopped.
@warning_ignore("untyped_declaration")
static func error(emitter: Object, function: Callable, message:String = "", level:int = 1) -> void:
	var do_log: bool = true
	if APP_CONFIG:
		do_log = APP_CONFIG.log_errors

	if not do_log:
		return

	if not GameManager.is_node_ready():
		await GameManager.ready

	if level == 1 and not APP_CONFIG.log_errors_1:
		return
	if level == 2 and not APP_CONFIG.log_errors_2:
		return
	if level == 3 and not APP_CONFIG.log_errors_3:
		return
	if level == 4 and not APP_CONFIG.log_errors_4:
		return
	if level == 5 and not APP_CONFIG.log_errors_5:
		return

	var msg: String = _get_message(emitter, function, str(message))
	push_error(msg)
	var time_passed: float = snappedf(
		Time.get_unix_time_from_system() - GameManager.program_start, 0.00000000000001)

	var string: String = "[bgcolor=#000][color=#f78437][font_size=25][" \
		+ "%0.14f" % time_passed + "][/font_size][/color][/bgcolor] - " \
		+ "[ERROR][" + str(level) + "]: " + ERROR_STARTS[level] \
		+ "%s" % msg + ERROR_ENDS[level]
	print_rich(string)

	if APP_CONFIG and APP_CONFIG.assert_errors:
		# Read the error and follow the stack trace to find your problem!
		assert(false)
#endregion
#region HELPERS
## Builds a log message identifying the object, calling function and optional message text.
static func _get_message(emitter: Object, function: Callable, message: String = "") -> String:
	var obj_name: String = emitter.to_string()
	if not emitter.has_method("is_inside_tree"):
		var s: Script = emitter.get_script()
		if s:
			obj_name = s.get_path().get_file()
	var func_name: String = function.get_method()

	var rs: String = ""
	if obj_name:
		rs = "%s" % obj_name
	if func_name:
		rs = rs + " calling %s() ->" % func_name
	if message:
		rs = rs + " %s" % message

	return rs


## Returns the object's script filename, or its built-in class name when no script is attached.
static func get_object_file_name(object: Object) -> String:
	var s: Script = object.get_script()

	if s:
		return s.resource_path.get_file()

	return object.get_class()
#endregion

#region CONSTANTS
## Resource loaded for app config; reused instead of looking up the file on each call.
const APP_CONFIG: CustomLoggerConfig = preload("res://GrimDays/imported/duriel_log_config.tres")
#"#cbffcb"
#"#9cff9c"
#"#71ff71"
#"#00ff00"
#"#2A2"
## Lookup table for confirm starts; keys select the corresponding stored values.
const CONFIRM_STARTS:Dictionary = {
	1:"[color=#FFF]",
	2:"[color=#9cff9c]",
	3:"[color=#71ff71][b]",
	4:"[color=#42ff42][b][i]",
	5:"[color=#00ff00][b][i][u]",
}

## Lookup table for confirm ends; keys select the corresponding stored values.
const CONFIRM_ENDS:Dictionary = {
	1:"[/color]",
	2:"[/color]",
	3:"[/b][/color]",
	4:"[/i][/b][/color]",
	5:"[/u][/i][/b][/color]",
}

## Lookup table for hint starts; keys select the corresponding stored values.
const HINT_STARTS:Dictionary = {
	1:"[color=#FFF]",
	2:"[color=#b6dfff]",
	3:"[color=#87c9fc][b]",
	4:"[color=#53b4fd][b][i]",
	5:"[color=#299cf5][b][i][u]",
}

## Lookup table for hint ends; keys select the corresponding stored values.
const HINT_ENDS:Dictionary = {
	1:"[/color]",
	2:"[/color]",
	3:"[/b][/color]",
	4:"[/i][/b][/color]",
	5:"[/u][/i][/b][/color]",
}
#"#f3ff9c"
#"#ffff71"
#"#ffe600"
#"#ffae2c"
## Lookup table for warn starts; keys select the corresponding stored values.
const WARN_STARTS:Dictionary = {
	1:"[color=#FFF]",
	2:"[color=#f3ff9c]",
	3:"[color=#ffff71][b]",
	4:"[color=#ffe600][b][i]",
	5:"[color=#ffae2c][b][i][u]",
}

## Lookup table for warn ends; keys select the corresponding stored values.
const WARN_ENDS:Dictionary = {
	1:"[/color]",
	2:"[/color]",
	3:"[/b][/color]",
	4:"[/i][/b][/color]",
	5:"[/u][/i][/b][/color]",
}

#"#ffc29c"
#"#ff9e71"
#"#ff5100"
#"#ff2c2c"
## Lookup table for error starts; keys select the corresponding stored values.
const ERROR_STARTS:Dictionary = {
	1:"[color=#FFF]",
	2:"[color=#ffc29c]",
	3:"[color=#ff9e71][b]",
	4:"[color=#ff5100][b][i]",
	5:"[color=#ff2c2c][b][i][u]",
}

## Lookup table for error ends; keys select the corresponding stored values.
const ERROR_ENDS:Dictionary = {
	1:"[/color]",
	2:"[/color]",
	3:"[/b][/color]",
	4:"[/i][/b][/color]",
	5:"[/u][/i][/b][/color]",
}


## Named choices for level: [code]VERY_VERBOSE[/code], [code]VERBOSE[/code], [code]MILD[/code],
## [code]IMPORTANT[/code], [code]SEVERE[/code].
enum LEVEL {
	VERY_VERBOSE = 1,
	VERBOSE= 2,
	MILD = 3,
	IMPORTANT = 4,
	SEVERE = 5

}
#endregion
