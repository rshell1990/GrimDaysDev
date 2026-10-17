## Checks ownership fixes and related stat behavior without writing player saves.
extends "res://editor_only_debug/scripts/debug/battle_smoke_tests/battle_smoke_test_suite.gd"

const DIALOGIC_HANDLER = preload("res://addons/dialogic/Core/DialogicGameHandler.gd")
const STAT_SUITES: Array[Script] = [
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/stat_model_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/stat_state_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/effect_lifecycle_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/authored_hit_proc_smoke_suite.gd"),
    preload("res://editor_only_debug/scripts/debug/battle_smoke_tests/action_rank_progression_smoke_suite.gd"),
]

var completed_checks: int = 0


func _ready() -> void:
    get_tree().create_timer(60.0).timeout.connect(_on_timeout)
    _run.call_deferred()


func _run() -> void:
    _check_dialogic_constructor()
    _check_display_manager()
    _check_runtime_speakers()
    _check_effect_arrays()
    _check_audio_ownership()
    await _check_stat_ownership()
    await _check_rollback_ownership()
    if completed_checks != 7:
        push_error("TEARDOWN_SMOKE_TEST: an ownership check did not finish.")
        get_tree().quit(1)
        return
    for script: Script in STAT_SUITES:
        var suite: Node = script.new()
        add_child(suite)
        await suite.run()
        await free_node(suite)
        print("TEARDOWN_STAT_SUITE_COMPLETE: " + script.resource_path.get_file()) # lint:ignore debug-print,line-length -- Required test/CLI output.
    GameManager.on_loading_sequence_start()
    print("TEARDOWN_SMOKE_TEST: PASS (7 ownership checks, 5 stat/effect suites)") # lint:ignore debug-print,line-length -- Required test/CLI output.
    get_tree().quit()


func _check_dialogic_constructor() -> void:
    var orphan_count := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
    var handler := DIALOGIC_HANDLER.new()
    handler.free()
    assert(
        Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphan_count,
        "Constructing and freeing a handler must not leave unused subsystem trees.",
    )
    for subsystem: Node in Dialogic.get_children():
        if subsystem is DialogicSubsystem:
            assert(Dialogic.get_subsystem(subsystem.name) == subsystem)
    completed_checks += 1


func _check_display_manager() -> void:
    assert(SM_Globals.display_manager is RefCounted, "The display helper must use reference ownership.")
    completed_checks += 1


func _check_runtime_speakers() -> void:
    var settings_key := "dialogic/directories/dch_directory"
    var before: Dictionary = ProjectSettings.get_setting(settings_key, {}).duplicate()
    var timeline := DialogicTimeline.new()
    timeline.from_text("TeardownRuntimeSpeaker: First line.\nTeardownRuntimeSpeaker: Second line.")
    timeline.process()
    var first: DialogicTextEvent = timeline.events[0]
    var second: DialogicTextEvent = timeline.events[1]
    assert(first.character != null and first.character == second.character)
    assert(first.character.get_identifier() == "TeardownRuntimeSpeaker")
    assert(DialogicResourceUtil.get_character_resource("TeardownRuntimeSpeaker") == first.character)
    assert(DialogicResourceUtil.resource_exists_from_identifier("TeardownRuntimeSpeaker", ".dch"))
    assert(
        ProjectSettings.get_setting(settings_key, {}) == before,
        "Runtime speakers must not mutate project settings.",
    )
    assert(not Engine.has_meta("dch_directory"), "Runtime resources must not outlive the main loop in Engine metadata.")
    assert(
        get_tree().get_meta("dch_directory").get("TeardownRuntimeSpeaker") == first.character,
        "The main loop must own the runtime directory through shutdown.",
    )
    # Leave the speaker registered: normal process shutdown must release it safely.
    completed_checks += 1


func _check_effect_arrays() -> void:
    var parent := EffectTemplate.new()
    var child := EffectTemplate.new()
    child.id = &"teardown_child"
    var other := EffectTemplate.new()
    for field: String in ["effects_on_expiry", "effects_on_hit", "effects_on_critical"]:
        var children: Array = parent.get(field)
        assert(children.get_typed_script() == EffectTemplate, "Empty follow-up arrays must remain effect-typed.")
        children.append(child)
        assert(parent.get(field).size() == 1, "Mutating the public array must update the resource.")
        assert(other.get(field).is_empty(), "Default arrays must not be shared across instances.")
        var replacement: Array[EffectTemplate] = [child]
        parent.set(field, replacement)
        assert(is_same(parent.get(field), replacement), "Typed assignments must preserve shared-array identity.")
        var copy := parent.duplicate(true) as EffectTemplate
        assert(copy.get(field).get_typed_script() == EffectTemplate)
        assert(copy.get(field)[0].id == child.id)
        assert(copy.get(field)[0] != child, "Deep duplication must still duplicate follow-up resources.")
        var exported := false
        for property: Dictionary in parent.get_property_list():
            if property.name == field:
                exported = property.hint == PROPERTY_HINT_TYPE_STRING and property.hint_string == "24/17:EffectTemplate"
        assert(exported, "The Inspector must retain the EffectTemplate element restriction.")
    var path := "user://teardown_effect_arrays_%s.tres" % Time.get_ticks_usec()
    assert(ResourceSaver.save(parent, path) == OK, "The follow-up resource must serialize.")
    var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as EffectTemplate
    var remove_error := DirAccess.remove_absolute(path)
    assert(remove_error == OK, "The temporary serialization fixture must be removed.")
    assert(restored != null)
    for field: String in ["effects_on_expiry", "effects_on_hit", "effects_on_critical"]:
        assert(restored.get(field).get_typed_script() == EffectTemplate)
        assert(restored.get(field).size() == 1 and restored.get(field)[0].id == child.id)
    completed_checks += 1


func _check_stat_ownership() -> void:
    var unit := create_unit()
    create_flat_stat(unit, CombatStats.STATS.Level, 1.0)
    var strength := create_flat_stat(unit, CombatStats.STATS.Strength, 10.0)
    var calculated := create_calculated_stat(unit)
    var scaled := create_scaled_stat(unit)
    var references: Array[WeakRef] = [weakref(strength), weakref(calculated), weakref(scaled)]
    strength = null
    calculated = null
    scaled = null
    await free_node(unit)
    await get_tree().process_frame
    for reference: WeakRef in references:
        assert(reference.get_ref() == null, "Freeing a unit must release its derived and base stats.")
    completed_checks += 1


func _check_audio_ownership() -> void:
    var player := OvaniPlayer.new()
    add_child(player)
    assert(player._audioStreamPlayback == null, "Idle players must not start server playback.")
    assert(not player._audioPlayer.playing)
    player._ensurePlayback()
    assert(player._audioStreamPlayback != null and player._audioPlayer.playing)
    player._process(0.0)
    assert(player._audioStreamPlayback == null, "Players with no songs must release playback.")
    assert(not player._audioPlayer.playing)
    player._ensurePlayback()
    remove_child(player)
    assert(not player._audioPlayer.playing, "Leaving the tree must stop the polyphonic player.")
    assert(player._audioStreamPlayback == null and player._soundManagers.is_empty())
    player.free()
    completed_checks += 1


func _check_rollback_ownership() -> void:
    var director := RollbackDirector.new()
    add_child(director)
    assert(director.operator.get_parent() == director, "The checkpoint helper must be owned by its director.")
    var reference: WeakRef = weakref(director.operator)
    await free_node(director)
    await get_tree().process_frame
    assert(reference.get_ref() == null, "Freeing a rollback director must free its checkpoint helper.")
    completed_checks += 1


func _on_timeout() -> void:
    push_error("TEARDOWN_SMOKE_TEST: timed out.")
    get_tree().quit(1)
