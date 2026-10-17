extends Resource
## Authored character profile information shown in the encyclopedia.
class_name PediaCharacterProfileStats

## Full readable name displayed in the profile.
@export var full_name: String
## Alternate name displayed in the profile.
@export var alias: String
## Age description displayed in the profile; stored as text rather than a number.
@export var age: String
## Occupation displayed in the character profile.
@export var job: String
## Home or residence displayed in the character profile.
@export var residence: String
## Additional descriptive facts displayed in the profile.
@export_multiline var facts: String
