# Editor configuration for Main Charging Sphere.
@tool
extends GPUParticles3D
## Starting delay before the charging effect begins its next update.
var initial_delay: float = 5
## Remaining time before this script performs its next timed update.
var delay: float = initial_delay
