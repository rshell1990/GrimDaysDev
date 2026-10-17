extends Node

## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary
## Lookup table for known administrators; keys select the corresponding stored values.
var known_administrators: Dictionary
## Shared identifier for just loaded, used so other scripts refer to the same setting or operation.
var just_loaded: bool = false
## Shared identifier for commands, used so other scripts refer to the same setting or operation.
var commands: String = ""
## Shared identifier for loading, used so other scripts refer to the same setting or operation.
const LOADING: String = "load"


## Returns whether an administrator is registered under the supplied name.
func has_administrator(admin_name) -> bool:
    if known_administrators.has(admin_name):
        return true
    return false


## Looks up the named administrator, collecting the scene's administrators first if the lookup table
## is empty.
func get_admin(admin_name):
    if known_administrators.is_empty():
        set_admins()
    return known_administrators[admin_name]


## Sets [code]known_administrators[administrator.name][/code] to [code]administrator[/code].
func set_admins() -> void:
    var root = SystemHelpers.get_game_root()
    var administrators: Array = root.get_tree().get_nodes_in_group("VNAdministrators")
    assert(not administrators.is_empty())
    for administrator in administrators:
        known_administrators[administrator.name] = administrator


## Tells the character and camera systems that the world scene has been replaced, so they can
## reconnect scene objects.
func on_world_loaded() -> void:
    call_handler(SignalArguments.CHARACTER, [WorldCommands.WORLD_SWAPPED, "empty"])
    call_handler(SignalArguments.CAMERA, [WorldCommands.WORLD_SWAPPED, "empty"])


# TODO: Make sure all systems can handle loading correctly.


## Sets [code]just_loaded[/code] to true.
func _on_load(args) -> void:
    CustomLogger.hint(self, self._on_load, "- is loading.", CustomLogger.LEVEL.MILD)
    just_loaded = true
    call_handler(SignalArguments.CAMERA, [LOADING, args])
    call_handler(SignalArguments.CHARACTER, [LOADING, args])


## Requests a checkpoint after dialogue text finishes displaying.
func _on_text_finished(_text_data: Dictionary) -> void:
    make_checkpoint(Dialogic.current_state)


## Writes a debug message acknowledging that a checkpoint was made; it does not create another
## checkpoint.
func on_checkpoint_made() -> void:
    CustomLogger.hint(self, on_checkpoint_made, " after checkpoint made.", CustomLogger.LEVEL.MILD)


## Routes a checkpoint request to the rollback handler.
func make_checkpoint(_state: Dialogic.States) -> void:
    call_handler(SignalArguments.ROLLBACK, RollbackCommands.CHECKPOINT)


## Sets [code]just_loaded[/code] to false.
func _on_auto_skip() -> void:
    if just_loaded:
        just_loaded = false
        return
    if not Dialogic.Inputs.auto_skip.enabled:
        return

    call_handler(SignalArguments.ROLLBACK, RollbackCommands.CHECKPOINT)


## Routes a restore-last-checkpoint request to the rollback handler.
func _on_rollback_initiated() -> void:
    call_handler(SignalArguments.ROLLBACK, RollbackCommands.ROLLBACK)


## Sets [code]commands[/code] to [code]argument[/code]; increases [code]commands[/code] by [code]","
## + argument[/code]; sets [code]commands[/code] to [code]""[/code].
func _on_generic_dialogic_signal(argument: String, last_command: bool = true) -> void:
    CustomLogger.hint(
        self,
        self._on_generic_dialogic_signal,
        "Recieved Argument:[color=#FF0]\n" + argument + "[/color]",
        CustomLogger.LEVEL.MILD
    )

    if argument.is_empty():
        CustomLogger.error(
            self,
            self._on_generic_dialogic_signal,
            "Empty argument...",
            CustomLogger.LEVEL.MILD
        )
        return

    if commands.is_empty():
        commands = argument
    else:
        commands += "," + argument
    if !last_command:
        return
    var split_commands = commands.split(Basics.COMMA)
    for command in split_commands:
        var new_command = command.strip_edges()
        var args: PackedStringArray = new_command.split(Basics.UNDERSCORE)
        var signal_type = args[Basics.FIRST].strip_edges()
        var passed_args = args.slice(1, args.size())

        call_handler(signal_type, passed_args)
    commands = ""


## Sets [code]Dialogic.Inputs.auto_skip.enabled[/code] to false.
func _on_timeline_ended() -> void:
    if Dialogic.Inputs.auto_skip.enabled:
        Dialogic.Inputs.auto_skip.enabled = false


## Passes the auto-skip choice to the dialogue command handler.
func _on_auto_skip_toggled(args) -> void:
    var passed_args = [DialogicCommands.SKIP, args]
    call_handler(SignalArguments.DIALOGIC, passed_args)


## Connects the supplied notification to its response function, using the connection checks in this
## helper.
func listen_for(sent_signal: Signal, calls: Callable) -> void:
    if sent_signal.is_connected(calls):
        return
    sent_signal.connect(calls)


## Runs the registered handler for a nonempty command type, supplying its arguments.
func call_handler(type, args) -> void:
    if type.is_empty():
        return
    handle_command_by_type[type].call(args)


## Finds this system’s helper nodes, registers its command handlers and connects the notifications
## it responds to.
func _ready():
    Dialogic.signal_event.connect(_on_generic_dialogic_signal)
    Dialogic.text_signal.connect(_on_generic_dialogic_signal)
    Dialogic.Text.text_finished.connect(_on_text_finished)
    Dialogic.Inputs.auto_skip.toggled.connect(_on_auto_skip_toggled)
    Dialogic.timeline_ended.connect(_on_timeline_ended)
    DDInputHandler.rollback_initiated.connect(_on_rollback_initiated)

    SaveAndLoadSystemManager.checkpoint_saved.connect(on_checkpoint_made)
    set_admins()

    SystemAdministrators.set_admins()
    handle_command_by_type = {}
    for signal_types in SignalArguments.TYPE_TO_ADMINISTRATOR.keys():
        var admin_name: String = SignalArguments.TYPE_TO_ADMINISTRATOR[signal_types]
        if known_administrators.has(admin_name):
            handle_command_by_type[signal_types] = known_administrators[admin_name].command
