class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Enums.ItemCategory = Enums.ItemCategory.DAILY
@export var price: int = 0
@export var is_consumable: bool = false
@export var icon: Texture2D
@export_multiline var description: String = ""
@export var effects: Array[ItemEffect] = []
@export var trust_gate_min: int = 0
@export var requires_meta: StringName = &""          # 空でない場合、当該メタ強化が解放されている時だけ Shop に陳列
