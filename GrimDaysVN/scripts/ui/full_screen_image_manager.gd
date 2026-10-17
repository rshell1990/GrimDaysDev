extends LoadableControl
## Lookup table for images; keys select the corresponding stored values.
@export var images: Dictionary[String, String]


## Shows the named image through the full-screen image display.
func show_image(image_name: String) -> void:
    var loaded = ResourceLoader.load(images[image_name], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
    var found_texture_rect: bool
    for child in get_children():
        if child.name == image_name:
            if child is TextureRect:
                child.texture = loaded
            else:
                found_texture_rect = assign_texture_to_child(child, loaded)

            fade_in(child)
            break


## Requests that the currently displayed image be hidden.
func hide_image(image_name: String) -> void:
    for child in get_children():
        if child.name == image_name:
            fade_out(child)
            break


## Smoothly changes opacity over time; sets [code]Dialogic.paused[/code] to true; sets
## [code]Dialogic.paused[/code] to false. It pauses for [code]tween.tween_property(node,
## "modulate:a", 1.0, VNAnimationTimes.LONG).finished[/code] before continuing.
func fade_in(node: Node) -> void:
    var tween = create_tween()
    CustomLogger.warn(self, self.fade_in, " will pause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true
    await tween.tween_property(node, "modulate:a", 1.0, VNAnimationTimes.LONG).finished
    CustomLogger.warn(self, self.fade_in, " will unpause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false


## Smoothly changes opacity over time; sets [code]Dialogic.paused[/code] to true; sets
## [code]node.texture[/code] to null. It also sets [code]Dialogic.paused[/code] to false. It pauses
## for [code]tween.tween_property(node, "modulate:a", 0.0, VNAnimationTimes.LONG).finished[/code]
## before continuing.
func fade_out(node: Node) -> void:
    var tween = create_tween()
    CustomLogger.warn(self, self.fade_out, " will pause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = true
    await tween.tween_property(node, "modulate:a", 0.0, VNAnimationTimes.LONG).finished
    if node is TextureRect:
        node.texture = null
    else:
        assign_texture_to_child(node, null)
    CustomLogger.warn(self, self.fade_out, " will unpause Dialogic.", CustomLogger.LEVEL.VERBOSE)
    Dialogic.paused = false


## Loads the selected full-screen image and assigns its texture to the display child.
func assign_texture_to_child(child, texture) -> bool:
    var found: bool = false
    for children in child.get_children():
        if children is TextureRect:
            children.texture = texture
            found = true
            break
        else:
            found = assign_texture_to_child(children, texture)
            if found:
                break

    return found
