extends Object

## Provides off-screen portrait positions by character ID. No positions are currently configured.
class_name OffScreenPositions


## Returns the configured off-screen portrait position for the supplied character ID.
## If the ID has no entry, returns [code]Vector2.ZERO[/code], the coordinates (0, 0).
## The position table is currently empty, so every ID uses this fallback.
static func locations(id: String) -> Vector2:
    var dict = {}
    if dict.has(id):
        return dict[id]
    return Vector2.ZERO
