## Adds a project lookup ID to an Ovani song resource.
@tool
@icon("res://GrimDays/imported/ovani/OvaniSongIcon.png")
class_name DDOvaniSong
extends OvaniSong

## Lookup ID used to find this entry in the relevant resource collection.
@export var id: String
