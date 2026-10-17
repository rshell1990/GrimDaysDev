extends Resource

## A CameraFX is an effect related to camera movement.  These effects are added to the main camera at runtime to
## give the camera movement abilities in a modular fashion so they can be expanded upon.
## Authored definition identifying a camera effect and its implementation.
class_name CameraFX

## What the camera fx is called when being referenced in the dialogic script.
@export var called: String

## The scene containing the logical node on how to preform this effect.
@export var resource: PackedScene
