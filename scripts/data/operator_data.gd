class_name OperatorData
extends Resource

@export var id: StringName = &""
# 翻訳キー（例: "OP_LEMUEN_NAME"）。表示する側は必ず tr() を通すこと。
@export var display_name: String = ""
@export var personality: Enums.Personality = Enums.Personality.SAINTLY_DUAL
@export var origin: StringName = &""
@export var liked_items: Array[StringName] = []
@export var disliked_items: Array[StringName] = []
@export var default_costume_id: StringName = &""
@export var stages: Array[TrustStageData] = []
@export var unlock_cost: int = 0
@export var portrait_idle: Texture2D
# 表情キー → 全身差し替え用 Texture2D。立ち絵 PNG を丸ごと差し替える方式。
@export var portrait_expressions: Dictionary = {}
# 表情キー → 顔差分用 Texture2D。CostumeData.face_anchor_rect の領域に
# レイヤー合成する（体スプライトはそのまま）。同じキーが両方に登録されてる場合は
# 顔差分が優先される（素材枚数が少なくて済むので推奨）。
@export var portrait_face_overlays: Dictionary = {}
@export var xray_detection_rate: float = 1.0   # 紳士眼鏡で気付かれる速度倍率
