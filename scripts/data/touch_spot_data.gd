class_name TouchSpotData
extends Resource

@export var id: StringName = &""
@export var operator_id: StringName = &""
@export var display_name: String = ""
@export var trust_gate_min: int = 0
@export var cooldown_sec: float = 0.5
@export var trust_delta_base: int = 1
@export var expression_on_use: StringName = &""
@export var hotspot_rect: Rect2 = Rect2()
@export var is_harassment: bool = false
@export var harassment_weight: int = 0
@export var trust_penalty_low: int = 0
@export var unlock_at_stage: int = 0
