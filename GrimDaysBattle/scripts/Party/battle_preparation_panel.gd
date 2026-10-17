extends Control
## Controller for the authored party_management scene. Party services own mutations;
## the preparation session owns pause, story continuation and save exclusion.
class_name BattlePreparationPanel

## Requests that the owning preparation session close this panel.
signal close_requested

## Roster-card scene instantiated for each available unit.
const MEMBER_SCENE := preload("res://GrimDaysBattle/scenes/ui/party_member_card.tscn")
## Scene path of the character identity and progression display.
const CHARACTER := "VBoxContainer/HBoxContainer/Character and Skill Panels/Character Panel/Character Management"
## Scene path of the equipment, resource-pool and stat controls.
const EQUIPMENT := CHARACTER + "/Equpment and Stats"
## Scene path of the attribute rows used to build progression draft controls.
const ATTRIBUTE_ROWS := EQUIPMENT + "/Attribute and Combat Stats Tab/Attributes/Attributes"
## Maps authored combat-stat row names to their runtime stats.
const STAT_ROWS := {
    "Health": CombatStats.STATS.Health,
    "Energy": CombatStats.STATS.Energy,
    "Mana": CombatStats.STATS.Mana,
    "Lucidity": CombatStats.STATS.Lucidity,
    "Physical Damage": CombatStats.STATS.PhysicalDamage,
    "Magical Damage": CombatStats.STATS.MagicDamage,
    "Physical Armor": CombatStats.STATS.PhysicalResistance,
    "Magic Armor": CombatStats.STATS.MagicResistance,
    "Swiftness": CombatStats.STATS.Swiftness,
    "Weight Limit": CombatStats.STATS.WeightLimit,
    "Accuracy": CombatStats.STATS.Accuracy,
    "Evasion": CombatStats.STATS.Evasion,
    "Lucky Evasion": CombatStats.STATS.LuckyEvasion,
    "Critical Chance": CombatStats.STATS.CriticalStrike,
    "Encumberance": CombatStats.STATS.Encumberance,
    "Damage Modifier": CombatStats.STATS.DamageModifier,
}

## Party service supplying roster data and authorizing mutations.
var party: BattlePartyManager
## Stable template ID of the selected roster member.
var unit_id: StringName
## Invalidates roster callbacks after rebuilding the cards.
var _generation: int = 0
## Exact lease owner required for project-skill purchases.
var _preparation_owner: Node
## Authored skill panel owns its controls and unit-wide pending investment.
@onready var _project_skills: BattleSkillPreparationView = %"Skill Panel"
var _skill_status: String = ""
## Invalidates attribute controls after selection or refresh changes.
var _attribute_generation: int = 0
## Progression revision against which the current attribute draft was staged.
var _attribute_revision: int = -1
## Uncommitted attribute increments for the selected unit.
var _attribute_draft: Dictionary = {}
## Unit whose progression signal is currently connected.
var _attribute_unit: BattleUnit
## Displays the latest preparation operation result.
@onready var status: Label = %Status
## Container holding selectable and reorderable party-member cards.
@onready var roster: VBoxContainer =  $"VBoxContainer/HBoxContainer/Character Pool and Options/%Roster"
## Child view managing shared/personal inventory and equipment commands.
@onready var inventory_view: BattlePreparationInventory = %Inventories


## Connects close, tab and inventory buttons, then gives keyboard focus to Close.
func _ready() -> void:
    $Close.pressed.connect(func(): close_requested.emit())
    $"VBoxContainer/HBoxContainer/Character Pool and Options/Button".pressed.connect(_show_talents.bind(false))
    $"VBoxContainer/HBoxContainer/Character Pool and Options/Button2".pressed.connect(_show_talents.bind(true))
    inventory_view.operation_finished.connect(_on_operation)
    _project_skills.state_changed.connect(_refresh_character)
    _project_skills.status_changed.connect(_on_skill_status)
    $Close.grab_focus()


## Connects to the supplied party, selects its first available member and builds the roster.
func present(manager: BattlePartyManager, preparation_owner: Node = null) -> void:
    party = manager
    _preparation_owner = preparation_owner
    var units := party.get_available_units()
    if not units.is_empty():
        _select_unit(units[0].template_resource.id)
    else:
        unit_id = &""
        _project_skills.dismiss()
        _project_skills.hide()
        $"Character Panel".hide()
        status.text = "No allies available."
    _refresh_roster()


## Disconnects listeners, discards unconfirmed attribute choices and disables the panel and
## inventory view.
func dismiss() -> void:
    if is_instance_valid(_project_skills):
        _project_skills.dismiss()
    _preparation_owner = null
    _generation += 1
    _disconnect_attribute_unit()
    _attribute_generation += 1
    _attribute_draft.clear()
    party = null
    inventory_view.dismiss()
    hide()
    process_mode = Node.PROCESS_MODE_DISABLED


## Switches between character details and skill trees.
func _show_talents(enabled: bool) -> void:
    %"Character Panel".visible = not enabled and not unit_id.is_empty()
    _project_skills.visible = enabled and not unit_id.is_empty()
    if enabled:
        status.text = _skill_status
        %"Status Holder".modulate.a = 1.0
    else:
        %"Status Holder".modulate.a = 0.0

## Selects a valid party member, discards the previous attribute draft and refreshes that member’s
## details, skills and inventory.
func _select_unit(id: StringName) -> void:
    if not is_instance_valid(party) or not party.runtime_units.has(id):
        return
    _disconnect_attribute_unit()
    _attribute_generation += 1
    _attribute_revision = -1
    _attribute_draft.clear()
    unit_id = id
    _attribute_unit = party.runtime_units[id]
    _attribute_unit.attribute_points_changed.connect(_on_attribute_points_changed)
    inventory_view.present(party, unit_id)
    _refresh_character()
    _refresh_skills()
    _refresh_roster()


## Lists active members first, followed by reserves. Adds selection, active-party and
## formation-order controls; rejects old button callbacks.
func _refresh_roster() -> void:
    _generation += 1
    var generation := _generation
    _clear(roster)
    # Active members follow encounter order; reserves remain available below them.
    var units: Array[BattleUnit] = []
    for id in party.active_party_ids:
        units.append(party.runtime_units[id])
    for unit in party.get_available_units():
        if unit not in units:
            units.append(unit)
    for unit in units:
        var id: StringName = unit.template_resource.id
        var card := MEMBER_SCENE.instantiate() as Control
        roster.add_child(card)
        card.get_node("Name").text = unit.template_resource.display_name
        card.get_node("Background Texture/Portrait Texture").texture = unit.template_resource.portrait
        card.get_node("Level Frame/Level Label").text = str(int(unit.level))
        card.get_node("Select").tooltip_text = "View " + unit.template_resource.display_name
        card.get_node("Select").pressed.connect(
            func():
                if generation == _generation and is_instance_valid(party):
                    _select_unit(id)
        )
        card.modulate = Color.WHITE if id == unit_id else Color(0.8, 0.8, 0.8)
        card.get_node("Notification Frame").visible = id == unit_id
        var active := card.get_node("Accent Graphic/Active") as CheckBox
        active.set_pressed_no_signal(id in party.active_party_ids)
        active.toggled.connect(
            func(selected: bool):
                if generation != _generation or not is_instance_valid(party):
                    return
                var ids := party.active_party_ids.duplicate()
                if selected:
                    ids.append(id)
                else:
                    ids.erase(id)
                var accepted: bool = not ids.is_empty() and party.set_active_party(ids)
                status.text = "Active party updated." if accepted else "Keep one to four party members selected."
                _refresh_roster()
        )
        var index := party.active_party_ids.find(id)
        for direction in [-1, 1]:
            var button := card.get_node("Accent Graphic/Up" if direction < 0 else "Accent Graphic/Down") as Button
            button.disabled = index < 0 or index + direction < 0 or index + direction >= party.active_party_ids.size()
            button.pressed.connect(
                func():
                    if generation != _generation or not is_instance_valid(party):
                        return
                    var ids := party.active_party_ids.duplicate()
                    if index < 0 or index + direction < 0 or index + direction >= ids.size():
                        return
                    ids[index] = ids[index + direction]
                    ids[index + direction] = id
                    party.set_active_party(ids)
                    _refresh_roster()
            )


## Updates the selected member’s name, level, XP, attributes, combat values and available resource
## bars.
func _refresh_character() -> void:
    var unit: BattleUnit = party.runtime_units.get(unit_id)
    if not unit:
        return
    get_node(CHARACTER + "/Character Name/Character Name").text = unit.template_resource.display_name
    var progress_path := (
        CHARACTER
        + "/Equpment and Stats/Attribute and Combat Stats Tab/Attributes/Attributes"
        + "/Level Info/Level Progress/MarginContainer/Level Progress Labels"
    )
    var progress := get_node(progress_path)
    progress.get_node("Number").text = "%s   •   XP:" % int(unit.level)
    progress.get_node("Current Amount").text = str(int(unit.get_stat(CombatStats.STATS.Experience).Current))
    # Level is curve-derived; there is no authored 'XP needed' API to display.
    progress.get_node("Divider").hide()
    progress.get_node("Amount Needed").hide()
    _refresh_attribute_controls()
    var combat := get_node(EQUIPMENT + "/Attribute and Combat Stats Tab/Combat Stats/ScrollContainer/Combat Stats")
    for row_name in STAT_ROWS:
        var row := combat.get_node(NodePath(row_name))
        var stat := unit.get_stat(STAT_ROWS[row_name])
        row.visible = stat != null
        if stat:
            var old_text = row.get_child(1).text
            if row_name == "Damage Modifier":
                row.get_child(1).text = str(int(snappedf(stat.Current * 100, 1.0))) + "%"
            elif "%" in old_text:
                row.get_child(1).text = str(int(snappedf(stat.Current, 1.0))) + "%"
            else:
                row.get_child(1).text = str(int(snappedf(stat.Current, 1.0)))
    combat.get_node("Speed/Speed Amount Label").text = str(int(snappedf(unit.speed, 1.0)))
    for pool in ["Health", "Mana", "Energy"]:
        var stat := unit.get_stat(CombatStats.STATS[pool])
        var display := (
            get_node(EQUIPMENT + "/Character Silouhette/Resource Displays/" + pool + " Display") as TextureProgressBar
        )
        display.visible = stat != null
        if stat:
            display.max_value = maxf(stat.Max, 1.0)
            display.value = stat.Current
            var labels := display.get_node("MarginContainer/HBoxContainer")
            labels.get_child(1).text = str(int(stat.Current))
            labels.get_child(3).text = str(int(stat.Max))


## Rebinds the authored panel without removing its scene-owned controls.
func _refresh_skills() -> void:
    var unit: BattleUnit = party.runtime_units.get(unit_id)
    _project_skills.present(party, unit, _preparation_owner)


## Keeps skill point totals and operation feedback in the existing party status area.
func _on_skill_status(message: String) -> void:
    _skill_status = message
    if _project_skills.visible:
        status.text = message


## Shows whether an inventory change succeeded and refreshes the character’s values.
func _on_operation(success: bool) -> void:
    status.text = (
        "Inventory updated." if success else "Cannot complete this change: check available space and equipment slots."
    )
    _refresh_character()


## Removes a container’s children immediately and schedules them for deletion.
static func _clear(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()


## Disconnects the previous member’s attribute-change listener.
func _disconnect_attribute_unit() -> void:
    if (
        is_instance_valid(_attribute_unit)
        and _attribute_unit.attribute_points_changed.is_connected(_on_attribute_points_changed)
    ):
        _attribute_unit.attribute_points_changed.disconnect(_on_attribute_points_changed)
    _attribute_unit = null


## Refreshes character values, inventory and roster after point availability changes.
func _on_attribute_points_changed() -> void:
    if is_instance_valid(party):
        _refresh_character()
        inventory_view.refresh()
        _refresh_roster()


## Spinboxes stage additional points. Decreasing can undo only this draft;
## committed attributes, gear bonuses and automatic growth are never refunded.
func _refresh_attribute_controls() -> void:
    var snapshot := party.get_attribute_points(unit_id)
    if snapshot.is_empty():
        return
    if _attribute_revision != snapshot.revision:
        _attribute_draft.clear()
    _attribute_revision = snapshot.revision
    _attribute_generation += 1
    var generation := _attribute_generation
    var selected_id := unit_id
    var revision := _attribute_revision
    var remaining: Dictionary = snapshot.available.duplicate()
    for stat_id: int in _attribute_draft:
        remaining[BattleAttributeProgression.pool_for(stat_id)] -= _attribute_draft[stat_id]
    var unit: BattleUnit = party.runtime_units[unit_id]
    var rows := get_node(ATTRIBUTE_ROWS)
    for row in rows.get_children():
        var stat_id: int = CombatStats.STATS.get(String(row.name), CombatStats.STATS.Empty)
        var pool := BattleAttributeProgression.pool_for(stat_id)
        if pool.is_empty():
            continue
        var stat := unit.get_stat(stat_id)
        row.visible = stat != null
        if not stat:
            continue
        var spin := row.get_node(String(row.name) + " SpinBox") as SpinBox
        for connection in spin.value_changed.get_connections():
            spin.value_changed.disconnect(connection.callable)
        var baseline := roundf(stat.Current)
        var pending: int = _attribute_draft.get(stat_id, 0)
        spin.min_value = baseline
        spin.max_value = baseline + pending + maxi(remaining[pool], 0)
        spin.set_value_no_signal(baseline + pending)
        spin.editable = party.can_prepare_inventory() and (pending > 0 or remaining[pool] > 0)
        spin.tooltip_text = (
            "Spend %s points. Apply commits; changing allies or closing discards unconfirmed points."
            % pool.replace("_", "-")
        )
        spin.value_changed.connect(
            func(value: float):
                if generation != _attribute_generation or not is_instance_valid(party) or selected_id != unit_id:
                    return
                var amount := int(round(value - baseline))
                if amount > 0:
                    _attribute_draft[stat_id] = amount
                else:
                    _attribute_draft.erase(stat_id)
                _refresh_attribute_controls()
        )
    rows.get_node("Luck2/Luck Label3").text = str(remaining.combat)
    rows.get_node("NonCombatPoints/Luck Label3").text = str(remaining.non_combat)
    var apply := rows.get_node("Spacer2/MarginContainer/Button") as Button
    apply.disabled = _attribute_draft.is_empty() or not party.can_prepare_inventory()
    for connection in apply.pressed.get_connections():
        apply.pressed.disconnect(connection.callable)
    apply.pressed.connect(
        func():
            if generation != _attribute_generation or not is_instance_valid(party) or selected_id != unit_id:
                return
            var accepted := party.spend_attribute_points(selected_id, _attribute_draft.duplicate(), revision)
            _attribute_draft.clear()
            _refresh_character()
            status.text = (
                "Attribute points applied."
                if accepted
                else "Attributes changed; review the available points and try again."
            )
    )
