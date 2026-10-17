extends FontOperator
class_name PrimaryFontOperator


## When the node is ready, this function connects responses to
## [code]VNSignalBus.primary_font_changed[/code].
func _ready() -> void:
    super()
    VNSignalBus.primary_font_changed.connect(on_font_changed)
    var primary_font = Repositories.get_resource(RepositoryTypes.FONTS).get_font_id(SM_Globals.user_prefs.primary_font)
    on_font_changed(primary_font)
    on_font_scale_changed(SM_Globals.user_prefs.font_scale)
