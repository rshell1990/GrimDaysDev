# Editor configuration for SoundEffectResource.
@icon("res://GrimDays/assets/visuals/editor_icons/sound-waves.svg")
## Authored sound effect data used by this system.
class_name SoundEffectResource
extends Resource

## Lookup ID used to find this entry in the relevant resource collection.
@export var id: String
## Audio resource to play.
@export var track: AudioStream
