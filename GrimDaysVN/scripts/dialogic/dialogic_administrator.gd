extends Node
## Handles dialogue show, hide, pause and skip commands from the game's command system.
class_name DialogicAdministrator
## Shared fixed value for max pause.
const MAX_PAUSE: float = 25.0
## Seconds remaining before the dialogue pause times out.
var pause_timer: float = MAX_PAUSE
## Looks up the function to run for each supported command name.
var handle_command_by_type: Dictionary
## Whether text finished received is currently enabled or true.
var text_finished_received: bool


## On each physics update, this function decreases [code]pause_timer[/code] by [code]delta[/code];
## sets [code]Dialogic.paused[/code] to false; sets [code]pause_timer[/code] to
## [code]MAX_PAUSE[/code].
func _physics_process(delta: float) -> void:
    if Dialogic.paused and Dialogic.current_timeline:
        pause_timer -= delta
        if pause_timer < 0.15:
            Dialogic.paused = false
    elif pause_timer < MAX_PAUSE:
        pause_timer = MAX_PAUSE


## Uses the command name to select a handler and passes it the remaining arguments.
func command(args) -> void:
    var extra_argument = null
    if args.size() > 1:
        extra_argument = args.slice(1, args.size())

    handle_command_by_type[args[Basics.FIRST]].call(extra_argument)


## Sets [code]Engine.time_scale[/code] to [code]7.5[/code]; sets [code]Engine.time_scale[/code] to
## [code]1.0[/code].
func _on_auto_skip_toggled(active) -> void:
    if active[Basics.FIRST]:
        Engine.time_scale = 7.5
    else:
        Engine.time_scale = 1.0


## Waits for any current dialogue animation before showing the dialogue interface and resuming
## dialogue as configured here.
func _on_show(_args) -> void:
    var unpause: bool = false
    Dialogic.Text.show_textbox()
    if Dialogic.Animations.is_animating():
        if not Dialogic.paused:
            CustomLogger.warn(
                self,
                self._on_show,
                " is pausing Dialogic, because Dialogic is busy animating.",
                CustomLogger.LEVEL.VERBOSE
            )
            Dialogic.paused = true
            unpause = true
        await Dialogic.Animations.finished
    if unpause:
        Dialogic.paused = false


## Pauses dialogue for the requested interval, using this administrator's timer and pause checks.
func _on_pause(args) -> void:
    var unpause: bool = false
    if Dialogic.paused:
        CustomLogger.warn(
            self,
            self._on_pause,
            " Dialogic is already paused, awaiting **dialogic_resumed** signal to execute the pause command.",
            CustomLogger.LEVEL.MILD
        )
        await Dialogic.dialogic_resumed
    var current_time_scale: float = Engine.time_scale
    Engine.time_scale = 1.0
    if not Dialogic.paused:
        CustomLogger.warn(
            self,
            self._on_pause,
            " is pausing Dialogic, due to the pause command in the current script.",
            CustomLogger.LEVEL.VERBOSE
        )
        Dialogic.paused = true
        unpause = true
    var duration: float = float(args[Basics.FIRST])
    await get_tree().create_timer(duration).timeout
    if unpause:
        CustomLogger.warn(
            self, self._on_pause, " is unpausing Dialogic, after the timer has finished.", CustomLogger.LEVEL.VERBOSE
        )
        Dialogic.paused = false
    Engine.time_scale = current_time_scale


## Pauses dialogue while hiding its interface and waiting for the animation, then resumes it.
func _on_hide(_args) -> void:
    var unpause: bool = false
    Dialogic.Text.hide_textbox()
    if Dialogic.Animations.is_animating():
        if not Dialogic.paused:
            CustomLogger.warn(
                self,
                self._on_hide,
                " is pausing Dialogic, because Dialogic is busy animating.",
                CustomLogger.LEVEL.VERBOSE
            )
            Dialogic.paused = true
            unpause = true
        await Dialogic.Animations.finished
    if unpause:
        Dialogic.paused = false


## Logs the information received when a line of dialogue finishes displaying.
func on_text_finished(info: Dictionary) -> void:
    CustomLogger.hint(
        self,
        self._on_show,
        " text has finished displaying: [b][color=#F55]" + str(info) + "[/color][/b]",
        CustomLogger.LEVEL.VERY_VERBOSE
    )


## Finds this system’s helper nodes, registers its command handlers and connects the notifications
## it responds to.
func _ready():
    if Dialogic.Text:
        Dialogic.Text.text_finished.connect(on_text_finished)
    handle_command_by_type = {
        DialogicCommands.SKIP: _on_auto_skip_toggled,
        DialogicCommands.HIDE: _on_hide,
        DialogicCommands.PAUSE: _on_pause,
        DialogicCommands.SHOW: _on_show,
    }
