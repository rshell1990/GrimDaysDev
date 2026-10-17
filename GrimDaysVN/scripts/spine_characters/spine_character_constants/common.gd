## Holds shared character IDs and readable names. No characters are currently configured.
class_name Common
extends Object

## Named character choices. Currently empty after removing characters from the original framework.
enum NAMES {}

## Matches character IDs to readable names. Currently empty.
const NAMES_TO_STRING: Dictionary = {}


## Returns the readable name for the supplied character choice, or "Invalid" if it has no mapping.
## With the current empty lookup table, this always returns "Invalid".
static func get_name_string(character: NAMES) -> String:
    if NAMES_TO_STRING.has(character):
        return NAMES_TO_STRING[character]

    return "Invalid"
