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
signal intimacy_changed(operator_id: StringName, new_value: int)
signal arousal_changed(operator_id: StringName, new_value: float)

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

# ルール
signal rule_activated(rule_id: StringName)
signal rule_deactivated(rule_id: StringName)

# 検査
signal inspection_performed(operator_id: StringName)

# 紳士眼鏡 / Scope
signal xray_changed(active: bool)
signal scope_battery_changed(seconds_remaining: float)
signal scope_equipped(scope_id: StringName)
signal xray_suspicion_changed(operator_id: StringName, value: float)
signal xray_caught(operator_id: StringName)

# プレステージ・メタ進行
signal prestige_count_changed(new_count: int)
signal prestige_currency_changed(new_amount: int)
signal bond_changed(operator_id: StringName, new_bond: int)
signal meta_upgrade_purchased(meta_id: StringName, new_level: int)

# 通知系（UI共通トースト等）
signal toast_requested(text: String)
