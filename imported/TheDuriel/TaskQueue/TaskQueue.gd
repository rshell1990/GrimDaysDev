class_name TaskQueue
extends RefCounted

## Notification for task queued. Supplies [code]task[/code] to connected functions.
signal task_queued(task: Task)
## Notification for task waited. Supplies [code]task[/code] to connected functions.
signal task_waited(task: Task)
## Notification for task readied. Supplies [code]task[/code] to connected functions.
signal task_readied(task: Task)
## Notification for task completed. Supplies [code]task[/code] to connected functions.
signal task_completed(task: Task)
## Notification for task failed. Supplies [code]task[/code] to connected functions.
signal task_failed(task: Task)
## Notification for task cancelled. Supplies [code]task[/code] to connected functions.
signal task_cancelled(task: Task)
## Notification for queue finished.
signal queue_finished

## Whether require manual flushing is currently enabled or true.
var require_manual_flushing: bool = false

# For debugging, artificially slows the queue down.
## Whether slow mode is currently enabled or true.
var slow_mode: bool = false
## Delay in seconds between task-queue updates when slow mode is enabled.
var slow_mode_wait_time: float = 0.15

# True if the queue is working. Useful for blocking user input until its done.
## Whether busy is currently enabled or true.
var busy: bool:
	get: return not _tasks.is_empty()

## Scene tree used to schedule task processing and waits.
var _tree: SceneTree
## List of tasks used by this script.
var _tasks: Array[Task] = []


## During creation, this function sets [code]_tree[/code] to [code]tree[/code].
func _init(tree: SceneTree) -> void:
	_tree = tree


## Schedules queued tasks to start only when manual flushing is enabled; otherwise logs a warning
## and returns.
func flush_manually() -> void:
	if not require_manual_flushing:
		CustomLogger.warn(
			self, flush_manually, "require_manual_flushing is not true", CustomLogger.LEVEL.MILD
		)
		return

	_ready_tasks.call_deferred()


	# Add Task to the end of the queue
## Adds the task to the end of the work queue.
func put_task(task: Task) -> void:
	put_last(task)


	# Add Task to the start of the queue
## Inserts the task at the front of the work queue.
func put_first(task: Task) -> void:
	_insert_task_at(task, 0)


	# Add Task to the end of the queue
## Inserts the task after all currently queued tasks.
func put_last(task: Task) -> void:
	_insert_task_at(task, _tasks.size())


	# Add Task before Task
## Adds a task before the matching task, but currently places it one position too early unless
## the match is first in line. For example, inserting X before C in [A, B, C] produces
## [A, X, B, C]. If no match exists, adds the task at the front.
func put_task_before(task: Task, before: Task) -> void:
	var index: int = 0
	for idx: int in _tasks.size():
		var value: Task = _tasks[idx]
		if value == before:
			index = int(max(idx - 1, 0))
			break
	_insert_task_at(task, index)


	# Add Task after Task
## Inserts immediately after the matching task, or at the end when no matching task exists.
func put_task_after(task: Task, after: Task) -> void:
	var index: int = _tasks.size()
	for idx: int in _tasks.size():
		var value: Task = _tasks[idx]
		if value == after:
			index = int(min(idx + 1, _tasks.size()))
			break
	_insert_task_at(task, index)


## Removes [code]task[/code] from [code]_tasks[/code]; sends [code]task_cancelled[/code]
## notifications.
func cancel_task(task: Task) -> void:
	if task in _tasks:
		_tasks.erase(task)
		task.cancel()
		task_cancelled.emit(task)


## Connects responses to [code]task.waited[/code], [code]task.readied[/code],
## [code]task.completed[/code], [code]task.failed[/code]; adds [code]task[/code] to
## [code]_tasks[/code]; sends [code]task_queued[/code] notifications.
func _insert_task_at(task: Task, index: int) -> void:
	if task.is_unique():
		for t: Task in _tasks:
			if t.get_script() == task.get_script(): # Stupid
				return

	if index == _tasks.size():
		_tasks.append(task)
	else:
		_tasks.insert(index, task)

	task.waited.connect(_on_task_waited)
	task.readied.connect(_on_task_readied)
	task.completed.connect(_on_task_completed)
	task.failed.connect(_on_task_failed)

	if not require_manual_flushing:
		_ready_tasks.call_deferred()

	task_queued.emit(task)

	CustomLogger.hint(
		self,
		_insert_task_at,
		CustomLogger.get_object_file_name(task) + " - queue size: %s" % _tasks.size(),
		CustomLogger.LEVEL.MILD
	)


## Sends [code]queue_finished[/code] notifications. It pauses for
## [code]_tree.create_timer(slow_mode_wait_time).timeout[/code] before continuing.
func _ready_tasks() -> void:
	if slow_mode:
		await _tree.create_timer(slow_mode_wait_time).timeout

	CustomLogger.hint(self, _ready_tasks)
	if _tasks.is_empty():
		CustomLogger.hint(self, _ready_tasks, "nothing to ready.",CustomLogger.LEVEL.MILD)
		queue_finished.emit()
		return

	# All async tasks
	for t: Task in _tasks:
		if t.is_async() and t.state == Task.STATE.NONE:
			t.prepare.call_deferred()

	CustomLogger.hint(self, _ready_tasks, "readying async.",CustomLogger.LEVEL.MILD)

	# First task in list
	var first_task: Task = _tasks[0]

	CustomLogger.hint(
		self,
		_ready_tasks,
		"First task is: %s" % CustomLogger.get_object_file_name(first_task),
		CustomLogger.LEVEL.MILD
	)

	if first_task.is_async():
		CustomLogger.hint(
			self, _ready_tasks, "first task is async. Stopped", CustomLogger.LEVEL.MILD
		)
		return

	if first_task.state <= Task.STATE.WAITING:
		first_task.prepare.call_deferred()
		CustomLogger.hint(self, _ready_tasks, "readied first task.",CustomLogger.LEVEL.MILD)
		return

	CustomLogger.hint(
		self, _ready_tasks, "failed. First task is %s" % first_task.state, CustomLogger.LEVEL.MILD
	)


## Sends [code]task_waited[/code] notifications. It pauses for
## [code]_tree.create_timer(slow_mode_wait_time).timeout[/code],
## [code]Engine.get_main_loop().process_frame[/code] before continuing.
func _on_task_waited(task: Task) -> void:
	if slow_mode:
		await _tree.create_timer(slow_mode_wait_time).timeout

	if task.is_async() or task == _tasks[0]:
		await Engine.get_main_loop().process_frame

		task.prepare.call_deferred()

	task_waited.emit(task)


## Sends [code]task_readied[/code] notifications. It pauses for
## [code]_tree.create_timer(slow_mode_wait_time).timeout[/code] before continuing.
func _on_task_readied(task: Task) -> void:
	if slow_mode:
		await _tree.create_timer(slow_mode_wait_time).timeout

	if task.is_async() or task == _tasks[0]:
		task.complete.call_deferred()

	task_readied.emit(task)


## Removes [code]task[/code] from [code]_tasks[/code]; sends [code]task_completed[/code]
## notifications. It pauses for [code]_tree.create_timer(slow_mode_wait_time).timeout[/code] before
## continuing.
func _on_task_completed(task: Task) -> void:
	if slow_mode:
		await _tree.create_timer(slow_mode_wait_time).timeout

	_tasks.erase(task)

	_ready_tasks.call_deferred()

	task_completed.emit(task)


## Removes [code]task[/code] from [code]_tasks[/code]; sends [code]task_failed[/code] notifications.
## It pauses for [code]_tree.create_timer(slow_mode_wait_time).timeout[/code] before continuing.
func _on_task_failed(task: Task) -> void:
	if slow_mode:
		await _tree.create_timer(slow_mode_wait_time).timeout

	_tasks.erase(task)

	_ready_tasks.call_deferred()

	task_failed.emit(task)
