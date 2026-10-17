## Checks story location labels and aliases without modifying player saves or navigation resources.
extends Node


func _ready() -> void:
    _run.call_deferred()


func _run() -> void:
    var repository: NavigationLocationsRepository = Repositories.get_repository(RepositoryTypes.LOCATIONS)
    var original: Dictionary = repository.master.duplicate()
    repository.master.clear()
    var expected_legacy: Array[StringName] = [
        &"NovarasChildhoodHomeLivingRoom", &"NovarasOrphanageCellar", &"NovarasOrphanageOffice",
    ]
    assert(NavigationAdministrator.LOCATIONS == expected_legacy, "Keep only referenced legacy location IDs.")
    var map_interaction := MapInteractable.new()
    assert(map_interaction.leads_to == SystemAdministrators.current_location())
    map_interaction.free()
    for id: StringName in SystemAdministratorsBase.STORY_LOCATION_NAMES:
        var display_name: String = SystemAdministratorsBase.STORY_LOCATION_NAMES[id]
        assert(SystemAdministrators.get_location_as_string(id) == display_name)
        assert(SystemAdministrators.get_location_from_alias(String(id)) == id)
        assert(SystemAdministrators.get_location_from_alias("  " + display_name.to_lower() + "  ") == id)
    for id: StringName in NavigationAdministrator.LOCATIONS:
        assert(SystemAdministrators.get_location_as_string(id) == String(id).capitalize())
        assert(SystemAdministrators.get_location_from_alias(String(id)) == id)
    var authored := NavigationLocation.new()
    authored.id = &"Gerano"
    authored.display_name = "Gerano Castle"
    repository.master[authored.id] = authored
    assert(SystemAdministrators.get_location_as_string(&"Gerano") == "Gerano Castle")
    assert(SystemAdministrators.get_location_from_alias(" gerano castle ") == &"Gerano")
    assert(SystemAdministrators.get_location_as_string(&"MissingLocation") == "Unknown location")
    assert(SystemAdministrators.get_location_from_alias("MissingLocation").is_empty())
    assert(SystemAdministrators.get_location_from_alias("").is_empty())
    var old_location := SystemAdministrators.current_location()
    SystemAdministrators.navigation_admin.get_location(["name:MissingLocation"])
    assert(SystemAdministrators.current_location() == old_location)
    repository.master.clear()
    repository.master.merge(original)
    print("STORY_LOCATION_NAMES_SMOKE_TEST: PASS") # lint:ignore debug-print -- Required test/CLI output.
    get_tree().quit()
