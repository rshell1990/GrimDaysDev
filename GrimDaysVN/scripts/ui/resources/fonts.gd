extends Resource
class_name GameFonts

## Entries supplied by this resource collection for the systems that read it.
@export var all: Array[GameFont]


## Returns the selected font resource from this collection.
func get_font(index) -> GameFont:
    return all[index]


## Returns the identifier of the selected font in this collection.
func get_font_id(index):
    return all[index].id
