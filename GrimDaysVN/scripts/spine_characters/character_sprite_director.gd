extends Node

## CharacterSpriteDirector controls relaying information from the Character Sprite Administrator to the managed
## character
## sprites on the various depth's of the current scene.
class_name CharacterSpriteDirector

## Shared fixed value for max pause.
const MAX_PAUSE: float = 1.5

## Notification for restored.
signal restored

## Signals that the side character should be set to the broadcasted PortraitOperator.
signal side_character_set(id, model)

## The designated identifier for saving the depth data upon making a checkpoint / hard save.
var save_name: String = "depths"

## The various depths the characters can be placed upon.
var depths: Dictionary

## Holds the current state of the depth's holding characters in the scene.
var state: Dictionary

## The template character to add new characters into the scene.
var template: PackedScene = load("res://GrimDaysVN/scenes/sub-scenes/spine_character.tscn") # lint:ignore load-in-var,line-length -- Keep instance-time scene loading.
## Resource loaded for template two; reused instead of looking up the file on each call.
var template_two: PackedScene = load("res://GrimDaysVN/scenes/sub-scenes/spine_portrait.tscn") # lint:ignore load-in-var,line-length -- Keep instance-time scene loading.

## Count of character movements still being tracked by the director.
var moving_characters: int = 0
## Count of character additions still being tracked by the director.
var adding_characters: int = 0
## Whether this director paused dialogue while waiting for character operations.
var set_paused: bool = false


## On each physics update, this function sets [code]set_paused[/code] to false; sets
## [code]Dialogic.paused[/code] to false.
func _physics_process(delta: float) -> void:
    if set_paused and not moving_characters and not adding_characters and Dialogic.paused:
        set_paused = false
        CustomLogger.error(self, _physics_process, "Character sprite director had to resume dialogic manually.", 4)
        Dialogic.paused = false


## Adds the provided character to the designated depth, and then passes the character and additional information to the
## attached movement operation.
func relay_add(data: Dictionary) -> void:
    CustomLogger.warn(self, self.relay_add, " is pausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true
    set_paused = true
    adding_characters += 1
    data["template"] = template
    if depths.is_empty():
        _reconnect_depths()
    var current_character: CharacterOperator = await depths[data.depth].add_char(data)
    adding_characters -= 1
    var move_data: Dictionary = {
        "method": data.method.to_lower(),
        "target_x": data.end.to_float(),
        "target_depth": data.depth,
        "current_position": current_character.position
    }

    relay_move(current_character, move_data)


## Unloads the provided characters from the scene completely.
func relay_leave(data: Dictionary) -> void:
    var character = _find_character(data.id)
    if not character:
        Dialogic.paused = false
        return
    character.on_leave()
    await character.tree_exited
    CustomLogger.warn(self, self.relay_leave, " is unpausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false


## Relays a movement command to a character after finding it by id from the supplied data.
func relay_movement(data: Dictionary) -> void:
    var character = _find_character(data.id)
    if not character:
        Dialogic.paused = false
        return
    var move_data: Dictionary = {
        "method": data.method.to_lower(),
        "target_x": data.end.to_float(),
        "target_depth": _find_depth(character),
        "current_position": character.position
    }
    relay_move(character, move_data)


## Tells the supplied character how to move to it's destination in the scene.
func relay_move(character: CharacterOperator, data: Dictionary) -> void:
    Dialogic.paused = true
    set_paused = true
    moving_characters += 1
    if not character.moved.is_connected(on_moved):
        character.moved.connect(on_moved)
    character.on_move(data)


## Updates the count of character movements still in progress.
func on_moved() -> void:
    moving_characters -= 1
    if moving_characters < 1 and adding_characters < 1:
        set_paused = false
        CustomLogger.warn(self, self.on_moved, " is unpausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
        Dialogic.paused = false


## Tells the designated character to flip either "BACK" or "FORWARD"
func relay_flip(data: Dictionary) -> void:
    var current_character: CharacterOperator = (
        _find_character(data.id) if _find_character(data.id) is CharacterOperator else null
    )
    if current_character == null:
        push_warning("FLIP FAILED on: ", data.id, " ", depths)
        return
    await current_character.on_flip({"direction": data.direction})
    if moving_characters < 1 and adding_characters < 1:
        set_paused = false
        CustomLogger.warn(self, self.relay_flip, " is unpausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
        Dialogic.paused = false


## Tells the designated character, to change it's current 'skin' into the supplied one.
func relay_skin(data: Dictionary) -> void:
    var current_character = _find_character(data.id)
    if not current_character:
        Dialogic.paused = false
        return
    if current_character is PortraitOperator:
        current_character = current_character.character
    current_character.on_skin_change({"id": data.id, "skin": data.skin})
    await current_character.skin_changed
    if moving_characters < 1 and adding_characters < 1:
        set_paused = false
        CustomLogger.warn(self, self.relay_skin, " is unpausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
        Dialogic.paused = false


## Tells the designated character to change the depth it is currently positioned on. Can also be used to give a
## character
## priority for collisions, so that they will jockey characters backwards when they collide.
func relay_transfer(data: Dictionary) -> void:
    var current_character: CharacterOperator = _find_character(data.id)
    if not current_character:
        Dialogic.paused = false
        return
    var current_depth: DepthOperator = _find_depth(current_character)
    var target_depth: DepthOperator = depths[data.depth]
    var target_location: Vector3 = Vector3(data.end.to_float(), target_depth.position.y, target_depth.position.z)
    var move_data: Dictionary = {
        "method": "transfer",
        "target_location": target_location,
        "target_depth": target_depth,
        "current_position": current_character.position
    }
    relay_move(current_character, move_data)

    # current_depth.remove_from(current_character)
    # target_depth.transfer_to(current_character)


## Tells the designated character to change their current expression.
func relay_expression(data: Dictionary) -> void:
    var current_character = _find_character(data.id)
    if not current_character:
        Dialogic.paused = false
        return
    var split_expression = data.change.split("/")
    current_character.on_expression_change({"group": split_expression[0], "layer": split_expression[1]})
    CustomLogger.warn(self, self.relay_expression, " is unpausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false


## Requests that characters leave the registered display layers.
func clear_depths() -> void:
    for depth in depths:
        for child in depths[depth].get_children():
            var data: Dictionary = {"id": child.id}
            relay_leave(data)


## Refreshes the character display-layer lookup after loading a scene.
func _reconnect_depths_on_load(_active_node: Node) -> void:
    _reconnect_depths()


## Upon swapping world scenarios, will find and restore the internal list of depths.
func _reconnect_depths() -> void:
    if not get_tree().current_scene:
        return
    if (
        not get_tree().current_scene.name == "TestTimelineScene"
        and not get_tree().current_scene is PortraitedSceneOperator
    ):
        CustomLogger.warn(
            self,
            self._reconnect_depths,
            (
                "Current scene is "
                + str(get_tree().current_scene.name)
                + ", no depths will exist, so exiting this funciton."
            ),
            1
        )
        return
    depths.clear()
    CustomLogger.hint(self, self._reconnect_depths, " is reconnecting the character depths.", 3)
    var root = get_node("/root")
    var root_tree = root.get_tree()
    var found_depths = root_tree.get_nodes_in_group(DDNodeTypes.SPRITE_DEPTH)
    CustomLogger.hint(self, self._reconnect_depths, " has found depths: " + str(found_depths), 3)
    for depth in found_depths:
        depths[depth.name] = depth
    if depths.is_empty():
        CustomLogger.error(self, self._reconnect_depths, " has failed to find depths to connect to...", 4)
    else:
        CustomLogger.confirm(self, self._reconnect_depths, " has restored the depths.", 4)


## Registers a named character display layer with the character system.
func add_depths(depth_name: String, sent_depth: DepthOperator) -> void:
    CustomLogger.hint(
        self, self.add_depths, str(sent_depth) + " will be added to the known depths under the key: " + depth_name, 3
    )
    depths.set(depth_name, sent_depth)


## Removes a named character display layer from the character system's lookup.
func remove_depths(depth_name: String) -> void:
    depths.erase(depth_name)
    CustomLogger.hint(self, self.add_depths, str(depth_name) + " will be removed from known depths.", 3)


## Find a character in the current scenario.
func _find_character(id: String) -> Variant:
    var searched_character: Variant = null
    for depth: Node3D in depths.values():
        for child in depth.get_children():
            if child.id == id:
                searched_character = child
                break

    return searched_character


## Find what layer a character is on.
func _find_depth(character: CharacterOperator) -> DepthOperator:
    for depth in depths.values():
        for child in depth.get_children():
            if child == character:
                return depth

    return depths[0]


## Creates a portrait (side) character, that is shown next to the textbox on screen. This character does not exist 'on
## screen' during the current scenario.
func _create_portrait_from_template(id: String) -> PortraitOperator:
    var new_character: PortraitOperator = template_two.instantiate()
    new_character.name = id
    new_character.on_init(id, Repositories.get_info(RepositoryTypes.CHARACTERS, id))
    return new_character


## Returns the current state of the character depths known, upon starting the save process.
func _get_state() -> Dictionary:
    if moving_characters:
        await Dialogic.dialogic_resumed
    for depth in depths:
        state[depth] = {}
        for child in depths[depth].get_children():
            state[depth][child.id] = child.get_character_info()

    var found_characters: Array = []

    for depth in state.keys():
        if state[depth].size() > 0:
            for id in state[depth]:
                found_characters.append(id)

    var checked_characters: Array = []
    for character in found_characters:
        if not checked_characters.has(character):
            checked_characters.append(character)

    if found_characters.size() > checked_characters.size():
        push_error("DUPLICATE CHARARACTERS")

    return state


## Adds [code]on_load_function[/code] as a child node; waits for a timer through
## [code]SystemHelpers[/code]; schedules [code]on_load_function[/code] for deletion. It also sends
## [code]restored[/code] notifications. It pauses for
## [code]get_tree().create_timer(0.1).timeout[/code], [code]_get_state()[/code] before continuing.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    if GameManager.state != GameManagerStates.STATES.Scenario:
        await get_tree().create_timer(0.1).timeout
        CustomLogger.confirm(
            self, self.restore, "The current state is not a scenario, skipping restoring saved character information."
        )
        restored.emit()
        return
    if data.is_empty():
        await get_tree().create_timer(0.1).timeout
        restored.emit()
        CustomLogger.error(
            self, self.restore, "[color=#000]" + name + " missing old depths data.[/color]", CustomLogger.LEVEL.MILD
        )
        return
    if get_tree().current_scene is PortraitedSceneOperator:
        _reconnect_depths()
    var old_depth_state: Dictionary = data
    var current_depth_state: Dictionary = await _get_state()

    if old_depth_state == current_depth_state:
        CustomLogger.hint(
            self, self.restore, "[color=#F00]" + name + "old state matches current state, skipping restore.[/color]"
        )
        await get_tree().create_timer(0.1).timeout
        restored.emit()
        return

    CustomLogger.warn(self, self.restore, " is pausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true

    reset_depths()
    if depths.is_empty():
        Dialogic.paused = false
        await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
        restored.emit()
        return
    CustomLogger.hint(self, self.restore, "CHARACTER ON LOAD FUNCTION TRIGGERED.", CustomLogger.LEVEL.MILD)
    var on_load_function: LoadCharactersOperation = LoadCharactersOperation.new()
    add_child(on_load_function)
    on_load_function.execute({"state": data, "template": template, "depths": depths, "controller": self})
    await on_load_function.loaded
    CustomLogger.hint(self, self.restore, "CHARACTER ON LOAD FUNCTION FINISHED.", 3)
    on_load_function.queue_free()
    await on_load_function.tree_exited
    CustomLogger.warn(self, self.restore, " is unpausing Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false

    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()


## Resets each registered character display layer.
func reset_depths() -> void:
    if depths.is_empty():
        _reconnect_depths()
    for depth in depths:
        if depth == null:
            continue
        for child in depths[depth].get_children():
            child.queue_free()
            await child.tree_exited


## Resets the registered character display layers.
func reset() -> void:
    CustomLogger.warn(self, self.reset, " is resetting, depths will be cleared.", CustomLogger.LEVEL.MILD)
    reset_depths()


## When the node enters the scene, this function registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)


## When the node is ready, this function connects responses to
## [code]SceneManager.load_complete[/code], [code]VNSignalBus.reset_sub_systems[/code].
func _ready():
    VNSignalBus.listen_for(side_character_set, VNSignalBus._on_side_character_set)
    SceneManager.load_complete.connect(_reconnect_depths_on_load)
    VNSignalBus.reset_sub_systems.connect(reset)
