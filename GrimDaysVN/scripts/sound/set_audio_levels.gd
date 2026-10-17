extends Node


## Applies each audio bus’s own volume preference and mutes that bus below the minimum level.
func _ready() -> void:
    AudioServer.set_bus_volume_db(
        SM_Globals.MASTER_BUS_ID, linear_to_db(SM_Globals.user_prefs.master_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.MASTER_BUS_ID, SM_Globals.user_prefs.master_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.DYNAMIC_BUS_ID, linear_to_db(SM_Globals.user_prefs.dynamic_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.DYNAMIC_BUS_ID, SM_Globals.user_prefs.dynamic_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.MUSIC_BUS_ID, linear_to_db(SM_Globals.user_prefs.music_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.MUSIC_BUS_ID, SM_Globals.user_prefs.music_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.SFX_BUS_ID, linear_to_db(SM_Globals.user_prefs.sfx_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.SFX_BUS_ID, SM_Globals.user_prefs.sfx_volume < .05)

    AudioServer.set_bus_volume_db(
        SM_Globals.AMBIENT_BUS_ID, linear_to_db(SM_Globals.user_prefs.ambient_volume)
    )
    AudioServer.set_bus_mute(SM_Globals.AMBIENT_BUS_ID, SM_Globals.user_prefs.ambient_volume < .05)
