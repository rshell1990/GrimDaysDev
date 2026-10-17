# Editor configuration for CharacterOperator.
@icon("res://GrimDays/assets/visuals/at-icons/node3d/human.svg")
extends Sprite3D
## Coordinates one scene character's movement, visual layers and collision responses.
class_name CharacterOperator
## Shared fixed value for skin group.
const SKIN_GROUP: String = "Base"

## Notification for area entered. Supplies [code]area_owner[/code], [code]hit_character[/code] to
## connected functions.
signal area_entered(area_owner: CharacterOperator, hit_character: CharacterOperator)
## Notification for area exited. Supplies [code]hit_character[/code] to connected functions.
signal area_exited(hit_character: CharacterOperator)

## Notification for expression changed.
signal expression_changed
## Notification for initialized.
signal initialized
## Notification for moved.
signal moved
## Notification for skin changed.
signal skin_changed

## Stored sprite used by this script’s update and input handling.
@export var sprite: LayeredCharacterOperator
## Scene control for outer view, used to display or change the related setting.
@export var outer_view: SubViewport
## Animation player used for animation player.
@export var animation_player: AnimationPlayer
## Scene object used for movement holder.
@export var movement_holder: Node
## Scene object used for collision area.
@export var collision_area: Area3D

## Lookup ID used to find this entry in the relevant resource collection.
var id: String
## Looks up the helper that implements each character movement style.
var movement_handlers: Dictionary
## Whether adjusted position is currently enabled or true.
var adjusted_position: bool = false

## Whether moving is currently enabled or true.
var moving: bool = false


## Uses the character's viewport texture as its displayed image and logs entry into the scene.
func _enter_tree() -> void:
    CustomLogger.hint(self, self._enter_tree, " is entering the scene tree.", 2)
    texture = outer_view.get_texture()


## Logs that the character is leaving the scene.
func _exit_tree() -> void:
    CustomLogger.hint(self, self._exit_tree, " is exiting the scene tree.", 2)


## Sends [code]area_entered[/code] notifications.
func on_area_entered(entering: CharacterOperator, hit: CharacterOperator) -> void:
    ##SystemHelpers.print("Announcing collision Enter.")
    if not moving:
        return
    area_entered.emit(entering, hit)


## Sends [code]area_exited[/code] notifications.
func on_area_exited(hit: CharacterOperator) -> void:
    ##SystemHelpers.print("Announcing Collision Exit.")
    if not moving:
        return
    area_exited.emit(hit)


## Marks the character as moving.
func set_moving() -> void:
    moving = true


## Marks the character as no longer moving.
func set_stopped() -> void:
    moving = false


## Connects movement handlers and instantiates the layered model returned by the repository.
## Waits for tree entry only when it has not already occurred, then announces initialization.
func on_init(a_id: String):
    CustomLogger.hint(self, self.on_init, id + ": starting init...", CustomLogger.LEVEL.MILD)
    id = a_id
    movement_handlers = {}
    for child in movement_holder.get_children():
        CustomLogger.hint(self, self.on_init, id + ": adding movement handler: " + child.name, CustomLogger.LEVEL.MILD)
        movement_handlers[child.name.to_lower()] = child
        if child.has_signal("moving"):
            child.moving.connect(set_moving)
        if child.has_signal("stopped"):
            child.stopped.connect(set_stopped)

    var packed_sprite_scene: PackedScene = (
        Repositories.get_info(RepositoryTypes.CHARACTERS, id)
        if Repositories.get_info(RepositoryTypes.CHARACTERS, id) is PackedScene
        else ResourceLoader.load(Repositories.get_info(RepositoryTypes.CHARACTERS, id))
    )
    var sprite_scene: LayeredCharacterOperator = packed_sprite_scene.instantiate()
    outer_view.add_child(sprite_scene)
    if not sprite_scene.is_inside_tree():
        await sprite_scene.tree_entered
    sprite = outer_view.get_child(0)
    CustomLogger.confirm(self, self.on_init, id + ": has completed initialization.", CustomLogger.LEVEL.MILD)
    initialized.emit()


## Disables the character's collision detection for movement or transitions.
func disable_collisions() -> void:
    collision_area.process_mode = Node.PROCESS_MODE_DISABLED


## Enables the character's collision detection after movement or transitions.
func enable_collisions() -> void:
    collision_area.process_mode = Node.PROCESS_MODE_INHERIT


## Disconnects responses from [code]moved[/code]; sends [code]moved[/code] notifications. It pauses
## for [code]movement_handlers[args.method.to_lower()].stopped[/code] before continuing.
func on_move(args):
    movement_handlers[args.method.to_lower()].execute(args)
    if movement_handlers[args.method.to_lower()].has_signal("stopped"):
        await movement_handlers[args.method.to_lower()].stopped
    moved.emit()
    for connections in moved.get_connections():
        moved.disconnect(connections.callable)


## Smoothly changes opacity over time; waits for a timer through [code]SystemHelpers[/code];
## schedules this node for deletion. It pauses for
## [code]SystemHelpers.start_timer(VNAnimationTimes.STANDARD)[/code],
## [code]tween.tween_property(self, "modulate:a", 0.0, VNAnimationTimes.STANDARD).finished[/code]
## before continuing.
func on_leave():
    if moving:
        await SystemHelpers.start_timer(VNAnimationTimes.STANDARD)
        on_leave()
        return
    var tween = create_tween()
    await tween.tween_property(self, "modulate:a", 0.0, VNAnimationTimes.STANDARD).finished
    queue_free()
    await tree_exiting


## Waits for a timer through [code]SystemHelpers[/code]; starts playback on
## [code]animation_player[/code]. It pauses for
## [code]SystemHelpers.start_timer(VNAnimationTimes.STANDARD)[/code],
## [code]animation_player.animation_finished[/code] before continuing. Returns
## [code]rotation[/code].
func on_flip(args):
    if moving:
        await SystemHelpers.start_timer(VNAnimationTimes.STANDARD)
        on_flip(args)
        return
    if args.direction == "BACK":
        animation_player.play("flip_back")
    elif args.direction == "FORWARD":
        animation_player.play_backwards("flip_back")
    await animation_player.animation_finished

    return rotation


## Sends [code]expression_changed[/code] notifications. It pauses for
## [code]sprite.on_layer_change(args.group, args.layer)[/code] before continuing.
func on_expression_change(args):
    await sprite.on_layer_change(args.group, args.layer)
    expression_changed.emit()


## Sends [code]skin_changed[/code] notifications. It pauses for
## [code]sprite.on_layer_change(SKIN_GROUP, args.skin)[/code] before continuing.
func on_skin_change(args):
    await sprite.on_layer_change(SKIN_GROUP, args.skin)
    skin_changed.emit()


## Returns the character's position, facing, rotation and selected visual layers for later
## restoration.
func get_character_info():
    var info: Dictionary = {}
    info["location"] = position
    info["flipped"] = flip_h
    info["rotation"] = rotation
    info["active_layers"] = sprite.active_layers
    return info


## Connects the supplied notification to its response function, using the connection checks in this
## helper.
func listen_for(sent_signal: Signal, run_when_signaled: Callable) -> void:
    if sent_signal.is_connected(run_when_signaled):
        return
    sent_signal.connect(run_when_signaled)
