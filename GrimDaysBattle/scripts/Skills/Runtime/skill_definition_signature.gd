extends RefCounted
## Stable gameplay-data fingerprint for save compatibility, independent of instance IDs and layout.

const OMIT_FIELDS = [
    "resource_local_to_scene",
    "resource_name",
    "resource_path",
    "script",
    "display_name",
    "description",
    "icon",
    "row",
    "attack_animation",
]


static func for_collection(collection: BattleSkillTreeCollection) -> String:
    return JSON.stringify(_value(collection, [])).sha256_text()


static func _value(value: Variant, ancestors: Array) -> Variant:
    if value is Resource:
        if value in ancestors:
            return "cycle"
        if value is Texture2D or value is AudioStream or value is PackedScene or value is Script:
            return value.resource_path
        var visited := ancestors.duplicate()
        visited.append(value)
        var fields: Dictionary = {}
        var script: Script = value.get_script()
        fields["type"] = script.resource_path if script else value.get_class()
        for property in value.get_property_list():
            if property.usage & PROPERTY_USAGE_STORAGE == 0 or property.name in OMIT_FIELDS:
                continue
            # Adding an opt-in target policy must not invalidate unchanged legacy saves.
            if value is ActionTemplate and property.name == "include_self" and not value.include_self:
                continue
            fields[property.name] = _value(value.get(property.name), visited)
        return _value(fields, visited)
    if value is Dictionary:
        var keys: Array = value.keys()
        keys.sort_custom(func(a, b): return str(a) < str(b))
        var entries: Array = []
        for key in keys:
            entries.append([str(key), _value(value[key], ancestors)])
        return entries
    if value is Array:
        var entries: Array = []
        for entry in value:
            entries.append(_value(entry, ancestors))
        return entries
    # Packed arrays and built-in numeric types have deterministic JSON representations.
    return value
