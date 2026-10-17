extends Resource
class_name GameFont

## Lookup ID used to find this entry in the relevant resource collection.
@export var id: String
## Font resource used for regular text.
@export var normal: Font
## Font resource used for italic text.
@export var italics: Font
## Font resource used for bold text.
@export var bold: Font
## Font resource used for text that is both bold and italic.
@export var combo: Font
