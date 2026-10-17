# Editor configuration for AmbientTrackResource.
@icon("res://GrimDays/assets/visuals/editor_icons/g-clef.svg")
## Authored ambient track data used by this system.
class_name AmbientTrackResource
extends Resource

## Lookup ID used to find this entry in the relevant resource collection.
@export var id: String
## Audio resource to play.
@export var track: AudioStream
