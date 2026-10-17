extends Node
## Named color palettes used by the interface's preset swatches.
class_name ColorCodes
## Lookup table for normal; keys select the corresponding stored values.
const NORMAL: Dictionary = {
    ## Left Side
    "Blue1": "#33dbff",
    "Blue2": "#00a0ff",
    "Blue3": "#72eeff",
    "Blue4": "#72beff",
    "Blue5": "#4f94db",
    "Green1": "#33ff57",
    "Green2": "#75ff33",
    "Green3": "#baf678",
    "Green4": "#78f6c3",
    "Green5": "#2ac837",
    "Yellow1": "#FFFF50",
    "Yellow2": "#f5d400",
    "Yellow3": "#ffec73",
    "Yellow4": "#eaee70",
    "Yellow5": "#ffe044",
    "White1": "#aaaaaa",
    "White2": "#cccccc",
    "White3": "#FFFFFF",
}
## Lookup table for dark; keys select the corresponding stored values.
const DARK: Dictionary = {
    ## Right Side
    "Red1": "#ff0000",
    "Red2": "#ff5f00",
    "Red3": "#ff8372",
    "Red4": "#ffb372",
    "Red5": "#db964f",
    "Purple1": "#ff009e",
    "Purple2": "#b130ff",
    "Purple3": "#b478f6",
    "Purple4": "#f678ab",
    "Purple5": "#c82abb",
    "Navy1": "#5050ff",
    "Navy2": "#0021f5",
    "Navy3": "#7386ff",
    "Navy4": "#7470ee",
    "Navy5": "#4463ff",
    "Grey1": "#555555",
    "Grey2": "#757575",
    "Grey3": "#909090",
}

## Shared fixed value for hue shift.
const HUE_SHIFT: float = 0.05
## Shared fixed value for darken by.
const DARKEN_BY: float = 0.15
## Shared fixed value for lighten by.
const LIGHTEN_BY: float = 0.15
