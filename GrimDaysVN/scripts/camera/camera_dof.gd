extends MeshInstance3D

## Maximum length of the ray used to choose the depth-of-field focus distance.
var DOF_LENGTH = 2000
## Physics layer mask used by the focus-distance ray.
var COLLISION_MASK = 2


## On each physics update, this function changes a shader setting on [code]sm[/code].
func _physics_process(_delta):
    var end = global_position - global_transform.basis.z * DOF_LENGTH

    var rayParams = PhysicsRayQueryParameters3D.create(global_position, end, COLLISION_MASK)
    var ray = get_world_3d().direct_space_state.intersect_ray(rayParams)
    SystemHelpers.print(ray)
    if !ray.is_empty():
        end = ray["position"]

    var sm = get_surface_override_material(0) as ShaderMaterial
    sm.set_shader_parameter("ray_position", end)
