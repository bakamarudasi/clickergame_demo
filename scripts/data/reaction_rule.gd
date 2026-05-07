class_name ReactionRule
extends Resource

@export var trigger_kind: Enums.TriggerKind = Enums.TriggerKind.ITEM
@export var trigger_id: StringName = &""
@export var operator_id: StringName = &""
@export var category: Enums.ItemCategory = Enums.ItemCategory.DAILY
@export var match_category: bool = false

@export var min_trust: int = 0
@export var max_trust: int = 99999
@export var consecutive_count_min: int = 0
@export var consecutive_count_max: int = 9999

@export var reaction: Enums.Reaction = Enums.Reaction.HAPPY
@export var trust_delta: int = 0
@export var expression: StringName = &""
@export_multiline var dialogue: String = ""
@export var side_effects: Array[ItemEffect] = []
@export var priority: int = 0
