class_name UpgradeData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_cost: int = 10
@export var cost_growth: float = 1.5
@export var effect_kind: Enums.UpgradeEffectKind = Enums.UpgradeEffectKind.ADD_CLICK
@export var effect_amount: float = 1.0
@export var max_level: int = -1
@export_multiline var description: String = ""
