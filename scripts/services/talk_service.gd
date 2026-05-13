class_name TalkService
extends Object

# 「話しかける」ボタン専用サービス。
# ReactionRule の TriggerKind.TALK を引いて、ヒットしなければ汎用フォールバックを流す。
# トラストや段階で揺れる程度の軽い反応（Gift より弱く、Idle より能動的）に位置付ける。

# TALK ルールに該当するものが無かった時に、UI が「無反応で気まずい」状態に
# ならないようにするためのフォールバック台詞のローカライズキー。
# 翻訳CSVの DIALOGUE_TALK_FALLBACK_* で本文を差し替えられる。
const FALLBACK_DIALOGUE_KEYS: Array[String] = [
	"DIALOGUE_TALK_FALLBACK_0",
	"DIALOGUE_TALK_FALLBACK_1",
	"DIALOGUE_TALK_FALLBACK_2",
]


static func talk(op_id: StringName) -> ReactionRule:
	if ReactionDispatcher.try_locked_revisit(op_id):
		return null
	var rule := ReactionResolver.fire(Enums.TriggerKind.TALK, &"", op_id)
	if rule == null:
		_emit_fallback(op_id)
	return rule


# Fallback は ReactionRule を通さずに直接 reaction_played 経由で渡したい所だが、
# シグナル契約上 rule:ReactionRule が必須なので、毎回 in-memory で薄いルールを
# 組み立てて emit する。trust_delta=0 / side_effects=[] なので副作用は無い。
static func _emit_fallback(op_id: StringName) -> void:
	var rule := ReactionRule.new()
	rule.trigger_kind = Enums.TriggerKind.TALK
	rule.operator_id = op_id
	rule.reaction = Enums.Reaction.HAPPY
	rule.trust_delta = 0
	rule.expression = &""
	rule.dialogue = FALLBACK_DIALOGUE_KEYS[randi() % FALLBACK_DIALOGUE_KEYS.size()]
	EventBus.reaction_played.emit(op_id, rule)
