## Validates local Dialogic resource saves and commits verified replacements
## with recoverable backups.
## Adapted from dark_dimensions fbb0cc09; this project uses DialogicSaveState,
## not a state Dictionary.
extends RefCounted

## Filename of the versioned integrity manifest in a save-slot directory.
const MANIFEST := "integrity.txt"
## Payload filenames included in integrity validation.
const PAYLOADS := ["state.txt", "game_info", "info.txt"]


## Rejects path traversal and empty slot names before filesystem access.
static func valid_slot_name(slot: String) -> bool:
    return (
        not slot.is_empty()
        and slot not in [".", ".."]
        and not slot.contains("/")
        and not slot.contains("\\")
        and not slot.contains(":")
    )


## Reads the local Variant format, including DialogicSaveState resources in state.txt.
## Save files are trusted local game data; this is corruption detection,
## not an untrusted-file sandbox.
static func read_file(save: Node, slot: String, filename: String) -> Dictionary:
    if not valid_slot_name(slot):
        return {"error": ERR_FILE_BAD_PATH}
    var path: String = save.get_slot_path(slot).path_join(filename)
    var password: String = save.get_encryption_password()
    var file: FileAccess
    if password.is_empty():
        file = FileAccess.open(path, FileAccess.READ)
    else:
        file = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, password)
    if not file:
        return {"error": FileAccess.get_open_error()}
    var data: Variant = file.get_var(filename == "state.txt")
    var error := file.get_error()
    if data == null and error == OK:
        error = ERR_FILE_CORRUPT
    return {"error": error, "data": data, "bytes": file.get_length()}


## Flushes writes and reports filesystem errors without changing latest/Continue metadata.
static func write_file(save: Node, slot: String, filename: String, data: Variant) -> Error:
    if not valid_slot_name(slot):
        return ERR_FILE_BAD_PATH
    var path: String = save.get_slot_path(slot).path_join(filename)
    var password: String = save.get_encryption_password()
    var file: FileAccess
    if password.is_empty():
        file = FileAccess.open(path, FileAccess.WRITE)
    else:
        file = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, password)
    if not file:
        return FileAccess.get_open_error()
    file.store_var(data, filename == "state.txt")
    file.flush()
    var error := file.get_error()
    file.close()
    return error


## Checks required payloads before any running scene, battle or dialogue is reset.
static func inspect_slot(save: Node, slot: String) -> Dictionary:
    var result := {
        "slot": slot,
        "error": OK,
        "errors": PackedStringArray(),
        "warnings": PackedStringArray(),
        "files": {},
    }
    if not valid_slot_name(slot):
        result.error = ERR_FILE_BAD_PATH
        result.errors.append("Invalid or empty slot name.")
        return result
    var decoded := {}
    for filename in PAYLOADS:
        var read := read_file(save, slot, filename)
        result.files[filename] = {"error": read.error, "bytes": read.get("bytes", 0)}
        if read.error != OK:
            var message: String = filename + ": " + error_string(read.error)
            if filename == "info.txt":
                result.warnings.append(message)
            else:
                result.errors.append(message)
        else:
            decoded[filename] = read.data
            var payload_path: String = save.get_slot_path(slot).path_join(filename)
            result.files[filename]["sha256"] = FileAccess.get_sha256(payload_path)
    if FileAccess.file_exists(save.get_slot_path(slot).path_join(MANIFEST)):
        var manifest := read_file(save, slot, MANIFEST)
        if manifest.error != OK or not manifest.get("data") is Dictionary:
            result.errors.append("Unreadable integrity manifest.")
        elif manifest.data.get("format") != 1 or not manifest.data.get("sha256") is Dictionary:
            result.errors.append("Unsupported or malformed integrity manifest.")
        else:
            for filename in PAYLOADS:
                if (
                    not manifest.data.sha256.get(filename) is String
                    or manifest.data.sha256[filename] != result.files[filename].get("sha256", "")
                ):
                    result.errors.append(filename + ": checksum mismatch or missing payload.")
    else:
        result.warnings.append("Legacy save: structural validation only; no checksums.")
    result.errors.append_array(validate_game_info(decoded.get("game_info")))
    result.errors.append_array(validate_dialogic_state(decoded.get("state.txt")))
    if not result.errors.is_empty():
        result.error = ERR_FILE_CORRUPT
        return result
    var repair := SaveRepairOperation.new(
        {"type": RollbackCommands.LOADED, "info": decoded.game_info}
    )
    result["game_info"] = repair.repair()
    repair.free()
    result["state"] = decoded["state.txt"]
    return result


## Validates restore fields and replaces missing or invalid dates with the default starting date.
static func validate_game_info(info: Variant) -> PackedStringArray:
    var errors := PackedStringArray()
    if not info is Dictionary or info.is_empty():
        return PackedStringArray(["game_info: expected a non-empty Dictionary."])
    for key in ["game_manager", "in_game_time", "navigation"]:
        if not info.get(key) is Dictionary:
            errors.append("game_info." + key + ": required Dictionary missing.")
    for key in info:
        if not info[key] is Dictionary:
            errors.append("game_info." + str(key) + ": expected a state Dictionary.")
    if not errors.is_empty():
        return errors
    _fields(
        info.game_manager,
        {
            "current_event": [TYPE_STRING, TYPE_STRING_NAME],
            "seen_events": [TYPE_ARRAY],
            "state": [TYPE_INT],
            "last_state": [TYPE_INT],
            "world": [TYPE_INT],
            "time": [TYPE_INT, TYPE_FLOAT]
        },
        "game_manager",
        errors
    )
    _fields(
        info.in_game_time, {"day_id": [TYPE_INT], "time_id": [TYPE_INT]}, "in_game_time", errors
    )
    _fields(
        info.navigation,
        {"location": [TYPE_STRING, TYPE_STRING_NAME], "dimension": [TYPE_INT]},
        "navigation",
        errors
    )
    if not errors.is_empty():
        return errors
    _normalize_date(info.in_game_time)
    for key in ["state", "last_state"]:
        if info.game_manager[key] not in GameManagerStates.STATES.values():
            errors.append("game_manager." + key + ": unknown state.")
    for id in info.game_manager.seen_events:
        if typeof(id) not in [TYPE_STRING, TYPE_STRING_NAME]:
            errors.append("game_manager.seen_events: invalid event identifier.")
    if (
        info.in_game_time.time_id not in TimeAdministrator.TIMES.values()
        or info.in_game_time.day_id < 0
        or info.in_game_time.day_id > 6
    ):
        errors.append("in_game_time: invalid time or weekday.")
    if not errors.is_empty():
        return errors
    var manager: Dictionary = info.game_manager
    var event_id: String = manager.current_event
    var scenario_states: Array = [
        GameManagerStates.STATES.Scenario,
        GameManagerStates.STATES.ScenarioSequence,
    ]
    if (
        event_id.is_empty()
        and (
            manager.state in scenario_states
            or manager.get("timeline_active", false)
        )
    ):
        if manager.seen_events.is_empty():
            errors.append("Active scenario has no current or previous event.")
        else:
            event_id = manager.seen_events[-1]
    if (
        not event_id.is_empty()
        and not Repositories.get_info(RepositoryTypes.EVENTS, event_id) is GameEvent
    ):
        errors.append("Saved event is unavailable: " + event_id)
    return errors


## Keeps the existing date bounds, but recovers malformed dates before restoration.
static func _normalize_date(clock: Dictionary) -> void:
    var date: Variant = clock.get("date")
    if date is Dictionary:
        var errors := PackedStringArray()
        _fields(
            date,
            {"year": [TYPE_INT], "month": [TYPE_INT], "day": [TYPE_INT]},
            "in_game_time.date",
            errors
        )
        if (
            errors.is_empty()
            and date.year >= 1
            and date.month >= 1
            and date.month <= 12
            and date.day >= 1
            and date.day <= 31
        ):
            return
    clock["date"] = TimeAdministrator.STARTING_DATE.duplicate(true)


## Validates the Resource format used by the vendored Dialogic version.
static func validate_dialogic_state(state: Variant) -> PackedStringArray:
    if not state is DialogicSaveState:
        return PackedStringArray(["state.txt: expected DialogicSaveState."])
    var errors := PackedStringArray()
    if not state.timeline.is_empty():
        if not ResourceLoader.exists(state.timeline):
            errors.append("Saved timeline is unavailable.")
        else:
            var timeline = ResourceLoader.load(state.timeline, "", ResourceLoader.CACHE_MODE_IGNORE)
            if not timeline is DialogicTimeline:
                errors.append("Saved timeline is not a DialogicTimeline.")
            else:
                timeline.process()
                if state.event_index < 0 or state.event_index >= timeline.events.size():
                    errors.append("Saved timeline event index is out of range.")
    return errors


## Adds missing-field/type diagnostics without invoking restore code.
static func _fields(
    data: Dictionary, schema: Dictionary, path: String, errors: PackedStringArray
) -> void:
    for key in schema:
        if not data.has(key) or typeof(data[key]) not in schema[key]:
            errors.append(path + "." + key + ": missing or invalid field.")


## Records hashes of closed payload files before verification and commit.
static func write_manifest(save: Node, slot: String) -> Error:
    var hashes := {}
    for filename in PAYLOADS:
        var path: String = save.get_slot_path(slot).path_join(filename)
        if not FileAccess.file_exists(path):
            return ERR_FILE_NOT_FOUND
        hashes[filename] = FileAccess.get_sha256(path)
    return write_file(save, slot, MANIFEST, {"format": 1, "sha256": hashes})


## Keep a recoverable, hidden backup. Never erase the old slot before verification.
static func commit_slot(save: Node, staging: String, slot: String) -> Dictionary:
    if not valid_slot_name(staging) or not valid_slot_name(slot) or staging == slot:
        return {"error": ERR_FILE_BAD_PATH}
    var source: String = save.get_slot_path(staging)
    var destination: String = save.get_slot_path(slot)
    var backup := ""
    if DirAccess.dir_exists_absolute(destination):
        backup = save.get_slot_path(".backup-%s-%s" % [slot, Time.get_ticks_usec()])
        var backup_error := DirAccess.rename_absolute(destination, backup)
        if backup_error != OK:
            return {"error": backup_error, "message": "Could not preserve the old save."}
    var error := DirAccess.rename_absolute(source, destination)
    if error != OK and not backup.is_empty():
        var restore_error := DirAccess.rename_absolute(backup, destination)
        return {
            "error": error,
            "message": "Save commit failed; backup restore: " + error_string(restore_error),
            "backup": backup
        }
    return {"error": error, "backup": backup}


## Internal helper used by this script.
static func report(result: Dictionary, operation: String) -> String:
    # Explicit allowlist: no saved dialogue, inventory, credentials, or entire payloads.
    return (
        "Grim Days save integrity report\n"
        + "Please describe what you were doing and submit this report to the developer.\n"
        + "Nothing is uploaded automatically.\n\n"
        + JSON.stringify(
            {
                "report_format": 1,
                "operation": operation,
                "utc": Time.get_datetime_string_from_system(true),
                "game_version": "%s.%s.%s" % [
                    Defaults.VERSION_MAJOR, Defaults.VERSION_MINOR, Defaults.VERSION_PATCH
                ],
                "godot": Engine.get_version_info().string,
                "os": OS.get_name(),
                "slot": result.get("slot", ""),
                "error": result.get("error", FAILED),
                "errors": result.get("errors", []),
                "warnings": result.get("warnings", []),
                "files": result.get("files", {})
            },
            "\t"
        )
    )
