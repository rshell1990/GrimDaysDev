extends Node


## Applies each audio bus’s own volume preference and mutes that bus below the minimum level.
func _ready() -> void:
    AudioServer.set_bus_volume_db(
        SM_Globals.master_bus_id, linear_to_db(SM_Globals.user_prefs.master_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.master_bus_id, SM_Globals.user_prefs.master_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.dynamic_bus_id, linear_to_db(SM_Globals.user_prefs.dynamic_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.dynamic_bus_id, SM_Globals.user_prefs.dynamic_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.music_bus_id, linear_to_db(SM_Globals.user_prefs.music_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.music_bus_id, SM_Globals.user_prefs.music_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.sfx_bus_id, linear_to_db(SM_Globals.user_prefs.sfx_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.sfx_bus_id, SM_Globals.user_prefs.sfx_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.ambient_bus_id, linear_to_db(SM_Globals.user_prefs.ambient_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.ambient_bus_id, SM_Globals.user_prefs.ambient_volume < .05)
