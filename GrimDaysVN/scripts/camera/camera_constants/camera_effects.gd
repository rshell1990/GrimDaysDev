## Named camera effects and their corresponding movement helpers.
class_name CameraEffects
extends Object

## Shared fixed value for quake.
const QUAKE: String = "quake"
## Shared fixed value for vpunch.
const VPUNCH: String = "vpunch"
## Shared fixed value for hpunch.
const HPUNCH: String = "hpunch"
## Lookup table for movements; keys select the corresponding stored values.
const MOVEMENTS: Dictionary = {
    QUAKE: 12.5,
    VPUNCH: 5,
    HPUNCH: 3,
}
