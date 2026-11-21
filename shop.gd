extends PanelContainer
## The CRUNCH SHOP: kaijus, food, upgrades. Built in code, styled like the rest of the UI.

const Cfg := preload("res://config.gd")
const KaijuScript := preload("res://kaiju.gd")
const IconScript := preload("res://icon.gd")
const OUT := Color("1d2433")
const TABS := ["KAIJUS", "FOOD", "UPGRADES"]

var main: Node
var px := 1.0
var font: Font
var big_font: Font
var coin_tex: Texture2D
var tab := 0
var tab_btns: Array = []
var pages: Array = []
var cards := {}            # id -> refs
var previews: Array = []   # kaiju preview nodes (animated)
var coin_lbl: Label
var coin_box: Control
var close_btn: Button
var t := 0.0

func setup(m: Node) -> void:
	main = m
	px = m.px
	font = m.FONT
	big_font = m.BIG_FONT
	coin_tex = m.coin_tex
	var psb := _sb(Color("fff7e6"), 20, 4)
	psb.shadow_color = Color(0, 0, 0, 0.38)
	psb.shadow_size = int(12 * px)
	psb.shadow_offset = Vector2(0, 5) * px
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		psb.set_content_margin(side, 16 * px)
	psb.content_margin_top = 10 * px
	psb.content_margin_bottom = 14 * px
	add_theme_stylebox_override("panel", psb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(8 * px))
	add_child(v)
	# header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", int(10 * px))
	v.add_child(hdr)
	var title := Label.new()
	title.text = "CRUNCH SHOP"
	title.add_theme_font_override("font", big_font)
	title.add_theme_font_size_override("font_size", int(32 * px))
	title.add_theme_color_override("font_color", Color("ffd23f"))
	title.add_theme_color_override("font_outline_color", OUT)
	title.add_theme_constant_override("outline_size", int(9 * px))
	hdr.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	var chip := PanelContainer.new()
	var csb := _sb(Color("2b2540"), 16, 3)
	csb.content_margin_left = 6 * px
	csb.content_margin_right = 12 * px
	csb.content_margin_top = 2 * px
	csb.content_margin_bottom = 2 * px
	chip.add_theme_stylebox_override("panel", csb)
	hdr.add_child(chip)
	coin_box = chip
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", int(6 * px))
	chip.add_child(ch)
	var ct := TextureRect.new()
	ct.texture = coin_tex
	ct.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ct.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ct.custom_minimum_size = Vector2(28, 28) * px
	ch.add_child(ct)
	coin_lbl = Label.new()
	coin_lbl.add_theme_font_override("font", big_font)
	coin_lbl.add_theme_font_size_override("font_size", int(24 * px))
	coin_lbl.add_theme_color_override("font_color", Color("ffd23f"))
	coin_lbl.custom_minimum_size = Vector2(64, 0) * px
	ch.add_child(coin_lbl)
	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(38, 38) * px
	close_btn.add_theme_font_override("font", big_font)
	close_btn.add_theme_font_size_override("font_size", int(20 * px))
	_style_btn(close_btn, Color("ff6b6b"), 19)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	close_btn.pressed.connect(main.close_shop)
	hdr.add_child(close_btn)
	# tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(8 * px))
	v.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40) * px
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", big_font)
		b.add_theme_font_size_override("font_size", int(19 * px))
		b.pressed.connect(set_tab.bind(i))
		tabs.add_child(b)
		tab_btns.append(b)
	# pages
	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ZERO
	v.add_child(holder)
	for i in 3:
		var g := GridContainer.new()
		g.columns = 2 if i == 0 else 3
		g.add_theme_constant_override("h_separation", int(10 * px))
		g.add_theme_constant_override("v_separation", int(10 * px))
		holder.add_child(g)
		pages.append(g)
	for id in Cfg.SPECIES_ORDER:
		pages[0].add_child(_kaiju_card(id))
	for id in Cfg.FOOD_ORDER:
		pages[1].add_child(_food_card(id))
	for id in Cfg.UPGRADE_ORDER:
		pages[2].add_child(_upgrade_card(id))
	var need := Vector2.ZERO
	for g in pages:
		need = need.max(g.get_combined_minimum_size())
	holder.custom_minimum_size = need
	set_tab(0, false)
	refresh()

# ---------- styling helpers ----------
func _sb(bg: Color, radius: int, border := 3, bc := OUT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius * px))
	s.set_border_width_all(int(border * px))
	s.border_color = bc
	s.anti_aliasing = true
	s.content_margin_left = 10 * px
	s.content_margin_right = 10 * px
	s.content_margin_top = 4 * px
	s.content_margin_bottom = 4 * px
	return s

func _style_btn(b: Button, col: Color, radius := 10) -> void:
	var n := _sb(col, radius)
	n.shadow_color = Color(0, 0, 0, 0.0)
	n.border_width_bottom = int(6 * px)
	var h := _sb(col.lightened(0.18), radius)
	h.border_width_bottom = int(6 * px)
	var p := _sb(col.darkened(0.12), radius)
	p.border_width_top = int(6 * px)
	var d := _sb(col.lerp(Color("cfc6b3"), 0.65), radius)
	d.border_width_bottom = int(3 * px)
	d.border_color = OUT.lerp(Color("cfc6b3"), 0.4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, OUT)
	b.add_theme_color_override("font_disabled_color", OUT.lerp(Color("cfc6b3"), 0.35))

func _label(text: String, size: int, col := OUT, big := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * px))
	l.add_theme_color_override("font_color", col)
	if big:
		l.add_theme_font_override("font", big_font)
	return l

func _card_base(col: Color) -> PanelContainer:
	var c := PanelContainer.new()
	var s := _sb(Color("fffdf6"), 14, 3)
	s.content_margin_left = 8 * px
	s.content_margin_right = 8 * px
	s.content_margin_top = 6 * px
	s.content_margin_bottom = 8 * px
	s.border_width_bottom = int(6 * px)
	s.set_meta("accent", col)
	c.add_theme_stylebox_override("panel", s)
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	return c

func _buy_btn(cb: Callable, col := Color("ffd25a")) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 38) * px
	b.add_theme_font_override("font", big_font)
	b.add_theme_font_size_override("font_size", int(17 * px))
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", int(22 * px))
	b.add_theme_constant_override("h_separation", int(6 * px))
	_style_btn(b, col)
	b.pressed.connect(cb)
	return b

func _icon_view(kind: String, sz: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(sz, sz) * px
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	var bs := _sb(Color("f1e6cc"), int(sz * 0.5), 0)
	bg.add_theme_stylebox_override("panel", bs)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = Vector2(sz, sz) * px
	holder.add_child(bg)
	var ic = IconScript.new()
	ic.kind = kind
	ic.font = font
	ic.pop = 1.0
	ic.show_label = false
	ic.position = Vector2(sz, sz) * 0.5 * px
	ic.scale = Vector2(px, px) * (sz / 74.0)
	holder.add_child(ic)
	holder.set_meta("icon", ic)
	return holder

# ---------- cards ----------
func _kaiju_card(id: String) -> Control:
	var info: Dictionary = Cfg.SPECIES[id]
	var c := _card_base(Color("62cc5c"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(8 * px))
	c.add_child(h)
	var pv := Control.new()
	pv.custom_minimum_size = Vector2(116, 150) * px
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage_bg := Panel.new()
	stage_bg.add_theme_stylebox_override("panel", _sb(Color("bfe6ff"), 12, 0))
	stage_bg.size = Vector2(116, 150) * px
	stage_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(stage_bg)
	var grass := Panel.new()
	grass.add_theme_stylebox_override("panel", _sb(Color("7fd16a"), 12, 0))
	grass.position = Vector2(0, 122) * px
	grass.size = Vector2(116, 28) * px
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(grass)
	var k = KaijuScript.new()
	k.species = id
	k.stage = 2
	var ks := 0.6 * px
	k.k = ks
	k.scale = Vector2(ks, ks)
	k.position = Vector2(58, 132) * px
	k.look = Vector2(0.5, -0.1)
	pv.add_child(k)
	previews.append(k)
	h.add_child(pv)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(1 * px))
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_label(info.name, 24, Color("2fa18b"), true))
	v.add_child(_label(info.title, 14, Color("6b7280")))
	var d := _label(info.desc, 13)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(170, 0) * px
	v.add_child(d)
	var stl := _label("", 14, Color("8a5a00"))
	v.add_child(stl)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var b := _buy_btn(_on_kaiju.bind(id))
	v.add_child(b)
	cards[id] = {"card": c, "btn": b, "status": stl, "kind": "kaiju", "kaiju": k}
	return c

func _food_card(id: String) -> Control:
	var info: Dictionary = Cfg.FOODS[id]
	var c := _card_base(Color("ff9f43"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(2 * px))
	c.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(6 * px))
	v.add_child(top)
	var iv := _icon_view("food_" + id, 58)
	top.add_child(iv)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(_label(info.name, 17, Color("e0602a"), true))
	var cnt := _label("", 14, Color("8a5a00"))
	tv.add_child(cnt)
	var d := _label(info.desc, 13)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(186, 36) * px
	v.add_child(d)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", int(6 * px))
	v.add_child(bh)
	var b := _buy_btn(_on_food_buy.bind(id))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(b)
	var b2 := _buy_btn(_on_food_drop.bind(id), Color("6fd3ff"))
	b2.text = "DROP"
	b2.custom_minimum_size = Vector2(70, 38) * px
	bh.add_child(b2)
	cards[id] = {"card": c, "btn": b, "btn2": b2, "status": cnt, "kind": "food", "icon": iv.get_meta("icon")}
	return c

func _upgrade_card(id: String) -> Control:
	var info: Dictionary = Cfg.UPGRADES[id]
	var c := _card_base(Color("6fd3ff"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(2 * px))
	c.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(6 * px))
	v.add_child(top)
	var iv := _icon_view("upg_" + id, 58)
	top.add_child(iv)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(_label(info.name, 17, Color("2b7bb9"), true))
	var lv := _label("", 14, Color("8a5a00"))
	tv.add_child(lv)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(110, 12) * px
	pips.draw.connect(_draw_pips.bind(pips, id))
	tv.add_child(pips)
	var d := _label(info.desc, 13)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(186, 36) * px
	v.add_child(d)
	var b := _buy_btn(_on_upgrade.bind(id), Color("8dff7a"))
	v.add_child(b)
	cards[id] = {"card": c, "btn": b, "status": lv, "kind": "upgrade", "pips": pips, "icon": iv.get_meta("icon")}
	return c

func _draw_pips(ctl: Control, id: String) -> void:
	var mx: int = Cfg.UPGRADES[id].max
	var lvl: int = main.upgrades.get(id, 0)
	var w := minf(14.0 * px, ctl.size.x / mx - 2 * px)
	for i in mx:
		var r := Rect2(Vector2(i * (w + 3 * px), 1 * px), Vector2(w, 9 * px))
		ctl.draw_rect(r.grow(1.5 * px), OUT)
		ctl.draw_rect(r, Color("8dff7a") if i < lvl else Color("e6dcc4"))

# ---------- state ----------
func set_tab(i: int, juice := true) -> void:
	tab = i
	for j in 3:
		pages[j].visible = j == i
		var b: Button = tab_btns[j]
		_style_btn(b, Color("ffd23f") if j == i else Color("eadfc6"), 12)
	if juice and main:
		main.sfx.play("pop", -6.0, 1.2 + i * 0.1)
		var b: Button = tab_btns[i]
		b.pivot_offset = b.size * 0.5
		var tw := create_tween()
		b.scale = Vector2(1.12, 1.12)
		tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	refresh()

func refresh() -> void:
	if main == null:
		return
	for id in Cfg.SPECIES_ORDER:
		var r: Dictionary = cards[id]
		var b: Button = r.btn
		var owned: bool = main.owned.has(id)
		b.icon = null
		b.disabled = false
		if main.species == id:
			b.text = "ACTIVE"
			b.disabled = true
			r.status.text = "Lv %d  %s" % [main.level, main.STAGE_NAMES[main.stage()]]
		elif owned:
			b.text = "SWITCH"
			_style_btn(b, Color("6fd3ff"))
			var sd: Dictionary = main.species_data.get(id, {})
			var lv := int(sd.get("level", 1))
			r.status.text = ("Lv %d  %s" % [lv, main.STAGE_NAMES[main.stage_of(lv)]]) if sd.get("hatched", false) else "Egg - ready to hatch"
		else:
			var price: int = Cfg.SPECIES[id].price
			b.text = "BUY  %d" % price
			b.icon = coin_tex
			_style_btn(b, Color("ffd25a") if main.coins >= price else Color("eadfc6"))
			r.status.text = "Not owned"
		if b.disabled:
			_style_btn(b, Color("8dff7a"))
	for id in Cfg.FOOD_ORDER:
		var r: Dictionary = cards[id]
		var price: int = Cfg.FOODS[id].price
		r.btn.text = "%d" % price
		r.btn.icon = coin_tex
		_style_btn(r.btn, Color("ffd25a") if main.coins >= price else Color("eadfc6"))
		var n: int = main.inventory.get(id, 0)
		r.status.text = "Owned: %d" % n
		r.btn2.disabled = n <= 0
	for id in Cfg.UPGRADE_ORDER:
		var r: Dictionary = cards[id]
		var lvl: int = main.upgrades.get(id, 0)
		var mx: int = Cfg.UPGRADES[id].max
		r.status.text = "Lv %d / %d" % [lvl, mx]
		if lvl >= mx:
			r.btn.text = "MAXED"
			r.btn.icon = null
			r.btn.disabled = true
		else:
			var cost := Cfg.upgrade_cost(id, lvl)
			r.btn.text = "UPGRADE  %d" % cost
			r.btn.icon = coin_tex
			r.btn.disabled = false
			_style_btn(r.btn, Color("8dff7a") if main.coins >= cost else Color("eadfc6"))
		r.pips.queue_redraw()

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	coin_lbl.text = str(int(round(main.coins_shown)))
	for i in previews.size():
		var k = previews[i]
		k.tail_t = t + i
		k.glow_t = t
		k.blink = 1.0 if fmod(t + i * 1.3, 3.7) < 0.12 else 0.0
		var sel: bool = main.species == k.species
		k.happy = 1.0 if sel else 0.0
		var b := sin(t * 3.0 + i) * 0.025
		var ks: float = 0.6 * px
		k.scale = Vector2(ks * (1.0 + b), ks * (1.0 - b))
		k.queue_redraw()
	for id in cards:
		if cards[id].has("icon"):
			var ic = cards[id].icon
			ic.t = t
			ic.queue_redraw()

# ---------- actions + juice ----------
func _ok(id: String, amount: int, btn: Control, big := false) -> void:
	var r: Dictionary = cards[id]
	var c: Control = r.card
	main.sfx.play("buy", 0.0, 1.0)
	var tw := create_tween()
	c.scale = Vector2(1.14, 1.14)
	c.modulate = Color(1.7, 1.7, 1.3)
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate", Color.WHITE, 0.35)
	var bc := btn.get_global_rect().get_center()
	main.ui_fx.stars(bc, 14 if not big else 26, 0.8 if not big else 1.3)
	main.ui_fx.ring(bc, 120.0 * px, Color("ffd23f"), 0.5)
	if amount > 0:
		main.ui_fx.text(bc + Vector2(0, -24 * px), "-%d" % amount, 30, Color("ff6b6b"), 1.1, true, 80.0)
	var cb := coin_box
	cb.pivot_offset = cb.size * 0.5
	var t2 := create_tween()
	cb.scale = Vector2(1.25, 1.25)
	t2.tween_property(cb, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if r.has("icon"):
		var ic = r.icon
		var t3 := create_tween()
		ic.rotation = -0.35
		t3.tween_property(ic, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	refresh()

func _fail(id: String, need: int, btn: Control) -> void:
	var c: Control = cards[id].card
	main.sfx.play("buzz", -4.0)
	var tw := create_tween()
	for i in 6:
		tw.tween_property(c, "rotation", (0.035 if i % 2 == 0 else -0.035), 0.04)
	tw.tween_property(c, "rotation", 0.0, 0.04)
	c.modulate = Color(1.0, 0.7, 0.7)
	tw.parallel().tween_property(c, "modulate", Color.WHITE, 0.3)
	main.ui_fx.text(btn.get_global_rect().get_center() + Vector2(0, -24 * px), "Need %d more!" % need, 22, Color("ff6b6b"), 1.2, true, 50.0)

func _on_kaiju(id: String) -> void:
	var btn: Button = cards[id].btn
	if main.species == id:
		return
	if main.owned.has(id):
		main.switch_species(id)
		_ok(id, 0, btn)
		return
	var price: int = Cfg.SPECIES[id].price
	if main.spend(price):
		main.owned.append(id)
		main.save_now()
		_ok(id, price, btn, true)
		main.ui_fx.text(cards[id].card.get_global_rect().get_center() + Vector2(0, -60 * px), "NEW KAIJU!", 34, Color("ffd23f"), 1.4, true, 40.0)
	else:
		_fail(id, price - main.coins, btn)

func _on_food_buy(id: String) -> void:
	var btn: Button = cards[id].btn
	var price: int = Cfg.FOODS[id].price
	if main.spend(price):
		main.inventory[id] = int(main.inventory.get(id, 0)) + 1
		main.save_now()
		_ok(id, price, btn)
	else:
		_fail(id, price - main.coins, btn)

func _on_food_drop(id: String) -> void:
	if int(main.inventory.get(id, 0)) <= 0:
		return
	main.sfx.play("pop", -2.0, 0.9)
	main.drop_food(id)
	refresh()

func _on_upgrade(id: String) -> void:
	var btn: Button = cards[id].btn
	var lvl: int = main.upgrades.get(id, 0)
	if lvl >= Cfg.UPGRADES[id].max:
		return
	var cost := Cfg.upgrade_cost(id, lvl)
	if main.spend(cost):
		main.upgrades[id] = lvl + 1
		main.save_now()
		_ok(id, cost, btn)
		main.ui_fx.text(btn.get_global_rect().get_center() + Vector2(0, -60 * px), "LV %d!" % (lvl + 1), 26, Color("8dff7a"), 1.2, true, 60.0)
	else:
		_fail(id, cost - main.coins, btn)

func button_for(id: String, second := false) -> Control:
	return cards[id].btn2 if second else cards[id].btn
