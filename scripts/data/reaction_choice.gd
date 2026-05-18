class_name ReactionChoice
extends Resource

# 選択肢ベースの反応分岐。ReactionRule.choices に並べる単体エントリ。
# ルールが発火すると本体台詞 + 表情がまず流れ、その後この選択肢ボタン群が
# 画面下に並ぶ。プレイヤーが選ぶと：
#  1. 選んだ選択肢のラベルがログにシステム行として残る
#  2. trust_delta / side_effects が適用される
#  3. response_key（バリエーションは response_alternates）が話者ログに積まれる
#  4. expression が指定されていれば立ち絵が一瞬その表情にフラッシュ
#
# 「Undertale風の軽め分岐」用の最小フィールドセット。
# 深いツリー（選択肢→さらに別ルール）が欲しくなったら next_rule_id 等を追加する。

# ボタン上のテキスト（翻訳キー）。空文字は許さない。
@export var label_key: String = ""

# 選択後にオペが返すセリフの翻訳キー。
@export_multiline var response_key: String = ""

# response_key と合わせてランダムプール化する追加バリエーション。
# pick_response() が毎回 1 件返す。
@export var response_alternates: Array[String] = []

# レスポンス時の表情（PortraitController.flash_expression に流す）。
@export var expression: StringName = &""

# 信頼度の増減。負値で減らす分岐も書ける。
@export var trust_delta: int = 0

# 追加の副作用。CG解放・親密度・発情度などはここに ItemEffect で積む。
# ReactionResolver.apply_choice() が ReactionRule.side_effects と同じ経路で処理する。
@export var side_effects: Array[ItemEffect] = []


func pick_response() -> String:
	if response_alternates.is_empty():
		return response_key
	var pool: Array[String] = [response_key]
	pool.append_array(response_alternates)
	return pool[randi() % pool.size()]
