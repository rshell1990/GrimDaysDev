extends Node
## Coordinates dynamic song players and remembers playback settings for restoration.
class_name OvaniSongsDirector
## Shared fixed value for muted.
const MUTED: float = -80.0
## Shared fixed value for first.
const FIRST: int = 8000
## List of ovani players used by this script.
var ovani_players: Array[OvaniSongOperator]
## Audio player currently selected to play the active song.
var active_player: OvaniSongOperator = null
## Index used to select the next dynamic song player.
var active_index: int = FIRST
## ID of the song most recently selected for playback.
var last_played: String = ""
## Key used to identify this script’s data in saved state.
var save_name: String = "songs"
## Song IDs recorded in playback order.
var play_history: PackedStringArray = PackedStringArray()
## Notification for restored.
signal restored


## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)


## When the node is ready, this function connects responses to [code]VNSignalBus.on_load[/code];
## adds [code]child[/code] to [code]ovani_players[/code].
func _ready() -> void:
    for child in get_children():
        if child is OvaniSongOperator:
            ovani_players.append(child)

    VNSignalBus.on_load.connect(_on_load)


## Fades every song player to the muted volume, waits for the fade allowance, then clears all song
## queues.
func silence_all() -> void:
    for song_player in ovani_players:
        song_player.set_volume(MUTED, VNAnimationTimes.LONG)
    await get_tree().create_timer(VNAnimationTimes.LONG + VNAnimationTimes.FAST).timeout
    clear_all_queues()


## Fades the active song player toward the muted volume over the requested time, if a player is
## active.
func set_active_silent(transition_time: float) -> void:
    if active_player == null:
        return
    last_played = ""
    active_player.set_volume(MUTED, transition_time)


## Reads intensity and transition speed from command data and applies them only if a song player is
## active.
func relay_intensity(data: Dictionary) -> void:
    if active_player == null:
        return
    var intensity = data.intensity as String
    var speed = data.speed as String
    set_intensity(intensity.to_float(), speed.to_float())


## Changes the active song's intensity over the supplied transition duration.
func set_intensity(intensity: float, speed: float) -> void:
    active_player.FadeIntensity(intensity, speed)


## Reads volume and transition speed from command data and applies them only if a song player is
## active.
func relay_volume(data: Dictionary) -> void:
    if active_player == null:
        return
    var volume = data.volume as String
    var speed = data.speed as String
    set_volume(volume.to_float(), speed.to_float())


## Changes the active song's volume over the supplied transition duration.
func set_volume(volume: float, speed: float) -> void:
    active_player.FadeVolume(volume, speed)


## Changes the active song player's mode when a player is available.
func relay_mode(data: Dictionary) -> void:
    if active_player == null:
        return
    active_player.set_mode(data.mode)


## Requests playback of the song named in the supplied command data.
func set_new_song(data: Dictionary) -> void:
    play_song(data.song)


## Requests playback of the song identified by the supplied name.
func play_song(song_name: String) -> void:
    var song = Repositories.get_info(RepositoryTypes.SONGS, song_name)
    last_played = song_name
    play_history.append(song_name)
    var next_player
    if active_player != null:
        var old_player: OvaniSongOperator = active_player
        old_player.set_volume(MUTED, VNAnimationTimes.SLOW)
        CustomLogger.warn(
            self,
            self.play_song,
            " will pause Dialogic while switching the current song player "
            + "and the next song player.",
            CustomLogger.LEVEL.VERBOSE
        )
        Dialogic.paused = true
        await get_tree().create_timer(VNAnimationTimes.LONG).timeout
        if old_player == null:
            play_song(song_name)
            return
        var old_index = ovani_players.find(old_player)
        if old_index != -1:
            ovani_players.pop_at(old_index)
        old_player.queue_free()
        var new_player = OvaniSongOperator.new()
        add_child(new_player)
        ovani_players.append(new_player)
        next_player = new_player
        await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
        Dialogic.paused = false
        CustomLogger.warn(
            self,
            self.play_song,
            " will unpause Dialogic.",
            CustomLogger.LEVEL.VERBOSE
        )

    if not next_player:
        next_player = get_next_player()

    active_player = next_player
    active_player.play(song)


## Queues the named song, or starts it immediately when there is no active player.
func queue_new_song(data: Dictionary) -> void:
    if active_player == null:
        play_song(data.song)
        return
    queue_song(data.song)


## Queues the named song after the active player's current song.
func queue_song(song_name: String) -> void:
    var song = Repositories.get_info(RepositoryTypes.SONGS, song_name)
    active_player.queue(song)


## Selects the next song player from the available player list.
func get_next_player():
    var next_player: OvaniSongOperator = null
    for operator in ovani_players:
        if operator != active_player:
            next_player = operator
            next_player.Volume = MUTED
            next_player.QueuedSongs.clear()
            break
    return next_player


## Clears queued songs on every player except the currently active player.
func clear_non_active_queues() -> void:
    for operator in ovani_players:
        if operator != active_player:
            operator.QueuedSongs.clear()


## Clears queued songs on every dynamic song player.
func clear_all_queues() -> void:
    last_played = ""
    for operator in ovani_players:
        operator.QueuedSongs.clear()


# TODO: Finish saving/loading for navigation director.
## Collects this object’s current last played, history, volume, intensity into a dictionary for
## saving or restoration.
func _get_state() -> Dictionary:
    if active_player and active_player.QueuedSongs.size() > 0 \
            and active_player.QueuedSongs[0].id not in play_history:
        play_history.append(active_player.QueuedSongs[0].id)
    var data: Dictionary = {
        "last_played": active_player.playing \
                if active_player and not active_player.playing.is_empty() else last_played,
        "history": play_history,
        "volume": active_player.Volume if active_player != null else -80.0,
        "intensity": active_player.Intensity if active_player != null else 0.0
    }
    return data


## Waits for a timer through [code]SystemHelpers[/code]; starts playback on
## [code]active_player[/code]; sets [code]active_player.Volume[/code] to
## [code]data.info[save_name]["volume"][/code]. It also sets [code]active_player.Intensity[/code] to
## [code]data.info[save_name]["intensity"][/code]. It pauses for
## [code]SystemHelpers.start_timer(VNAnimationTimes.FAST)[/code] before continuing.
func _on_load(data: Dictionary) -> void:
    if not data.info.has(save_name):
        SystemHelpers.print_rich("[b][u]No Song Data[/u][/b]")
        return
    if data.info[save_name]["last_played"].is_empty():
        return
    SystemHelpers.print_rich("[b][u]Loading Song[/u][/b]")
    if active_player == null:
        play_song(data.info[save_name]["last_played"])
        await SystemHelpers.start_timer(VNAnimationTimes.FAST)
        set_volume(data.info[save_name]["volume"], 0.01)
        set_intensity(data.info[save_name]["intensity"], 0.01)
    else:
        active_player.play(
            Repositories.get_info(RepositoryTypes.SONGS, data.info[save_name]["last_played"])
        )
        active_player.Volume = data.info[save_name]["volume"]
        active_player.Intensity = data.info[save_name]["intensity"]


## Waits for a timer through [code]SystemHelpers[/code]; sets [code]active_player.Volume[/code] to
## [code]data.volume[/code]; sets [code]active_player.Intensity[/code] to
## [code]data.intensity[/code]. It also sends [code]restored[/code] notifications. It pauses for
## [code]SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)[/code],
## [code]SystemHelpers.start_timer(VNAnimationTimes.SLOW)[/code] before continuing.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    if data.last_played.is_empty():
        CustomLogger.hint(
            self,
            self.restore,
            save_name + " is missing last played song, so will be aborted..." + str(data)
        )
        await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
        restored.emit()
        return

    if data.last_played != last_played:
        clear_all_queues()
        play_song(data.last_played)
        await SystemHelpers.start_timer(VNAnimationTimes.SLOW)

    if data.last_played == last_played:
        CustomLogger.hint(
            self,
            self.restore,
            "[color=#5F0]" + name + " skipping playing the already playing song.[/color]",
            CustomLogger.LEVEL.MILD
        )
    active_player.Volume = data.volume
    active_player.Intensity = data.intensity
    last_played = data.last_played
    if data.has("history"):
        play_history = (
            PackedStringArray(data.history)
            if typeof(data.history) == TYPE_ARRAY
            else data.history
        )
    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()
