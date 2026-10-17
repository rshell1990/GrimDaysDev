extends Label

## Shared fixed value for reset.
const RESET: float = 0.16
## Remaining time before this script performs its next timed update.
var delay: float = RESET


# Called every frame. 'delta' is the elapsed time since the previous frame.
## On each drawn frame, this function decreases [code]delay[/code] by [code]delta[/code]; sets
## [code]delay[/code] to [code]RESET[/code].
func _process(delta: float) -> void:
    delay -= delta
    if delay > 0:
        return
    set_fps_text()
    delay = RESET


## Displays frame rate, frame-processing time in milliseconds, and system/graphics memory use in
## megabytes.
func set_fps_text():
    var fps_stat_strings: Dictionary = {
        "fps": str(Performance.get_monitor(Performance.TIME_FPS)),
        "processing": str(snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000, 0.01)),
        "memory": str(roundf((Performance.get_monitor(Performance.MEMORY_STATIC) / 1024) / 1024)),
        "video": str(roundf((Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1024) / 1024))
    }
    var formatting_string: String = "FPS: {fps}\nLATENCY: {processing} ms\nRAM: {memory} MB\nVRAM: {video} MB"
    text = formatting_string.format(fps_stat_strings)
