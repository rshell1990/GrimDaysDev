extends Resource
## Pairs a dialogue timeline resource with the filename-based ID used to look it up.
class_name DialogicTimelineReference

## Dialogue timeline used by this reference or action.
@export var timeline: DialogicTimeline


## Returns the timeline resource filename without its extension, used as its lookup ID.
func get_timeline_id() -> String:
    var split: PackedStringArray = timeline.resource_path.split("/")
    var filename_and_extension: String = split[-1]
    var split_filename: PackedStringArray = filename_and_extension.split(".")
    var file_name: String = split_filename[0]

    return file_name
