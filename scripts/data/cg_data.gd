class_name CGData
extends Resource

@export var id: StringName = &""
@export var operator_id: StringName = &""
@export var stage_required: int = 0
@export var trigger_item_id: StringName = &""

# 単発画像。後方互換用（旧 CG はこれだけで OK）。
# 新規 CG は steps の中に CGStep.cg_image を持たせるのを推奨。
@export var image: Texture2D
# ギャラリーで使うサムネイル（縮小画像。null なら image / 最初の step.cg_image を使う）。
@export var thumbnail: Texture2D
# ギャラリー一覧用の見出し（翻訳キー）。
@export var caption: String = ""
# CG 全編で流す BGM（任意）。
@export var bgm: AudioStream = null
# 進行スクリプト。空のままでも image + caption で「1枚絵 + キャプション」表示は可能。
# steps が 1 件以上ある場合はビューアが steps を辿る。
@export var steps: Array[CGStep] = []
