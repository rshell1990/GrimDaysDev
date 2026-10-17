extends Node
## Run this scene to check music input forms and actual playback parameters.

var failures: int = 0
## Count of playback notifications observed by the regression listener.
var signals_received: int = 0


## Schedules the checks after the scene and autoloads are ready.
func _ready() -> void:
    run_checks.call_deferred()


## Counts a failed condition and reports its message without stopping the remaining checks.
func check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)


## Checks the four supported music inputs, playback settings and notification counts; rejects
## invalid inputs; loads the known regression resources and scripts. Prints PASS or FAIL and exits
## with the matching status.
func run_checks() -> void:
    SoundManager.music_played.connect(_on_music_played)
    var wrapper = Repositories.get_info(RepositoryTypes.MUSIC, "theme")
    check(wrapper is MusicTrackResource, "Theme repository must return a music wrapper")
    if wrapper is MusicTrackResource:
        for input in [wrapper, wrapper.track, "theme", &"theme"]:
            var player: AudioStreamPlayer = SoundManager.play_music(input, 0.0, 0.25, 2.0, "Master")
            check(player != null, "Supported music input must create a player")
            if player != null:
                # Timers run before tweens; a slow first frame can expire both together.
                await SoundManager.music._tweens[player].finished
                await get_tree().create_timer(0.08).timeout
                check(player.stream.resource_path == wrapper.track.resource_path, "Must play the requested stream")
                check(player.playing, "Music must be playing")
                check(absf(player.volume_db - linear_to_db(0.25)) < 0.01, "Linear volume must be converted to dB")
                check(
                    player.get_playback_position() >= 2.0 and player.get_playback_position() < 2.5,
                    "Playback must start at the supplied position"
                )
                check(player.bus == &"Master", "Bus override must be forwarded")
            SoundManager.stop_music(0.0)
            await get_tree().create_timer(0.05).timeout
    check(signals_received == 4, "Each valid request must emit music_played once")
    for input in [null, MusicTrackResource.new(), "__missing_music_smoke_fixture__", 42]:
        check(SoundManager.play_music(input) == null, "Invalid or missing music must return null")
    check(signals_received == 4, "Invalid music must not emit music_played")
    SoundManager.music_played.disconnect(_on_music_played)
    for unit in ["celine_teen", "goon_a", "goon_b", "harlok"]:
        for stat in ["lucky_evasion", "magic_resistance"]:
            var path = "res://GrimDaysBattle/resources/units/%s/stats/scaling/%s.tres" % [unit, stat]
            var resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
            check(
                resource != null and resource.to_stat_maximum_curve != null,
                "Previously failing stat must load: " + path
            )
    for path in [
        "res://editor_only_debug/scripts/debug/courtyard_balance_probe.gd",
        "res://editor_only_debug/scripts/debug/battle_smoke_tests/party_preparation_smoke_suite.gd",
        "res://editor_only_debug/scripts/debug/battle_smoke_tests/attribute_progression_smoke_suite.gd",
        "res://GrimDaysBattle/scripts/Runtime/debug_battle_controller.gd",
        "res://GrimDaysBattle/scripts/Battle/Runtime/battle_coordinator.gd",
    ]:
        var script = load(path) # lint:ignore load-in-var -- Load fixtures during test execution.
        check(script is GDScript and script.can_instantiate(), "Previously failing script must compile: " + path)
    print("MUSIC_PLAYBACK_SMOKE_TEST: ", "PASS" if failures == 0 else "FAIL (%d)" % failures) # lint:ignore debug-print,line-length -- Required test/CLI output.
    get_tree().quit(0 if failures == 0 else 1)


## Counts valid playback notifications so the test can detect missing or duplicate signals.
func _on_music_played() -> void:
    signals_received += 1
