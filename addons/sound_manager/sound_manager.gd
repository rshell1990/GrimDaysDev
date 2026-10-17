extends Node

signal music_played()

const SoundEffectsPlayer = preload("./sound_effects.gd")
const AmbientSoundsPlayer = preload("./ambient_sounds.gd")
const MusicPlayer = preload("./music.gd")


var sound_effects: SoundEffectsPlayer = SoundEffectsPlayer.new(["SFX"], 8)
var ui_sound_effects: SoundEffectsPlayer = SoundEffectsPlayer.new(["SFX"], 8)
var ambient_sounds: AmbientSoundsPlayer = AmbientSoundsPlayer.new(["Effect Ambient"], 8)
var music: MusicPlayer = MusicPlayer.new(["Music"], 2)

var sound_process_mode: ProcessMode:
	set(value):
		sound_effects.process_mode = value
	get:
		return sound_effects.process_mode

var ui_sound_process_mode: ProcessMode:
	set(value):
		ui_sound_effects.process_mode = value
	get:
		return ui_sound_effects.process_mode


var ambient_sound_process_mode: ProcessMode:
	set(value):
		ambient_sounds.process_mode = value
	get:
		return ambient_sounds.process_mode


var music_process_mode: ProcessMode:
	set(value):
		music.process_mode = value
	get:
		return music.process_mode


func _init() -> void:
	Engine.register_singleton("SoundManager", self)

	add_child(sound_effects)
	add_child(ui_sound_effects)
	add_child(ambient_sounds)
	add_child(music)

	self.sound_process_mode = PROCESS_MODE_PAUSABLE
	self.ui_sound_process_mode = PROCESS_MODE_ALWAYS
	self.ambient_sound_process_mode = PROCESS_MODE_ALWAYS
	self.music_process_mode = PROCESS_MODE_ALWAYS


#region Sounds


func get_sound_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(sound_effects.bus)))


func set_sound_volume(volume_between_0_and_1: float) -> void:
	_show_shared_bus_warning()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(sound_effects.bus), linear_to_db(volume_between_0_and_1))


func play_sound(resource: Variant, override_bus: String = "") -> AudioStreamPlayer:
	var loaded = resource
	if not resource is AudioStream:
		loaded = resource.track if typeof(resource) != TYPE_STRING else Repositories.get_info(RepositoryTypes.SOUNDS, resource).track
	if loaded == null:
		return
	return sound_effects.play(loaded, override_bus)


func play_sound_with_pitch(resource: Variant, pitch: float = 1.0, override_bus: String = "") -> AudioStreamPlayer:
	var loaded = resource
	if not resource is AudioStream:
		loaded = resource.track if typeof(resource) != TYPE_STRING else Repositories.get_info(RepositoryTypes.SOUNDS, resource).track
	if loaded == null:
		return
	var player = sound_effects.play(loaded, override_bus)
	player.pitch_scale = pitch
	return player


func stop_sound(resource: AudioStream) -> void:
	return sound_effects.stop(resource)


func set_default_sound_bus(bus: String) -> void:
	sound_effects.bus = bus


#endregion

#region UI sounds


func get_ui_sound_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(ui_sound_effects.bus)))


func set_ui_sound_volume(volume_between_0_and_1: float) -> void:
	_show_shared_bus_warning()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(ui_sound_effects.bus), linear_to_db(volume_between_0_and_1))


func play_ui_sound(resource: AudioStream, override_bus: String = "") -> AudioStreamPlayer:
	return ui_sound_effects.play(resource, override_bus)


func play_ui_sound_with_pitch(resource: AudioStream, pitch: float = 1.0, override_bus: String = "") -> AudioStreamPlayer:
	var player = ui_sound_effects.play(resource, override_bus)
	player.pitch_scale = pitch
	return player


func stop_ui_sound(resource: AudioStream) -> void:
	return ui_sound_effects.stop(resource)


func set_default_ui_sound_bus(bus: String) -> void:
	ui_sound_effects.bus = bus


#endregion

#region Ambient sound


func get_ambient_sound_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(ambient_sounds.bus)))


func set_ambient_sound_volume(volume_between_0_and_1: float) -> void:
	_show_shared_bus_warning()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(ambient_sounds.bus), linear_to_db(volume_between_0_and_1))


func adjust_ambient_volume(track_id:String, new_volume:float) -> void:
	var track:AudioStream = Repositories.get_info(RepositoryTypes.AMBIENT, track_id).track
	print_rich("[bgcolor=#F0F][color=#FFF][b][i][u]Adjusting ambient volume: ", track_id, " to: ", new_volume, " Busy Players: ", ambient_sounds.busy_players)
	if ambient_sounds.busy_players.has(track.resource_path):
		var player = ambient_sounds.busy_players[track.resource_path]
		ambient_sounds.fade_volume(player, player.volume_db, linear_to_db(new_volume), 1.0)
	else:
		print_rich("[bgcolor=#0F0][color=#000][b]Track not in busy players: ",track)

func play_ambient_sound(resource: Variant, volume:float = 1.0, fade_in_duration: float = 0.0, override_bus: String = "") -> AudioStreamPlayer:
	CustomLogger.hint(self, stop_ambient_sound, "[bgcolor=#F00]Looking for ambient sound:  "+str(resource) + "[/bgcolor]",CustomLogger.LEVEL.VERY_VERBOSE)
	if Engine.time_scale != 1.0:
		fade_in_duration = 0.0

	var loaded = Repositories.get_info(RepositoryTypes.AMBIENT, resource).track
	if loaded == null:
		CustomLogger.warn(self, stop_ambient_sound, "Could not find an ambient sound with the id: "+str(resource) + "[/bgcolor]",CustomLogger.LEVEL.MILD)
		return
	return ambient_sounds.play(loaded, volume, fade_in_duration, override_bus)


func stop_ambient_sound(resource: Variant, fade_out_duration: float = 0.0) -> void:
	CustomLogger.hint(self, stop_ambient_sound, "[bgcolor=#F00]Looking for ambient sound:  "+str(resource) + "[/bgcolor]",CustomLogger.LEVEL.VERY_VERBOSE)
	var loaded = Repositories.get_info(RepositoryTypes.AMBIENT, resource).track
	if Engine.time_scale != 1.0:
		fade_out_duration = 0.0
	if loaded == null:
		CustomLogger.warn(self, stop_ambient_sound, "Could not find an ambient sound with the id: "+str(resource) + "[/bgcolor]",CustomLogger.LEVEL.MILD)
		return
	CustomLogger.confirm(self, stop_ambient_sound, "[bgcolor=#F00]Stopping ambient sound: "+str(loaded) + "[/bgcolor]",CustomLogger.LEVEL.VERBOSE)
	ambient_sounds.stop(loaded, fade_out_duration)


func stop_all_ambient_sounds(fade_out_duration: float = 0.0) -> void:
	ambient_sounds.stop_all(fade_out_duration)


func set_default_ambient_sound_bus(bus: String) -> void:
	ambient_sounds.bus = bus


#endregion

#region Music

func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(music.bus)))


func set_music_volume(volume_between_0_and_1: float) -> void:
	_show_shared_bus_warning()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(music.bus), linear_to_db(volume_between_0_and_1))


func play_music(resource: Variant, crossfade_duration: float = 0.0,volume: float = 1.0, position: float = 0.0, override_bus: String = "") -> AudioStreamPlayer:
	if Engine.time_scale != 1.0:
		crossfade_duration = 0.0
	var loaded = resource
	if resource is String or resource is StringName:
		loaded = Repositories.get_info(RepositoryTypes.MUSIC, resource)
	if loaded is MusicTrackResource:
		loaded = loaded.track
	if not loaded is AudioStream:
		CustomLogger.warn(self, play_music, "Could not load: " + str(resource),CustomLogger.LEVEL.MILD)
		return
	music_played.emit()
	return music.play(loaded, crossfade_duration, position, linear_to_db(volume), override_bus)

func _on_ovani_music_played() -> void:
	var last_track = get_last_played_music_track()
	var is_playing = true if is_music_track_playing(last_track) else false
	if is_playing:
		for track in get_currently_playing_music():
			pause_music(track)

func get_music_track_history() -> Array:
	return music.track_history


func get_last_played_music_track() -> String:
	if get_music_track_history().is_empty():
		return "nothing"
	return music.track_history[0]


func is_music_playing(resource: Variant = null) -> bool:
	var loaded = resource
	if not resource is AudioStream:
		loaded = Repositories.get_info(RepositoryTypes.MUSIC, resource)
	if loaded == null:
		return false

	return music.is_playing(resource)


func is_music_track_playing(resource_path: String) -> bool:
	return music.is_track_playing(resource_path)


func get_currently_playing_music() -> Array:
	return music.get_currently_playing()


func get_currently_playing_music_tracks() -> Array:
	return music.get_currently_playing_tracks()


func pause_music(resource: AudioStream = null) -> void:
	music.pause(resource)


func resume_music(resource: AudioStream = null) -> void:
	music.resume(resource)


func stop_music(fade_out_duration: float = 0.0) -> void:
	music.stop(fade_out_duration)

func set_default_music_bus(bus: String) -> void:
	music.bus = bus


#endregion

#region OVANI
func play_song(id:String, volume:float) -> void:

	SystemAdministrators.play_song(id)
	await get_tree().create_timer(0.02).timeout
	SystemAdministrators.set_song_intensity(0,0.01 if Engine.time_scale != 1.0 else AnimationTimes.FAST)
	await get_tree().create_timer(0.5).timeout
	SystemAdministrators.set_song_volume(volume,0.01 if Engine.time_scale != 1.0 else AnimationTimes.LONG)

func update_song(volume:float, intensity:float, transition_time:float) -> void:
	transition_time = 0.01 if Engine.time_scale != 1.0 else transition_time
	SystemAdministrators.set_song_intensity(intensity, transition_time)
	await get_tree().create_timer(transition_time * 0.25).timeout
	SystemAdministrators.set_song_volume(volume, transition_time)

func stop_song(transition_time:float) -> void:
	transition_time = 0.01 if Engine.time_scale != 1.0 else transition_time
	mute_active_song(transition_time)

func mute_all_songs() -> void:
	SystemAdministrators.silence_all_songs()

func mute_active_song(transition_time:float) -> void:
	transition_time = 0.01 if Engine.time_scale != 1.0 else transition_time
	SystemAdministrators.mute_active_song(transition_time)

func queue_song(id:String) -> void:
	SystemAdministrators.queue_song(id)
	await get_tree().create_timer(0.02).timeout
	SystemAdministrators.set_song_intensity(0, AnimationTimes.FAST)

#endregion

#region helpers

func stop_all() -> void:
	mute_all_songs()
	stop_music()
	stop_all_ambient_sounds()

func _show_shared_bus_warning() -> void:
	if "Master" in [music.bus, sound_effects.bus, ui_sound_effects.bus, ambient_sounds.bus]:
		push_warning("Using the Master sound bus directly isn't recommended.")
	if music.bus == sound_effects.bus or music.bus == ui_sound_effects.bus:
		push_warning("Both music and sounds are using the same bus: %s" % music.bus)

func _ready() -> void:
	VNSignalBus.listen_for(music_played, VNSignalBus._on_music_played)
	VNSignalBus.ovani_music_played.connect(_on_ovani_music_played)

#endregion
