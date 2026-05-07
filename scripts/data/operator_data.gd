class_name OperatorData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var personality: Enums.Personality = Enums.Personality.SAINTLY_DUAL
@export var origin: StringName = &""
@export var liked_items: Array[StringName] = []
@export var disliked_items: Array[StringName] = []
@export var default_costume_id: StringName = &""
@export var stages: Array[TrustStageData] = []
@export var unlock_cost: int = 0
@export var portrait_idle: Texture2D
@export var portrait_expressions: Dictionary = {}
