extends Sprite3D
## Scene template used to create template.
@export var template: PackedScene
## List of sprites used by this script.
@export var sprites: Array[Texture2D]


## When the node is ready, this function adds [code]new_sprite[/code] as a child node; sets
## [code]new_sprite_2D.texture[/code] to [code]sprite[/code]; sets
## [code]new_sprite.position.x[/code] to [code]start_position_x[/code].
func _ready() -> void:
    var start_position_x: float = -600
    for sprite in sprites:
        var new_sprite: Sprite3D = template.instantiate()
        var new_sprite_2D: Sprite2D = new_sprite.sprite
        new_sprite_2D.texture = sprite
        add_child(new_sprite)
        new_sprite.position.x = start_position_x
        start_position_x += 100.0
