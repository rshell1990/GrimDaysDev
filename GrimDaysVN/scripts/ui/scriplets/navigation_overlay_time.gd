extends Control

## Scene control for icon, used to display or change the related setting.
@export_category("Displayed Icon")
@export var icon: TextureRect
## Scene control for icon shadow, used to display or change the related setting.
@export var icon_shadow: TextureRect
## Image used to display dawn icon.
@export_category("Icons")
@export var dawn_icon: Texture2D
## Image used to display morning icon.
@export var morning_icon: Texture2D
## Image used to display afternoon icon.
@export var afternoon_icon: Texture2D
## Image used to display evening icon.
@export var evening_icon: Texture2D
## Image used to display night icon.
@export var night_icon: Texture2D
## Image used to display bedtime icon.
@export var bedtime_icon: Texture2D
## Color used for dawn color.
@export_category("Time Color Modulation")
@export var dawn_color: Color
## Color used for morning color.
@export var morning_color: Color
## Color used for afternoon color.
@export var afternoon_color: Color
## Color used for evening color.
@export var evening_color: Color
## Color used for night color.
@export var night_color: Color
## Color used for bedtime color.
@export var bedtime_color: Color
## Scene control for bar, used to display or change the related setting.
@export_category("Background and Frame")
@export var bar: ProgressBar
## Scene object used for bar holder.
@export var bar_holder: Panel
## Scene object used for frame.
@export var frame: Panel


## When the node is ready, this function connects responses to [code]VNSignalBus.time_passed[/code],
## [code]VNSignalBus.on_load[/code], [code]VNSignalBus.reset_sub_systems[/code].
func _ready() -> void:
    VNSignalBus.time_passed.connect(on_time_passed)
    VNSignalBus.on_load.connect(on_load)
    VNSignalBus.reset_sub_systems.connect(reset)


## Resets the time display to Dawn.
func reset() -> void:
    on_time_passed(TimeAdministrator.TIMES.Dawn, TimeAdministrator.TIMES.Dawn)


## Updates the time display using the time-of-day value in loaded game data.
func on_load(data: Dictionary) -> void:
    var loaded_time = data.info.in_game_time.time_id
    on_time_passed(0, loaded_time)


## Sets [code]icon.texture[/code] to [code]dawn_icon[/code]; sets [code]icon_shadow.texture[/code]
## to [code]dawn_icon[/code]; sets [code]icon.texture[/code] to [code]morning_icon[/code].
func on_time_passed(_old_time, new_time) -> void:
    CustomLogger.hint(
        self,
        on_time_passed,
        "[color=#F60] Time has passed, updating the value of the current time to: " + str(new_time) + "[/color]"
    )
    match new_time:
        TimeAdministrator.TIMES.Dawn:
            color_self(dawn_color)
            icon.texture = dawn_icon
            icon_shadow.texture = dawn_icon
            tween_bar(bar.max_value)
        TimeAdministrator.TIMES.Morning:
            color_self(morning_color)
            icon.texture = morning_icon
            icon_shadow.texture = morning_icon
            tween_bar(bar.max_value - 1)
        TimeAdministrator.TIMES.Afternoon:
            color_self(afternoon_color)
            icon.texture = afternoon_icon
            icon_shadow.texture = afternoon_icon
            tween_bar(bar.max_value - 2)
        TimeAdministrator.TIMES.Evening:
            color_self(evening_color)
            icon.texture = evening_icon
            icon_shadow.texture = evening_icon
            tween_bar(bar.max_value - 3)
        TimeAdministrator.TIMES.Night:
            color_self(night_color)
            icon.texture = night_icon
            icon_shadow.texture = night_icon
            tween_bar(bar.max_value - 4)
        TimeAdministrator.TIMES.Bedtime:
            color_self(bedtime_color)
            icon.texture = bedtime_icon
            icon_shadow.texture = bedtime_icon
            tween_bar(bar.max_value - 5)


## Smoothly updates the time display's progress bar toward its new value.
func tween_bar(new_value) -> void:
    var tween = create_tween()
    tween.tween_property(bar, "value", new_value, VNAnimationTimes.STANDARD)


## Applies the selected UI color scheme to this control's background and frame.
func color_self(color):
    var bg_color = color
    bar_holder.modulate = bg_color

    if frame == null:
        return

    var frame_color = color
    frame_color = frame_color.lightened(ColorCodes.LIGHTEN_BY * 2.0)
    frame.self_modulate = frame_color
