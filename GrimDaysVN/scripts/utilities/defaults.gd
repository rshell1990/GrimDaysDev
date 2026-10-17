## Default game and interface settings used before player preferences override them.
class_name Defaults
extends Object

## Shared fixed value for resolution.
const RESOLUTION: Vector2i = Vector2i(960, 540)

## Shared fixed value for user prefs path.
const USER_PREFS_PATH: String = "user://GrimDays_user_preferences.tres"

## Shared fixed value for prime base color.
const PRIME_BASE_COLOR: String = "#a71d1d"
## Shared fixed value for prime text color.
const PRIME_TEXT_COLOR: String = "#ffffff"
## Shared fixed value for prime outline color.
const PRIME_OUTLINE_COLOR: String = "#000000"

## Shared fixed value for dark base color.
const DARK_BASE_COLOR: String = "#933FC5"
## Shared fixed value for dark text color.
const DARK_TEXT_COLOR: String = "#DDDDDD"
## Shared fixed value for dark outline color.
const DARK_OUTLINE_COLOR: String = "#000000"

## Shared fixed value for default alpha.
const DEFAULT_ALPHA: float = 0.85
## Shared fixed value for frame brightened by.
const FRAME_BRIGHTENED_BY: float = 0.2
## Shared fixed value for frame hue shifted by.
const FRAME_HUE_SHIFTED_BY: float = 0.2
## Shared fixed value for background darkened by.
const BACKGROUND_DARKENED_BY: float = 0.2
## Shared fixed value for background hue shifted by.
const BACKGROUND_HUE_SHIFTED_BY: float = 0.2
## Shared fixed value for default volume.
const DEFAULT_VOLUME: float = 0.5

## Shared fixed value for default monitor.
const DEFAULT_MONITOR: int = 0

## Shared fixed value for internal width.
const INTERNAL_WIDTH: float = 1920.0
## Shared fixed value for internal height.
const INTERNAL_HEIGHT: float = 1080.0

## Named choices for windowmode: [code]WINDOWED[/code], [code]FULLSCREEN[/code],
## [code]BORDERLESS[/code].
enum WINDOWMODE {
    WINDOWED,
    FULLSCREEN,
    BORDERLESS,
}

## Shared fixed value for default windowmode.
const DEFAULT_WINDOWMODE: WINDOWMODE = WINDOWMODE.WINDOWED
## Lookup table for windowmode; keys select the corresponding stored values.
const WINDOWMODE_OPTIONS: Dictionary = {0: WINDOWMODE.WINDOWED, 1: WINDOWMODE.FULLSCREEN, 2: WINDOWMODE.BORDERLESS}

## Named choices for difficulty: [code]STORY[/code], [code]NORMAL[/code], [code]CHALLENGE[/code].
enum DIFFICULTY { STORY, NORMAL, CHALLENGE }

## Shared fixed value for default difficulty.
const DEFAULT_DIFFICULTY: DIFFICULTY = DIFFICULTY.NORMAL
## Lookup table for difficulty; keys select the corresponding stored values.
const DIFFICULTY_OPTIONS: Dictionary = {0: DIFFICULTY.STORY, 1: DIFFICULTY.NORMAL, 2: DIFFICULTY.CHALLENGE}

## Named choices for language: [code]ENGLISH[/code].
enum LANGUAGE {
    ENGLISH,
}

## Shared fixed value for default language.
const DEFAULT_LANGUAGE = LANGUAGE.ENGLISH

## Shared fixed value for language.
const LANGUAGE_OPTIONS = {0: LANGUAGE.ENGLISH}

## Named choices for censoring: [code]NONE[/code], [code]BASIC[/code], [code]SOME[/code],
## [code]COMPLETE[/code].
enum CENSORING { NONE, BASIC, SOME, COMPLETE }

## Lookup table for censoring; keys select the corresponding stored values.
const CENSORING_OPTIONS: Dictionary = {0: CENSORING.NONE, 1: CENSORING.BASIC, 2: CENSORING.SOME, 3: CENSORING.COMPLETE}

## Shared fixed value for default censoring.
const DEFAULT_CENSORING: CENSORING = CENSORING.NONE

## Named choices for fonts: [code]ANSWER[/code], [code]DEJAVU[/code], [code]DYSLEXIA[/code].
enum FONTS { ANSWER, DEJAVU, DYSLEXIA }

## Named choices for color scheme: [code]MONOCHROME[/code], [code]TWO_TONE[/code],
## [code]FRAME_ONLY[/code], [code]MONOCHROME_DARK[/code], [code]TWO_TONE_DARK[/code].
enum COLOR_SCHEME { MONOCHROME = 0, TWO_TONE = 1, FRAME_ONLY = 2, MONOCHROME_DARK = 3, TWO_TONE_DARK = 4 }

## Lookup table for fonts; keys select the corresponding stored values.
const FONTS_OPTIONS: Dictionary = {0: FONTS.ANSWER, 1: FONTS.DEJAVU, 2: FONTS.DYSLEXIA}

## Shared fixed value for default font.
const DEFAULT_FONT: FONTS = FONTS.ANSWER
## Shared fixed value for default font scale.
const DEFAULT_FONT_SCALE: float = 1.0

## Shared fixed value for story difficulty bonus damage.
const STORY_DIFFICULTY_BONUS_DAMAGE: float = 0.75
## Shared fixed value for story difficulty damage reduction.
const STORY_DIFFICULTY_DAMAGE_REDUCTION: float = 0.5
## Shared fixed value for story difficulty bonus time.
const STORY_DIFFICULTY_BONUS_TIME: float = 0.33

## Shared fixed value for challenge difficulty bonus damage.
const CHALLENGE_DIFFICULTY_BONUS_DAMAGE: float = 0.425
## Shared fixed value for challenge difficulty bonus time.
const CHALLENGE_DIFFICULTY_BONUS_TIME: float = -0.25

## Shared fixed value for version major.
const VERSION_MAJOR: String = "0.05"
## Shared fixed value for version minor.
const VERSION_MINOR: String = "08-31-26"
## Shared fixed value for version patch.
const VERSION_PATCH: String = "Prototype_Four"
