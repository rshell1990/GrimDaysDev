extends SpineSprite
## Loads the title logo's Spine data and provides its visual-effect callbacks.
class_name LogoShaderController
## Viewport container displaying this logo's rendered image.
var container: SubViewportContainer


# Called when the node enters the scene tree for the first time.
## Loads the title-logo Spine skeleton when this node enters the scene.
func _enter_tree() -> void:
    skeleton_data_res = ResourceLoader.load(
        "res://GrimDaysVN/resources/spine/dd_logo.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
    )


## Releases the Spine skeleton resource reference when this node leaves the scene.
func _exit_tree() -> void:
    skeleton_data_res = null


## When the node is ready, this function sets [code]container[/code] to
## [code]get_parent().get_parent()[/code].
func _ready():
    container = get_parent().get_parent()
    update_mode = SpineConstant.UpdateMode_Physics


## Currently only waits for the configured delay. The shader changes in this function are commented
## out.
func turn_shader_off():
    # var shader_mat:ShaderMaterial = container.material
    # shader_mat.set_shader_parameter("amplitude", Vector2(0.013,0.013))
    await get_tree().create_timer(VNAnimationTimes.LONG + 0.5).timeout
    # shader_mat.set_shader_parameter("amplitude", Vector2(0.000,0.000))

    # ##SystemHelpers.print(shader_mat.get_shader_parameter("amplitude"))
    # shader_mat.set_shader_parameter("speed", Vector2(0.0,0.0))
