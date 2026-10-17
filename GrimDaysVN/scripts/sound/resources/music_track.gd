# Editor configuration for MusicTrackResource.
@icon("res://GrimDays/assets/visuals/editor_icons/zigzag-tune.svg")
## Authored music track data used by this system.
class_name MusicTrackResource
extends Resource

## Lookup ID used to find this entry in the relevant resource collection.
@export var id: String
## Audio resource to play.
@export var track: AudioStream
