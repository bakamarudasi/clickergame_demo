extends Node

# 翻訳系ヘルパー。locale 切替を一元化し、UIに通知を流す。
# 個別のラベル更新は Godot 標準の NOTIFICATION_TRANSLATION_CHANGED が
# Control 全体に飛ぶので、各タブは _notification で受けて再構築すればよい。

signal locale_changed(new_locale: String)

const SUPPORTED_LOCALES := ["ja", "en", "zh_CN"]
const DEFAULT_LOCALE := "ja"


func _ready() -> void:
	var current := TranslationServer.get_locale()
	# 想定外ロケールならデフォルトに寄せる
	var base := current.get_slice("_", 0)
	if not (base in SUPPORTED_LOCALES):
		change_locale(DEFAULT_LOCALE)


func change_locale(code: String) -> void:
	if not (code in SUPPORTED_LOCALES):
		push_warning("LocaleService: unsupported locale '%s'" % code)
		return
	if TranslationServer.get_locale() == code:
		return
	TranslationServer.set_locale(code)
	locale_changed.emit(code)


func current_locale() -> String:
	return TranslationServer.get_locale()


# 翻訳キーから空文字を弾きつつ tr() するユーティリティ。
# Resource の display_name などが空のときに空文字を返したいケース用。
static func t(key: Variant) -> String:
	if key == null:
		return ""
	var s := str(key)
	if s.is_empty():
		return ""
	return TranslationServer.translate(s)
