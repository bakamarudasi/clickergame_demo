extends Control

# メタ強化（プレステージ強化）タブ。3柱（Affinity / Economy / Catalog）に分けて表示し、
# 各柱のメタ強化を源石片で購入する。
# Work タブと同様、他タブを直接参照せず Service / EventBus 経由でだけ状態を変える。

@onready var currency_label: Label = %CurrencyLabel
@onready var tab_affinity: Button = %TabAffinity
@onready var tab_economy: Button = %TabEconomy
@onready var tab_catalog: Button = %TabCatalog
@onready var meta_grid: GridContainer = %MetaGrid

var _current_pillar: Enums.MetaPillar = Enums.MetaPillar.ECONOMY
var _cards: Dictionary = {}     # meta_id -> PanelContainer


func _ready() -> void:
	var pillar_group := ButtonGroup.new()
	tab_affinity.button_group = pillar_group
	tab_economy.button_group = pillar_group
	tab_catalog.button_group = pillar_group

	tab_affinity.pressed.connect(_on_pillar_pressed.bind(Enums.MetaPillar.AFFINITY))
	tab_economy.pressed.connect(_on_pillar_pressed.bind(Enums.MetaPillar.ECONOMY))
	tab_catalog.pressed.connect(_on_pillar_pressed.bind(Enums.MetaPillar.CATALOG))

	EventBus.prestige_currency_changed.connect(_on_prestige_currency_changed)
	EventBus.meta_upgrade_purchased.connect(_on_meta_purchased)

	_refresh_currency_label()
	_build_cards()


func _on_pillar_pressed(pillar: Enums.MetaPillar) -> void:
	if _current_pillar == pillar:
		return
	_current_pillar = pillar
	_build_cards()


func _refresh_currency_label() -> void:
	currency_label.text = tr("META_CURRENCY_LABEL") % FormatUtils.short(GameState.prestige_currency)


func _on_prestige_currency_changed(_v: int) -> void:
	_refresh_currency_label()
	for id in _cards.keys():
		_refresh_card(id)


func _on_meta_purchased(_id: StringName, _lv: int) -> void:
	_refresh_currency_label()
	for id in _cards.keys():
		_refresh_card(id)


func _build_cards() -> void:
	for child in meta_grid.get_children():
		child.queue_free()
	_cards.clear()
	var entries: Array = []
	for m: MetaUpgradeData in DataRegistry.meta_upgrades.values():
		if m.pillar == _current_pillar:
			entries.append(m)
	# 安価なものから順に並べる
	entries.sort_custom(func(a: MetaUpgradeData, b: MetaUpgradeData) -> bool:
		return a.base_cost < b.base_cost)
	for m: MetaUpgradeData in entries:
		var card := _make_card(m)
		meta_grid.add_child(card)
		_cards[m.id] = card
		_refresh_card(m.id)


func _make_card(m: MetaUpgradeData) -> PanelContainer:
	var color: Color = UIConstants.PILLAR_COLORS.get(m.pillar, Color(1, 1, 1, 1))

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = UIConstants.RARITY_PANEL_BG
	sbox.border_color = color
	sbox.set_border_width_all(2)
	sbox.set_corner_radius_all(8)
	sbox.content_margin_left = 12
	sbox.content_margin_right = 12
	sbox.content_margin_top = 10
	sbox.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sbox)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	# Header: name + Lv
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vb.add_child(header)

	var name_label := Label.new()
	name_label.text = tr(m.display_name)
	name_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	name_label.modulate = color
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)

	var lv_label := Label.new()
	lv_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	header.add_child(lv_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = tr(m.description)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.theme_type_variation = UIConstants.VAR_SUBTITLE_LABEL
	desc_label.modulate = Color(1, 1, 1, 0.82)
	vb.add_child(desc_label)

	# Footer: cost + buy
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vb.add_child(footer)

	var cost_label := Label.new()
	cost_label.theme_type_variation = UIConstants.VAR_TITLE_LABEL
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(cost_label)

	var buy_button := Button.new()
	buy_button.text = tr("META_BUY_BUTTON")
	buy_button.add_theme_color_override("font_color", color)
	buy_button.custom_minimum_size = Vector2(140, 36)
	buy_button.pressed.connect(_on_buy_pressed.bind(m.id))
	footer.add_child(buy_button)

	panel.set_meta("meta_id", m.id)
	panel.set_meta("lv_label", lv_label)
	panel.set_meta("cost_label", cost_label)
	panel.set_meta("buy_button", buy_button)
	panel.set_meta("stylebox", sbox)
	panel.set_meta("name_label", name_label)
	panel.set_meta("desc_label", desc_label)
	return panel


func _refresh_card(id: StringName) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var m := DataRegistry.get_meta_upgrade(id)
	if m == null:
		return
	var lv := GameState.get_meta_level(id)
	var lv_label: Label = card.get_meta("lv_label")
	var cost_label: Label = card.get_meta("cost_label")
	var buy_button: Button = card.get_meta("buy_button")
	var sbox: StyleBoxFlat = card.get_meta("stylebox")

	var maxed := MetaUpgradeService.is_max_level(id)
	if maxed:
		lv_label.text = tr("META_LV_MAX_FMT") % lv
		cost_label.text = tr("WORK_UPGRADE_COST_MAX")
		buy_button.disabled = true
		sbox.bg_color = UIConstants.RARITY_PANEL_BG_DISABLED
	else:
		lv_label.text = tr("META_LV_FMT") % lv
		var cost := MetaUpgradeService.current_cost(id)
		cost_label.text = tr("META_COST_FMT") % FormatUtils.short(cost)
		var can_buy := MetaUpgradeService.can_buy(id)
		buy_button.disabled = not can_buy
		sbox.bg_color = UIConstants.RARITY_PANEL_BG if can_buy else UIConstants.RARITY_PANEL_BG_DISABLED


func _on_buy_pressed(id: StringName) -> void:
	MetaUpgradeService.buy(id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_currency_label()
		_rebuild_static_text()


func _rebuild_static_text() -> void:
	for id in _cards.keys():
		var card: PanelContainer = _cards[id]
		var m := DataRegistry.get_meta_upgrade(id)
		if m == null:
			continue
		(card.get_meta("name_label") as Label).text = tr(m.display_name)
		(card.get_meta("desc_label") as Label).text = tr(m.description)
		(card.get_meta("buy_button") as Button).text = tr("META_BUY_BUTTON")
		_refresh_card(id)
