extends Node2D
## Particles, floating text, shockwaves, speech bubble.

const OUT := Color("1d2433")
signal coin_landed
var parts: Array = []
var font: Font
var big_font: Font
var px := 1.0
var bubble_text := ""
var bubble_t := 0.0
var bubble_life := 0.0
var bubble_pos := Vector2.ZERO
var bubble_angry := false
var bubble_rect := Rect2()

func say(text: String, life := 2.6, angry := false) -> void:
	bubble_text = text
	bubble_t = 0.0
	bubble_life = life
	bubble_angry = angry

func crumbs(pos: Vector2, col: Color, n := 14, power := 1.0) -> void:
	for i in n:
		var a := randf_range(-PI, 0.0)
		parts.append({"k": "crumb", "p": pos, "v": Vector2(cos(a), sin(a)) * randf_range(120, 380) * power * px,
			"life": randf_range(0.5, 0.9), "t": 0.0, "c": col.lerp(Color.WHITE, randf() * 0.3), "s": randf_range(3, 7) * px * sqrt(power), "r": randf() * TAU})

func hearts(pos: Vector2, n := 3) -> void:
	for i in n:
		parts.append({"k": "heart", "p": pos + Vector2(randf_range(-20, 20), 0) * px, "v": Vector2(randf_range(-40, 40), randf_range(-120, -80)) * px,
			"life": 1.1, "t": -i * 0.08, "c": Color("ff5c8a"), "s": randf_range(8, 12) * px, "r": 0.0})

func stars(pos: Vector2, n := 12, power := 1.0) -> void:
	for i in n:
		var a := TAU * i / n + randf() * 0.3
		parts.append({"k": "star", "p": pos, "v": Vector2(cos(a), sin(a)) * randf_range(200, 420) * power * px,
			"life": 0.9, "t": 0.0, "c": [Color("ffd23f"), Color("ff9f43"), Color("ffffff"), Color("6fe3ff")][i % 4], "s": randf_range(7, 12) * px * sqrt(power), "r": randf() * TAU})

func ring(pos: Vector2, radius: float, col := Color(1, 1, 1, 0.9), life := 0.6) -> void:
	parts.append({"k": "ring", "p": pos, "v": Vector2.ZERO, "life": life, "t": 0.0, "c": col, "s": radius, "r": 0.0})

func puff(pos: Vector2, n := 6, col := Color("d9f5b5"), power := 1.0) -> void:
	for i in n:
		parts.append({"k": "puff", "p": pos + Vector2(randf_range(-10, 10), randf_range(-6, 6)) * px * power, "v": Vector2(randf_range(10, 70), randf_range(-70, -30)) * px * power,
			"life": randf_range(0.7, 1.1), "t": 0.0, "c": col, "s": randf_range(8, 15) * px * power, "r": 0.0})

func text(pos: Vector2, s: String, size := 26, col := Color.WHITE, life := 1.2, big := false, rise := 60.0) -> void:
	parts.append({"k": "text", "p": pos, "v": Vector2(0, -rise * px), "life": life, "t": 0.0, "c": col, "s": size * px, "r": 0.0, "txt": s, "big": big})

## Fire breath particle: hot core -> orange -> red -> smoke.
func flame(pos: Vector2, dir: Vector2, power := 1.0) -> void:
	var a := dir.angle() + randf_range(-0.16, 0.16)
	parts.append({"k": "flame", "p": pos, "v": Vector2(cos(a), sin(a)) * randf_range(620, 900) * px * power,
		"life": randf_range(0.42, 0.62), "t": 0.0, "c": Color.WHITE, "s": randf_range(9, 15) * px * power, "r": randf() * TAU})

func coins(from: Vector2, to: Vector2, n := 5) -> void:
	for i in n:
		parts.append({"k": "coin", "p": from, "from": from, "to": to, "v": Vector2(randf_range(-160, 160), randf_range(-320, -160)) * px,
			"life": 0.85 + i * 0.05, "t": -i * 0.05, "c": Color("ffd23f"), "s": 9.0 * px, "r": randf() * TAU})

func _flame_col(u: float) -> Color:
	if u < 0.15:
		return Color("fff7c2").lerp(Color("ffd23f"), u / 0.15)
	if u < 0.4:
		return Color("ffd23f").lerp(Color("ff7a1a"), (u - 0.15) / 0.25)
	if u < 0.7:
		return Color("ff7a1a").lerp(Color("e8213b"), (u - 0.4) / 0.3)
	return Color("e8213b").lerp(Color(0.25, 0.22, 0.25), (u - 0.7) / 0.3)

func draw_coin(c: Vector2, r: float, spin := 0.0, a := 1.0) -> void:
	var sx := maxf(0.25, absf(cos(spin)))
	var tr := Transform2D(0.0, Vector2(sx, 1.0), 0.0, c)
	var body := PackedVector2Array()
	for i in 24:
		var an := TAU * i / 24.0
		body.append(Vector2(cos(an), sin(an)) * r)
	var bite := PackedVector2Array()
	for i in 12:
		var an := TAU * i / 12.0
		bite.append(Vector2(r * 0.8, -r * 0.8) + Vector2(cos(an), sin(an)) * r * 0.42)
	var cut := Geometry2D.clip_polygons(body, bite)
	if cut.size() > 0:
		body = cut[0]
	body = tr * body
	for o in Geometry2D.offset_polygon(body, maxf(1.5, r * 0.22), Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, Color(OUT.r, OUT.g, OUT.b, a))
	draw_colored_polygon(body, Color(1.0, 0.72, 0.15, a))
	var inner := PackedVector2Array()
	for p in body:
		inner.append(c + (p - c) * 0.72)
	draw_colored_polygon(inner, Color(1.0, 0.85, 0.25, a))
	draw_line(c + Vector2(-r * 0.2 * sx, -r * 0.35), c + Vector2(-r * 0.2 * sx, r * 0.35), Color(1, 1, 1, 0.75 * a), maxf(1.5, r * 0.2), true)

func _process(dt: float) -> void:
	var keep: Array = []
	for p in parts:
		p.t += dt
		if p.t < 0.0:
			keep.append(p)
			continue
		match p.k:
			"crumb":
				p.v.y += 1400.0 * px * dt
				p.r += dt * 9.0
			"star":
				p.v *= pow(0.04, dt)
				p.r += dt * 4.0
			"puff":
				p.v *= pow(0.3, dt)
				p.s += dt * 14.0 * px
			"text":
				p.v *= pow(0.15, dt)
			"flame":
				p.v *= pow(0.12, dt)
				p.v.y -= 260.0 * px * dt
				p.s += dt * 60.0 * px
				p.r += dt * 3.0
			"coin":
				var u: float = p.t / p.life
				var e := u * u * (3.0 - 2.0 * u)
				var arc: Vector2 = p.from.lerp(p.to, e) + p.v * 0.35 * sin(u * PI)
				p.p = arc
				p.r += dt * 9.0
				if p.t >= p.life:
					coin_landed.emit()
				if p.t < p.life:
					keep.append(p)
				continue
		p.p += p.v * dt
		if p.t < p.life:
			keep.append(p)
	parts = keep
	if bubble_text != "":
		bubble_t += dt
		if bubble_t > bubble_life:
			bubble_text = ""
	queue_redraw()

func _star(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot + TAU * i / 10.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts

func _heart(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 30:
		var t := TAU * i / 30.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y) * s / 16.0)
	return pts

func _outlined(poly: PackedVector2Array, col: Color, w: float) -> void:
	for o in Geometry2D.offset_polygon(poly, w, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, Color(OUT.r, OUT.g, OUT.b, col.a))
	draw_colored_polygon(poly, col)

func _draw() -> void:
	for p in parts:
		if p.t < 0.0:
			continue
		var u: float = p.t / p.life
		var a := 1.0 - u * u
		var col: Color = p.c
		match p.k:
			"crumb":
				var s: float = p.s
				var poly := PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s * 0.8, -s), Vector2(s, s * 0.7), Vector2(-s * 0.5, s)])
				var tr := Transform2D(p.r, p.p)
				_outlined(tr * poly, Color(col.r, col.g, col.b, a), 1.5 * px)
			"heart":
				var s2: float = p.s * (1.0 + 0.3 * sin(minf(1.0, u * 4.0) * PI))
				_outlined(_heart(p.p, s2), Color(col.r, col.g, col.b, a), 2.5 * px)
			"star":
				_outlined(_star(p.p, p.s * (1.0 - u * 0.5), p.r), Color(col.r, col.g, col.b, a), 2.0 * px)
			"ring":
				var r: float = p.s * (0.2 + 0.8 * (1.0 - pow(1.0 - u, 3.0)))
				draw_arc(p.p, r, 0, TAU, 64, Color(col.r, col.g, col.b, col.a * (1.0 - u)), (10.0 * (1.0 - u) + 2.0) * px, true)
			"flame":
				var fc := _flame_col(u)
				var fa := 0.92 * (1.0 - u * u)
				if u > 0.7:
					fa *= 0.55
				var r: float = p.s
				# cartoon fireball: dark-red rim, body colour, hot core
				draw_circle(p.p, r * 1.18, Color(0.75, 0.1, 0.12, fa * 0.55 * (1.0 - u)))
				draw_circle(p.p, r, Color(fc.r, fc.g, fc.b, fa))
				if u < 0.45:
					draw_circle(p.p - Vector2(0, r * 0.15), r * (0.55 - u), Color(1, 1, 0.82, fa))
			"coin":
				draw_coin(p.p, p.s * (1.0 + 0.4 * sin(u * PI)), p.r)
			"puff":
				draw_circle(p.p, p.s + 2.0 * px, Color(OUT.r, OUT.g, OUT.b, 0.5 * a))
				draw_circle(p.p, p.s, Color(col.r, col.g, col.b, 0.9 * a))
			"text":
				var f: Font = big_font if p.big else font
				var fs := int(p.s)
				var pop := 1.0 + 0.4 * maxf(0.0, 1.0 - u * 6.0)
				fs = int(fs * pop)
				var w := f.get_string_size(p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var pos: Vector2 = p.p - Vector2(w * 0.5, 0)
				var al := clampf((1.0 - u) * 3.0, 0.0, 1.0)
				draw_string_outline(f, pos + Vector2(0, fs * 0.08), p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.32) + 4, Color(OUT.r, OUT.g, OUT.b, al))
				draw_string(f, pos, p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, al))
	if bubble_text != "":
		_draw_bubble()

func _draw_bubble() -> void:
	var fs := int(17 * px)
	var lines := bubble_text.split("\n")
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var lh := fs * 1.15
	var pad := 12.0 * px
	var sz := Vector2(w + pad * 2, lh * lines.size() + pad * 1.4)
	var popin := minf(1.0, bubble_t * 8.0)
	var popout := clampf((bubble_life - bubble_t) * 6.0, 0.0, 1.0)
	var sc := (0.6 + 0.4 * popin + 0.08 * sin(minf(1.0, bubble_t * 4.0) * PI)) * popout
	var vp := get_viewport_rect().size
	var tip := bubble_pos
	var r := Rect2(tip + Vector2(-sz.x * 0.3, -sz.y - 16 * px), sz)
	r.position.x = clampf(r.position.x, 8, vp.x - sz.x - 8)
	r.position.y = clampf(r.position.y, 8, vp.y - sz.y - 8)
	bubble_rect = r.grow(10 * px)
	draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), 0.0, tip) * Transform2D(0.0, -tip))
	var bg := Color("fffaf0") if not bubble_angry else Color("ffe3dc")
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(14 * px))
	sb.set_border_width_all(int(3 * px))
	sb.border_color = OUT
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = int(6 * px)
	sb.shadow_offset = Vector2(0, 3) * px
	var tail_base := Vector2(clampf(tip.x, r.position.x + 18 * px, r.end.x - 18 * px), r.end.y - 2 * px)
	var tri := PackedVector2Array([tail_base + Vector2(-10, 0) * px, tail_base + Vector2(10, 0) * px, tip + Vector2(0, -4) * px])
	for o in Geometry2D.offset_polygon(tri, 3 * px, Geometry2D.JOIN_ROUND):
		draw_colored_polygon(o, OUT)
	draw_style_box(sb, r)
	draw_colored_polygon(tri, bg)
	for i in lines.size():
		var lw := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(r.position.x + (sz.x - lw) * 0.5, r.position.y + pad * 0.7 + fs * 0.95 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, OUT)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Screen-space rects of everything currently drawn (used for the Windows window region,
## which clips rendering as well as input).
func visual_rects() -> Array:
	var out: Array = []
	var agg := Rect2()
	var has_agg := false
	for p in parts:
		if p.t < 0.0:
			continue
		var s: float = p.s
		if p.k == "flame" or p.k == "coin" or p.k == "crumb":
			var e2 := s * 2.0 + 6.0 * px
			var pr := Rect2(p.p - Vector2(e2, e2), Vector2(e2, e2) * 2.0)
			agg = pr if not has_agg else agg.merge(pr)
			has_agg = true
			continue
		match p.k:
			"ring":
				var u: float = p.t / p.life
				var r: float = s * (0.2 + 0.8 * (1.0 - pow(1.0 - u, 3.0))) + 14.0 * px
				out.append(Rect2(p.p - Vector2(r, r), Vector2(r, r) * 2.0))
			"text":
				var f: Font = big_font if p.big else font
				var fs := int(s * 1.4)
				var w := f.get_string_size(p.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs
				out.append(Rect2(p.p - Vector2(w * 0.5, fs * 1.1), Vector2(w, fs * 1.6)))
			_:
				var e := s * 2.0 + 6.0 * px
				out.append(Rect2(p.p - Vector2(e, e), Vector2(e, e) * 2.0))
	if has_agg:
		out.append(agg)
	if bubble_text != "":
		out.append(bubble_rect)
	return out
