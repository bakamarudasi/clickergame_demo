extends Node

# 全タブ横断シグナル。UI同士は直接参照せずここを介して通信する。

# 通貨
signal currency_changed(new_value: int)
signal per_second_changed(new_value: int)
signal click_power_changed(new_value: int)

# オペレータ
signal operator_unlocked(operator_id: StringName)
signal trust_changed(operator_id: StringName, new_trust: int, new_stage: int)
signal stage_advanced(operator_id: StringName, new_stage: int)
signal operator_locked(operator_id: StringName, until_unix: float)

# インベントリ・ショップ
signal inventory_changed(item_id: StringName, new_count: int)
signal item_purchased(item_id: StringName)
signal upgrade_purchased(upgrade_id: StringName, new_level: int)

# 反応・コンテンツ
signal reaction_played(operator_id: StringName, rule: ReactionRule)
signal cg_unlocked(cg_id: StringName)
signal costume_unlocked(operator_id: StringName, costume_id: StringName)
signal costume_equipped(operator_id: StringName, costume_id: StringName)
signal memory_unlocked(memory_id: StringName)
signal incoming_message_arrived(message: IncomingMessage)

# 通知系（UI共通トースト等）
signal toast_requested(text: String)
