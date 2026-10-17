extends Resource

## Reference to a specific scene.  Used to find a particular scene to instantiate.  SceneManager will typically call
## the relavent repository to replace a scene in the 'game' scene which is the main scene.
## Named scene definition used to find a scene and its associated setup data.
class_name SceneTemplate

## The identifier for the scene in the Scene Template Repository.
@export var called: String

## The scene file.
@export var resource: PackedScene
