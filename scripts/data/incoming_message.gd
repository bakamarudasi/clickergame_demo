class_name IncomingMessage
extends Resource

@export var id: StringName = &""
@export var operator_id: StringName = &""
@export var trust_min: int = 0
@export var trust_max: int = 99999
@export var cooldown_real_sec: float = 60.0
@export_multiline var text: String = ""
@export var choices: Array[String] = []
@export var linked_memory_id: StringName = &""
