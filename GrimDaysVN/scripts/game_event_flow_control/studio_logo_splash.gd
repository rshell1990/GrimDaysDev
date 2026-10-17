extends Control
## Scene object used for studio hiding color rect.
@export var studio_hiding_color_rect: ColorRect
## Scene object used for studio color rect.
@export var studio_color_rect: ColorRect
## Animation player used for player.
@export var player: AnimationPlayer


# Called when the node enters the scene tree for the first time.
## Stops [code]player[/code].
func init_scene() -> void:
    player.stop()
    UIDirector.fade_flag_hide()


## Begins the studio-logo appearance sequence.
func start_scene() -> void:
    _studio_splash_appears()


## Reveals the studio-logo splash with its fade and animation sequence.
func _studio_splash_appears() -> void:
    var tween = create_tween().set_ease(Tween.EASE_IN)
    tween.tween_property(studio_hiding_color_rect, "modulate:a", 0.0, VNAnimationTimes.STANDARD)
    await get_tree().create_timer(VNAnimationTimes.STANDARD).timeout
    SystemHeadquarters.call_handler(
        SignalArguments.SONG, ["INTENSITY", "INTENSITY:50.0", "SPEED:0.66"]
    )
    player.play("logo_animation")
    await get_tree().create_timer(4.0).timeout
    studio_hiding_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _handle_splashscreen()


## Waits for the logo's display allowance, then switches to the title scene.
func _handle_splashscreen() -> void:
    await get_tree().create_timer(VNAnimationTimes.LONG + 0.2).timeout
    SceneManager.swap_scenes(
        self,
        get_node("."),
        Repositories.get_resource_path(RepositoryTypes.SCENES, "title")
    )
