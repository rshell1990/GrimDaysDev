extends Node
## Keeps remembered rollback state and coordinates checkpoint operations.
class_name RollbackDirector
## Notification for checkpoint loaded. Supplies [code]args[/code] to connected functions.
signal checkpoint_loaded(args)
## Helper that performs checkpoint save and restore operations.
var operator: CheckpointOperator
## Remembered state used when returning to an earlier dialogue checkpoint.
var rollback_data: Dictionary


## When the node is ready, this function connects responses to
## [code]operator.checkpoint_loaded[/code], [code]VNSignalBus.reset_sub_systems[/code]; updates
## [code]operator[/code] using [code]CheckpointOperator.new[/code].
func _ready():
    operator = CheckpointOperator.new()
    add_child(operator)
    operator.checkpoint_loaded.connect(on_checkpoint_loaded)
    SystemHeadquarters.listen_for(checkpoint_loaded, Callable(SystemHeadquarters, "_on_load"))
    VNSignalBus.reset_sub_systems.connect(reset)


## Passes the current state to the rollback system to remember for a later restore.
func set_current_rollback_data(new_data: Dictionary) -> void:
    rollback_data.set(Dialogic.VAR.lines_read, new_data)


## Returns the state currently remembered by the rollback system.
func get_current_rollback_data() -> Dictionary:
    return rollback_data


## Asks the checkpoint operator to restore the previous checkpoint.
func load_last_checkpoint() -> void:
    operator.load_last_checkpoint()


## Asks the checkpoint operator to save a checkpoint.
func make_checkpoint() -> void:
    operator.make_checkpoint()


## Sends [code]VNSignalBus.on_load[/code], [code]checkpoint_loaded[/code] notifications.
func on_checkpoint_loaded(args) -> void:
    VNSignalBus.on_load.emit(args)
    checkpoint_loaded.emit(args)


## Clears rollback data when this system is reset.
func reset() -> void:
    CustomLogger.warn(
        self, self.reset, " is resetting, rollback will be cleared.", CustomLogger.LEVEL.MILD
    )
    clear_rollback()


## Clears [code]rollback_data[/code].
func clear_rollback() -> void:
    Dialogic.VAR.set_variable("lines_read", 0)
    #if GameManager.state != GameManagerStates.STATES.BeforeGame:
    #UIDirector.add_notification("Rollback cleared")
    rollback_data.clear()
    for x in range(0, SystemLimits.CHECKPOINTS):
        var slot_name_to_format = "{prefix}___rollback-save___{number}"
        var slot_name = slot_name_to_format.format({"prefix": Dialogic.VAR.prefix, "number": x})

        if Dialogic.Save.has_slot(slot_name):
            Dialogic.Save.delete_slot(slot_name)
