@icon("res://GrimDays/imported/ovani/OvaniSongIcon.png")
@tool
class_name OvaniSong
## The OvaniSong Holds onto all your music variants, for use with the [OvaniPlayer].
extends Resource

@export_category("Sound Files")
## This should be set to your least intense music file.
@export var intensity_1 : AudioStream;
## This should be set to your semi-intense music file.
@export var intensity_2 : AudioStream;
## This should be set to your most intense music file.
@export var intensity_3 : AudioStream;

## Set this to any 30 second loop of your music.
@export var loop_30 : AudioStream;
## Set this to any 60 second loop of your music.
@export var loop_60 : AudioStream;

## Set this to how long the sound should loop over itself. [br]
## This will make any songs with a Reverb Tail loop perfectly.
@export var reverb_tail : float;


## Named choices for ovani mode: [code]INTENSITIES[/code],
## [code]LOOP_30[/code], [code]LOOP_60[/code].
@export_category("Default Settings")
enum OvaniMode {
	## Determines this [OvaniSong] will play the [member intensity_1],
	## [member Intensity2], and [member Intensity3], music files.
	INTENSITIES = 0,
	LOOP_30 = 1, ## Determines this [OvaniSong] will play the [member loop_30] music file.
	LOOP_60 = 2 ## Determines this [OvaniSong] will play the [member loop_60] music file.
}
## Set this to change what linked music files will be played.
@export var song_mode : OvaniMode = OvaniMode.INTENSITIES;
