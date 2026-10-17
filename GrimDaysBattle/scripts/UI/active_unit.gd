extends Panel
## Shared runtime binding for active and compact ally portraits.
class_name AllyUnitUI

var unit_reference: BattleUnit
var _lucidity: UnitGenericStat
var _level: UnitGenericStat


func setup(unit: BattleUnit) -> void:
    if not is_node_ready():
        await ready
    unbind()
    unit_reference = unit
    for pair in [
        ["Health", CombatStats.STATS.Health], ["Mana", CombatStats.STATS.Mana], ["Energy", CombatStats.STATS.Energy]
    ]:
        var display := get_node("Resource Displays/%s Display" % pair[0]) as BattleResourceDisplay
        display.bind_resource(unit.get_stat(pair[1]) if unit else null)
    if not unit:
        return
    $Background/Portrait.texture = unit.template_resource.portrait
    for label in find_children("*", "Label", true, false):
        if label.name in ["Shadow", "Display Name", "Character's Name"]:
            label.text = unit.template_resource.display_name
    _lucidity = unit.get_stat(CombatStats.STATS.Lucidity)
    $Background/LucidityFill.visible = _lucidity != null
    if _lucidity:
        _lucidity.value_changed.connect(_refresh_lucidity)
        _refresh_lucidity()
    _level = unit.get_stat(CombatStats.STATS.Level)
    if _level:
        _level.value_changed.connect(_refresh_level)
        _refresh_level()


func _refresh_lucidity(_stat: UnitGenericStat = null, _old: float = 0, _new: float = 0) -> void:
    $Background/LucidityFill.value = 100.0 - _lucidity.percentage


func _refresh_level(_stat: UnitGenericStat = null, _old: float = 0, _new: float = 0) -> void:
    for label in find_children("*", "Label", true, false):
        if label.name in ["Level", "Level Label", "Level Shadow"]:
            label.text = str(roundi(_level.Current))


func unbind() -> void:
    if _lucidity and _lucidity.value_changed.is_connected(_refresh_lucidity):
        _lucidity.value_changed.disconnect(_refresh_lucidity)
    if _level and _level.value_changed.is_connected(_refresh_level):
        _level.value_changed.disconnect(_refresh_level)
    _lucidity = null
    _level = null
    unit_reference = null
    for display in find_children("*", "TextureProgressBar", true, false):
        if display is BattleResourceDisplay:
            display.bind_resource(null)


func setup_resource_display(resource: UnitGenericStat, display: TextureProgressBar) -> void:
    display.bind_resource(resource)


func _exit_tree() -> void:
    unbind()
