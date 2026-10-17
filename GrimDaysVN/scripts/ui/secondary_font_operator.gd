extends FontOperator
class_name SecondaryFontOperator


## When the node is ready, this function connects responses to
## [code]VNSignalBus.secondary_font_changed[/code].
func _ready() -> void:
    super()
    VNSignalBus.secondary_font_changed.connect(on_font_changed)
    var secondary_font = Repositories.get_resource(RepositoryTypes.FONTS).get_font_id(
        SM_Globals.user_prefs.secondary_font
    )
    on_font_changed(secondary_font)
    on_font_scale_changed(SM_Globals.user_prefs.font_scale)
