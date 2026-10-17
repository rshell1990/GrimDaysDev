## Regression checks for VN fixes ported from dark_dimensions fbb0cc09.
## Uses temporary save fixtures and transient objects, never a player's save slots.
extends Node

## Save-integrity helper exercised against temporary fixture slots.
const INTEGRITY = preload("res://GrimDaysVN/scripts/_a_major_refactor/save_and_load/save_integrity.gd")
## Audio preference adapter exercised with settings restored after the check.
const AUDIO_LEVELS = preload("res://GrimDaysVN/scripts/sound/set_audio_levels.gd")
## Number of top-level checks that reached their successful end.
var completed_checks: int = 0
## Failure messages observed during explicitly isolated save-I/O checks.
var failure_reports: Array[String] = []
## Enables automatic dismissal only for reports expected by the isolated I/O fixture.
var acknowledge_failures: bool = false

## PASS marker printed after the requested VN checks complete.
const SUCCESS_MESSAGE := "VN_UPSTREAM_FIXES_SMOKE_TEST: PASS"


class FixtureSave:
    extends Node
    var directory: String

    func get_slot_path(slot: String) -> String:
        return directory.path_join(slot)

    func get_encryption_password() -> String:
        return ""


class RecordedWalk:
    extends CharacterSpriteWalkTo
    var points: Array[Vector3] = []

    func tween_between_points(_i, point) -> void:
        points.append(point)


class RecordedRun:
    extends CharacterSpriteRunTo
    var points: Array[Vector3] = []

    func tween_between_points(_i, point) -> void:
        points.append(point)


## Defers checks until all autoloads and the scene are ready.
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    run_checks.call_deferred()


## Verifies serialization, failed replacement recovery, clocks, movement and independent audio buses.
func run_checks() -> void:
    _check_save_integrity()
    _check_playtime()
    await _check_clock_restore()
    await _check_movement()
    _check_audio_levels()
    _check_tooltip_signals()
    _check_navigation_commands()
    _check_save_repair_copy()
    var expected_checks := 8
    if OS.get_environment("VN_TEST_SAVE_IO") == "1":
        await _check_save_task_io()
        expected_checks += 1
    assert(completed_checks == expected_checks, "A regression check failed before completion.")
    print(SUCCESS_MESSAGE) # lint:ignore debug-print -- Required test/CLI output.


## Builds a small valid game-state dictionary for isolated save checks.
func _valid_game_info() -> Dictionary:
    return {
        "game_manager":
        {
            "current_event": &"",
            "seen_events": [],
            "state": GameManagerStates.STATES.Navigation,
            "last_state": GameManagerStates.STATES.Navigation,
            "world": 0,
            "time": 1234
        },
        "in_game_time": {"date": {"year": 2006, "month": 10, "day": 13}, "day_id": 5, "time_id": 0},
        "navigation": {"location": &"NovarasChildhoodHomeLivingRoom", "dimension": 0}
    }


## Writes temporary state, game information and metadata, optionally adding an integrity manifest.
func _write_fixture(save: FixtureSave, slot: String, with_manifest: bool = true) -> void:
    assert(DirAccess.make_dir_recursive_absolute(save.get_slot_path(slot)) == OK)
    assert(INTEGRITY.write_file(save, slot, "state.txt", DialogicSaveState.new()) == OK)
    assert(INTEGRITY.write_file(save, slot, "game_info", _valid_game_info()) == OK)
    assert(INTEGRITY.write_file(save, slot, "info.txt", {"save_name": "fixture"}) == OK)
    if with_manifest:
        assert(INTEGRITY.write_manifest(save, slot) == OK)


## Checks names, legacy saves, checksums, invalid structures, replacement failure and backup
## preservation using temporary directories, then removes those fixtures.
func _check_save_integrity() -> void:
    var save := FixtureSave.new()
    var temporary_root := OS.get_environment("VN_TEST_TMP")
    if temporary_root.is_empty():
        temporary_root = "user://"
    save.directory = temporary_root.path_join("vn_upstream_fixtures_%s" % Time.get_ticks_usec())
    for slot_name in ["", ".", "..", "../slot", "a/b", "a\\b", "a:b"]:
        assert(not INTEGRITY.valid_slot_name(slot_name))
    assert(INTEGRITY.valid_slot_name("2006_10_13___12_0_0___0.05.1___Game-Save___1"))
    assert(INTEGRITY.inspect_slot(save, "missing").error != OK)
    _write_fixture(save, "legacy", false)
    var checked := INTEGRITY.inspect_slot(save, "legacy")
    assert(checked.error == OK and not checked.warnings.is_empty())
    assert(checked.state is DialogicSaveState)
    assert(checked.game_info.info.game_manager.time == 1234)
    _write_fixture(save, "verified")
    assert(INTEGRITY.inspect_slot(save, "verified").error == OK)
    var changed := _valid_game_info()
    changed.game_manager.world = 9
    assert(INTEGRITY.write_file(save, "verified", "game_info", changed) == OK)
    assert(INTEGRITY.inspect_slot(save, "verified").error == ERR_FILE_CORRUPT)
    # A valid checksum cannot make the wrong state format valid.
    assert(INTEGRITY.write_file(save, "verified", "state.txt", {}) == OK)
    assert(INTEGRITY.write_manifest(save, "verified") == OK)
    assert(INTEGRITY.inspect_slot(save, "verified").error == ERR_FILE_CORRUPT)
    _write_fixture(save, "destination")
    var original_hash := FileAccess.get_sha256(save.get_slot_path("destination").path_join("game_info"))
    var failed := INTEGRITY.commit_slot(save, "missing", "destination")
    assert(failed.error != OK)
    assert(FileAccess.get_sha256(save.get_slot_path("destination").path_join("game_info")) == original_hash)
    _write_fixture(save, ".pending-new")
    assert(INTEGRITY.write_file(save, ".pending-new", "game_info", changed) == OK)
    assert(INTEGRITY.write_manifest(save, ".pending-new") == OK)
    assert(INTEGRITY.inspect_slot(save, ".pending-new").error == OK)
    var committed := INTEGRITY.commit_slot(save, ".pending-new", "destination")
    assert(committed.error == OK and not committed.backup.is_empty())
    assert(FileAccess.get_sha256(committed.backup.path_join("game_info")) == original_hash)
    assert(INTEGRITY.inspect_slot(save, "destination").game_info.info.game_manager.world == 9)
    # The preflight result is a snapshot, unaffected by later disk writes.
    assert(checked.game_info.info.game_manager.world == 0)
    var invalid := _valid_game_info()
    invalid.game_manager.seen_events = [4]
    assert(not INTEGRITY.validate_game_info(invalid).is_empty())
    invalid = _valid_game_info()
    invalid.in_game_time.time_id = 999
    assert(not INTEGRITY.validate_game_info(invalid).is_empty())
    _remove_fixture_directory(save.directory)
    save.free()
    completed_checks += 1


## Recursively removes only the temporary fixture directory passed by the test.
func _remove_fixture_directory(path: String) -> void:
    var directory := DirAccess.open(path)
    directory.include_hidden = true
    for child in directory.get_directories():
        _remove_fixture_directory(path.path_join(child))
    for filename in directory.get_files():
        assert(DirAccess.remove_absolute(path.path_join(filename)) == OK)
    assert(DirAccess.remove_absolute(path) == OK)


## Checks saved elapsed time plus current-session ticks, and verifies reset starts a fresh counter.
func _check_playtime() -> void:
    var manager := GameManagerSingleton.new()
    manager.accumulated_playtime_ms = 9000
    manager.session_started_at_ms = Time.get_ticks_msec() - 2000
    assert(absi(manager.get_total_playtime_ms() - 11000) < 100)
    manager.reset()
    assert(manager.get_total_playtime_ms() < 100)
    manager.free()
    completed_checks += 1


## Checks that restoring the date and time sends an unchanged-time refresh rather than advancing
## the day.
func _check_clock_restore() -> void:
    var clock := TimeDirector.new()
    clock.date = Calendar.Date.new(2006, 10, 13)
    clock.time_id = TimeAdministrator.TIMES.Bedtime
    var notifications := []
    var handler := func(old_time, new_time): notifications.append([old_time, new_time])
    VNSignalBus.time_passed.connect(handler)
    await clock.restore(
        {"date": {"year": 2006, "month": 10, "day": 13}, "day_id": 5, "time_id": TimeAdministrator.TIMES.Dawn}
    )
    assert(clock.date.day == 13 and clock.time_id == TimeAdministrator.TIMES.Dawn)
    assert(
        notifications == [[TimeAdministrator.TIMES.Dawn, TimeAdministrator.TIMES.Dawn]],
        "Restoring time refreshes listeners with no simulated time passage."
    )
    VNSignalBus.time_passed.disconnect(handler)
    clock.free()
    completed_checks += 1


## Checks walk/run destination coordinates, one start/end notification pair, and preservation of an
## existing dialogue pause.
func _check_movement() -> void:
    var was_paused := Dialogic.paused
    Dialogic.paused = true
    for mover in [RecordedWalk.new(), RecordedRun.new()]:
        var signals := []
        mover.moving.connect(func(): signals.append("moving"))
        mover.stopped.connect(func(): signals.append("stopped"))
        await mover.execute({"current_position": Vector3(0, 7, -12), "target_x": 125})
        assert(mover.points.back() == Vector3(125, 7, -12))
        assert(signals == ["moving", "stopped"])
        assert(Dialogic.paused, "Movement helpers must not unpause other concurrent movements.")
        mover.free()
    Dialogic.paused = was_paused
    completed_checks += 1


## Checks that each audio bus uses its own preference, then restores the original preferences and
## bus levels.
func _check_audio_levels() -> void:
    var preferences := SM_Globals.user_prefs
    var original := [
        preferences.master_volume,
        preferences.dynamic_volume,
        preferences.music_volume,
        preferences.sfx_volume,
        preferences.ambient_volume
    ]
    var levels := [0.9, 0.7, 0.5, 0.3, 0.0]
    var fields := ["master_volume", "dynamic_volume", "music_volume", "sfx_volume", "ambient_volume"]
    var buses := [
        SM_Globals.MASTER_BUS_ID,
        SM_Globals.DYNAMIC_BUS_ID,
        SM_Globals.MUSIC_BUS_ID,
        SM_Globals.SFX_BUS_ID,
        SM_Globals.AMBIENT_BUS_ID
    ]
    var audio := AUDIO_LEVELS.new()
    for i in fields.size():
        preferences.set(fields[i], levels[i])
    audio._ready()
    for i in buses.size():
        assert(AudioServer.is_bus_mute(buses[i]) == (levels[i] < 0.05))
        if levels[i] > 0:
            assert(is_equal_approx(AudioServer.get_bus_volume_db(buses[i]), linear_to_db(levels[i])))
    for i in fields.size():
        preferences.set(fields[i], original[i])
    audio._ready()
    audio.free()
    completed_checks += 1


## Uses a separate signal bus to check that a location change hides the tooltip first.
func _check_tooltip_signals() -> void:
    # Use a separate bus so no live game listeners run.
    var bus = load("res://GrimDaysVN/scripts/_globals/_observers/general_signal_bus.gd").new() # lint:ignore load-in-var,line-length -- Load fixtures during test execution.
    var notifications := []
    bus.on_tooltip_hide.connect(func(): notifications.append("hide"))
    bus.location_changed.connect(func(_location): notifications.append("location"))
    bus.on_location_changed(&"example")
    assert(notifications == ["hide", "location"])
    bus.free()
    completed_checks += 1


## Checks that the navigation administrator resolves a named location.
func _check_navigation_commands() -> void:
    var admin := NavigationAdministrator.new()
    var director := NavigationDirector.new()
    admin.director = director
    admin.get_location(["name:NovarasChildhoodHomeLivingRoom"])
    assert(director.location == &"NovarasChildhoodHomeLivingRoom")
    director.free()
    admin.free()
    completed_checks += 1


## Checks that editing a repaired nested dictionary does not change the original data.
func _check_save_repair_copy() -> void:
    var original := {"info": {"nested": {"value": 1}}}
    var repair := SaveRepairOperation.new(original)
    var copy := repair.repair()
    copy.info.nested.value = 2
    assert(original.info.nested.value == 1)
    repair.free()
    completed_checks += 1


## Exercises the real queued save path only in an explicitly isolated user-data directory.
func _check_save_task_io() -> void:
    var isolated_root := OS.get_environment("XDG_DATA_HOME")
    assert(isolated_root.begins_with("/tmp/vn-save-integration-"))
    assert(OS.get_user_data_dir().begins_with(isolated_root))
    Dialogic.Save.latest_thumbnail = Image.create(2, 2, false, Image.FORMAT_RGB8)
    var slot := "regression___Game-Save___1"
    acknowledge_failures = true
    var saved: bool = await SaveAndLoadSystemManager.save_game(slot, "Original")
    assert(saved and failure_reports.is_empty())
    var checked := INTEGRITY.inspect_slot(Dialogic.Save, slot)
    assert(checked.error == OK)
    assert(Dialogic.Save.get_global_info("last_hard_save", "") == slot)
    saved = await SaveAndLoadSystemManager.save_game(slot, "Replacement")
    assert(saved and failure_reports.is_empty())
    assert(INTEGRITY.read_file(Dialogic.Save, slot, "info.txt").data.save_name == "Replacement")
    var restored: bool = await SaveAndLoadSystemManager.load_game(slot)
    assert(restored and failure_reports.is_empty())
    # An invalid save is rejected before resetting the live game or hiding its menu.
    var current_state = GameManager.state
    var current_event = GameManager.current_event
    var payload: Dictionary = checked.game_info.info.duplicate(true)
    payload.game_manager.world += 1
    assert(INTEGRITY.write_file(Dialogic.Save, slot, "game_info", payload) == OK)
    var loaded: bool = await SaveAndLoadSystemManager.load_game(slot)
    assert(not loaded and failure_reports.size() == 1)
    assert(GameManager.state == current_state and GameManager.current_event == current_event)
    assert(not SaveAndLoadSystemManager._operation_in_progress)
    assert(not get_tree().paused)
    acknowledge_failures = false
    completed_checks += 1


## Automatically dismisses reports only during the isolated save-I/O regression check.
func _process(_delta: float) -> void:
    if acknowledge_failures and is_instance_valid(SaveAndLoadSystemManager.failure_dialog):
        failure_reports.append(SaveAndLoadSystemManager.failure_dialog.report_text)
        SaveAndLoadSystemManager.failure_dialog.acknowledge()
