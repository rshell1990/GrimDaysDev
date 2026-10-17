extends LoadableTextureRect
class_name FadeFlagOperator
## Notification for screen shot faded.
signal screen_shot_faded

## Time value used when calculating elapsed play time; see the update and conversion functions in
## this script.
var time_passed: float


## On each physics update, this function increases [code]time_passed[/code] by [code]delta[/code];
## sets [code]time_passed[/code] to [code]0[/code].
func _physics_process(delta) -> void:
    if not Dialogic.current_timeline:
        return
    if not modulate.a > 0.1:
        return
    time_passed += delta
    if time_passed < 50.0:
        return

    fade_screenshot()
    time_passed = 0


## Captures the current view and assigns it to the transition-cover display.
func get_and_set_screen_shot() -> void:
    var img = get_viewport().get_texture().get_image()
    var screenshot = ImageTexture.create_from_image(img)
    texture = screenshot
    modulate.a = 1.0
    await RenderingServer.frame_post_draw


## Fades out the captured transition image and announces when the fade ends.
func fade_screenshot() -> void:
    var unpause: bool = false
    if not Dialogic.paused:
        CustomLogger.warn(self, self.fade_screenshot, " will pause Dialogic.", CustomLogger.LEVEL.VERBOSE)
        Dialogic.paused = true
        unpause = true
    var tween = create_tween()
    await tween.tween_property(self, "modulate:a", 0.0, VNAnimationTimes.SLOW).finished
    screen_shot_faded.emit()
    if unpause:
        CustomLogger.warn(self, self.fade_screenshot, " will unpause Dialogic.", CustomLogger.LEVEL.VERBOSE)
        Dialogic.paused = false
