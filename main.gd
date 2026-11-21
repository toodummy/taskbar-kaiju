extends Node2D
## Taskbar Kaiju - desktop pet prototype.
## SAFETY: this game never touches real files or real desktop icons. The only
## file it writes is its own save (user://save.json). Every "icon" it eats is a
## fake sprite spawned by this script (see icon.gd).

const KaijuScript := preload("res://kaiju.gd")
const IconScript := preload("res://icon.gd")
const FxScript := preload("res://fx.gd")
const SfxScript := preload("res://sfx.gd")
const FaceScript := preload("res://ui_face.gd")
const FONT := preload("res://fonts/LilitaOne-Regular.ttf")
const BIG_FONT := preload("res://fonts/LuckiestGuy-Regular.ttf")
const Cfg := preload("res://config.gd")
const ShopScript := preload("res://shop.gd")
const HudScript := preload("res://hud.gd")
const CursorScript := preload("res://cursor.gd")

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const STAGE_NAMES := ["Hatchling", "Chunky", "Brute", "Titan", "KAIJU"]
const STAGE_LEVEL := [1, 4, 8, 13, 19]
const STAGE_SCALE := [0.8, 1.15, 1.6, 2.3, 6.2]
const GIANT_SINK := 178.0
const MOUTH := Vector2(23, -36)
const OFFLINE_CAP := 8.0 * 3600.0
const OUT := Color("1d2433")

# --- persistent state ---
var xp := 0.0
var level := 1
var mood := 80.0
var eaten := 0
var fed := 0
var born := 0.0
var hatched := false
var muted := false
# v2: economy + collection (balance numbers live in config.gd)
var coins := 0
var species := "dino"
var species_data := {}     # id -> {xp, level, mood, eaten, fed, born, hatched}
var owned: Array = ["dino"]
var inventory := {}        # food id -> count
var upgrades := {}         # upgrade id -> level
var xp_boost_t := 0.0
var frenzy_t := 0.0

# --- runtime ---
var W := 1280.0
var H := 720.0
var floor_y := 700.0
var floor_off := 0.0
var px := 1.0
var demo := false
var fresh := false
var pass_mode := "poly"
var px_override := 0.0
var want_debug_region := false
var debug_region: Node2D = null
var demo_eats := 0
var world: Node2D
var clip: Control
var kaiju: Node2D
var icon_layer: Node2D
var fx: Node2D
var sfx: Node
var ui: CanvasLayer
var face_btn: Control
var panel: PanelContainer
var lbl := {}
var xp_bar: ProgressBar
var mood_bar: ProgressBar
var mood_fill: StyleBoxFlat
var btn_mute: Button
var btn_reset: Button
var reset_armed := 0.0
var snack_cd := 0.0
var icons: Array = []

var kx := 300.0
var face := 1.0
var st := "idle"
var st_t := 0.0
var st_dur := 0.0
var target_x := 300.0
var target_icon: Node2D = null
var disp_scale := 0.8
var y_off := 0.0
var squash := 0.0
var squash_v := 0.0
var mouth_cur := 0.0
var phase := 0.0
var last_step := 0
var blink_t := 2.0
var blink_v := 0.0
var happy_v := 0.0
var happy_t := 0.0
var angry_v := 0.0
var rampage := false
var pending_stage := -1
var pending_level := false
var next_hunt := 12.0
var next_spawn := 3.0
var next_wander := 2.0
var next_chatter := 25.0
var shake := 0.0
var time := 0.0
var autosave_t := 0.0
var passive_acc := 0.0
var pet_times: Array = []
var dragging: Node2D = null
var drag_off := Vector2.ZERO
var drag_prev := Vector2.ZERO
var last_pass_key := ""
var last_pass_flag := -1
var grow_from := 0.8
var grow_to := 0.8
var chew_burp := true
var demo_queue: Array = []
var demo_wait := 0.0
var demo_fake_drag: Dictionary = {}
var demo2 := false
var coins_shown := 0.0
var coin_tex: Texture2D
var coin_pet_cd := 0.0
var shop: PanelContainer
var hud: Control
var ui_fx: Node2D
var fake_cursor: Node2D
var burned := 0
var fire_acc := 0.0
var pending_fire := false
var hatch_speed := 1.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	# Windows: the passthrough polygon (SetWindowRgn) also clips DRAWING, so the region must
	# cover everything visible -> "region" mode. Linux/macOS only clip input -> "poly".
	pass_mode = "region" if OS.get_name() == "Windows" else "poly"
	for a in args:
		if a == "--demo": demo = true
		elif a == "--demo2": demo = true; demo2 = true
		elif a == "--fresh": fresh = true
		elif a.begins_with("--floor="): floor_off = float(a.split("=")[1])
		elif a.begins_with("--passthrough="): pass_mode = a.split("=")[1]
		elif a.begins_with("--px="): px_override = float(a.split("=")[1])
		elif a == "--debug-region": want_debug_region = true
	get_tree().set_auto_accept_quit(false)
	_setup_window()
	world = Node2D.new()
	add_child(world)
	icon_layer = Node2D.new()
	world.add_child(icon_layer)
	clip = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2.ZERO
	clip.size = Vector2(W, floor_y + 1)
	world.add_child(clip)
	kaiju = KaijuScript.new()
	clip.add_child(kaiju)
	fx = FxScript.new()
	fx.font = FONT
	fx.big_font = BIG_FONT
	fx.px = px
	world.add_child(fx)
	sfx = SfxScript.new()
	add_child(sfx)
	born = Time.get_unix_time_from_system()
	coins = Cfg.START_COINS
	coin_tex = HudScript.make_coin_texture(int(64))
	if demo2:
		_setup_demo2()
	elif demo:
		_setup_demo()
	else:
		if not fresh:
			_load()
		_offline_catchup()
	coins_shown = coins
	kaiju.species = species
	sfx.muted = muted
	sfx.log_events = demo
	disp_scale = STAGE_SCALE[stage()] * px
	if stage() == 4:
		y_off = GIANT_SINK * px
	kx = W * 0.35
	target_x = kx
	if not hatched:
		st = "egg"
		kx = W * 0.5
	_build_ui()
	_refresh_ui()
	if demo2:
		_run_demo2()
	if has_meta("migrated"):
		var gift: int = get_meta("migrated")
		get_tree().create_timer(2.0).timeout.connect(func(): fx.say("NEW: the CRUNCH SHOP!\nHere's %d Crunch for\nbeing an OG. Spend it!" % gift, 5.0))
	if want_debug_region:
		debug_region = Node2D.new()
		debug_region.z_index = 100
		debug_region.draw.connect(_draw_debug_region)
		var cl := CanvasLayer.new()
		cl.layer = 20
		add_child(cl)
		cl.add_child(debug_region)

func _draw_debug_region() -> void:
	for r in debug_region.get_meta("rects", []):
		debug_region.draw_rect(r, Color(1, 0, 1, 0.12))
		debug_region.draw_rect(r, Color(1, 0, 1, 0.9), false, 2.0)

func _setup_window() -> void:
	var win := get_window()
	var scr := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(scr)
	var full := DisplayServer.screen_get_size(scr)
	if area.size == full:
		area.size.y -= 1   # avoid the OS treating us as a fullscreen app
	win.borderless = true
	win.always_on_top = true
	win.transparent = true
	win.position = area.position
	win.size = area.size
	W = area.size.x
	H = area.size.y
	px = clampf(snappedf(H / 1040.0, 0.25), 1.0, 3.0)
	if px_override > 0.0:
		px = px_override
	floor_y = H - floor_off

func stage() -> int:
	return stage_of(level)

func stage_of(lv: int) -> int:
	var s := 0
	for i in STAGE_LEVEL.size():
		if lv >= STAGE_LEVEL[i]:
			s = i
	return s

func sp() -> Dictionary:
	return Cfg.SPECIES[species]

func upg(id: String) -> int:
	return int(upgrades.get(id, 0))

func upg_val(id: String) -> float:
	return upg(id) * float(Cfg.UPGRADES[id].per)

# ---------------- economy ----------------
func add_coins(n: int, from := Vector2(-1, -1), show := true) -> void:
	if n <= 0:
		return
	coins += n
	if show and from.x >= 0.0 and hud != null:
		fx.coins(from, hud.coin_center(), clampi(n, 2, 8))
		fx.text(from + Vector2(-30 * px * face, -50 * px), "+%d" % n, 24, Color("ffd23f"), 1.2, true)
	elif hud != null:
		coins_shown = coins
		hud.bump = 1.0

func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	return true

func save_now() -> void:
	_save()

func _on_coin_landed() -> void:
	coins_shown = minf(coins, coins_shown + maxf(1.0, (coins - coins_shown) * 0.35))
	hud.bump = 1.0
	sfx.play("coin", -12.0, randf_range(0.95, 1.15))

func xp_need(l: int) -> float:
	return floor(18.0 * pow(1.3, l - 1))

func feet() -> Vector2:
	return Vector2(kx, floor_y + y_off)

func mouth_pos() -> Vector2:
	return feet() + Vector2(MOUTH.x * face, MOUTH.y) * disp_scale

# ---------------- save / load ----------------
func _store_species() -> void:
	species_data[species] = {"xp": xp, "level": level, "mood": mood, "eaten": eaten, "fed": fed, "born": born, "hatched": hatched}

func _load_species(id: String) -> void:
	var d: Dictionary = species_data.get(id, {})
	xp = float(d.get("xp", 0.0)); level = int(d.get("level", 1)); mood = float(d.get("mood", 80.0))
	eaten = int(d.get("eaten", 0)); fed = int(d.get("fed", 0))
	born = float(d.get("born", Time.get_unix_time_from_system())); hatched = bool(d.get("hatched", false))

func _save() -> void:
	if demo:
		return
	_store_species()
	var d := {"v": SAVE_VERSION, "coins": coins, "species": species, "species_data": species_data, "owned": owned,
		"inventory": inventory, "upgrades": upgrades, "muted": muted, "last": Time.get_unix_time_from_system()}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	muted = d.get("muted", false)
	set_meta("last", d.get("last", Time.get_unix_time_from_system()))
	if int(d.get("v", 1)) < 2:
		# migrate a v1 save: the old pet becomes the dino, plus a welcome gift
		species_data = {"dino": {"xp": d.get("xp", 0.0), "level": d.get("level", 1), "mood": d.get("mood", 80.0),
			"eaten": d.get("eaten", 0), "fed": d.get("fed", 0), "born": d.get("born", born), "hatched": d.get("hatched", false)}}
		species = "dino"
		owned = ["dino"]
		var gift: int = Cfg.MIGRATION_GIFT_BASE + Cfg.MIGRATION_GIFT_PER_EATEN * int(d.get("eaten", 0))
		coins = gift
		set_meta("migrated", gift)
	else:
		coins = int(d.get("coins", 0))
		species_data = d.get("species_data", {})
		owned = d.get("owned", ["dino"])
		species = str(d.get("species", "dino"))
		if not Cfg.SPECIES.has(species) or not owned.has(species):
			species = "dino"
		for k in d.get("inventory", {}):
			inventory[k] = int(d.inventory[k])
		for k in d.get("upgrades", {}):
			upgrades[k] = int(d.upgrades[k])
	_load_species(species)

func _offline_catchup() -> void:
	if not has_meta("last") or not hatched:
		return
	var away := clampf(Time.get_unix_time_from_system() - float(get_meta("last")), 0.0, OFFLINE_CAP)
	if away < 60.0:
		return
	var dream := 1.0 + upg_val("dreams")
	var gain := away / 60.0 * Cfg.OFFLINE_XP_PER_MIN * dream
	var cgain := int(away / 60.0 * Cfg.COIN_OFFLINE_PER_MIN * dream)
	var old_stage := stage()
	_add_xp(gain, false)
	coins += cgain
	mood = clampf(mood - away / Cfg.MOOD_OFFLINE_DIV * _mood_mult(), 0.0, 100.0)
	var msg := "You were gone %s.\nI grew %d XP, found %d Crunch" % [_dur(away), int(gain), cgain]
	if stage() > old_stage:
		msg += " and got BIGGER!"
	msg += "\n" + ("...and I'm HANGRY." if mood < 25.0 else "Feed me?")
	get_tree().create_timer(1.2).timeout.connect(func(): fx.say(msg, 5.0, mood < 25.0))
	for i in 4:
		_spawn_icon()

func _dur(s: float) -> String:
	var m := int(s / 60.0)
	if m < 60:
		return "%dm" % m
	if m < 24 * 60:
		return "%dh %02dm" % [m / 60, m % 60]
	return "%dd %dh" % [m / 1440, (m % 1440) / 60]

func _mood_mult() -> float:
	return float(sp().mood) * (1.0 - upg_val("chill"))

func _reset() -> void:
	coins = Cfg.START_COINS; coins_shown = coins; species = "dino"; kaiju.species = species
	species_data = {}; owned = ["dino"]; inventory = {}; upgrades = {}; xp_boost_t = 0.0; frenzy_t = 0.0
	if shop:
		shop.visible = false
		shop.refresh()
	xp = 0.0; level = 1; mood = 80.0; eaten = 0; fed = 0
	born = Time.get_unix_time_from_system(); hatched = false
	for ic in icons:
		ic.queue_free()
	icons.clear()
	target_icon = null
	disp_scale = STAGE_SCALE[0] * px
	y_off = 0.0
	rampage = false
	kx = W * 0.5
	_set_state("egg")
	_save()
	_refresh_ui()

# ---------------- progression ----------------
func _add_xp(amount: float, show := true) -> void:
	var old_stage := stage()
	var old_level := level
	xp += amount
	var lv_coins := 0
	while xp >= xp_need(level) and level < 30:
		xp -= xp_need(level)
		level += 1
		lv_coins += Cfg.COIN_LEVEL_BASE + Cfg.COIN_LEVEL_PER * level
	if lv_coins > 0:
		if show:
			set_meta("lv_coins", int(get_meta("lv_coins", 0)) + lv_coins)
		else:
			coins += lv_coins
	if show and level > old_level:
		pending_level = true
	if stage() > old_stage and show:
		pending_stage = stage()
	elif stage() > old_stage:
		disp_scale = STAGE_SCALE[stage()] * px
		y_off = GIANT_SINK * px if stage() == 4 else 0.0

func _demo_stage_up() -> void:
	var s := mini(stage() + 1, 4)
	if s == 4:
		mood = 75.0
		rampage = false
	var target_level: int = STAGE_LEVEL[s]
	var need := 0.0
	var l := level
	need -= xp
	while l < target_level:
		need += xp_need(l)
		l += 1
	_add_xp(need + 1.0)

# ---------------- icons ----------------
func _spawn_icon(kind := "", pos := Vector2(-1, -1)) -> Node2D:
	var ic: Node2D = IconScript.new()
	var kinds: Array = IconScript.KINDS.keys()
	if kind == "":
		var unused: Array = kinds.filter(func(kd): return not icons.any(func(o): return o.kind == kd))
		var pool: Array = unused if not unused.is_empty() else kinds
		kind = pool[randi() % pool.size()]
	ic.kind = kind
	ic.font = FONT
	ic.px = px
	ic.scale = Vector2(px, px)
	if pos.x < 0:
		pos = _free_slot()
	ic.position = pos
	icon_layer.add_child(ic)
	icons.append(ic)
	sfx.play("pop", -10.0, randf_range(0.9, 1.2))
	return ic

func _free_slot() -> Vector2:
	var cw := 104.0 * px
	var ch := 118.0 * px
	var best := Vector2(W * 0.5, H * 0.4)
	for tries in 40:
		var cx := randi_range(int(W * 0.2 / cw), int(W * 0.9 / cw))
		var cy := randi_range(1, maxi(1, int((floor_y - 260.0 * px) / ch)))
		var p := Vector2((cx + 0.5) * cw, (cy + 0.3) * ch)
		var ok := true
		for ic in icons:
			if ic.position.distance_to(p) < 90.0 * px:
				ok = false
				break
		if ok:
			return p
		best = p
	return best

func _icon_rect(ic: Node2D) -> Rect2:
	return Rect2(ic.position + Vector2(-38, -36) * px, Vector2(76, 94) * px)

func _icon_visual_rect(ic: Node2D) -> Rect2:
	var hw: float = ic.half_width() * px
	var e := 6.0 * px
	return Rect2(ic.position + Vector2(-hw - e, -44 * px - e), Vector2(hw * 2.0 + e * 2.0, 106 * px + e * 2.0))

func _update_icons(dt: float) -> void:
	var mp := get_viewport().get_mouse_position()
	var ground_y := floor_y - 29.0 * px
	for ic in icons.duplicate():
		ic.t += dt
		ic.pop = minf(1.0, ic.pop + dt * 3.5)
		ic.hover = dragging == null and _icon_rect(ic).has_point(mp)
		match ic.state:
			"shake":
				ic.rotation = sin(ic.t * 60.0) * 0.12
				if ic.t > 0.55:
					ic.state = "fall"
					ic.vel = Vector2(randf_range(-40, 40), -260) * px
					ic.spin = randf_range(-6, 6)
			"fall":
				ic.vel.y += 2400.0 * px * dt
				ic.position += ic.vel * dt
				ic.rotation += ic.spin * dt
				if ic.position.y >= ground_y:
					ic.position.y = ground_y
					if ic.vel.y > 500.0 * px:
						ic.vel.y *= -0.32
						ic.vel.x *= 0.5
						ic.spin *= -0.5
						sfx.play("plop", -6.0, randf_range(0.9, 1.1))
						fx.puff(Vector2(ic.position.x, floor_y - 4 * px), 3, Color(1, 1, 1, 0.8), 0.6)
					else:
						ic.state = "ground"
						ic.vel = Vector2.ZERO
			"ground":
				ic.rotation = lerp_angle(ic.rotation, 0.0, minf(1.0, dt * 10.0))
			"drag":
				ic.position = mp + drag_off
				var v: Vector2 = (ic.position - drag_prev) / maxf(dt, 0.001)
				ic.rotation = lerp_angle(ic.rotation, clampf(v.x / (2000.0 * px), -0.5, 0.5), minf(1.0, dt * 12.0))
				drag_prev = ic.position
			"burn":
				ic.rotation = sin(ic.t * 50.0) * 0.08
				var u := clampf(ic.t / 0.75, 0.0, 1.0)
				ic.modulate = Color(1, 1, 1).lerp(Color(0.25, 0.12, 0.08), u)
				if randf() < dt * 30.0:
					fx.flame(ic.position + Vector2(randf_range(-22, 22), 10) * px, Vector2(0, -1), 0.35)
				if ic.t > 0.75:
					_burn_done(ic)
			"eaten":
				var m := mouth_pos()
				ic.position = ic.position.lerp(m, minf(1.0, dt * 18.0))
				var s := maxf(0.05, ic.scale.x - dt * 3.0 * px)
				ic.scale = Vector2(s, s)
				ic.rotation += dt * 12.0
		ic.queue_redraw()

func _remove_icon(ic: Node2D) -> void:
	icons.erase(ic)
	if is_instance_valid(ic):
		ic.queue_free()

# ---------------- kaiju behaviour ----------------
func _set_state(s: String, dur := 0.0) -> void:
	st = s
	st_t = 0.0
	st_dur = dur

func _speed() -> float:
	var base := 60.0 * px * pow(disp_scale / px, 0.45)
	if stage() == 4:
		base = 70.0 * px
	base *= float(sp().speed)
	if rampage or frenzy_t > 0.0:
		base *= 1.8
	if st == "hunt":
		base *= 1.6
	return base

func _interruptible() -> bool:
	return st in ["idle", "walk", "notice", "wait_drop", "hunt", "pet"]

## (state names that are allowed to be interrupted by a dropped snack)

func _start_hunt(ic: Node2D) -> void:
	target_icon = ic
	face = signf(ic.position.x - kx) if absf(ic.position.x - kx) > 2.0 else face
	if ic.state == "desk":
		_set_state("notice", 0.7)
		fx.text(feet() + Vector2(0, -105) * disp_scale / px * px - Vector2(0, 10 * px), "!", 40, Color("ffd23f"), 0.8, true)
	else:
		_set_state("hunt")

func _pick_icon(kind := "") -> Node2D:
	var best: Node2D = null
	var bd := INF
	for ic in icons:
		if ic.state in ["drag", "eaten", "shake", "fall"]:
			continue
		if kind != "" and ic.kind != kind:
			continue
		var d := absf(ic.position.x - kx) + (0.0 if ic.state == "ground" else 150.0)
		if ic.is_food():
			d -= 100000.0
		if d < bd:
			bd = d
			best = ic
	return best

func _eat(ic: Node2D, by_hand: bool) -> void:
	target_icon = ic
	ic.state = "eaten"
	face = signf(ic.position.x - kx) if absf(ic.position.x - kx) > 4.0 else face
	_set_state("chomp", 0.26)
	set_meta("by_hand", by_hand)

func _chomp_now() -> void:
	var ic := target_icon
	var info: Dictionary = ic.info() if is_instance_valid(ic) else {"xp": 8, "col": Color.WHITE, "line": "Nom."}
	var by_hand: bool = get_meta("by_hand", false)
	print("[kaiju] ate ", ic.kind if is_instance_valid(ic) else "?", " by_hand=", by_hand, " level=", level)
	var m := mouth_pos()
	var power := sqrt(disp_scale / px)
	fx.crumbs(m, info.col, 16 + int(power * 4), power)
	fx.text(m + Vector2(0, -30 * px * power), "CHOMP!", int(30 * minf(2.2, power)), Color("ffd23f"), 0.9, true)
	sfx.play("chomp", 0.0, clampf(1.25 - disp_scale / px * 0.08, 0.6, 1.3))
	shake = maxf(shake, 5.0 * px * power)
	squash_v += 3.0
	var is_food: bool = is_instance_valid(ic) and ic.is_food()
	var gain: float = info.xp * (2.0 if by_hand else 1.0) * (1.0 + stage() * 0.25)
	gain *= (1.0 + upg_val("appetite")) * float(sp().xp) * (float(sp().fed_xp) if by_hand else 1.0)
	if xp_boost_t > 0.0:
		gain *= 2.0
	var c := (Cfg.COIN_BITE_BASE + float(info.xp) / Cfg.COIN_BITE_XP_DIV + upg("teeth")) * float(sp().coin)
	if by_hand:
		c *= Cfg.COIN_HANDFED_MULT
	if frenzy_t > 0.0:
		c *= Cfg.FRENZY_COIN_MULT
	if is_food:
		gain = 4.0
		c = 0.0
	add_coins(int(round(c)), m + Vector2(0, -10 * px))
	eaten += 1
	if by_hand:
		fed += 1
		mood = minf(100.0, mood + 14.0)
		fx.hearts(m + Vector2(0, -20 * px), 3)
	else:
		mood = minf(100.0, mood + 4.0)
	if demo and get_meta("demo_up", false):
		set_meta("demo_up", false)
		_demo_stage_up()
	else:
		_add_xp(gain)
	fx.text(m + Vector2(30 * px * face, -60 * px), "+%d XP" % int(gain), 22, Color("8dff7a"), 1.3)
	if is_food:
		_apply_food(ic.kind.substr(5))
	elif randf() < 0.75 or demo:
		get_tree().create_timer(0.35).timeout.connect(func(): fx.say(info.line, 2.2))
	if is_instance_valid(ic):
		_remove_icon(ic)
	target_icon = null
	_set_state("chew", 0.7)
	chew_burp = randf() < 0.7 or pending_stage >= 0
	if demo:
		chew_burp = demo_eats == 0 or stage() == 4
		demo_eats += 1
	if demo2:
		chew_burp = false
	_refresh_ui()

func _roar(big := false) -> void:
	_set_state("roar", 1.45 if demo else 1.7)
	var power := sqrt(disp_scale / px)
	var pitch := clampf(1.9 - stage() * 0.32, 0.62, 1.9)
	sfx.play("roar", 2.0 if big else 0.0, pitch)
	shake = maxf(shake, (16.0 if big else 9.0) * px * power * (1.0 + upg_val("roar")))
	if upg("roar") > 0 and hatched:
		add_coins(upg("roar") * 3, mouth_pos())

# ---------------- food ----------------
func drop_food(id: String) -> void:
	if int(inventory.get(id, 0)) <= 0:
		return
	inventory[id] = int(inventory[id]) - 1
	close_shop()
	panel.visible = false
	var x := clampf(kx + face * 190.0 * px, 80.0 * px, W - 160.0 * px)
	var ic := _spawn_icon("food_" + id, Vector2(x, -40.0 * px))
	ic.pop = 1.0
	ic.state = "fall"
	ic.vel = Vector2(0, 200.0 * px)
	ic.spin = randf_range(-4, 4)
	fx.text(Vector2(x, 120 * px), "SNACK!", 30, Color("ffd23f"), 1.0, true)
	if st != "egg" and _interruptible():
		target_icon = ic
		face = signf(x - kx) if absf(x - kx) > 2.0 else face
		_set_state("hunt")
	next_hunt = 0.0
	_save()

func _apply_food(id: String) -> void:
	var info: Dictionary = Cfg.FOODS[id]
	var head := feet() + Vector2(0, -110) * disp_scale
	var line: String = IconScript.FOOD_INFO["food_" + id].line
	print("[kaiju] ate food ", id)
	match id:
		"burger":
			xp_boost_t = float(info.dur)
			fx.text(head, "2x XP!", 40, Color("ffb347"), 1.6, true)
			fx.stars(mouth_pos(), 14, 0.9)
		"cake":
			mood = 100.0
			rampage = false
			fx.hearts(head, 8)
			happy_t = 2.0
			fx.text(head, "MOOD MAX!", 36, Color("ff8fc0"), 1.6, true)
		"soda":
			frenzy_t = float(info.dur)
			next_hunt = 0.4
			for i in 3:
				get_tree().create_timer(0.3 + i * 0.25).timeout.connect(func(): _spawn_icon())
			fx.text(head, "FRENZY!", 46, Color("ff4b4b"), 1.6, true)
			fx.ring(feet() + Vector2(0, -50) * disp_scale, 380.0 * px, Color("ff4b4b"), 0.8)
		"gummy":
			_add_xp(xp_need(level) - xp + 0.01)
			fx.text(head, "GROWTH!", 40, Color("6fe07a"), 1.6, true)
		"pepper":
			pending_fire = true
	get_tree().create_timer(0.35).timeout.connect(func(): fx.say(line, 2.0, id == "pepper" or id == "soda"))

func _fire_dir() -> Vector2:
	# sweep: up-forward, then turn around halfway and sweep the other side
	var u := clampf(st_t / st_dur, 0.0, 1.0)
	var half := fmod(u * 2.0, 1.0)
	var a := lerpf(-0.22, -1.25, sin(half * PI * 0.5 + 0.0) if u < 0.5 else 1.0 - sin(half * PI * 0.5))
	return Vector2(cos(a) * face, sin(a))

func _fire_power() -> float:
	return clampf(sqrt(disp_scale / px) * 1.5, 1.9, 3.2)

func _fire_tick(dt: float) -> void:
	var m := mouth_pos() + Vector2(6 * face, -4) * disp_scale
	var dir := _fire_dir()
	var pw := _fire_power()
	fire_acc += dt * 110.0
	while fire_acc >= 1.0:
		fire_acc -= 1.0
		fx.flame(m, dir, pw)
	shake = maxf(shake, 4.0 * px)
	var reach := 330.0 * px * pw
	for ic in icons.duplicate():
		if ic.state in ["eaten", "burn", "drag"] or ic.is_food():
			continue
		var v: Vector2 = ic.position - m
		if v.length() > reach:
			continue
		var da := absf(angle_difference(v.angle(), dir.angle()))
		if da < 0.2 + 40.0 * px / maxf(v.length(), 1.0):
			ic.state = "burn"
			ic.t = 0.0
			sfx.play("crack", -6.0, randf_range(0.6, 0.8))

func _burn_done(ic: Node2D) -> void:
	var info: Dictionary = ic.info()
	var p: Vector2 = ic.position
	fx.puff(p, 8, Color(0.3, 0.3, 0.32), 1.2)
	fx.crumbs(p, Color(0.2, 0.15, 0.12), 12, 0.8)
	var c := int(round((Cfg.COIN_BITE_BASE + float(info.xp) / Cfg.COIN_BITE_XP_DIV + upg("teeth")) * float(sp().coin) * Cfg.COIN_BURN_MULT * (Cfg.FRENZY_COIN_MULT if frenzy_t > 0.0 else 1.0)))
	add_coins(maxi(1, c), p)
	_add_xp(float(info.xp) * 0.5 * (1.0 + upg_val("appetite")))
	burned += 1
	fx.text(p + Vector2(0, -50 * px), ["ROASTED!", "TOASTY!", "CRISPY!", "WELL DONE!"][burned % 4], 26, Color("ff9f1c"), 1.0, true)
	sfx.play("pop", -6.0, 0.6)
	_remove_icon(ic)

func _update_kaiju(dt: float) -> void:
	st_t += dt
	var walking := false
	var mouth_tgt := 0.0
	var arms := 0.0
	var s := stage()
	match st:
		"egg":
			kaiju.egg = true
			st_t += dt * (hatch_speed - 1.0)
			kaiju.egg_crack = clampf(st_t / 3.2, 0.0, 1.0)
			kaiju.egg_wobble += dt * (6.0 + st_t * 6.0)
			if int(st_t * 2.0) != int((st_t - dt) * 2.0) and st_t > 0.8:
				sfx.play("crack", -4.0, randf_range(0.9, 1.3))
			if st_t > 3.4:
				kaiju.egg = false
				hatched = true
				sfx.play("pop", 0.0, 0.8)
				fx.crumbs(feet() + Vector2(0, -38 * px), Color("fff4dc"), 18, 1.2)
				fx.stars(feet() + Vector2(0, -40 * px), 10, 0.7)
				squash_v -= 6.0
				_set_state("idle")
				next_hunt = 8.0
				var hello: String = {"dino": "RAWR!\n(I'm hungry.)", "octo": "Blub blub!\n(feed me.)", "mecha": "BEEP BOOP.\nINITIATING SNACK.", "yeti": "Hrrmf! So warm\nin here. Snack?"}[species]
				get_tree().create_timer(0.5).timeout.connect(func(): fx.say(hello, 3.0))
				sfx.play("roar", -4.0, 1.9)
				if not demo2:
					for i in 4:
						get_tree().create_timer(1.5 + i * 0.4).timeout.connect(func(): _spawn_icon())
				_save()
		"idle":
			if not demo:
				next_wander -= dt
				if next_hunt <= 0.0 and _pick_icon() != null:
					_start_hunt(_pick_icon())
					next_hunt = randf_range(4.0, 7.0) if rampage else randf_range(25.0, 45.0)
				elif next_wander <= 0.0:
					next_wander = randf_range(3.0, 9.0) / (2.0 if rampage else 1.0)
					var margin := 70.0 * disp_scale
					target_x = clampf(kx + randf_range(-450, 450) * px, margin, W - margin - 90.0 * px)
					_set_state("walk")
		"walk":
			walking = _walk_to(target_x, dt)
			if not walking:
				_set_state("idle")
		"notice":
			mouth_tgt = 0.25
			if st_t > st_dur:
				if is_instance_valid(target_icon) and target_icon.state == "desk":
					target_icon.state = "shake"
					target_icon.t = 0.0
					_set_state("wait_drop")
				elif is_instance_valid(target_icon):
					_set_state("hunt")
				else:
					_set_state("idle")
		"wait_drop":
			mouth_tgt = 0.35
			if not is_instance_valid(target_icon) or target_icon.state in ["drag", "eaten"]:
				target_icon = null
				_set_state("idle")
			elif target_icon.state == "ground" or (target_icon.state == "fall" and st_t > 0.4):
				_set_state("hunt")
		"hunt":
			if not is_instance_valid(target_icon) or target_icon.state in ["drag", "eaten", "desk"]:
				target_icon = null
				_set_state("idle")
			else:
				var ix: float = target_icon.position.x
				var f := signf(ix - kx) if absf(ix - kx) > MOUTH.x * disp_scale * 0.5 else face
				var tx := ix - f * MOUTH.x * disp_scale
				mouth_tgt = 0.3 if absf(tx - kx) > 60 * px else 0.8
				if absf(tx - kx) < 5.0 * px and target_icon.state == "ground":
					face = f
					_eat(target_icon, false)
				else:
					walking = _walk_to(tx, dt)
					if not walking and target_icon.state == "ground":
						_eat(target_icon, false)
		"chomp":
			mouth_tgt = 1.0
			if st_t > st_dur:
				_chomp_now()
		"chew":
			mouth_tgt = 0.25 + 0.25 * sin(st_t * 28.0)
			if st_t > st_dur:
				if pending_fire:
					pending_fire = false
					_set_state("spicy", 1.2)
					fx.text(feet() + Vector2(0, -130) * disp_scale - Vector2(0, 20 * px), "SPICY!!", 54, Color("ff3b2f"), 1.3, true)
					sfx.play("burp", -2.0, 1.5)
				elif chew_burp:
					_set_state("burp", 0.8)
					sfx.play("burp", 0.0, clampf(1.35 - stage() * 0.15, 0.7, 1.4))
					var power := sqrt(disp_scale / px)
					fx.puff(mouth_pos(), 7, Color("d9f5b5"), power)
					fx.text(mouth_pos() + Vector2(40 * face, -20) * px * power, "BURP!", int(26 * minf(2.0, power)), Color("b8f28a"), 1.1, true)
					squash_v -= 3.0
				else:
					_after_meal()
		"burp":
			mouth_tgt = 0.65 * sin(minf(1.0, st_t / 0.6) * PI)
			if st_t > st_dur:
				_after_meal()
		"grow":
			var u := clampf(st_t / st_dur, 0.0, 1.0)
			var e := 1.0 + (pow(2.0, -10.0 * u) * sin((u * 10.0 - 0.75) * TAU / 3.0)) * -1.0
			disp_scale = lerpf(grow_from, grow_to, e if u < 1.0 else 1.0)
			mouth_tgt = 0.2
			shake = maxf(shake, 3.0 * px)
			if st_t > st_dur:
				disp_scale = grow_to
				_stage_banner()
				_roar(true)
		"sink":
			var u := clampf(st_t / st_dur, 0.0, 1.0)
			y_off = lerpf(0.0, 110.0 * disp_scale, u * u)
			shake = maxf(shake, 4.0 * px)
			if st_t > st_dur:
				disp_scale = STAGE_SCALE[4] * px
				y_off = 105.0 * disp_scale
				_set_state("rumble", 0.8)
				fx.say("", 0.1)
		"rumble":
			shake = maxf(shake, 7.0 * px)
			y_off = 96.0 * disp_scale + sin(st_t * 9.0) * 4.0 * px
			kx += sin(st_t * 2.5) * 60.0 * px * dt
			if int(st_t * 4.0) != int((st_t - dt) * 4.0):
				sfx.play("step", 2.0, 0.6)
			if st_t > st_dur:
				_set_state("rise", 1.3)
		"rise":
			var u := clampf(st_t / st_dur, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - u, 3.0)
			y_off = lerpf(105.0 * disp_scale, GIANT_SINK * px, e)
			shake = maxf(shake, 6.0 * px)
			if st_t > st_dur:
				_stage_banner()
				_roar(true)
		"roar":
			var u := st_t / st_dur
			mouth_tgt = 1.0 if u < 0.8 else 0.0
			arms = 1.0 if u < 0.85 else 0.0
			if int(st_t * 6.0) != int((st_t - dt) * 6.0) and u < 0.7:
				var power := sqrt(disp_scale / px)
				fx.ring(mouth_pos(), 160.0 * px * power, Color(1, 1, 1, 0.8), 0.7)
			shake = maxf(shake, 3.0 * px * sqrt(disp_scale / px) * (1.0 - u))
			if st_t > st_dur:
				_set_state("idle")
		"pet":
			mouth_tgt = 0.0
			if st_t > st_dur:
				_set_state("idle")
		"spicy":
			var u := st_t / st_dur
			mouth_tgt = 0.15 + 0.15 * sin(st_t * 40.0)
			kaiju.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.5), clampf(u * 1.5, 0.0, 1.0))
			shake = maxf(shake, 2.0 * px + u * 4.0 * px)
			squash = sin(st_t * 45.0) * 0.04
			if randf() < dt * 14.0:
				fx.puff(feet() + Vector2(randf_range(-30, 30), -100) * disp_scale, 1, Color(1, 1, 1, 0.85), 0.7)
			if st_t > st_dur:
				_set_state("fire", float(Cfg.FOODS.pepper.dur))
				fire_acc = 0.0
				sfx.play("fire", 2.0, 1.0)
				sfx.play("roar", 0.0, clampf(1.9 - stage() * 0.32, 0.62, 1.9) * 0.9)
		"fire":
			mouth_tgt = 1.0
			arms = 1.0
			kaiju.modulate = Color(1.0, 0.75, 0.7)
			var before := st_t - dt
			if before < st_dur * 0.5 and st_t >= st_dur * 0.5:
				face = -face
				squash_v += 3.0
			for tt in [1.35, 2.7]:
				if before < tt and st_t >= tt:
					sfx.play("fire", 2.0, randf_range(0.95, 1.05))
			_fire_tick(dt)
			if st_t > st_dur:
				kaiju.modulate = Color.WHITE
				fx.puff(mouth_pos(), 9, Color(0.35, 0.35, 0.38), sqrt(disp_scale / px))
				fx.text(mouth_pos() + Vector2(40 * face, -20) * px, "*cough*", 26, Color("cfcfcf"), 1.1, true)
				sfx.play("burp", 0.0, 0.9)
				get_tree().create_timer(0.5).timeout.connect(func(): fx.say("Worth it.", 2.0))
				_set_state("burp", 0.8)
	# dragged icon near mouth -> gape
	if dragging != null and _interruptible():
		var d := dragging.position.distance_to(mouth_pos())
		if d < 260.0 * px:
			face = signf(dragging.position.x - kx) if absf(dragging.position.x - kx) > 10.0 else face
			mouth_tgt = maxf(mouth_tgt, clampf(1.2 - d / (220.0 * px), 0.3, 1.0))
	if demo_fake_drag.size() > 0:
		mouth_tgt = maxf(mouth_tgt, 0.8)
	mouth_cur = lerpf(mouth_cur, mouth_tgt, minf(1.0, dt * 16.0))
	# walk cycle, stomps
	if walking:
		phase += dt * _speed() / (9.0 * disp_scale) * 1.0
		var stp := int(phase / PI)
		if stp != last_step:
			last_step = stp
			if s >= 2 and s < 4:
				shake = maxf(shake, (s - 1) * 1.6 * px)
				sfx.play("step", -14.0 + s * 3.0, 1.2 - s * 0.1)
	kaiju.walk_amt = lerpf(kaiju.walk_amt, 1.0 if walking else 0.0, minf(1.0, dt * 10.0))
	# squash spring
	squash_v += (-180.0 * squash - 11.0 * squash_v) * dt
	squash += squash_v * dt
	var sq: float = squash + sin(phase * 2.0) * 0.035 * kaiju.walk_amt + sin(time * 2.2) * 0.012
	# blink
	blink_t -= dt
	if blink_t <= 0.0:
		blink_v = 1.0
		blink_t = randf_range(2.0, 5.0)
	blink_v = maxf(0.0, blink_v - dt * 7.0)
	# emotion
	happy_t -= dt
	happy_v = lerpf(happy_v, 1.0 if happy_t > 0.0 else 0.0, minf(1.0, dt * 10.0))
	angry_v = lerpf(angry_v, 1.0 if rampage else (0.55 if frenzy_t > 0.0 else 0.0), minf(1.0, dt * 3.0))
	# look target
	var look_at := get_viewport().get_mouse_position()
	if is_instance_valid(target_icon):
		look_at = target_icon.position
	elif dragging != null:
		look_at = dragging.position
	elif demo:
		look_at = feet() + Vector2(face * 200, -260) * px
	var eye := feet() + Vector2(15 * face, -62) * disp_scale
	var lv := (look_at - eye)
	var ll := Vector2(lv.x * face, lv.y)
	kaiju.look = ll.normalized() * clampf(ll.length() / (80.0 * px), 0.0, 1.0)
	# push to the drawing node
	kaiju.position = feet()
	kaiju.scale = Vector2(face * disp_scale * (1.0 + sq), disp_scale * (1.0 - sq))
	kaiju.rotation = sin(phase) * 0.04 * kaiju.walk_amt
	kaiju.k = disp_scale
	kaiju.stage = s if st != "grow" else maxi(0, s - 1) if st_t < st_dur * 0.4 else s
	kaiju.walk_phase = phase
	kaiju.mouth = mouth_cur
	kaiju.blink = blink_v
	kaiju.happy = happy_v
	kaiju.angry = angry_v
	kaiju.arms_up = lerpf(kaiju.arms_up, arms, minf(1.0, dt * 12.0))
	kaiju.tail_t = time
	kaiju.glow_t = time
	kaiju.queue_redraw()
	fx.bubble_pos = feet() + Vector2(10 * face, -98) * disp_scale
	if stage() == 4:
		fx.bubble_pos.y = maxf(fx.bubble_pos.y, 180.0 * px)

func _walk_to(tx: float, dt: float) -> bool:
	var dx := tx - kx
	if absf(dx) < 3.0 * px:
		return false
	face = signf(dx)
	kx += face * minf(absf(dx), _speed() * dt)
	return true

func _after_meal() -> void:
	if pending_stage >= 0:
		pending_level = false
		grow_from = disp_scale
		grow_to = STAGE_SCALE[pending_stage] * px
		if pending_stage == 4:
			_set_state("sink", 0.6)
			fx.say("uh oh.", 1.2)
		else:
			_set_state("grow", 0.8 if demo else 1.0)
			sfx.play("level", -2.0)
		pending_stage = -1
		return
	var lvc: int = get_meta("lv_coins", 0)
	if lvc > 0:
		set_meta("lv_coins", 0)
		add_coins(lvc, feet() + Vector2(0, -90) * disp_scale)
	if pending_level:
		pending_level = false
		sfx.play("level", -4.0)
		fx.stars(feet() + Vector2(0, -60) * disp_scale, 10, 0.7)
		fx.text(feet() + Vector2(0, -120) * disp_scale, "LEVEL %d" % level, 30, Color("ffd23f"), 1.4, true)
	_set_state("idle")
	next_wander = randf_range(0.5, 2.0)

func _stage_banner() -> void:
	var s := stage()
	var p := Vector2(W * 0.5, H * 0.36)
	fx.text(p, "STAGE %d" % (s + 1), 40, Color.WHITE, 2.6, true, 20.0)
	fx.text(p + Vector2(0, 74 * px), STAGE_NAMES[s].to_upper() + "!", 76 if s < 4 else 110, Color("ffd23f") if s < 4 else Color("ff5a4f"), 2.6, true, 20.0)
	fx.stars(mouth_pos(), 22, 1.4)
	fx.ring(feet() + Vector2(0, -50) * disp_scale, 420.0 * px, Color("ffd23f"), 0.9)
	add_coins(Cfg.COIN_STAGE_UP, mouth_pos())
	_refresh_ui()

func _pet() -> void:
	var now := time
	pet_times = pet_times.filter(func(t): return now - t < 4.0)
	pet_times.append(now)
	if pet_times.size() > 7:
		fx.say("OK OK. Personal\nspace, human.", 1.6, true)
		squash_v += 2.0
		return
	happy_t = 0.9
	print("[kaiju] petted, mood=", int(mood))
	squash_v -= 5.0
	mood = minf(100.0, mood + 6.0 * float(sp().pet))
	if coin_pet_cd <= 0.0:
		coin_pet_cd = Cfg.COIN_PET_COOLDOWN
		add_coins(int(round(Cfg.COIN_PET * float(sp().pet))), feet() + Vector2(0, -95) * disp_scale)
	fx.hearts(feet() + Vector2(0, -95) * disp_scale, 3)
	sfx.play("pet", -2.0, clampf(1.3 - stage() * 0.12, 0.7, 1.3))
	if st in ["idle", "walk"]:
		_set_state("pet", 0.5)
	_refresh_ui()

func _kaiju_hit(p: Vector2) -> bool:
	if st == "egg":
		return p.distance_to(feet() + Vector2(0, -38) * disp_scale) < 40.0 * disp_scale
	var l := (p - feet()) / disp_scale
	l.x *= face
	var body := pow(l.x / 46.0, 2) + pow((l.y + 47.0) / 50.0, 2) <= 1.0
	return body and p.y < floor_y

func _kaiju_rect() -> Rect2:
	var f := feet()
	var r := Rect2(f + Vector2(-92, -120) * disp_scale, Vector2(184, 124) * disp_scale)
	return r.intersection(Rect2(0, 0, W, floor_y))

# ---------------- input ----------------
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			for i in range(icons.size() - 1, -1, -1):
				var ic: Node2D = icons[i]
				if ic.state in ["desk", "ground", "shake", "fall"] and _icon_rect(ic).has_point(e.position):
					dragging = ic
					drag_off = ic.position - e.position
					drag_prev = ic.position
					ic.state = "drag"
					ic.z_index = 5
					sfx.play("pop", -12.0, 1.4)
					return
			if _kaiju_hit(e.position):
				if st == "egg":
					kaiju.egg_wobble += 2.0
					st_t += 0.4
				else:
					_pet()
		elif dragging != null:
			_drop(dragging)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		panel.visible = false
		close_shop()

func _drop(ic: Node2D) -> void:
	dragging = null
	ic.z_index = 0
	var near := ic.position.distance_to(mouth_pos()) < maxf(70.0 * px, 32.0 * disp_scale)
	if near and _interruptible() and st != "egg":
		_eat(ic, true)
	elif ic.position.y > floor_y - 140.0 * px:
		ic.state = "fall"
		ic.vel = Vector2.ZERO
		ic.spin = randf_range(-3, 3)
	else:
		ic.state = "desk"
		ic.rotation = 0.0
		ic.position.y = clampf(ic.position.y, 40 * px, floor_y - 140 * px)

# ---------------- passthrough ----------------
func _game_rects(visual := false) -> Array:
	var rs: Array = []
	rs.append(_kaiju_rect().grow(shake + (8.0 * px if visual else 0.0)))
	for ic in icons:
		if visual:
			rs.append(_icon_visual_rect(ic).grow(shake))
		elif ic.state != "eaten":
			rs.append(_icon_rect(ic))
	rs.append(Rect2(face_btn.position, face_btn.size).grow(4 * px if not visual else 10 * px))
	if panel.visible:
		rs.append(Rect2(panel.position, panel.size).grow(4 * px if not visual else 16 * px))
	rs.append(Rect2(hud.position, hud.size).grow(4 * px if not visual else 10 * px))
	if visual and (xp_boost_t > 0.0 or frenzy_t > 0.0):
		rs.append(Rect2(hud.position + Vector2(-200 * px, -34 * px), Vector2(hud.size.x + 200 * px, 32 * px)))
	if shop.visible:
		var sr := Rect2(shop.position, shop.size)
		rs.append(sr.grow(4 * px if not visual else 20 * px))
	if visual:
		for r in fx.visual_rects():
			rs.append((r as Rect2).grow(shake))
		for r in ui_fx.visual_rects():
			rs.append(r)
	return rs

func _update_passthrough() -> void:
	var capture_all := dragging != null
	if pass_mode == "flag":
		var mp := Vector2(DisplayServer.mouse_get_position() - get_window().position)
		var over := capture_all
		if not over:
			for r in _game_rects():
				if r.has_point(mp):
					over = true
					break
		var want := 0 if over else 1
		if want != last_pass_flag:
			last_pass_flag = want
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, want == 1)
		return
	if pass_mode == "off":
		return
	if capture_all:
		if last_pass_key != "ALL":
			last_pass_key = "ALL"
			DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		return
	var rs: Array = []
	var win_r := Rect2(0, 0, W, H)
	for r0 in _game_rects(pass_mode == "region"):
		var r: Rect2 = (r0 as Rect2).intersection(win_r)
		if r.size.x <= 1 or r.size.y <= 1:
			continue
		var g: Rect2 = r.grow(6)
		g.position = (g.position / 8.0).floor() * 8.0
		g.end = (g.end / 8.0).ceil() * 8.0
		rs.append(g)
	# merge overlaps so even-odd filling never cancels areas
	var merged := true
	while merged:
		merged = false
		for i in rs.size():
			for j in range(i + 1, rs.size()):
				if (rs[i] as Rect2).intersects(rs[j]):
					rs[i] = (rs[i] as Rect2).merge(rs[j])
					rs.remove_at(j)
					merged = true
					break
			if merged:
				break
	var key := str(rs)
	if debug_region != null:
		debug_region.set_meta("rects", rs)
		debug_region.queue_redraw()
	if key == last_pass_key:
		return
	last_pass_key = key
	var pts := PackedVector2Array()
	var anchor := Vector2(0, 0)
	for r in rs:
		pts.append(anchor)
		pts.append(r.position)
		pts.append(Vector2(r.end.x, r.position.y))
		pts.append(r.end)
		pts.append(Vector2(r.position.x, r.end.y))
		pts.append(r.position)
	DisplayServer.window_set_mouse_passthrough(pts)

# ---------------- main loop ----------------
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	time += dt
	if demo:
		_demo_tick(dt)
	elif st != "egg":
		mood = maxf(0.0, mood - dt * Cfg.MOOD_DRAIN_PER_SEC * _mood_mult())
		passive_acc += dt
		if passive_acc >= 60.0:
			passive_acc -= 60.0
			_add_xp(Cfg.PASSIVE_XP_PER_MIN)
			_refresh_ui()
		next_hunt -= dt
		next_spawn -= dt
		var cap := Cfg.ICON_CAP + upg("auto") + (3 if rampage or frenzy_t > 0.0 else 0)
		if next_spawn <= 0.0:
			var iv := randf_range(Cfg.SPAWN_INTERVAL.x, Cfg.SPAWN_INTERVAL.y) / (1.0 + upg_val("auto"))
			next_spawn = randf_range(5.0, 8.0) if rampage else (randf_range(1.5, 3.0) if frenzy_t > 0.0 else iv)
			if icons.size() < cap:
				_spawn_icon()
		if frenzy_t > 0.0 and next_hunt > 2.0:
			next_hunt = randf_range(0.5, 1.5)
		next_chatter -= dt
		if next_chatter <= 0.0 and st == "idle":
			next_chatter = randf_range(40.0, 80.0)
			var lines := ["Snack?", "Is that a folder?\nLooks crunchy.", "I could eat\nyour taskbar.", "Pet me. Now.", "*stomach rumbles*"]
			if mood < 40.0:
				lines = ["Hungry...", "Feed me or\nI eat everything.", "*grumble*"]
			fx.say(lines[randi() % lines.size()], 2.4, mood < 40.0)
	# rampage logic
	if not rampage and mood < 25.0 and hatched and st == "idle":
		rampage = true
		fx.say("YOU IGNORED ME.\nRAMPAGE!!", 2.5, true)
		_roar(false)
		next_hunt = 1.5
		for i in 2:
			_spawn_icon()
	elif rampage and mood > 55.0:
		rampage = false
		fx.say("...ok I feel\nbetter now.", 2.0)
	xp_boost_t = maxf(0.0, xp_boost_t - dt)
	frenzy_t = maxf(0.0, frenzy_t - dt)
	coin_pet_cd = maxf(0.0, coin_pet_cd - dt)
	if coins_shown > coins:
		coins_shown = maxf(coins, coins_shown - maxf(60.0, (coins_shown - coins) * 4.0) * dt)
	elif coins_shown < coins and not _coins_in_flight():
		coins_shown = minf(coins, coins_shown + maxf(30.0, (coins - coins_shown) * 5.0) * dt)
	_update_icons(dt)
	_update_kaiju(dt)
	_update_fake_drag(dt)
	# shake
	shake = maxf(0.0, shake - dt * 30.0 * px)
	world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	_update_passthrough()
	if reset_armed > 0.0:
		reset_armed -= dt
		if reset_armed <= 0.0:
			btn_reset.text = "Reset"
	snack_cd = maxf(0.0, snack_cd - dt)
	autosave_t += dt
	if autosave_t > 20.0:
		autosave_t = 0.0
		_save()
	if panel.visible and int(time * 2.0) != int((time - dt) * 2.0):
		_refresh_ui()
	if shop.visible and int(time * 2.0) != int((time - dt) * 2.0):
		shop.refresh()
	_place_shop()

func _coins_in_flight() -> bool:
	for p in fx.parts:
		if p.k == "coin":
			return true
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()

# ---------------- species ----------------
func switch_species(id: String) -> void:
	if id == species or not owned.has(id):
		return
	_store_species()
	var at := feet() + Vector2(0, -50) * disp_scale
	fx.puff(at, 14, Color(1, 1, 1, 0.95), sqrt(disp_scale / px) * 1.4)
	fx.stars(at, 16, 1.0)
	sfx.play("poof", 0.0)
	species = id
	kaiju.species = id
	_load_species(id)
	pending_stage = -1
	pending_level = false
	pending_fire = false
	rampage = false
	target_icon = null
	kaiju.modulate = Color.WHITE
	disp_scale = STAGE_SCALE[stage()] * px
	y_off = GIANT_SINK * px if stage() == 4 else 0.0
	kx = clampf(kx, 120.0 * px, W - 300.0 * px)
	if not hatched:
		_set_state("egg")
	else:
		_set_state("idle")
		get_tree().create_timer(0.4).timeout.connect(func(): fx.say("%s reporting\nfor snack duty!" % sp().name, 2.2))
	print("[kaiju] switched to ", id)
	_save()
	_refresh_ui()

func _quit() -> void:
	if demo:
		sfx.dump("/tmp/tk_sfx")
	_save()
	get_tree().quit()

# ---------------- UI ----------------
func _sb(bg: Color, radius: int, border := 3, bc := OUT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius * px))
	s.set_border_width_all(int(border * px))
	s.border_color = bc
	s.anti_aliasing = true
	s.content_margin_left = 10 * px
	s.content_margin_right = 10 * px
	s.content_margin_top = 5 * px
	s.content_margin_bottom = 5 * px
	return s

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = int(17 * px)
	th.set_color("font_color", "Label", OUT)
	th.set_stylebox("normal", "Button", _sb(Color("ffd25a"), 10))
	th.set_stylebox("hover", "Button", _sb(Color("ffe28f"), 10))
	th.set_stylebox("pressed", "Button", _sb(Color("f2b630"), 10))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "Button", OUT)
	face_btn = FaceScript.new()
	face_btn.px = px
	face_btn.size = Vector2(54, 54) * px
	face_btn.position = Vector2(W - 70 * px, floor_y - 66 * px)
	face_btn.pressed.connect(_on_face)
	face_btn.tooltip_text = ""
	ui.add_child(face_btn)

	panel = PanelContainer.new()
	panel.theme = th
	var psb := _sb(Color("fff7e6"), 18, 4)
	psb.shadow_color = Color(0, 0, 0, 0.35)
	psb.shadow_size = int(10 * px)
	psb.shadow_offset = Vector2(0, 4) * px
	psb.content_margin_left = 18 * px
	psb.content_margin_right = 18 * px
	psb.content_margin_top = 14 * px
	psb.content_margin_bottom = 16 * px
	panel.add_theme_stylebox_override("panel", psb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(6 * px))
	panel.add_child(v)
	var title := Label.new()
	title.text = "TASKBAR KAIJU"
	title.add_theme_font_override("font", BIG_FONT)
	title.add_theme_font_size_override("font_size", int(28 * px))
	title.add_theme_color_override("font_color", Color("2fa18b"))
	title.add_theme_color_override("font_outline_color", OUT)
	title.add_theme_constant_override("outline_size", int(6 * px))
	v.add_child(title)
	for key in ["stage", "level"]:
		var l := Label.new()
		v.add_child(l)
		lbl[key] = l
	lbl.stage.add_theme_font_size_override("font_size", int(21 * px))
	xp_bar = _bar(Color("62cc5c"))
	v.add_child(xp_bar)
	var ml := Label.new()
	v.add_child(ml)
	lbl["mood"] = ml
	mood_bar = _bar(Color("ff6f91"))
	mood_fill = mood_bar.get_theme_stylebox("fill")
	v.add_child(mood_bar)
	for key in ["eaten", "age"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", int(15 * px))
		v.add_child(l)
		lbl[key] = l
	var shop_btn := _btn("CRUNCH SHOP", _on_shop_btn)
	shop_btn.custom_minimum_size = Vector2(270, 44) * px
	shop_btn.add_theme_font_override("font", BIG_FONT)
	shop_btn.add_theme_font_size_override("font_size", int(21 * px))
	shop_btn.icon = coin_tex
	shop_btn.add_theme_constant_override("icon_max_width", int(26 * px))
	var ssb := _sb(Color("ff9f43"), 12)
	ssb.border_width_bottom = int(6 * px)
	shop_btn.add_theme_stylebox_override("normal", ssb)
	var ssh := _sb(Color("ffb76b"), 12)
	ssh.border_width_bottom = int(6 * px)
	shop_btn.add_theme_stylebox_override("hover", ssh)
	shop_btn.add_theme_color_override("font_color", Color.WHITE)
	shop_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	shop_btn.add_theme_color_override("font_outline_color", OUT)
	shop_btn.add_theme_constant_override("outline_size", int(6 * px))
	v.add_child(shop_btn)
	lbl["shop_btn"] = shop_btn
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(8 * px))
	grid.add_theme_constant_override("v_separation", int(8 * px))
	v.add_child(grid)
	btn_mute = _btn("Sound: ON", _on_mute)
	grid.add_child(btn_mute)
	grid.add_child(_btn("Snacks x3", _on_snacks))
	btn_reset = _btn("Reset", _on_reset)
	grid.add_child(btn_reset)
	grid.add_child(_btn("Quit", _quit))
	var hint := Label.new()
	hint.text = "Drag icons into its mouth. Click to pet.\nIt only eats its own fake icons.\nYour real files are never touched."
	hint.add_theme_font_size_override("font_size", int(13 * px))
	hint.add_theme_color_override("font_color", Color("6b7280"))
	v.add_child(hint)
	panel.visible = false
	ui.add_child(panel)
	panel.reset_size()

	hud = HudScript.new()
	hud.main = self
	hud.px = px
	hud.font = FONT
	hud.big_font = BIG_FONT
	hud.coin_tex = coin_tex
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.size = Vector2(132, 44) * px
	hud.position = Vector2(W - 70 * px - 142 * px, floor_y - 61 * px)
	hud.gui_input.connect(_on_hud_input)
	ui.add_child(hud)

	shop = ShopScript.new()
	shop.theme = th
	shop.visible = false
	ui.add_child(shop)
	shop.setup(self)
	shop.reset_size()

	var top := CanvasLayer.new()
	top.layer = 12
	add_child(top)
	ui_fx = FxScript.new()
	ui_fx.font = FONT
	ui_fx.big_font = BIG_FONT
	ui_fx.px = px
	top.add_child(ui_fx)
	fx.coin_landed.connect(_on_coin_landed)
	if demo2:
		var cl := CanvasLayer.new()
		cl.layer = 30
		add_child(cl)
		fake_cursor = CursorScript.new()
		fake_cursor.px = px
		fake_cursor.position = Vector2(W * 0.62, H * 0.55)
		cl.add_child(fake_cursor)

func _on_hud_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		open_shop()

func open_shop(tab := -1) -> void:
	panel.visible = false
	if tab >= 0:
		shop.set_tab(tab, false)
	shop.refresh()
	shop.visible = true
	_place_shop()
	shop.pivot_offset = shop.size
	shop.scale = Vector2(0.6, 0.6)
	shop.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(shop, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shop, "modulate:a", 1.0, 0.15)
	sfx.play("pop", -4.0, 0.9)

func close_shop() -> void:
	if shop and shop.visible:
		shop.visible = false
		sfx.play("pop", -8.0, 1.3)

func _place_shop() -> void:
	if shop == null:
		return
	shop.reset_size()
	shop.position = Vector2(W - shop.size.x - 20 * px, floor_y - shop.size.y - 84 * px)

func _on_shop_btn() -> void:
	open_shop()

func _on_face() -> void:
	if shop.visible:
		close_shop()
		return
	panel.visible = not panel.visible
	sfx.play("pop", -8.0, 1.1)
	_refresh_ui()

func _on_mute() -> void:
	muted = not muted
	sfx.muted = muted
	_save()
	_refresh_ui()

func _on_snacks() -> void:
	if snack_cd > 0.0:
		fx.say("Chill. Snacks in %ds." % int(snack_cd + 1), 1.5)
		return
	snack_cd = 20.0
	for i in 3:
		_spawn_icon()

func _on_reset() -> void:
	if reset_armed > 0.0:
		reset_armed = 0.0
		btn_reset.text = "Reset"
		_reset()
	else:
		reset_armed = 3.0
		btn_reset.text = "Sure? Again!"

func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(270, 16) * px
	b.add_theme_stylebox_override("background", _sb(Color("eadfc6"), 8, 2))
	var f := _sb(col, 8, 2)
	f.content_margin_left = 0
	f.content_margin_right = 0
	b.add_theme_stylebox_override("fill", f)
	return b

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(131, 36) * px
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _refresh_ui() -> void:
	if panel == null:
		return
	var s := stage()
	lbl.stage.text = "%s the %s  (stage %d/5)" % [sp().name, STAGE_NAMES[s], s + 1]
	lbl.level.text = "Level %d   %d / %d XP" % [level, int(xp), int(xp_need(level))]
	xp_bar.max_value = xp_need(level)
	xp_bar.value = xp
	var mood_name := "Happy" if mood > 70 else "OK" if mood > 45 else "Grumpy" if mood > 25 else "RAMPAGING"
	if rampage:
		mood_name = "RAMPAGING"
	lbl.mood.text = "Mood: %s" % mood_name
	mood_bar.max_value = 100
	mood_bar.value = mood
	mood_fill.bg_color = Color("ff6f91") if mood > 45 else Color("ffb347") if mood > 25 else Color("e5534b")
	lbl.eaten.text = "Icons eaten: %d   (hand-fed: %d)" % [eaten, fed]
	lbl.age.text = "Age: %s" % _dur(maxf(0.0, Time.get_unix_time_from_system() - born))
	btn_mute.text = "Sound: OFF" if muted else "Sound: ON"
	panel.reset_size()
	panel.position = Vector2(W - panel.size.x - 20 * px, floor_y - panel.size.y - 84 * px)

# ---------------- demo (for the showcase video) ----------------
func _setup_demo() -> void:
	hatched = true
	level = 3
	xp = 0.0
	mood = 85.0
	eaten = 37
	fed = 9
	born -= 3 * 86400 + 4 * 3600
	demo_queue = [
		[0.1, "spawn"], [0.9, "hunt", "doc", false],
		[0.1, "pet"], [0.15, "feed", "trash", true],
		[0.3, "hunt", "globe", true], [0.3, "rampage"], [0.1, "hunt", "", true],
		[0.2, "hunt", "", true], [0.3, "drop_snack"], [0.25, "menu"], [1.9, "end"],
	]

func _demo_tick(dt: float) -> void:
	if not (st == "idle") or demo_fake_drag.size() > 0 or demo_queue.is_empty():
		demo_wait = 0.0
		return
	demo_wait += dt
	var a: Array = demo_queue[0]
	if demo_wait < a[0]:
		return
	demo_queue.pop_front()
	demo_wait = 0.0
	match a[1]:
		"spawn":
			var places := [["doc", 0.43, 0.50], ["trash", 0.30, 0.36], ["globe", 0.62, 0.42], ["sheet", 0.70, 0.62],
				["zip", 0.40, 0.24], ["image", 0.80, 0.30], ["music", 0.55, 0.20], ["folder", 0.24, 0.60]]
			for i in places.size():
				var p: Array = places[i]
				get_tree().create_timer(i * 0.06).timeout.connect(func(): _spawn_icon(p[0], Vector2(W * p[1], H * p[2])))
		"walkto":
			target_x = W * a[2]
			_set_state("walk")
		"hunt":
			var ic := _pick_icon(a[2])
			if ic == null:
				ic = _spawn_icon("", Vector2(clampf(kx + face * 300 * px, 100 * px, W - 200 * px), H * 0.45))
			set_meta("demo_up", a[3])
			_start_hunt(ic)
			if a[3]:
				for i in 1:
					get_tree().create_timer(2.5).timeout.connect(_demo_extra)
		"pet":
			_pet()
		"drop_snack":
			var ic := _spawn_icon("zip", Vector2(mouth_pos().x + face * 40 * px, H * 0.3))
			ic.pop = 1.0
			ic.state = "fall"
			ic.vel = Vector2.ZERO
			set_meta("demo_up", false)
			target_icon = ic
			_set_state("wait_drop")
		"feed":
			var ic := _pick_icon(a[2])
			if ic:
				set_meta("demo_up", a[3])
				ic.state = "drag"
				demo_fake_drag = {"ic": ic, "from": ic.position, "t": 0.0}
		"rampage":
			mood = 12.0
			for i in 2:
				_spawn_icon()
		"menu":
			panel.visible = true
			_refresh_ui()
		"end":
			_quit()

func _demo_extra() -> void:
	if icons.size() < 6:
		_spawn_icon()

func _update_fake_drag(dt: float) -> void:
	if demo_fake_drag.is_empty():
		return
	var ic: Node2D = demo_fake_drag.ic
	demo_fake_drag.t += dt / 1.4
	var u: float = minf(1.0, demo_fake_drag.t)
	var e := u * u * (3.0 - 2.0 * u)
	var to := mouth_pos()
	var from: Vector2 = demo_fake_drag.from
	var mid := (from + to) * 0.5 + Vector2(0, -120 * px)
	ic.position = from.lerp(mid, e).lerp(mid.lerp(to, e), e)
	ic.rotation = sin(u * PI) * 0.25
	if u >= 1.0:
		demo_fake_drag = {}
		_eat(ic, true)


# ---------------- demo 2: the shop showcase (scripted, with a drawn cursor) ----------------
func _setup_demo2() -> void:
	hatched = true
	level = 6
	xp = 12.0
	mood = 82.0
	eaten = 58
	fed = 14
	born -= 2 * 86400 + 7 * 3600
	coins = 455
	owned = ["dino", "octo"]
	upgrades = {"teeth": 2}
	species_data["octo"] = {"xp": 0.0, "level": 9, "mood": 90.0, "eaten": 40, "fed": 11, "born": born, "hatched": true}
	hatch_speed = 1.8

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _wait_idle() -> void:
	while st != "idle" or demo_fake_drag.size() > 0:
		await get_tree().process_frame

func _cur_to(p: Vector2, dur := 0.55) -> void:
	var tw := create_tween()
	tw.tween_property(fake_cursor, "position", p, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _cur_click(c: Control, dur := 0.55) -> void:
	await _cur_to(c.get_global_rect().get_center() + Vector2(4, 6) * px, dur)
	await _wait(0.12)
	fake_cursor.press = 1.0
	sfx.play("pop", -16.0, 1.6)
	if c is Button:
		(c as Button).pressed.emit()
	elif c.has_signal("pressed"):
		c.emit_signal("pressed")
	await _wait(0.1)

func _run_demo2() -> void:
	await _wait(0.3)
	var places := [["doc", 0.47, 0.50], ["trash", 0.22, 0.40], ["globe", 0.56, 0.33], ["sheet", 0.12, 0.62], ["zip", 0.30, 0.26]]
	for p in places:
		_spawn_icon(p[0], Vector2(W * p[1], H * p[2]))
		await _wait(0.06)
	await _wait(0.5)
	# 1) earn: it eats a desk icon on its own -> Crunch flies to the counter
	_start_hunt(_pick_icon("doc"))
	await _wait_idle()
	# 2) pet it (coins + hearts)
	await _cur_to(feet() + Vector2(0, -60) * disp_scale, 0.5)
	for i in 2:
		fake_cursor.press = 1.0
		_pet()
		await _wait(0.3)
	await _wait_idle()
	# 3) hand-feed by dragging the trash can into its mouth (x1.5 Crunch)
	var ic := _pick_icon("trash")
	if ic:
		await _cur_to(ic.position + Vector2(4, 8) * px, 0.5)
		fake_cursor.press = 1.0
		ic.state = "drag"
		demo_fake_drag = {"ic": ic, "from": ic.position, "t": 0.0}
		while demo_fake_drag.size() > 0:
			fake_cursor.position = ic.position + Vector2(4, 8) * px
			await get_tree().process_frame
	await _wait_idle()
	await _wait(0.2)
	# 4) open the kaiju-face menu -> CRUNCH SHOP
	await _cur_click(face_btn, 0.6)
	await _wait(0.45)
	await _cur_click(lbl.shop_btn, 0.4)
	await _wait(0.6)
	# 5) buy MEK-0, try the yeti (too poor), then switch to the mecha
	await _cur_click(shop.button_for("mecha"), 0.5)
	await _wait(0.85)
	await _cur_click(shop.button_for("yeti"), 0.45)
	await _wait(0.7)
	await _cur_click(shop.button_for("mecha"), 0.4)
	await _wait(1.0)
	# 6) upgrades: Big Appetite twice (scaling cost)
	await _cur_click(shop.tab_btns[2], 0.45)
	await _wait(0.35)
	await _cur_click(shop.button_for("appetite"), 0.4)
	await _wait(0.6)
	await _cur_click(shop.button_for("appetite"), 0.25)
	await _wait(0.7)
	# 7) food: buy a Ghost Pepper and drop it
	await _cur_click(shop.tab_btns[1], 0.45)
	await _wait(0.35)
	await _cur_click(shop.button_for("pepper"), 0.45)
	await _wait(0.6)
	var burn_spots := [["folder", 0.50, 0.58], ["image", 0.60, 0.72], ["music", 0.17, 0.66], ["gear", 0.42, 0.42], ["pad", 0.26, 0.50]]
	for p in burn_spots:
		_spawn_icon(p[0], Vector2(W * p[1], H * p[2]))
	await _cur_click(shop.button_for("pepper", true), 0.4)
	await _cur_to(Vector2(W * 0.8, H * 0.5), 0.6)
	# 8) it eats it -> SPICY -> fire breath roasts the icons
	while st != "fire":
		await get_tree().process_frame
	while st != "idle":
		await get_tree().process_frame
	await _wait(1.2)
	_quit()
