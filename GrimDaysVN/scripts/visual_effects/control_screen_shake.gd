extends LoadableColorRect
class_name ScreenShakingColorRect

## Notification for restored.
signal restored
## Key used to identify this script’s data in saved state.
var save_name = "screen_shaker"
## Shader material receiving the screen-shake settings.
var current_material: ShaderMaterial
## Whether ramp up is currently enabled or true.
var ramp_up: bool = false
## Whether cycling is currently enabled or true.
var cycling: bool = false
## Transition value used while changing the screen-shake cycle.
var cycle_transition: float
## Strength currently being applied to the screen-shake shader.
var current_strength: float
## Requested peak strength of the screen-shake effect.
var max_strength: float
# Called when the node enters the scene tree for the first time.
## Lookup table for shaker state; keys select the corresponding stored values.
var shaker_state: Dictionary


## When the node is ready, this function sets [code]current_material[/code] to [code]material as
## ShaderMaterial[/code].
func _ready() -> void:
    current_material = material as ShaderMaterial


## When the node enters the scene, this function connects responses to
## [code]VNSignalBus.reset_sub_systems[/code]; registers [code]self[/code] with
## [code]SaveAndLoadSystemManager[/code].
func _enter_tree() -> void:
    SaveAndLoadSystemManager.add_node(self)
    VNSignalBus.reset_sub_systems.connect(reset)


## Collects this object’s current display and resource settings into a dictionary for saving or
## restoration.
func _get_state() -> Dictionary:
    get_state()
    state.set("ramp_up", ramp_up)
    state.set("cycling", cycling)
    state.set("current_strength", current_strength)
    state.set("max_strength", max_strength)
    state.set("cycle_transition", cycle_transition)
    shaker_state = state
    return shaker_state


## Waits for a timer through [code]SystemHelpers[/code]; sets [code]ramp_up[/code] to
## [code]data.ramp_up[/code]; sets [code]cycling[/code] to [code]data.cycling[/code]. It also sends
## [code]restored[/code] notifications. It pauses for
## [code]SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)[/code] before continuing.
func restore(data: Dictionary) -> void:
    CustomLogger.hint(self, self.restore, "is restoring data.", CustomLogger.LEVEL.MILD)
    restore_state(data)
    ramp_up = data.ramp_up
    cycling = data.cycling
    cycle_transition = data.cycle_transition
    current_strength = data.current_strength
    set_shake_strength(data.max_strength, cycle_transition)
    await SystemHelpers.start_timer(VNAnimationTimes.NEAR_INSTANT)
    restored.emit()


## Updates the screen-shake effect's strength and optional transition speed.
func set_shake_strength(value: float, cycle_length: float) -> void:
    if not current_material:
        return
    current_material.set_shader_parameter("ShakeStrength", value)
    current_strength = value
    max_strength = value
    if cycle_length < 0.1:
        return
    cycle_transition = cycle_length


## Currently performs no work; this function is a placeholder for behavior supplied later or by a
## child script.
func _process(delta: float) -> void:
    pass
    #if not ramp_up:
    #cycle_down(delta)
    #else:
    #cycle_up(delta)


## Animates the screen-shake strength toward the lower part of its cycle.
func cycle_down(amount: float) -> void:
    current_strength -= amount
    current_strength = clampf(current_strength, 0.0, max_strength)
    current_material.set_shader_parameter("ShakeStrength", current_strength)
    if current_strength < 0.01:
        ramp_up = true


## Animates the screen-shake strength toward the upper part of its cycle.
func cycle_up(amount: float) -> void:
    current_strength += amount
    current_strength = clampf(current_strength, 0.0, max_strength)
    current_material.set_shader_parameter("ShakeStrength", current_strength)
    if current_strength > max_strength - 0.01:
        ramp_up = false


## Sets [code]ramp_up[/code] to false; sets [code]cycling[/code] to false; sets
## [code]cycle_transition[/code] to [code]0.0[/code].
func reset() -> void:
    ramp_up = false
    cycling = false
    cycle_transition = 0.0
    current_strength = 0.0
    max_strength = 0.0
