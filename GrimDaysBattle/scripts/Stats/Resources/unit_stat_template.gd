# Editor configuration for UnitStatTemplate.
@tool
extends ResourceTemplate
## Coordinates unit stat template behavior for the battle system.
class_name UnitStatTemplate

## Configures the type used by this unit stat template.
@export var type: CombatStats.STATS = CombatStats.STATS.Empty:
    set(value):
        type = value
        notify_property_list_changed()
## Configures the starting amount used by this unit stat template.
@export var starting_amount: float


## Initializes a new unit stat template with the supplied values.
func _init() -> void:
    if id.is_empty():
        setup_id.call_deferred()


## Validates property for this unit stat template.
func _validate_property(property: Dictionary) -> void:
    if property.name == "type":
        setup_id()


## Initializes id for this unit stat template.
func setup_id() -> void:
    id = CombatStats.get_stat_as_string(type)
