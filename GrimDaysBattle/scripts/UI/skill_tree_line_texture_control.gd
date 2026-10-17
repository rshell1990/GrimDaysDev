extends TextureRect
## The texture to use if a connection between nodes on the same row of the skill
## tree exists.
var connection_exists_texture: String = "uid://wgp1lxaidk6c"
## The texture to use if a connection between nodes on the same row of the skill
## tree exists and the first node is invested in.
var connection_available_texture: String = "uid://chqtt8mjgrx4i"
## The texture to use if a connection between nodes on the same row of the skill
## tree exists and both nodes in the connection are invested in.
var connection_completed_texture: String = "uid://bka24tmd0fwtd"


func set_exists_texture() -> void:
    var new_texture = ResourceLoader.load(connection_exists_texture, "", ResourceLoader.CACHE_MODE_REUSE)
    if not new_texture:
        return
    texture = new_texture


func set_available_texture() -> void:
    var new_texture = ResourceLoader.load(connection_available_texture, "", ResourceLoader.CACHE_MODE_REUSE)
    if not new_texture:
        return
    texture = new_texture


func set_completed_texture() -> void:
    var new_texture = ResourceLoader.load(connection_completed_texture, "", ResourceLoader.CACHE_MODE_REUSE)
    if not new_texture:
        return
    texture = new_texture
