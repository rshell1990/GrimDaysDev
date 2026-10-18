class_name CustomLoggerConfig
extends Resource
## Game Config Resource
##
## A simple resource which can be loaded in various parts of your app to apply configurations.
## The default location is res://app_config.tres.

## Whether log confirms is currently enabled or true.
@export_category("Logging")
@export var log_confirms: bool = true
## Whether log hints is currently enabled or true.
@export var log_hints: bool = true
## Whether log warnings is currently enabled or true.
@export var log_warnings: bool = true
## Whether log errors is currently enabled or true.
@export var log_errors: bool = true
## Whether assert errors is currently enabled or true.
@export var assert_errors: bool = false


## Whether log hints 1 is currently enabled or true.
@export var log_hints_1:bool = true
## Whether log hints 2 is currently enabled or true.
@export var log_hints_2:bool = true
## Whether log hints 3 is currently enabled or true.
@export var log_hints_3:bool = true
## Whether log hints 4 is currently enabled or true.
@export var log_hints_4:bool = true
## Whether log hints 5 is currently enabled or true.
@export var log_hints_5:bool = true

## Whether log confirms 1 is currently enabled or true.
@export var log_confirms_1:bool = true
## Whether log confirms 2 is currently enabled or true.
@export var log_confirms_2:bool = true
## Whether log confirms 3 is currently enabled or true.
@export var log_confirms_3:bool = true
## Whether log confirms 4 is currently enabled or true.
@export var log_confirms_4:bool = true
## Whether log confirms 5 is currently enabled or true.
@export var log_confirms_5:bool = true

## Whether log warnings 1 is currently enabled or true.
@export var log_warnings_1:bool = true
## Whether log warnings 2 is currently enabled or true.
@export var log_warnings_2:bool = true
## Whether log warnings 3 is currently enabled or true.
@export var log_warnings_3:bool = true
## Whether log warnings 4 is currently enabled or true.
@export var log_warnings_4:bool = true
## Whether log warnings 5 is currently enabled or true.
@export var log_warnings_5:bool = true

## Whether log errors 1 is currently enabled or true.
@export var log_errors_1:bool = true
## Whether log errors 2 is currently enabled or true.
@export var log_errors_2:bool = true
## Whether log errors 3 is currently enabled or true.
@export var log_errors_3:bool = true
## Whether log errors 4 is currently enabled or true.
@export var log_errors_4:bool = true
## Whether log errors 5 is currently enabled or true.
@export var log_errors_5:bool = true