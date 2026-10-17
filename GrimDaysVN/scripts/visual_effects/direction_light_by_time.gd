extends DirectionalLight3D

## Color used for dawn light color.
@export_category("Lighting Color")
@export var dawn_light_color: Color
## Color used for morning light color.
@export var morning_light_color: Color
## Color used for afternoon light color.
@export var afternoon_light_color: Color
## Color used for evening light color.
@export var evening_light_color: Color
## Color used for night light color.
@export var night_light_color: Color
## Color used for bedtime light color.
@export var bedtime_light_color: Color

## Light brightness to use at dawn.
@export_category("Lighting Strength")
@export_range(0.33, 1.0) var dawn_light_energy: float
## Light brightness to use at morning.
@export_range(0.33, 1.0) var morning_light_energy: float
## Light brightness to use at afternoon.
@export_range(0.33, 1.0) var afternoon_light_energy: float
## Light brightness to use at evening.
@export_range(0.33, 1.0) var evening_light_energy: float
## Light brightness to use at night.
@export_range(0.33, 1.0) var night_light_energy: float
## Light brightness to use at bedtime.
@export_range(0.33, 1.0) var bedtime_light_energy: float


## Applies the configured light color and brightness for the current time of day.
func _ready() -> void:
    match SystemAdministrators.current_time():
        TimeAdministrator.TIMES.Dawn:
            light_color = dawn_light_color
            light_energy = dawn_light_energy
        TimeAdministrator.TIMES.Morning:
            light_color = morning_light_color
            light_energy = morning_light_energy
        TimeAdministrator.TIMES.Afternoon:
            light_color = afternoon_light_color
            light_energy = afternoon_light_energy
        TimeAdministrator.TIMES.Evening:
            light_color = evening_light_color
            light_energy = evening_light_energy
        TimeAdministrator.TIMES.Night:
            light_color = night_light_color
            light_energy = night_light_energy
        TimeAdministrator.TIMES.Bedtime:
            light_color = bedtime_light_color
            light_energy = bedtime_light_energy
