extends Control

# Shopタブ。雑貨店ではなく「ターミナル端末で物資をオーダー」する想定。
# 他タブを直接参照しない。ShopService 経由でのみ購入処理を行う。
#
# 役割は orchestrator に絞り、カード組み立て・更新は ItemCardFactory に委譲。
# 見出し・カテゴリピル等のスタイルは ThemeFactory が一元管理。

@onready var category_bar: VBoxContainer = %CategoryBar
@onready var item_grid: GridContainer = %ItemGrid
@onready var empty_label: Label = %EmptyLabel

const CATEGORY_ENTRIES := [
	{ "label_key": "CATEGORY_DAILY", "value": Enums.ItemCategory.DAILY },
	{ "label_key": "CATEGORY_HOBBY", "value": Enums.ItemCategory.HOBBY },
	{ "label_key": "CATEGORY_BODY_CARE", "value": Enums.ItemCategory.BODY_CARE },
	{ "label_key": "CATEGORY_ROMANCE", "value": Enums.ItemCategory.ROMANCE },
	{ "label_key": "CATEGORY_DIRECT_TOY", "value": Enums.ItemCategory.DIRECT_TOY },
	{ "label_key": "CATEGORY_DIRECT_DRUG", "value": Enums.ItemCategory.DIRECT_DRUG },
	{ "label_key": "CATEGORY_DIRECT_BIND", "value": Enums.ItemCategory.DIRECT_BIND },
	{ "label_key": "CATEGORY_DIRECT_PROT", "value": Enums.ItemCategory.DIRECT_PROT },
	{ "label_key": "CATEGORY_COS_OUTFIT", "value": Enums.ItemCategory.COS_OUTFIT },
	{ "label_key": "CATEGORY_COS_PARTS", "value": Enums.ItemCategory.COS_PARTS },
	{ "label_key": "CATEGORY_INVITATION", "value": Enums.ItemCategory.INVITATION },
	{ "label_key": "CATEGORY_RULE", "value": Enums.ItemCategory.RULE },
	{ "label_key": "CATEGORY_SCOPE", "value": Enums.ItemCategory.SCOPE },
]

var _selected_category: int = Enums.ItemCategory.DAILY
var _card_factory: ItemCardFactory
var _cards: Dictionary = {}
# カテゴリタイル：cat -> PanelContainer。選択中タイルだけアクセント表示にする。
var _category_tiles: Dictionary = {}


func _ready() -> void:
	_card_factory = ItemCardFactory.new(self)
	_card_factory.buy_requested.connect(_on_buy_requested)

	EventBus.currency_changed.connect(_refresh_all_cards)
	EventBus.item_purchased.connect(_on_item_purchased)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.meta_upgrade_purchased.connect(_on_meta_upgrade_purchased)

	_build_category_buttons()
	_rebuild_item_grid()


# --- カテゴリバー -------------------------------------------------------

func _build_category_buttons() -> void:
	_category_tiles.clear()
	for child in category_bar.get_children():
		child.queue_free()
	for entry in CATEGORY_ENTRIES:
		var tile := _make_category_tile(entry.label_key, entry.value)
		category_bar.add_child(tile)
		_category_tiles[entry.value] = tile
	_update_tile_selection()


# カテゴリタイル：アイコン上＋ラベル下の縦レイアウト。Button の標準レイアウトでは
# 縦並びが組めないので、PanelContainer + VBox(TextureRect/Label) で作って
# gui_input をクリック検出に使う。OperatorCardFactory と同じパターン。
func _make_category_tile(label_key: String, cat: int) -> PanelContainer:
	var accent: Color = ItemCardFactory.CATEGORY_ACCENTS.get(cat, UIConstants.COLOR_ACCENT_CYAN)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 68)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.set_meta("cat", cat)
	panel.set_meta("accent", accent)
	panel.add_theme_stylebox_override("panel", _make_tile_stylebox(accent, false))
	panel.gui_input.connect(_on_tile_input.bind(cat))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)

	var icon_rect := TextureRect.new()
	icon_rect.texture = ItemCardFactory.CATEGORY_ICONS.get(cat, null)
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.modulate = accent
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_rect)

	var label := Label.new()
	label.text = label_key  # Button.text と同様、Label.text に翻訳キーを入れれば Godot が自動 tr する
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", UIConstants.FONT_SMALL)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(label)

	return panel


# 選択中だけ太枠＋背景色違いに切り替える StyleBox を生成。
func _make_tile_stylebox(accent: Color, is_selected: bool) -> StyleBoxFlat:
	var sbox := StyleBoxFlat.new()
	if is_selected:
		sbox.bg_color = UIConstants.COLOR_BG_HEADER
		sbox.border_color = accent
		sbox.border_width_left = UIConstants.ACCENT_STRIPE_WIDTH
		sbox.border_width_top = UIConstants.HAIRLINE
		sbox.border_width_right = UIConstants.HAIRLINE
		sbox.border_width_bottom = UIConstants.HAIRLINE
	else:
		sbox.bg_color = UIConstants.COLOR_BG_PANEL_DEEP
		sbox.border_color = UIConstants.COLOR_BORDER
		sbox.set_border_width_all(UIConstants.HAIRLINE)
	sbox.set_corner_radius_all(UIConstants.PANEL_CORNER_RADIUS)
	sbox.content_margin_left = 8
	sbox.content_margin_right = 8
	sbox.content_margin_top = 8
	sbox.content_margin_bottom = 8
	return sbox


func _update_tile_selection() -> void:
	for cat in _category_tiles:
		var tile: PanelContainer = _category_tiles[cat]
		var accent: Color = tile.get_meta("accent")
		var is_sel: bool = (cat == _selected_category)
		tile.add_theme_stylebox_override("panel", _make_tile_stylebox(accent, is_sel))


func _on_tile_input(event: InputEvent, cat: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_category_pressed(cat)


func _on_category_pressed(cat: int) -> void:
	if _selected_category == cat:
		return
	_selected_category = cat
	_update_tile_selection()
	_rebuild_item_grid()


# --- 商品グリッド -------------------------------------------------------

func _rebuild_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	_cards.clear()

	var items: Array = []
	for it: ItemData in DataRegistry.get_items_by_category(_selected_category):
		# メタ強化によるゲート：requires_meta が未解放なら陳列しない
		if it.requires_meta != &"" and not GameState.has_meta_unlock(it.requires_meta):
			continue
		items.append(it)
	# 価格昇順で並べる
	items.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.price < b.price)

	empty_label.visible = items.is_empty()
	for it: ItemData in items:
		var card := _card_factory.build(it)
		item_grid.add_child(card)
		_cards[it.id] = card
		_card_factory.refresh(card, it)


func _refresh_all_cards(_v: int = 0) -> void:
	for id in _cards.keys():
		var it := DataRegistry.get_item(id)
		if it != null:
			_card_factory.refresh(_cards[id], it)


# --- イベントハンドラ ---------------------------------------------------

func _on_buy_requested(id: StringName, qty: int) -> void:
	ShopService.buy(id, qty)


func _on_item_purchased(id: StringName) -> void:
	var card: PanelContainer = _cards.get(id)
	if card != null:
		var it := DataRegistry.get_item(id)
		if it != null:
			_card_factory.play_purchase_feedback(card, it)
	_refresh_all_cards()


func _on_inventory_changed(id: StringName, _new_count: int) -> void:
	var card: PanelContainer = _cards.get(id)
	if card == null:
		return
	var it := DataRegistry.get_item(id)
	if it != null:
		_card_factory.refresh(card, it)


func _on_meta_upgrade_purchased(_meta_id: StringName, _new_level: int) -> void:
	_rebuild_item_grid()


# --- i18n ---------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		# カテゴリボタンは Button.text に翻訳キーが入っているので Godot が自動再翻訳する。
		# カード側は tr() 経由で組み立てた文言を含むため、明示的に貼り直し＋数値再描画する。
		for id in _cards.keys():
			var it := DataRegistry.get_item(id)
			if it == null:
				continue
			_card_factory.rebuild_static_text(_cards[id], it)
		_refresh_all_cards()
