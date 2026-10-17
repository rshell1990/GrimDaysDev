# Editor configuration for BattlePhase.
@icon("res://GrimDays/assets/visuals/class_icons/phase.png")
extends Node
## Base contract for one step in the presentation-driven battle state machine.
## Subclasses call the base lifecycle method, then emit its matching signal.
class_name BattlePhase

## Emitted after a phase has prepared all execution prerequisites.
signal entered
## Emitted after a phase has completed its domain or presentation work.
signal executed
## Emitted after a phase has released transient callbacks and state.
signal exited

## Unique state-machine key used to register this phase with its controller.
@export var id: Combat.BATTLE_STATES
## Destination restored on every entry unless execution chooses another branch.
@export var default_next_phase: Combat.BATTLE_STATES
## Transient payload passed between consecutive battle phases.
var cargo
## Controller that owns this phase and the shared action context.
var phase_controller: BattlePhaseController
## Phase identifier to enter after this phase finishes successfully.
var next_phase: Combat.BATTLE_STATES
## Combatant whose turn is currently being processed.
var active_unit: BattleUnit
## Remaining target-processing view; index zero is always the current target.
var targets: Array
## Action selected for the current combatant and target sequence.
var selected_action: ActionTemplate


## Initializes [member next_phase] from its authored default.
func _ready() -> void:
    next_phase = default_next_phase


## Resets branch selection on entry. Subclasses prepare state before emitting [signal entered].
func _enter() -> void:
    CustomLogger.hint(self, _enter, "Entered %s phase." % name, CustomLogger.LEVEL.VERY_VERBOSE)
    next_phase = default_next_phase


## Applies an optional cargo-provided branch. Subclasses perform work before
## emitting [signal executed] and asking the controller to advance.
func execute() -> void:
    CustomLogger.hint(self, execute, "Executed %s phase." % name, CustomLogger.LEVEL.VERY_VERBOSE)
    if cargo and cargo.has("next_phase"):
        next_phase = cargo.next_phase


## Base exit hook. Subclasses disconnect transient callbacks before emitting [signal exited].
func _exit() -> void:
    CustomLogger.hint(self, _exit, "Exited %s phase." % name, CustomLogger.LEVEL.VERY_VERBOSE)
