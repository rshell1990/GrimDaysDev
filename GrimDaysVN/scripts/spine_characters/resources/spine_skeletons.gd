extends Resource

## A dictionary of all the spine characters referenced by their identifier
## to get access to their 'skeletons'.
## Authored spine skeletons data used by this system.
class_name MasterSkeletonDictionary

## The dictionary referenced by the repository to make it avialable at runtime.
@export var directory: Dictionary
