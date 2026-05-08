class_name CostumeData
extends Resource

@export var id: StringName = &""
@export var operator_id: StringName = &""
@export var display_name: String = ""
@export var sprite: Texture2D                          # 通常表示
@export var sprite_pose_seductive: Texture2D          # 高信頼で気付かれた時の見せつけ

# 顔レイヤー合成方式での顔差分の貼付け位置。sprite の rect に対する
# 正規化座標（0..1）。OperatorData.portrait_face_overlays に登録した
# 顔差分テクスチャをこの矩形に重ねる。コスチュームごとに顔位置が違うので
# 衣装側で持つ。デフォルトは「上部中央 40% 幅 / 30% 高さ」。
@export var face_anchor_rect: Rect2 = Rect2(0.3, 0.05, 0.4, 0.3)

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

