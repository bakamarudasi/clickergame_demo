class_name ReactionRule
extends Resource

@export var trigger_kind: Enums.TriggerKind = Enums.TriggerKind.ITEM
@export var trigger_id: StringName = &""
@export var operator_id: StringName = &""
@export var category: Enums.ItemCategory = Enums.ItemCategory.DAILY
@export var match_category: bool = false

# --- 数値範囲ゲート -----------------------------------------------------
@export var min_trust: int = 0
@export var max_trust: int = 99999
@export var min_intimacy: int = 0                     # 親密度の下限
@export var max_harassment: int = 99999               # ハラス値の上限（高すぎると発火しない）
@export var consecutive_count_min: int = 0
@export var consecutive_count_max: int = 9999

# --- 進行軸ゲート -------------------------------------------------------
@export var min_tier: int = 0                         # GameState.prestige_count がこの値以上
@export var min_bond: int = 0                         # GameState.get_bond(op_id) がこの値以上
@export var min_arousal: float = 0.0                  # GameState.get_arousal(op_id) がこの値以上

# --- 状態ゲート ---------------------------------------------------------
@export var requires_equipped_costume: StringName = &""   # 装備中衣装が一致してないと発火しない
@export var requires_xray_active: bool = false             # 紳士眼鏡 ON 必須

# --- コンテンツ・コンボゲート（全て AND 評価） ----------------------------
# requires_active_rules はアイテム使用などで立てた active rule を AND で要求する。
# 例: ロープ + 目隠し両方使った後にしか発火しない反応 →
#     [&"rule_rope_in_room", &"rule_blindfold_in_room"]
@export var requires_active_rules: Array[StringName] = []
@export var requires_cgs: Array[StringName] = []
@export var requires_memories: Array[StringName] = []

# --- 発火制御 -----------------------------------------------------------
@export var probability: float = 1.0                  # < 1.0 で確率発火（条件全部通った後で抽選）

# --- 反応内容 -----------------------------------------------------------
@export var reaction: Enums.Reaction = Enums.Reaction.HAPPY
@export var trust_delta: int = 0
@export var expression: StringName = &""
@export_multiline var dialogue: String = ""
@export var side_effects: Array[ItemEffect] = []
@export var priority: int = 0
