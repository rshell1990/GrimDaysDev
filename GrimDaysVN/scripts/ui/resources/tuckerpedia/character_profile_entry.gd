extends Resource
## Authored character profile information shown in the encyclopedia.
class_name PediaCharacterProfileEntry

## Lookup ID used to find this entry in the relevant resource collection.
@export var id: Common.NAMES
## Portrait or illustration displayed for this profile entry.
@export var photo: Texture2D
## Structured information shown in this profile's details panel.
@export var stats: PediaCharacterProfileStats
## Biography text displayed in the character profile.
@export_multiline var bio: String
## List of memories used by this script.
@export var memories: Array[GameEvent]
## Coordinates used for avatar offset.
@export var avatar_offset: Vector2
