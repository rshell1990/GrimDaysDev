extends FontOperator
class_name TertiaryFontOperator


## When the node is ready, this function connects responses to
## [code]VNSignalBus.tertiary_font_changed[/code].
func _ready() -> void:
    super()
    VNSignalBus.tertiary_font_changed.connect(on_font_changed)
    var tertiary_font = Repositories.get_resource(RepositoryTypes.FONTS).get_font_id(
        SM_Globals.user_prefs.tertiary_font
    )
    on_font_changed(tertiary_font)
    on_font_scale_changed(SM_Globals.user_prefs.font_scale)
