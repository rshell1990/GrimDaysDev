# Opens party preparation during Navigation once CelineTeen reaches level 3.
extends Button

const CELINE_ID: StringName = &"CelineTeen"
const MINIMUM_LEVEL: int = 3

var _party: BattlePartyManager
var _level: UnitGenericStat


func _ready() -> void:
    hide()
    disabled = true
    button_up.connect(_on_button_up)
    GameManager.state_changed.connect(_refresh_availability.unbind(1))
    if not BattleController.is_node_ready():
        await BattleController.ready
    _party = BattleController.party_manager
    if not is_instance_valid(_party):
        return
    _party.party_changed.connect(_bind_level.unbind(1))
    _party.restored.connect(_bind_level)
    _bind_level()


## Reset/load can replace the runtime unit and its level stat.
func _bind_level() -> void:
    _disconnect_level()
    var celine: BattleUnit = _party.runtime_units.get(CELINE_ID)
    if is_instance_valid(celine):
        _level = celine.get_stat(CombatStats.STATS.Level)
    if is_instance_valid(_level):
        _level.value_changed.connect(_on_level_changed)
    _refresh_availability()


func _on_level_changed(_stat: UnitGenericStat, _old_value: float, _new_value: float) -> void:
    _refresh_availability()


func _refresh_availability() -> void:
    var available := (
        GameManager.state == GameManagerStates.STATES.Navigation
        and is_instance_valid(_level)
        and _level.Current >= MINIMUM_LEVEL
    )
    visible = available
    disabled = not available


func _on_button_up() -> void:
    _refresh_availability()
    if not disabled:
        UIDirector.show_party_preparation()


func _disconnect_level() -> void:
    if is_instance_valid(_level) and _level.value_changed.is_connected(_on_level_changed):
        _level.value_changed.disconnect(_on_level_changed)
    _level = null


func _exit_tree() -> void:
    _disconnect_level()
