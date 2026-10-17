extends BaseSystemManager
## Nodes registered for saving, looked up by each node’s save name.
var nodes_with_data: Dictionary


## Connects responses to [code]node.tree_exiting[/code].
func add_node(node) -> void:
    nodes_with_data.set(node.save_name, node)
    node.tree_exiting.connect(remove_node.bind(node))


## Disconnects responses from [code]node.tree_exiting[/code]; removes [code]node.save_name[/code]
## from [code]nodes_with_data[/code].
func remove_node(node) -> void:
    node.tree_exiting.disconnect(remove_node.bind(node))
    nodes_with_data.erase(node.save_name)


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func save_game() -> void:
    pass


## Adds work to [code]task_queue[/code].
func load_checkpoint(task = null) -> void:
    var task_to_do = task
    if not task_to_do:
        task_to_do = TaskLoadCheckpoint.new(&"Load Checkpoint")
    task_queue.put_task(task_to_do)


## Get nodes with information that should be 'saved' thus making the nodes persistent.
func get_persistent_data() -> Dictionary:
    var dictionary = {}
    for node in nodes_with_data:
        dictionary[node] = nodes_with_data[node].call(&"_get_state")

    return dictionary


## Asks registered nodes to restore matching saved entries and waits for restoration notifications.
## Warns when an entry is absent.
func restore_data(data: Dictionary) -> void:
    for node_save_name in nodes_with_data.keys():
        if data.has(node_save_name):
            nodes_with_data[node_save_name].restore(data[node_save_name])
            await data[node_save_name].restored
        else:
            push_warning(node_save_name, " does not exist in the saved data dictionary.")
