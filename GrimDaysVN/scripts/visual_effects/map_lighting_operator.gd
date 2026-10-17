extends Node

## Scene environment receiving the time-of-day lighting settings.
@export var world_environment: WorldEnvironment
## Environment settings to use at dawn.
@export var dawn_environment: Environment
## Environment settings to use at morning.
@export var morning_environment: Environment
## Environment settings to use at afternoon.
@export var afternoon_environment: Environment
## Environment settings to use at evening.
@export var evening_environment: Environment
## Environment settings to use at night.
@export var night_environment: Environment
## Environment settings to use at bedtime.
@export var bedtime_environment: Environment

## Directional light used for dawn lighting.
@export var dawn_light: DirectionalLight3D
## Directional light used for morning lighting.
@export var morning_light: DirectionalLight3D
## Directional light used for afternoon lighting.
@export var afternoon_light: DirectionalLight3D
## Directional light used for evening lighting.
@export var evening_light: DirectionalLight3D
## Directional light used for night lighting.
@export var night_light: DirectionalLight3D
## Directional light used for bedtime lighting.
@export var bedtime_light: DirectionalLight3D

## List of lights used by this script.
@export var lights: Array[DirectionalLight3D]


## When the node is ready, this function connects responses to [code]VNSignalBus.time_passed[/code].
func _ready() -> void:
    VNSignalBus.time_passed.connect(on_time_passed)
    on_time_passed(SystemAdministrators.current_time(), SystemAdministrators.current_time())


## Sets [code]dawn_light.visible[/code] to true; sets [code]world_environment.environment[/code] to
## [code]dawn_environment[/code]; sets [code]morning_light.visible[/code] to true. It pauses for
## [code]get_tree().create_timer(VNAnimationTimes.STANDARD).timeout[/code] before continuing.
func on_time_passed(_old_time: TimeAdministrator.TIMES, new_time: TimeAdministrator.TIMES) -> void:
    await get_tree().create_timer(VNAnimationTimes.STANDARD).timeout
    match new_time:
        TimeAdministrator.TIMES.Dawn:
            diable_lights()
            dawn_light.visible = true
            world_environment.environment = dawn_environment
        TimeAdministrator.TIMES.Morning:
            diable_lights()
            morning_light.visible = true
            world_environment.environment = morning_environment
        TimeAdministrator.TIMES.Afternoon:
            diable_lights()
            afternoon_light.visible = true
            world_environment.environment = afternoon_environment
        TimeAdministrator.TIMES.Evening:
            diable_lights()
            evening_light.visible = true
            world_environment.environment = evening_environment
        TimeAdministrator.TIMES.Night:
            diable_lights()
            night_light.visible = true
            world_environment.environment = night_environment
        TimeAdministrator.TIMES.Bedtime:
            diable_lights()
            bedtime_light.visible = true
            world_environment.environment = bedtime_environment


## Disables the time-of-day lights before selecting the required lighting setup.
func diable_lights() -> void:
    for light in lights:
        light.visible = false
