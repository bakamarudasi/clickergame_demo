class_name CostumeData
extends Resource

@export var id: StringName = &""
@export var operator_id: StringName = &""
@export var display_name: String = ""
@export var sprite: Texture2D                          # 通常表示
@export var sprite_pose_seductive: Texture2D          # 高信頼で気付かれた時の見せつけ

# 枠（ScopeData.view_kind）ごとの透過版。
# キーは &"underwear" / &"nude" / &"thermal" / &"swimsuit" など。
# キーが無ければ通常 sprite にフォールバック。
@export var sprite_xray_variants: Dictionary = {}

@export var unlock_via: Enums.CostumeUnlockVia = Enums.CostumeUnlockVia.STAGE
@export var shop_price: int = 0


func get_xray_sprite(view_kind: StringName) -> Texture2D:
	if view_kind == &"" or not sprite_xray_variants.has(view_kind):
		return sprite
	var t: Texture2D = sprite_xray_variants[view_kind]
	return t if t != null else sprite

