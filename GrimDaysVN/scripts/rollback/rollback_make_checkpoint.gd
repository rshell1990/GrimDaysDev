extends Node
## Older helper that writes a numbered rollback save slot directly.
class_name MakeCheckpointOperation


## Creates or replaces a numbered rollback slot and writes dialogue and persistent game state. This
## older direct-write helper does not check the centralized battle save guard.
static func execute() -> void:
    SystemHelpers.set_prefix_if_empty()
    var extra_info := {}
    extra_info["lines_read"] = Dialogic.VAR.lines_read
    var slot_name_to_format = "{prefix}___rollback-save___{number}"
    var slot_name = slot_name_to_format.format(
        {
            "prefix": Dialogic.VAR.prefix,
            "number": Dialogic.VAR.lines_read % SystemLimits.CHECKPOINTS
        }
    )

    if Dialogic.Save.has_slot(slot_name):
        Dialogic.Save.delete_slot(slot_name)

    Dialogic.Save.add_empty_slot(slot_name)
    Dialogic.Save.save(slot_name, false, Dialogic.Save.ThumbnailMode.NONE, extra_info)
    Dialogic.Save.save_file(
        slot_name, "game_info", await SaveAndLoadSystemManager.get_persistent_data()
    )
