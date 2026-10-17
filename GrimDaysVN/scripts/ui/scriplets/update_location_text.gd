# Keeps the navigation label synchronized with the current in-game location.
extends Label


func _ready() -> void:
    VNSignalBus.location_changed.connect(_on_location_changed)
    if not SystemHeadquarters.is_node_ready():
        await SystemHeadquarters.ready
    _on_location_changed(SystemAdministrators.current_location())


func _on_location_changed(location: StringName) -> void:
    text = SystemAdministrators.get_location_as_string(location)
