extends Node2D
## A FAKE desktop icon that the game spawns itself. Pure drawing; it has no link
## to any real file or real desktop icon.

const OUT := Color("1d2433")
const KINDS := {
	"trash": {"label": "Trash", "xp": 8, "col": Color("9fb3c8"), "line": "Recycling! Om nom."},
	"folder": {"label": "New Folder (7)", "xp": 6, "col": Color("ffd25a"), "line": "Crunchy folder."},
	"doc": {"label": "homework.docx", "xp": 10, "col": Color("4f8ef7"), "line": "The kaiju ate my homework."},
	"globe": {"label": "Internet", "xp": 14, "col": Color("4cb3f5"), "line": "I ate the internet."},
	"sheet": {"label": "taxes_FINAL.xlsx", "xp": 12, "col": Color("3fbf6f"), "line": "No taxes this year."},
	"image": {"label": "selfie_04.png", "xp": 9, "col": Color("ff8fb1"), "line": "Cute. Tasty."},
	"music": {"label": "mixtape.mp3", "xp": 9, "col": Color("a77bff"), "line": "Bass-heavy snack."},
	"zip": {"label": "do_not_open.zip", "xp": 15, "col": Color("ffb347"), "line": "SPICY!"},
	"gear": {"label": "Settings", "xp": 7, "col": Color("b8c2cc"), "line": "Settings: deleted. Jk, eaten."},
	"pad": {"label": "games", "xp": 11, "col": Color("ff6b6b"), "line": "Game over. For the icon."},
}

var kind := "folder"
var state := "desk"        # desk, shake, fall, ground, drag, eaten
var vel := Vector2.ZERO
var spin := 0.0
var t := 0.0
var hover := false
var pop := 0.0             # spawn pop-in 0..1
var font: Font
var px := 1.0

func half_width() -> float:
	var w := font.get_string_size(info().label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	return maxf(40.0, w * 0.5 + 6.0)

const FOOD_INFO := {
	"food_burger": {"label": "Byte Burger", "xp": 0, "col": Color("ffb347"), "line": "BYTE BURGER!\nBrain go brrr (2x XP)"},
	"food_cake": {"label": "Cuddle Cake", "xp": 0, "col": Color("ff9fc8"), "line": "Cake = love.\nMood: MAX"},
	"food_soda": {"label": "Rage Soda", "xp": 0, "col": Color("ff4b4b"), "line": "FRENZY MODE!!!"},
	"food_gummy": {"label": "Growth Gummy", "xp": 0, "col": Color("6fe07a"), "line": "I feel... BIGGER."},
	"food_pepper": {"label": "Ghost Pepper", "xp": 0, "col": Color("ff3b2f"), "line": "SPICY SPICY SPICY"},
}
var show_label := true

func is_food() -> bool:
	return kind.begins_with("food_")

func info() -> Dictionary:
	if KINDS.has(kind):
		return KINDS[kind]
	if FOOD_INFO.has(kind):
		return FOOD_INFO[kind]
	return {"label": "", "xp": 0, "col": Color.WHITE, "line": ""}

func _ell(c: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p

func _rr(r: Rect2, rad: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + r.size - Vector2(rad, rad), r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for ci in 4:
		for j in 7:
			var a := -PI * 0.5 + (ci + j / 6.0) * PI * 0.5
			p.append(cs[ci] + Vector2(cos(a), sin(a)) * rad)
	return p

func _f(p: PackedVector2Array, col: Color, ow := 3.0) -> void:
	if ow > 0.0:
		for o in Geometry2D.offset_polygon(p, ow, Geometry2D.JOIN_ROUND):
			draw_colored_polygon(o, OUT)
			var c := o.duplicate(); c.append(o[0])
			draw_polyline(c, OUT, 1.0, true)
	draw_colored_polygon(p, col)
	var c2 := p.duplicate(); c2.append(p[0])
	draw_polyline(c2, col, 1.0, true)

func _page(col: Color) -> void:
	var p := PackedVector2Array([Vector2(-20, -28), Vector2(10, -28), Vector2(22, -16), Vector2(22, 28), Vector2(-20, 28)])
	_f(p, Color("fdfdfd"))
	_f(PackedVector2Array([Vector2(10, -28), Vector2(22, -16), Vector2(10, -16)]), Color("d9dde3"), 0.0)
	draw_polyline(PackedVector2Array([Vector2(10, -28), Vector2(10, -16), Vector2(22, -16)]), OUT, 2.0, true)
	_f(_rr(Rect2(-26, -6, 30, 22), 4), col, 2.5)

func _draw() -> void:
	var s := 1.0
	if pop < 1.0:
		s = 1.0 + sin(pop * PI) * 0.35 - (1.0 - pop) * 0.6
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	if hover and state in ["desk", "ground"]:
		var hr := _rr(Rect2(-40, -38, 80, 96), 6)
		draw_colored_polygon(hr, Color(0.55, 0.75, 1.0, 0.28))
		var c := hr.duplicate(); c.append(hr[0])
		draw_polyline(c, Color(0.7, 0.85, 1.0, 0.7), 1.5, true)
	var col: Color = info().col
	match kind:
		"trash":
			_f(PackedVector2Array([Vector2(-18, -16), Vector2(18, -16), Vector2(14, 28), Vector2(-14, 28)]), col)
			for x in [-8.0, 0.0, 8.0]:
				draw_line(Vector2(x, -10), Vector2(x * 0.85, 22), OUT.lerp(col, 0.4), 2.5, true)
			_f(_ell(Vector2(-4, -22), 9, 7), Color("fdfdfd"), 2.5)
			_f(_rr(Rect2(-22, -20, 44, 7), 3), col.darkened(0.15), 3.0)
			_f(_rr(Rect2(-6, -25, 12, 5), 2), col.darkened(0.15), 2.5)
		"folder":
			_f(_rr(Rect2(-26, -22, 22, 12), 3), col.darkened(0.12))
			_f(_rr(Rect2(-26, -16, 52, 40), 4), col.darkened(0.12))
			_f(_rr(Rect2(-24, -8, 50, 32), 4), col)
			draw_line(Vector2(-18, -2), Vector2(18, -2), Color(1, 1, 1, 0.5), 2.5, true)
		"doc":
			_page(col)
			draw_string(font, Vector2(-23, 11), "DOC", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			for i in 2:
				draw_line(Vector2(-14, 20 + i * 5), Vector2(14, 20 + i * 5), Color("9aa4b2"), 2.0, true)
		"sheet":
			_page(col)
			draw_string(font, Vector2(-23, 11), "XLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			for i in 3:
				draw_line(Vector2(8, -10 + i * 9), Vector2(18, -10 + i * 9), Color("9aa4b2"), 1.5, true)
			draw_line(Vector2(13, -14), Vector2(13, 24), Color("9aa4b2"), 1.5, true)
		"zip":
			_page(col)
			draw_string(font, Vector2(-23, 11), "ZIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, OUT)
			for i in 6:
				draw_rect(Rect2(10 + (i % 2) * 4, -26 + i * 5, 4, 3), OUT)
		"image":
			_f(_rr(Rect2(-26, -22, 52, 44), 5), Color("bfe6ff"))
			_f(PackedVector2Array([Vector2(-24, 20), Vector2(-6, -4), Vector2(6, 10), Vector2(14, 2), Vector2(24, 20)]), Color("5cc46a"), 0.0)
			_f(_ell(Vector2(12, -10), 6, 6), Color("ffd25a"), 2.0)
			draw_polyline(PackedVector2Array([Vector2(-24, 20), Vector2(-6, -4), Vector2(6, 10), Vector2(14, 2), Vector2(24, 20)]), OUT, 2.0, true)
		"globe":
			var g := _ell(Vector2.ZERO, 25, 25, 40)
			_f(g, col)
			for blob in [[Vector2(-9, -8), 9.0, 7.0], [Vector2(8, 9), 8.0, 10.0], [Vector2(12, -12), 5.0, 4.0]]:
				var b := Geometry2D.intersect_polygons(_ell(blob[0], blob[1], blob[2]), g)
				for q in b:
					draw_colored_polygon(q, Color("5cd17a"))
			draw_arc(Vector2.ZERO, 25, 0, TAU, 40, Color(1, 1, 1, 0), 1.0)
			draw_line(Vector2(-25, 0), Vector2(25, 0), Color(1, 1, 1, 0.65), 2.0, true)
			var mer := PackedVector2Array()
			for i in 21:
				var a := -PI * 0.5 + PI * i / 20.0
				mer.append(Vector2(cos(a) * 11, sin(a) * 25))
			draw_polyline(mer, Color(1, 1, 1, 0.65), 2.0, true)
			var mer2 := PackedVector2Array()
			for p in mer:
				mer2.append(Vector2(-p.x, p.y))
			draw_polyline(mer2, Color(1, 1, 1, 0.65), 2.0, true)
			draw_line(Vector2(0, -25), Vector2(0, 25), Color(1, 1, 1, 0.65), 2.0, true)
			_f(_ell(Vector2(-8, -12), 5, 3), Color(1, 1, 1, 0.5), 0.0)
		"music":
			_f(_rr(Rect2(-24, -24, 48, 48), 12), col)
			_f(_ell(Vector2(-6, 12), 7, 5.5), Color.WHITE, 0.0)
			_f(_ell(Vector2(12, 7), 7, 5.5), Color.WHITE, 0.0)
			draw_line(Vector2(0, 12), Vector2(0, -14), Color.WHITE, 3.5)
			draw_line(Vector2(18, 7), Vector2(18, -18), Color.WHITE, 3.5)
			draw_line(Vector2(-1, -14), Vector2(19, -19), Color.WHITE, 5.0)
		"gear":
			var gp := PackedVector2Array()
			for i in 48:
				var a := TAU * i / 48
				var r := 25.0 if (i / 3) % 2 == 0 else 19.0
				gp.append(Vector2(cos(a), sin(a)) * r)
			_f(gp, col)
			_f(_ell(Vector2.ZERO, 8, 8), Color("6b7785"), 2.5)
		"pad":
			var pad := _rr(Rect2(-27, -14, 54, 30), 14)
			_f(pad, col)
			draw_line(Vector2(-17, 1), Vector2(-7, 1), Color.WHITE, 4.0)
			draw_line(Vector2(-12, -4), Vector2(-12, 6), Color.WHITE, 4.0)
			_f(_ell(Vector2(10, -2), 3.5, 3.5), Color.WHITE, 0.0)
			_f(_ell(Vector2(17, 4), 3.5, 3.5), Color.WHITE, 0.0)
	_draw_extra()
	# label like a desktop icon (hidden while flying / on the floor)
	if not show_label or not state in ["desk", "drag", "shake"]:
		return
	var lbl: String = info().label
	var fs := 14
	var w := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(-w * 0.5, 50)
	draw_string_outline(font, pos + Vector2(1, 1.5), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.55))
	draw_string(font, pos, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _taper(pts: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var l := PackedVector2Array(); var r := PackedVector2Array()
	for i in pts.size():
		var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-d.y, d.x) * lerpf(w0, w1, float(i) / (pts.size() - 1))
		l.append(pts[i] + n); r.append(pts[i] - n)
	r.reverse()
	l.append_array(r)
	return l

func _tooth(c: Vector2, s: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		p.append(c + Vector2(cos(a) * 16, sin(a) * 12 - 2) * s)
	p.append(c + Vector2(16, 6) * s); p.append(c + Vector2(12, 22) * s); p.append(c + Vector2(6, 22) * s)
	p.append(c + Vector2(2, 10) * s); p.append(c + Vector2(-2, 10) * s); p.append(c + Vector2(-6, 22) * s)
	p.append(c + Vector2(-12, 22) * s); p.append(c + Vector2(-16, 6) * s)
	return p

func _draw_extra() -> void:
	match kind:
		"food_burger":
			_f(_rr(Rect2(-24, 8, 48, 12), 6), Color("e8a24a"))
			_f(_rr(Rect2(-26, -2, 52, 11), 5), Color("7a3e1d"))
			_f(PackedVector2Array([Vector2(-22, -4), Vector2(24, -4), Vector2(14, 6), Vector2(8, 2), Vector2(0, 9), Vector2(-8, 2), Vector2(-16, 6)]), Color("ffd23f"), 2.0)
			var lt := PackedVector2Array()
			for i in 13:
				lt.append(Vector2(-26 + i * 52.0 / 12.0, -6 + (3.0 if i % 2 == 0 else -1.0)))
			lt.append(Vector2(26, -10)); lt.append(Vector2(-26, -10))
			_f(lt, Color("6fd16a"), 2.0)
			var top := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				top.append(Vector2(cos(a) * 25, sin(a) * 20 - 9))
			_f(top, Color("f0a845"))
			for sd in [Vector2(-10, -20), Vector2(2, -24), Vector2(12, -18), Vector2(-2, -15)]:
				_f(_ell(sd, 2.2, 1.3), Color("fff6dc"), 0.0)
			_f(_ell(Vector2(-10, -18), 6, 2.5), Color(1, 1, 1, 0.35), 0.0)
		"food_cake":
			_f(PackedVector2Array([Vector2(-24, 22), Vector2(24, 22), Vector2(24, -4), Vector2(-24, 10)]), Color("ffe7b8"))
			draw_line(Vector2(-24, 15), Vector2(24, 8), Color("ff8fb8"), 3.0, true)
			_f(PackedVector2Array([Vector2(-26, 10), Vector2(26, -6), Vector2(26, 0), Vector2(18, 4), Vector2(14, 10), Vector2(8, 5), Vector2(-4, 12), Vector2(-12, 9), Vector2(-26, 16)]), Color("ff8fc0"), 2.5)
			draw_line(Vector2(14, -16), Vector2(10, -6), Color("3f8a3a"), 2.5, true)
			_f(_ell(Vector2(10, -4), 6, 6), Color("e8213b"), 2.5)
			_f(_ell(Vector2(8, -6), 2, 1.5), Color(1, 1, 1, 0.7), 0.0)
			for sp in [Vector2(-14, 9), Vector2(-2, 6), Vector2(18, 0)]:
				_f(_rr(Rect2(sp, Vector2(4, 2)), 1), Color("6fe3ff"), 0.0)
		"food_soda":
			var can := _rr(Rect2(-15, -24, 30, 50), 7)
			_f(can, Color("ff4b4b"))
			_f(_ell(Vector2(0, -22), 13, 4), Color("c9d2dc"), 2.0)
			_f(PackedVector2Array([Vector2(3, -12), Vector2(-7, 4), Vector2(0, 4), Vector2(-4, 18), Vector2(8, -1), Vector2(1, -1), Vector2(6, -12)]), Color("ffe14d"), 2.0)
			_f(_rr(Rect2(-11, -14, 4, 32), 2), Color(1, 1, 1, 0.35), 0.0)
		"food_gummy":
			var gc := Color(0.42, 0.88, 0.48, 0.95)
			for e in [Vector2(-10, -22), Vector2(10, -22)]:
				_f(_ell(e, 6, 6), gc)
			_f(_ell(Vector2(0, 10), 17, 17), gc)
			_f(_ell(Vector2(-15, 4), 6, 8), gc)
			_f(_ell(Vector2(15, 4), 6, 8), gc)
			_f(_ell(Vector2(-10, 24), 7, 6), gc)
			_f(_ell(Vector2(10, 24), 7, 6), gc)
			_f(_ell(Vector2(0, -12), 14, 12), gc)
			_f(_ell(Vector2(-5, -15), 2, 2.5), OUT, 0.0)
			_f(_ell(Vector2(5, -15), 2, 2.5), OUT, 0.0)
			draw_arc(Vector2(0, -10), 4, 0.3, PI - 0.3, 8, OUT, 1.8, true)
			_f(_ell(Vector2(-6, 4), 4, 7, 12), Color(1, 1, 1, 0.4), 0.0)
		"food_pepper":
			var fl := 1.0 + 0.15 * sin(t * 18.0)
			for fc in [[Vector2(10, -24), 7.0, Color("ff9f1c")], [Vector2(10, -23), 4.0, Color("ffe14d")]]:
				var c: Vector2 = fc[0]
				var r: float = fc[1] * fl
				_f(PackedVector2Array([c + Vector2(-r, 4), c + Vector2(0, -r * 2.0), c + Vector2(r, 4), c + Vector2(0, r * 0.9)]), fc[2], 0.0)
			var cl := PackedVector2Array()
			var ctrl := [Vector2(-10, -14), Vector2(14, -6), Vector2(10, 22), Vector2(-6, 28)]
			for i in 14:
				var u := i / 13.0
				var q: Vector2 = ctrl[0] * pow(1 - u, 3) + ctrl[1] * 3 * u * pow(1 - u, 2) + ctrl[2] * 3 * u * u * (1 - u) + ctrl[3] * pow(u, 3)
				cl.append(q)
			_f(_taper(cl, 12.0, 1.5), Color("ff3b2f"))
			draw_polyline(PackedVector2Array([Vector2(-6, -19), Vector2(6, -14), Vector2(12, -4)]), Color(1, 1, 1, 0.5), 3.0, true)
			draw_line(Vector2(-14, -18), Vector2(-20, -28), Color("3f9b46"), 4.0, true)
			_f(_ell(Vector2(-11, -16), 8, 6), Color("3f9b46"), 2.5)
		"upg_appetite":
			_f(_ell(Vector2(0, 4), 24, 18), Color("f4f6fa"))
			_f(_ell(Vector2(0, 4), 16, 11), Color("dfe5ee"), 0.0)
			draw_line(Vector2(-30, -20), Vector2(-24, 26), OUT, 6.0, true)
			draw_line(Vector2(-30, -20), Vector2(-24, 26), Color("c9d2dc"), 3.0, true)
			for fx in [-34.0, -30.0, -26.0]:
				draw_line(Vector2(fx, -28), Vector2(fx + 1, -18), Color("c9d2dc"), 2.0, true)
			_f(PackedVector2Array([Vector2(26, -26), Vector2(32, -4), Vector2(28, 26), Vector2(24, 26), Vector2(24, -4)]), Color("c9d2dc"), 2.5)
		"upg_teeth":
			var tp := _tooth(Vector2(0, -4), 1.25)
			_f(tp, Color("ffd23f"), 3.0)
			_f(_ell(Vector2(-8, -12), 5, 3, 10), Color(1, 1, 1, 0.6), 0.0)
			var sp := Vector2(18, -22)
			_f(PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(2, -2), sp + Vector2(7, 0), sp + Vector2(2, 2), sp + Vector2(0, 7), sp + Vector2(-2, 2), sp + Vector2(-7, 0), sp + Vector2(-2, -2)]), Color.WHITE, 0.0)
		"upg_chill":
			var hp := PackedVector2Array()
			for i in 30:
				var a := TAU * i / 30.0
				hp.append(Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))) * 1.6 + Vector2(0, 2))
			_f(hp, Color("ff6f91"))
			_f(_rr(Rect2(-22, -8, 19, 11), 4), OUT, 0.0)
			_f(_rr(Rect2(3, -8, 19, 11), 4), OUT, 0.0)
			draw_line(Vector2(-4, -5), Vector2(4, -5), OUT, 3.0)
			draw_line(Vector2(-18, -6), Vector2(-12, -6), Color(1, 1, 1, 0.6), 2.0)
			draw_line(Vector2(7, -6), Vector2(13, -6), Color(1, 1, 1, 0.6), 2.0)
			draw_arc(Vector2(0, 10), 6, 0.4, PI - 0.4, 8, OUT, 2.5, true)
		"upg_dreams":
			var moon := Geometry2D.clip_polygons(_ell(Vector2(-4, 2), 22, 22, 40), _ell(Vector2(8, -6), 18, 18, 40))
			for q in moon:
				_f(q, Color("ffd23f"))
			draw_string(font, Vector2(8, 4), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
			draw_string(font, Vector2(20, -10), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		"upg_auto":
			_f(_rr(Rect2(-22, -6, 44, 30), 4), Color("ff6b6b"))
			_f(_rr(Rect2(-25, -14, 50, 10), 3), Color("ff8a8a"))
			_f(_rr(Rect2(-4, -14, 8, 38), 1.5), Color("ffd23f"), 2.0)
			_f(_ell(Vector2(-8, -20), 8, 5, 20), Color("ffd23f"), 2.5)
			_f(_ell(Vector2(8, -20), 8, 5, 20), Color("ffd23f"), 2.5)
		"upg_roar":
			_f(PackedVector2Array([Vector2(-24, -6), Vector2(-8, -6), Vector2(14, -20), Vector2(14, 20), Vector2(-8, 6), Vector2(-24, 6)]), Color("ff9f43"))
			_f(_rr(Rect2(-12, 4, 6, 14), 2), Color("ff9f43"), 2.5)
			for i in 3:
				draw_arc(Vector2(16, 0), 8.0 + i * 7.0, -0.7, 0.7, 10, OUT, 5.0, true)
				draw_arc(Vector2(16, 0), 8.0 + i * 7.0, -0.7, 0.7, 10, Color("ffd23f"), 2.5, true)
