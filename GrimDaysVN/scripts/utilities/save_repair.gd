extends Node
class_name SaveRepairOperation

## Lookup table for data to repair; keys select the corresponding stored values.
var data_to_repair: Dictionary


## During creation, this function sets [code]data_to_repair[/code] to [code]data[/code].
func _init(data: Dictionary) -> void:
    data_to_repair = data


#TODO: Expand with functionality to repair save data.
## Returns a shallow copy of the supplied save dictionary. This implementation does not apply repair
## operations to it.
func repair() -> Dictionary:
    var repaired_data: Dictionary = data_to_repair.duplicate(true)

    return repaired_data


## Repairs a missing phone in the inventory.
func repair_test_data(data: Dictionary) -> Dictionary:
    if data["info"]["game_manager"]["current_event"] == "test_2_over":
        data["info"]["game_manager"]["current_event"] = ""

    return data


## Repairs a missing phone in the inventory.
func repair_missing_phone(data: Dictionary) -> Dictionary:
    if "main_4_pickup_phone" in data["info"]["game_manager"]["seen_events"]:
        if not data["info"]["player"]["inventory"].has(1000):
            data["info"]["player"]["inventory"][1000] = 1

    return data


## Repairs incorrect time from picking up the phone originally.
func repair_time(data: Dictionary) -> Dictionary:
    if not "main_9_lancers_class_starts" in data["info"]["game_manager"]["seen_events"]:
        if not data["info"]["in_game_time"]["time_id"] == 0:
            data["info"]["in_game_time"]["time_id"] = 0

    return data


## Repair's being blocked from the Gymnasium after incorrectly being allowed to leave during the event in the lockers.
func repair_stuck(data: Dictionary) -> Dictionary:
    if (
        "main_11_sam_screams" in data["info"]["game_manager"]["seen_events"]
        and not "main_11_decide_what_to_do" in data["info"]["game_manager"]["seen_events"]
    ):
        data["info"]["navigation"]["location"] = &"PrimeCasperHighGymnasium"

    return data


## Repair's being blocked from the Gymnasium after incorrectly being allowed to leave during the event in the lockers.
func repair_camera(data: Dictionary) -> Dictionary:
    if not data["info"]["camera"].has("camera_pos"):
        return data
    var camera_position: Transform3D = data["info"]["camera"]["camera_pos"]
    if camera_position.origin.z > 1400:
        camera_position.origin.z = 4.71
        data["info"]["camera"]["camera_pos"] = camera_position

    return data
