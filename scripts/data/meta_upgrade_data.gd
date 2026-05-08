class_name MetaUpgradeData
extends Resource

# プレステージで購入する永続強化のマスターデータ。
# data/meta_upgrades/*.tres に並べる。
# 効果の適用ロジックは別レイヤ（MetaUpgradeService 予定）が
# id / pillar / target_id を見て分岐する想定。
# このデータ自体は「何を売っているか」と「いくらか」だけを持つ。

@export var id: StringName = &""
@export var display_name: String = ""                 # 翻訳キー
@export var pillar: Enums.MetaPillar = Enums.MetaPillar.ECONOMY
@export var base_cost: int = 1                        # 1Lvあがるごとに cost_growth で増えていく
@export var cost_growth: float = 2.0
@export var max_level: int = 1                        # 1なら単発購入、>1で段階購入、-1で無限段階
@export var target_id: StringName = &""               # 例: meta_bond_lemuen の op_id, meta_unlock_<X> の対象キー
@export_multiline var description: String = ""        # 翻訳キー（_multiline で長文も書ける）
