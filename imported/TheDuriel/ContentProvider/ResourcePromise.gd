class_name ResourcePromise
extends RefCounted

## Notification for loading finished. Supplies [code]status[/code] to connected functions.
signal loading_finished(status: STATUS)

## Named choices for status: [code]NONE[/code], [code]OK[/code], [code]FAILED[/code].
enum STATUS {NONE, OK, FAILED}

## Current loading status; the public status announces completion when the request succeeds or
## fails.
var status: STATUS:
	get:
		if _status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			return STATUS.OK
		if _status == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			return STATUS.FAILED
		return STATUS.NONE

## Last status reported by Godot’s background resource loader.
var _status: ResourceLoader.ThreadLoadStatus = \
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS
## Loaded resource returned by this request, available when loading succeeds.
var resource: Resource
## File or resource path used for resource path.
var resource_path: String
## Lookup ID of the resource being loaded.
var resource_id: String


## During creation, this function connects responses to [code].process_frame[/code]; sets
## [code]resource_id[/code] to [code]id[/code]; sets [code]resource_path[/code] to
## [code]path[/code].
func _init(
	id: String, path: String, perform_load: bool = true, use_sub_threads: bool = false
) -> void:
	resource_id = id
	resource_path = path

	# Used when no threaded loading is actually required.
	if not perform_load:
		return

	ResourceLoader.load_threaded_request(resource_path, "", use_sub_threads)
	Engine.get_main_loop().process_frame.connect(_on_process_frame)


## Disconnects responses from [code].process_frame[/code]; updates [code]_status[/code] using
## [code]ResourceLoader.load_threaded_get_status[/code]; updates [code]resource[/code] using
## [code]ResourceLoader.load_threaded_get[/code]. It also sends [code]loading_finished[/code]
## notifications.
func _on_process_frame() -> void:
	_status = ResourceLoader.load_threaded_get_status(resource_path)

	var stop: bool = true

	match _status:
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_INVALID_RESOURCE:
			CustomLogger.error(
				self, _on_process_frame,
				"Resource %s does not exist." % resource_path, CustomLogger.LEVEL.MILD
			)
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			stop = false
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			CustomLogger.error(
				self, _on_process_frame,
				"Resource %s failed to load." % resource_path, CustomLogger.LEVEL.MILD
			)
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			resource = ResourceLoader.load_threaded_get(resource_path)

	if stop:
		Engine.get_main_loop().process_frame.disconnect(_on_process_frame)
		loading_finished.emit(status)
