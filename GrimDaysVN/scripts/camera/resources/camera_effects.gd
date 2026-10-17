extends Resource

## A list of all camera effects that have been created.
## Named camera effects and their corresponding movement helpers.
class_name CameraFXS

## The array of camera effects that have been created, this master resource is referenced by the main camera to
## instantiate
## the various individual camera effects at runtime.
@export var directory: Array[CameraFX]
