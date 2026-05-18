class_name MetaCardFactory
extends RefCounted

# Meta タブのメタ強化カードを構築・更新するファクトリ。
# 3柱（Affinity/Economy/Catalog）それぞれの色をアクセントに使い、
# 「ダーク基調＋左端アクセント＋シアン購入ボタン」の意匠で他タブと統一。

signal buy_requested(id: StringName)

const CARD_BUTTON_HEIGHT := 36
const CARD_BUTTON_MIN_WIDTH := 140

var _host: Control


func _init(host: Control) -> void:
	_host = host


func build(m: MetaUpgradeData) -> PanelContainer:
	var accent: Color = UIConstants.PILLAR_COLORS.get(m.pillar, UIConstants.COLOR_ACCENT_CYAN)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.set_meta("meta_id", m.id)
	panel.set_meta("accent_color", accent)

	var sbox := PanelStyler.card(accent)
	panel.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", UIConstants.SEP_SMALL)
	panel.add_child(vb)

	# Header: name + Lv
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UIConstants.SEP_DEFAULT)
	vb.add_child(header)

	var name_label := Label.new()
	name_label.text = _t(m.display_name)
	name_label.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	name_label.add_theme_color_override("font_color", accent)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)

	var lv_label := Label.new()
	lv_label.theme_type_variation = UIConstants.VAR_NUMERIC_LABEL
	lv_label.add_theme_color_override("font_color", accent)
	header.add_child(lv_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = _t(m.description)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.theme_type_variation = UIConstants.VAR_DIM_LABEL
	vb.add_child(desc_label)

	# Footer: cost + buy
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", UIConstants.SEP_MEDIUM)
	vb.add_child(footer)

	var cost_label := Label.new()
	cost_label.theme_type_variation = UIConstants.VAR_NUMERIC_LABEL
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(cost_label)

	var buy_button := Button.new()
	buy_button.theme_type_variation = UIConstants.VAR_ACCENT_BUTTON
	buy_button.text = _t("META_BUY_BUTTON")
	buy_button.custom_minimum_size = Vector2(CARD_BUTTON_MIN_WIDTH, CARD_BUTTON_HEIGHT)
	buy_button.pressed.connect(_on_buy_pressed.bind(m.id))
	footer.add_child(buy_button)

	panel.set_meta("name_label", name_label)
	panel.set_meta("desc_label", desc_label)
	panel.set_meta("lv_label", lv_label)
	panel.set_meta("cost_label", cost_label)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	return panel


func refresh(card: PanelContainer, m: MetaUpgradeData) -> void:
	var lv := GameState.get_meta_level(m.id)
	var lv_label: Label = card.get_meta("lv_label")
	var cost_label: Label = card.get_meta("cost_label")
	var buy_button: Button = card.get_meta("buy_button")
	var sbox: StyleBoxFlat = card.get_meta("stylebox")

	var maxed := MetaUpgradeService.is_max_level(m.id)
	if maxed:
		lv_label.text = _t("META_LV_MAX_FMT") % lv
		cost_label.text = _t("WORK_UPGRADE_COST_MAX")
		buy_button.disabled = true
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_MAXED
	else:
		lv_label.text = _t("META_LV_FMT") % lv
		var cost := MetaUpgradeService.current_cost(m.id)
		cost_label.text = _t("META_COST_FMT") % FormatUtils.short(cost)
		var can_buy := MetaUpgradeService.can_buy(m.id)
		buy_button.disabled = not can_buy
		sbox.bg_color = UIConstants.RARITY_PANEL_BG if can_buy else UIConstants.RARITY_PANEL_BG_DISABLED


func rebuild_static_text(card: PanelContainer, m: MetaUpgradeData) -> void:
	(card.get_meta("name_label") as Label).text = _t(m.display_name)
	(card.get_meta("desc_label") as Label).text = _t(m.description)
	(card.get_meta("buy_button") as Button).text = _t("META_BUY_BUTTON")


func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _on_buy_pressed(id: StringName) -> void:
	buy_requested.emit(id)
