class_name MemorySceneData
extends Resource

@export var id: StringName = &""
@export var operator_id: StringName = &""
@export var stage_required: int = 0
@export var unlock_trigger: Enums.UnlockTrigger = Enums.UnlockTrigger.AUTO_ON_STAGE
@export var trigger_item_id: StringName = &""
@export var title: String = ""
@export var thumbnail: Texture2D
@export var lines: Array[DialogueLine] = []
