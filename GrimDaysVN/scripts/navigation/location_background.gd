# Editor configuration for NavigationBackground.
@icon("res://GrimDays/assets/visuals/at-icons/node3d/mountains.svg")
extends LoadableSprite3D
## Loads the appropriate background image for the current time of day.
class_name NavigationBackground

## File path for dawn.
@export_file() var dawn_texture: String
## File path for morning.
@export_file() var morning_texture: String
## File path for afternoon.
@export_file() var afternoon_texture: String
## File path for evening.
@export_file() var evening_texture: String
## File path for night.
@export_file() var night_texture: String


## Releases the texture reference when the node leaves the scene.
func _exit_tree() -> void:
    texture = null


## Resolves a recognized resource UID to a file path; otherwise keeps the supplied path. Also stores
## the chosen path on this node.
func convert_uid_back_to_path(texture_path) -> String:
    path = texture_path
    if "uid" in texture_path:
        var id = ResourceUID.text_to_id(texture_path)
        if ResourceUID.has_id(id):
            path = ResourceUID.get_id_path(id)
    CustomLogger.hint(
        self, self.convert_uid_back_to_path, texture_path + "- converted to: " + path,
        CustomLogger.LEVEL.MILD
    )
    return path


## When the node is ready, this function connects responses to [code]VNSignalBus.time_passed[/code].
func _ready() -> void:
    VNSignalBus.time_passed.connect(on_time_passed)
    set_texture_by_time()


## Reloads the background image for the current time of day.
func on_time_passed(_old_time, _new_time) -> void:
    set_texture_by_time()


## Loads the background image configured for the current time of day, without reusing the deep
## resource cache.
func set_texture_by_time() -> void:
    match SystemAdministrators.current_time():
        TimeAdministrator.TIMES.Dawn:
            var texture_path = convert_uid_back_to_path(dawn_texture)
            texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

        TimeAdministrator.TIMES.Morning:
            var texture_path = convert_uid_back_to_path(morning_texture)

            texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

        TimeAdministrator.TIMES.Afternoon:
            var texture_path = convert_uid_back_to_path(afternoon_texture)
            texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

        TimeAdministrator.TIMES.Evening:
            var texture_path = convert_uid_back_to_path(evening_texture)
            texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

        TimeAdministrator.TIMES.Night:
            var texture_path = convert_uid_back_to_path(night_texture)
            texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)

        TimeAdministrator.TIMES.Bedtime:
            var texture_path = convert_uid_back_to_path(night_texture)
            texture = ResourceLoader.load(texture_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
