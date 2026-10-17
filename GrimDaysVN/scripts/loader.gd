extends Node3D

## Scene object used for item holder.
@export var item_holder: Node
## List of scenes to load used by this script.
@export var scenes_to_load: Array
## Control showing progress while resources or scenes load.
@export var progress_bar: ProgressBar
## Path of the next resource or scene to load.
var path_to_load: String


## When the node enters the scene, this function changes the game mode through
## [code]GameManager[/code]. It pauses for [code]GameManager.ready[/code] before continuing.
func _enter_tree() -> void:
    if not GameManager.is_node_ready():
        await GameManager.ready
    GameManager.change_state(GameManagerStates.STATES.Init)


## When the node is ready, this function connects responses to
## [code]progress_bar.value_changed[/code], [code]item_holder.child_entered_tree[/code],
## [code]item_holder.child_exiting_tree[/code]; changes whether an audio bus is muted; adds
## [code]item.instantiate()[/code] as a child of [code]item_holder[/code]. It also sets
## [code]progress_bar.value[/code] to [code]0.0[/code].
func _ready() -> void:
    if scenes_to_load.is_empty():
        SceneManager.swap_scenes(self, self, Repositories.get_resource_path(RepositoryTypes.SCENES, "disclaimer"))
        return
    AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
    scenes_to_load = Repositories.get_repository(RepositoryTypes.SCENES).master.values()
    progress_bar.max_value = float(scenes_to_load.size())
    progress_bar.value = 0.0
    progress_bar.value_changed.connect(on_value_changed)
    item_holder.child_entered_tree.connect(on_added_item)
    item_holder.child_exiting_tree.connect(on_item_removed)

    path_to_load = scenes_to_load.pop_front()
    var item: PackedScene = ResourceLoader.load(path_to_load, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    item_holder.add_child(item.instantiate())


## Updates the loading display from the supplied progress value.
func on_value_changed(new_value: float) -> void:
    if new_value != progress_bar.max_value:
        return
    SceneManager.swap_scenes(self, self, Repositories.get_resource_path(RepositoryTypes.SCENES, "disclaimer"))


## Schedules [code]child[/code] for deletion; schedules [code]item[/code] for deletion. It pauses
## for [code]item.ready[/code], [code]get_tree().create_timer(0.02).timeout[/code] before
## continuing.
func on_added_item(item: Node) -> void:
    if not item.is_node_ready():
        await item.ready
    %Filename.text = item.name
    await get_tree().create_timer(0.02).timeout
    for child in item.find_children("*"):
        CustomLogger.hint(self, on_added_item, child.name + " freed", CustomLogger.LEVEL.IMPORTANT)
        child.queue_free()
    item.queue_free()


## Increases [code]progress_bar.value[/code] by [code]1.0[/code]; updates [code]path_to_load[/code]
## using [code]scenes_to_load.pop_front[/code].
func on_item_removed(_item: Node) -> void:
    progress_bar.value += 1.0
    if scenes_to_load.is_empty():
        return
    path_to_load = scenes_to_load.pop_front()
    var item: PackedScene = ResourceLoader.load(path_to_load, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    item_holder.add_child.call_deferred(item.instantiate())
