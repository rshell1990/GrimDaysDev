extends Control
## Scene template used to create character template.
@export var character_template: PackedScene
## Scene object used for portrait container.
@export var portrait_container: Panel
## Notification for restored.
signal restored
## Whether side showing is currently enabled or true.
var side_showing: bool
## ID of the character currently shown by this display.
var current_id: String
## Character object controlled or observed by this helper.
var character: PortraitOperator
## The designated identifier for saving the layer data upon making a checkpoint / hard save.
var save_name: String = "side_portrait"
## Lookup table for state; keys select the corresponding stored values.
var state: Dictionary


## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)


## When the node is ready, this function connects responses to
## [code]VNSignalBus.on_side_character_set[/code], [code]VNSignalBus.on_load[/code],
## [code]Dialogic.Text.textbox_visibility_changed[/code],
## [code]Dialogic.Inputs.dialogic_action[/code]; sets [code]side_showing[/code] to false.
func _ready():
    visible = false
    side_showing = false
    VNSignalBus.on_side_character_set.connect(_on_side_character_set)
    VNSignalBus.on_load.connect(_on_load)
    Dialogic.Text.textbox_visibility_changed.connect(_hide)
    Dialogic.Inputs.dialogic_action.connect(_set_flag_to_false)


## Toggles the side portrait along with the hide-textbox action, but only when a side portrait is
## currently in use.
func _input(_event):
    if Input.is_action_just_released("hide_textbox"):
        if Dialogic.Text.is_textbox_visible() and side_showing:
            visible = false
        elif not Dialogic.Text.is_textbox_visible() and side_showing:
            visible = true


## Deletes [code]character[/code] immediately; moves [code]incoming_character[/code] under
## [code]portrait_container[/code]; adds [code]incoming_character[/code] as a child of
## [code]portrait_container[/code]. It also sets [code]incoming_character.owner[/code] to null.
func _on_side_character_set(incoming_character: SpineSprite) -> void:
    if character != null:
        character.free()

    incoming_character.scale = Vector2(0.45, 0.45)
    incoming_character.position = OffScreenPositions.locations(incoming_character.id)
    incoming_character.owner = null

    if incoming_character.get_parent() != null:
        incoming_character.reparent(portrait_container)
    else:
        portrait_container.add_child(incoming_character)

    incoming_character.owner = portrait_container

    character = incoming_character

    visible = true
    current_id = character.id
    side_showing = true


## Schedules [code]character.sprite[/code] for deletion. It pauses for
## [code]character.sprite.tree_exited[/code] before continuing.
func _hide(textbox_showing) -> void:
    ##SystemHelpers.print("Hide?", textbox_showing)
    if not textbox_showing:
        visible = false
    elif not textbox_showing and not side_showing:
        visible = false
        character.sprite.queue_free()
        await character.sprite.tree_exited
    elif textbox_showing and side_showing:
        visible = true


## Clears the flag that records whether the side portrait is being shown.
func _set_flag_to_false():
    side_showing = false


## Returns the current state of the character layers known, upon starting the save process.
func _get_state() -> Dictionary:
    var current_state: Dictionary = {}

    current_state["visible"] = visible
    current_state["side_showing"] = side_showing
    current_state["current_id"] = current_id
    if character != null:
        current_state["character_info"] = character.get_character_info()
    else:
        current_state["character_info"] = {}

    return current_state


## Clears the character layers and then restores the characters that were in
## the scene at the time the save was created.
func _on_load(data: Dictionary) -> void:
    CustomLogger.error(
        self,
        self._on_load,
        " has been triggered, this is the deprecated way to load a side character.",
        4
    )
    if character == null or not data.info.has(save_name):
        return
    var loaded_state = data.info[save_name]
    visible = false
    side_showing = loaded_state.side_showing
    current_id = loaded_state.current_id
    character.free()
    if current_id.is_empty():
        return
    CustomLogger.warn(self, self._on_load, " will pause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true

    character = character_template.instantiate()

    character.on_init(current_id, Repositories.get_info(RepositoryTypes.CHARACTERS, current_id))
    character.on_expression_change(
        {"id": current_id, "animation_list": loaded_state.character_info.animation}
    )
    character.on_skin_change({"id": current_id, "skin": loaded_state.character_info.skins})
    character.owner = null

    portrait_container.add_child(character)
    character.scale = Vector2(0.45, 0.45)
    character.position = OffScreenPositions.locations(character.id)

    character.owner = portrait_container

    visible = loaded_state.visible
    CustomLogger.warn(self, self._on_load, " will unpause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false
    await SystemHelpers.start_timer(VNAnimationTimes.FAST)
    state = _get_state()


## Waits for a timer through [code]SystemHelpers[/code]; deletes [code]character[/code] immediately;
## adds [code]character[/code] as a child of [code]portrait_container[/code]. It also sends
## [code]restored[/code] notifications. It pauses for
## [code]SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)[/code] before continuing.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    if character == null:
        await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
        state = _get_state()
        restored.emit()
        return
    var loaded_state = data
    visible = false
    side_showing = loaded_state.side_showing
    current_id = loaded_state.current_id
    character.free()
    if current_id.is_empty():
        CustomLogger.warn(
            self,
            self.restore,
            "[color=#FFF]" + name + " missing current id, aborting restoration.[/color]"
        )
        await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
        state = _get_state()
        restored.emit()
        return
    CustomLogger.warn(self, self.restore, " will pause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true

    character = character_template.instantiate()

    character.on_init(current_id, Repositories.get_info(RepositoryTypes.CHARACTERS, current_id))
    character.on_expression_change(
        {"id": current_id, "animation_list": loaded_state.character_info.animation}
    )
    character.on_skin_change({"id": current_id, "skin": loaded_state.character_info.skins})
    character.owner = null

    portrait_container.add_child(character)
    character.scale = Vector2(0.45, 0.45)
    character.position = OffScreenPositions.locations(character.id)

    character.owner = portrait_container

    visible = loaded_state.visible
    CustomLogger.warn(self, self._on_load, " will unpause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false
    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    state = _get_state()
    restored.emit()
