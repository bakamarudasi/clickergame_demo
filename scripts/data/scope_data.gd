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

# 将来拡張：四角枠オーバーレイ等を貼るときに使う
@export var frame_overlay: Texture2D
