extends Resource

## The information about a particular 'skin' a spine character has.
## Authored spine skin data used by this system.
class_name CharacterSkinInfo

## The identifier of this particular skin.
@export var called: String

## An array of the name of parts that make up a skin,
## these are specific textures that are available in a spine file.
@export var parts: Array[String]
