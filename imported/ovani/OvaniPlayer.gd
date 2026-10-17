@tool
@icon("res://GrimDays/imported/ovani/OvaniPlayerIcon.png")
class_name OvaniPlayer
## The OvaniPlayer will let you easily Manage dynamic music in your game, via [OvaniSong]s.
##
## This Node will let you: [br]
## 1. Seamlessly loop the same song via "Reverb tails" [br]
## 2. Seamlessly transition through different "Intensities" & Volumes [br]
## 3. Easily fade or transition between different songs [br]
extends Node

## [OvaniSong]s in this array will play one by one, after each other.
## Add to this directly in code, or use [method OvaniPlayer.play_song_now]
@export var queued_songs : Array[OvaniSong];

## The volume of this player in Decibels
@export_range(-80, 20) var volume : float = 0:
	get:
		return volume;
	set(value):
		for psm in _soundManagers:
			psm.volume = value;
		volume = value;
## The current intensity of the playing OvaniSong
@export_range(0, 1) var intensity : float = 0:
	get:
		return intensity;
	set(value):
		for psm in _soundManagers:
			psm.intensity = value;
		intensity = value;
## Check this to preview how your [OvaniPlayer] and [OvaniSong]s sounds in the editor.
## It will dequeue finished songs!
@export var play_in_editor : bool = false;

## This is the Godot Audio Bus that your music will play through. Can be assigned dynamically.
@export var bus : StringName = "Master":
	get:
		if _audio_player != null && !Engine.is_editor_hint():
			return _audio_player.bus;
		else:
			return bus;
	set(value):
		bus = value;
		if _audio_player != null:
			_audio_player.bus = value;

## Audio player used to play this dynamic song's combined audio stream.
var _audio_player : AudioStreamPlayer:
	get:
		return _audio_player;
	set(value):
		value.bus = bus;
		_audio_player = value

## Checking this will make the Queue send finished songs to the end of the queue,
## to infinitely loop music.
@export var loop_queue : bool


## Use play_song_now to Replace the current OvaniSong with a new one.[br]
## Use transition_time to govern how fast it fades to the next song.[br]
## Setting transition_time to -1 will use the current songs reverbTail to fade.
func play_song_now(song : OvaniSong, _transition_time : float = -1):
	if (len(QueuedSongs) > 0):
		QueuedSongs.clear();

	QueuedSongs.append(song);

## Adds the supplied song to this player's playback queue.
func queue_song(song : OvaniSong):
	QueuedSongs.append(song);

## Playback object that can play and mix several audio layers at once.
var _audio_stream_playback : AudioStreamPlaybackPolyphonic;
## List of sound managers used by this script.
var _sound_managers : Array[PolySoundManager]:
	get:
		return _sound_managers;

## [enum OvaniPlayer.NextState] is used internally by the [OvaniPlayer], don't mind it.
enum NextState {
	NONE = 0,
	STARTED_LOOP = 1,
	STARTED_DIFFERENT = 2
}
class PolySoundManager:
	var my_stream : AudioStreamPlaybackPolyphonic;
	var ids : Array[int];
	var volume : float:
		get:
			return volume;
		set(value):
			var real_intensity : float;
			if (len(ids) == 3):
				real_intensity = intensity;
			else:
				real_intensity = 0;
			for i in range(len(ids)):
				# set volume based on intensity
				# if only 1 audio id it'll just be full
				var weight : float = max((.5 - abs((i as float)/2 - real_intensity))/.5, 0);
				my_stream.set_stream_volume(ids[i], linear_to_db(db_to_linear(value) * weight));
			volume = value;
	var intensity : float:
		get:
			return intensity;
		set(value):
			intensity = value;
			volume = volume;
	var start_time : float;
	var song_length : float;
	var reverb_tail : float;
	var fade_in : float = -1;
	var fade_out : float = -1;
	var started_next_state : NextState = NextState.None;

## Starts the available intensity layers of a song and returns an object tracking their playback IDs
## and song length.
func _construct_poly_sound_manager(song : OvaniSong) -> PolySoundManager:
	var o : PolySoundManager = PolySoundManager.new();
	o.MyStream = _audio_stream_playback;

	if (song != null):
		if (song.SongMode == OvaniSong.OvaniMode.Intensities):
			o.ids.append(_audio_stream_playback.play_stream(song.Intensity1));
			o.ids.append(_audio_stream_playback.play_stream(song.Intensity2));
			o.ids.append(_audio_stream_playback.play_stream(song.Intensity3));
			o.intensity = Intensity;
			o.song_length = song.Intensity1.get_length();
		elif (song.SongMode == OvaniSong.OvaniMode.Loop30):
			o.ids.append(_audio_stream_playback.play_stream(song.Loop30));
			o.intensity = 0;
			o.song_length = song.Loop30.get_length();
		else:
			o.ids.append(_audio_stream_playback.play_stream(song.Loop60));
			o.intensity = 0;
			o.song_length = song.Loop60.get_length();
		o.reverb_tail = song.ReverbTail;

	o.volume = volume;
	o.StartTime = _cur_time;
	return o;


## When the node is ready, this function creates the internal [code]_audio_player[/code] with an
## [AudioStreamPolyphonic] stream and adds it as an internal child. Playback starts lazily when a
## song is queued and stops again once the player is idle.
func _ready():
	_audio_player = AudioStreamPlayer.new();
	_audio_player.stream = AudioStreamPolyphonic.new();
	add_child(_audio_player, INTERNAL_MODE_BACK);
	_audio_player.owner = null;


## Starts the polyphonic stream only when a song needs it; idle players own no server playback.
func _ensure_playback():
	if _audio_stream_playback != null && _audio_player.playing:
		return;
	_audio_player.play();
	_audio_stream_playback = _audio_player.get_stream_playback();


## Stops the polyphonic stream and drops every reference to its server playback.
func _release_playback():
	_soundManagers.clear()
	_audio_stream_playback = null
	if is_instance_valid(_audio_player):
		_audio_player.stop()


func _exit_tree() -> void:
	_release_playback()


## Intensity value at the beginning of the current intensity fade.
var _start_int_fade_val : float = 0;
## Target intensity value at the end of the current intensity fade.
var _end_int_fade_val : float = 1;
## Player-clock time when the current intensity fade started.
var _time_int_fade_started : float = 0;
## Player-clock time when the current intensity fade should finish.
var _time_int_fade_ended : float = 1;
## Use this to transition the current Intensity over time. [br]
## It's a simple alternative to setting the Intensity manually yourself each frame.
func fade_intensity(intensity : float, transition_time : float):
	_time_int_fade_started = _cur_time
	_time_int_fade_ended  = _cur_time + transition_time;
	_start_int_fade_val = Intensity;
	_end_int_fade_val = intensity;

## Volume value at the beginning of the current volume fade.
var _start_vol_fade_val : float = 0;
## Target volume value at the end of the current volume fade.
var _end_vol_fade_val : float = 1;
## Player-clock time when the current volume fade started.
var _time_vol_fade_started : float = 0;
## Player-clock time when the current volume fade should finish.
var _time_vol_fade_ended : float = 1;
## Use this to transition the current Decibel Volume over time. [br]
## It's a simple alternative to setting the Volume manually yourself each frame.
func fade_volume(volume : float, transition_time : float):
	_time_vol_fade_started = _cur_time
	_time_vol_fade_ended  = _cur_time + transition_time;
	_start_vol_fade_val = Volume;
	_end_vol_fade_val = volume;

## Elapsed time tracked by this audio player for fades and playback updates.
var _cur_time : float = 500;
## On each drawn frame, this function adds [code]_constructPolySoundManager(QueuedSongs[0])[/code]
## to [code]_soundManagers[/code]; adds [code]_constructPolySoundManager(nextSong)[/code] to
## [code]_soundManagers[/code]; removes [code]psm[/code] from [code]_soundManagers[/code]. It also
## sets [code]psm.started_next_state[/code] to [code]NextState.StartedLoop;[/code].
func _process(delta):
	if (Engine.is_editor_hint() && !PlayInEditor):
		for psm in _soundManagers:
			if (psm.started_next_state != NextState.StartedLoop):
				psm.StartTime = (_cur_time - psm.SongLength) + 1;
				psm.fade_out = 1;
				psm.started_next_state = NextState.StartedLoop;

	_cur_time += delta / Engine.time_scale;

	# Intensity Fade Logic
	if (_timeIntFadeStarted < _cur_time && _timeIntFadeEnded > _cur_time):
		Intensity = lerp(_startIntFadeVal, _endIntFadeVal,
			(_cur_time - _timeIntFadeStarted)/(_timeIntFadeEnded - _timeIntFadeStarted))
	# Volume Fade Logic
	if (_timeVolFadeStarted < _cur_time && _time_vol_fade_ended > _cur_time):
		Volume = lerp(_startVolFadeVal, _end_vol_fade_val,
			(_cur_time - _timeVolFadeStarted)/(_time_vol_fade_ended - _timeVolFadeStarted))

	# Play queued songs logic
	if (len(QueuedSongs) > 0):
		if (len(_soundManagers) == 0 && (!Engine.is_editor_hint() || PlayInEditor)):
			_ensure_playback();
			_soundManagers.append(_constructPolySoundManager(QueuedSongs[0]));
		for psm in _soundManagers:
			# handle fade in
			var time_played : float = _cur_time - psm.StartTime;
			if (psm.FadeIn != -1 && time_played < psm.FadeIn):
				psm.Volume = linear_to_db((time_played / psm.FadeIn) * db_to_linear(Volume));

			# handle fade out
			var remaining_time : float = -(_cur_time - (psm.StartTime + psm.SongLength));
			if (psm.fade_out != -1 && remaining_time < psm.fade_out):
				psm.Volume = linear_to_db((remaining_time / psm.fade_out) * db_to_linear(Volume));

			if (remaining_time < psm.reverb_tail):
				if (psm.started_next_state == NextState.None):

					if (!Engine.is_editor_hint() || PlayInEditor):
						var next_song : OvaniSong;
						if (len(QueuedSongs) == 1):
							next_song = QueuedSongs[0];
							psm.started_next_state = NextState.StartedLoop;
						else:
							next_song = QueuedSongs[1];
							psm.started_next_state = NextState.StartedDifferent;
						_soundManagers.append(_constructPolySoundManager(next_song));
				if (remaining_time < 0):
					_soundManagers.erase(psm);
					for id in psm.Ids:
						psm.MyStream.stop_stream(id);
					if (psm.started_next_state == NextState.StartedDifferent):
						var leaving_song : OvaniSong = QueuedSongs.pop_front()
						if LoopQueue:
							QueuedSongs.append(leaving_song);
						notify_property_list_changed();

		return
	if (len(_soundManagers) == 0 && _audio_stream_playback != null):
		_release_playback();
