class_name Task
extends RefCounted

## Notification for waited. Supplies [code]task[/code] to connected functions.
signal waited(task: Task)
## Notification for readied. Supplies [code]task[/code] to connected functions.
signal readied(task: Task)
## Notification for completed. Supplies [code]task[/code] to connected functions.
signal completed(task: Task)
## Notification for failed. Supplies [code]task[/code] to connected functions.
signal failed(task: Task)

## Named choices for state: [code]NONE[/code], [code]WAITING[/code], [code]READY[/code],
## [code]COMPLETED[/code], [code]FAILED[/code].
enum STATE {NONE, WAITING, READY, COMPLETED, FAILED}
## Current task state, used to decide which queue operations and notifications apply.
var state: int:
	get: return _state
## Current task state, used to decide which queue operations and notifications apply.
var _state: int = STATE.NONE
## Whether async is currently enabled or true.
var _async: bool = false
## Whether unique is currently enabled or true.
var _unique: bool = false
## Readable name used to identify this task.
var _name:StringName = &""

## Override This
func _init(task_name:StringName) -> void:
	_name = task_name


## Override This
func _prepare() -> void:
	goto_ready() #Or if we're waiting, goto_waiting()


## Override This
func _complete() -> void:
	goto_completed()


## Override This
func _cancel() -> void:
	goto_failed()


## Runs the task-specific preparation function supplied by this class or a child script.
func prepare() -> void:
	_prepare()


## Runs the task-specific completion function supplied by this class or a child script.
func complete() -> void:
	_complete()


## Runs the task-specific cancellation function supplied by this class or a child script.
func cancel() -> void:
	_cancel()


## Returns whether this task is marked for asynchronous execution, allowing it to wait while other
## work proceeds.
func is_async() -> bool:
	return _async


## Returns whether this task is marked unique for queue handling.
func is_unique() -> bool:
	return _unique


## Sets [code]_state[/code] to [code]STATE.WAITING[/code]; sets [code]_state[/code] to
## [code]STATE.READY[/code]; sets [code]_state[/code] to [code]STATE.COMPLETED[/code]. It also sends
## [code]waited[/code], [code]readied[/code], [code]completed[/code] notifications.
func set_state(new_state: int) -> void:
	var old_state: int = _state

	if old_state == new_state:
		return

	match new_state:
		STATE.NONE:
			pass
		STATE.WAITING:
			_state = STATE.WAITING
			CustomLogger.hint(self, set_state,_name + " waiting",CustomLogger.LEVEL.MILD)
			waited.emit(self)
		STATE.READY:
			_state = STATE.READY
			CustomLogger.hint(self, set_state,_name + " ready",CustomLogger.LEVEL.MILD)
			readied.emit(self)
		STATE.COMPLETED:
			_state = STATE.COMPLETED
			CustomLogger.confirm(self, set_state,_name +  " completed",CustomLogger.LEVEL.MILD)
			completed.emit(self)
		STATE.FAILED:
			_state = STATE.FAILED
			CustomLogger.error(self, set_state,_name + " failed",CustomLogger.LEVEL.MILD)
			failed.emit(self)


## Changes the task state to WAITING and sends the corresponding state notification.
func goto_waiting() -> void: set_state(STATE.WAITING)
## Changes the task state to READY and sends the corresponding state notification.
func goto_ready() -> void: set_state(STATE.READY)
## Changes the task state to COMPLETED and sends the corresponding state notification.
func goto_completed() -> void: set_state(STATE.COMPLETED)
## Changes the task state to FAILED and sends the corresponding state notification.
func goto_failed() -> void: set_state(STATE.FAILED)

## Returns whether the task is currently waiting.
func is_waiting() -> bool: return _state == STATE.WAITING
## Returns whether the task is ready to run.
func is_ready() -> bool: return _state == STATE.READY
## Returns whether the task has moved beyond the READY state in the state ordering.
func was_ready() -> bool: return _state > STATE.READY
## Returns whether the task completed successfully.
func is_completed() -> bool: return _state == STATE.COMPLETED
## Returns whether the task is in the failed state.
func is_failed() -> bool: return _state == STATE.FAILED
