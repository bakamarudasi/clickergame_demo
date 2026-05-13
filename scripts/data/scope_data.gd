class_name ScopeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export var price: int = 5000

# 衣装側 sprite_xray_variants を引くキー（&"underwear" / &"nude" / &"thermal" など）
@export var view_kind: StringName = &"underwear"

# 性能パラメータ
@export var battery_max_sec: float = 30.0
@export var resolution_level: int = 1
@export var suspicion_rate: float = 1.0      # 倍率。低いほどバレにくい

@export_multiline var description: String = ""

# 「動かせる枠」表示モード -----------------------------------------------
# - is_inverse = false : 枠の内側だけ xray 差分が見える（通常の紳士枠）
# - is_inverse = true  : 枠の内側だけ通常服が残り、外側が xray になる（逆紳士枠）
# 全身切替モードは廃止。常に窓方式で重ねる。
@export var is_inverse: bool = false
# 枠の表示サイズ（PortraitView 内のピクセル）。ドラッグで位置だけ動く。
@export var window_size: Vector2 = Vector2(220, 220)

# 枠の見た目（NinePatchRect 用テクスチャ）。null ならコード側の既定ボーダー。
@export var frame_overlay: Texture2D
