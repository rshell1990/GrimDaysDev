## Shared command prefixes used to route dialogue requests to the right game system.
class_name SignalArguments
extends Object

## Shared identifier for camera, used so other scripts refer to the same setting or operation.
const CAMERA: String = "CAMERA"
## Shared identifier for character, used so other scripts refer to the same setting or operation.
const CHARACTER: String = "CHAR"
## Shared identifier for rollback, used so other scripts refer to the same setting or operation.
const ROLLBACK: String = "ROLL"
## Shared identifier for hide, used so other scripts refer to the same setting or operation.
const HIDE: String = "HIDE"
## Shared identifier for pause, used so other scripts refer to the same setting or operation.
const PAUSE: String = "PAUSE"
## Shared identifier for show, used so other scripts refer to the same setting or operation.
const SHOW: String = "SHOW"
## Shared identifier for dialogic, used so other scripts refer to the same setting or operation.
const DIALOGIC: String = "DIA"
## Shared identifier for song, used so other scripts refer to the same setting or operation.
const SONG: String = "SONG"

#Planned
## Shared identifier for music, used so other scripts refer to the same setting or operation.
const MUSIC: String = "MUSIC"
## Shared identifier for sound, used so other scripts refer to the same setting or operation.
const SOUND: String = "SOUND"
## Shared identifier for ambient, used so other scripts refer to the same setting or operation.
const AMBIENT: String = "AMBIENT"

## Shared identifier for route, used so other scripts refer to the same setting or operation.
const ROUTE: String = "ROUTE"

## Shared identifier for battle, used so other scripts refer to the same setting or operation.
const BATTLE: String = "BATTLE"
## Shared identifier for background, used so other scripts refer to the same setting or operation.
const BACKGROUND: String = "BG"

## Shared identifier for effect, used so other scripts refer to the same setting or operation.
const EFFECT: String = "VFX"
## Shared identifier for shout, used so other scripts refer to the same setting or operation.
const SHOUT: String = "SHOUT"
## Shared identifier for devnote, used so other scripts refer to the same setting or operation.
const DEVNOTE: String = "NOTE"

## Shared identifier for phone, used so other scripts refer to the same setting or operation.
const PHONE: String = "TXTMSG"

## Shared identifier for state, used so other scripts refer to the same setting or operation.
const STATE: String = "STATE"

## Lookup table for type to administrator; keys select the corresponding stored values.
const TYPE_TO_ADMINISTRATOR: Dictionary = {
    CAMERA: AdministratorTypes.CAMERA,
    CHARACTER: AdministratorTypes.CHARACTER,
    ROLLBACK: AdministratorTypes.ROLLBACK,
    DIALOGIC: AdministratorTypes.DIALOGIC,
    SONG: AdministratorTypes.SONG
}
