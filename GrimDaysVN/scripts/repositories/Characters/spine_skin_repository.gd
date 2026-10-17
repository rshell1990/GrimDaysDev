extends Node
## Master list of skins that the spine sprites have.  It takes a resource list of skins and then
## sorts them into a dictionary that can be refrenced to get information about the
## animation throughout the project.

## The resource file containing information about the skins.
var resource: MasterSkinDictionary

## The dictionary to be accessed by other parts of the project.
var master: Dictionary


## Builds this repository’s lookup table from its assigned resources when the node is ready.
func _ready():
    if resource == null:
        return
    for id in resource.directory:
        var character_skins = resource.directory[id]
        master[id] = {}
        for skin in character_skins.skins:
            master[id][skin.called] = skin.parts
