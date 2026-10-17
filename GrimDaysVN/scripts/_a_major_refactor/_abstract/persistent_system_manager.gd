extends BaseSystemManager
class_name PersistentSystemManager

## Indicates state has been successfully imported.
signal restored


## Aside from initializing the task queue, adds itself the the save and load system.
func _enter_tree() -> void:
    super()
    SaveAndLoadSystemManager.add_node(self)


## Overwritten, by extended class.
func _get_state() -> Dictionary:
    var state: Dictionary
    return state


## Overwritten, by extended class.
func restore(data: Dictionary) -> void:
    pass
