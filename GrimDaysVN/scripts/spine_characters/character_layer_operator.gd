extends Sprite3D
## Holds characters at one display depth and manages transfers and collision spacing.
class_name DepthOperator

## Shared fixed value for collision cooldown.
const COLLISION_COOLDOWN: float = 0.2
## Shared fixed value for retreat distance.
const RETREAT_DISTANCE: float = 5
## Shared fixed value for collision disabled for.
const COLLISION_DISABLED_FOR: float = -0.2

## Whether start hidden is currently enabled or true.
@export var start_hidden: bool = false

## List of characters used by this script.
var characters: Array[CharacterOperator]
## Elapsed time since the last character-entry collision response.
var time_since_last_collision_entered: float = 0
## Elapsed time since the last character-exit collision response.
var time_since_last_collision_exited: float = 0


## When the node enters the scene, this function connects responses to
## [code]child_entered_tree[/code], [code]child_exiting_tree[/code].
func _enter_tree() -> void:
    var portraited_scene = get_parent().get_parent()
    if portraited_scene is PortraitedSceneOperator:
        SystemAdministrators.add_depths(name, self)
    child_entered_tree.connect(on_child_entered)
    child_exiting_tree.connect(on_child_exited)


## Unregisters this named character display layer when it leaves the scene.
func _exit_tree() -> void:
    SystemAdministrators.remove_depths(name)


## Logs which character was added to this display layer.
func on_child_entered(the_child: Node) -> void:
    CustomLogger.hint(
        self, on_child_entered, "Character: " + the_child.name + "added to depth: " + name, CustomLogger.LEVEL.MILD
    )


## Removes empty references from the remembered character list after a child exits.
func on_child_exited(the_child: Node) -> void:
    for x in range(characters.size() - 1, -1, -1):
        if not characters[x]:
            characters.remove_at(x)


## On each drawn frame, this function increases [code]time_since_last_collision_entered[/code] by
## [code]delta[/code]; increases [code]time_since_last_collision_exited[/code] by
## [code]delta[/code].
func _process(delta: float) -> void:
    time_since_last_collision_entered += delta
    time_since_last_collision_exited += delta


## Connects responses to [code]returned.area_entered[/code], [code]returned.area_exited[/code]; adds
## [code]returned[/code] to [code]characters[/code]. It pauses for
## [code]AddToDepthOperation.execute(new_data, start_hidden)[/code] before continuing. Returns
## [code]returned[/code].
func add_char(data: Dictionary) -> CharacterOperator:
    var new_data: Dictionary = data
    new_data["depth"] = self
    var returned: CharacterOperator = await AddToDepthOperation.execute(new_data, start_hidden)
    characters.append(returned)
    returned.area_entered.connect(on_enter_collision)
    returned.area_exited.connect(on_exit_collision)
    return returned


## Moves a character into this display layer and tracks it in the layer's character list.
func transfer_to(character: CharacterOperator) -> void:
    characters.append(character)
    character.area_entered.connect(on_enter_collision)
    character.area_exited.connect(on_exit_collision)


## Removes the character from this display layer's tracking.
func remove_from(character: CharacterOperator) -> void:
    var index: int = characters.find(character)

    character.area_entered.disconnect(on_enter_collision)
    character.area_exited.disconnect(on_exit_collision)

    characters.remove_at(index)


## Clears the characters currently attached to this display layer.
func reset_depth() -> void:
    for id in characters:
        if id == null:
            continue
        remove_from(id)
    time_since_last_collision_entered = COLLISION_DISABLED_FOR
    time_since_last_collision_exited = COLLISION_DISABLED_FOR


## Sets [code]time_since_last_collision_entered[/code] to [code]0[/code].
func on_enter_collision(entering: CharacterOperator, hit: CharacterOperator) -> void:
    if time_since_last_collision_entered < COLLISION_COOLDOWN:
        return
    time_since_last_collision_entered = 0
    CustomLogger.hint(self, on_enter_collision, entering.name + " hit " + hit.name + " on " + self.name, 5)

    var character_order: int = characters.find(entering)
    var hit_order: int = characters.find(hit)

    var oldest_char: int = mini(character_order, hit_order)

    move_char_backwards(characters[oldest_char])


## Sets [code]time_since_last_collision_exited[/code] to [code]0[/code].
func on_exit_collision(hit: CharacterOperator) -> void:
    if time_since_last_collision_exited < COLLISION_COOLDOWN:
        return
    time_since_last_collision_exited = 0
    reset_char_position(hit)
    CustomLogger.hint(self, on_exit_collision, "Exiting " + hit.name + " on " + self.name, 5)


## Moves a character back after a collision so overlapping characters can separate.
func move_char_backwards(character) -> void:
    if not character:
        return
    if character.adjusted_position:
        return
    CustomLogger.warn(self, move_char_backwards, str(character) + " is being moved backwards on the Z axis.", 5)
    character.adjusted_position = true
    var tween = create_tween()
    await (
        tween
        . tween_property(character, "position:z", character.position.z - RETREAT_DISTANCE, VNAnimationTimes.FAST)
        . finished
    )
    character.adjusted_position = false


## Returns the character toward its normal layer position after a collision adjustment.
func reset_char_position(character) -> void:
    if character.adjusted_position:
        return
    CustomLogger.warn(self, reset_char_position, str(character) + " is resetting Z.", 5)
    var tween = create_tween()
    var half_distance = lerpf(character.position.z, 0.0, 0.5)
    await tween.tween_property(character, "position:z", half_distance, VNAnimationTimes.FAST).finished
    tween = create_tween()
    var full_distance = lerpf(character.position.z, 0.0, 1.0)
    await tween.tween_property(character, "position:z", full_distance, VNAnimationTimes.FAST).finished
