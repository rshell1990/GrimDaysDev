extends "./abstract_audio_player_pool.gd"


func play(resource: AudioStream, volume:float, fade_in_duration: float, override_bus: String = "") -> AudioStreamPlayer:
	var player = get_busy_player_with_resource(resource)

	# If it's already playing then don't play it again
	if is_instance_valid(player): return player

	player = prepare(resource, override_bus)
	fade_volume(player, -80.0, linear_to_db(volume), fade_in_duration)
	player.call_deferred("play")
	return player


func stop(resource: AudioStream, fade_out_duration: float = 0.0) -> void:
	CustomLogger.hint(self,stop,"Starting to process the stop command for: " + str(resource), CustomLogger.LEVEL.VERY_VERBOSE)
	if fade_out_duration <= 0.0:
			fade_out_duration = 0.01
	var path = resource.resource_path
	if busy_players.has(path):
		fade_volume(busy_players[path], busy_players[path].volume_db, -80, fade_out_duration)


func stop_all(fade_out_duration: float = 0.0) -> void:
	if fade_out_duration <= 0.0:
			fade_out_duration = 0.01

	for player in busy_players.values():
		fade_volume(player, player.volume_db, -80, fade_out_duration)
