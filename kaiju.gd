extends Node2D
## Cartoon vector kaiju. Origin = between the feet on the ground, facing +x.
## main.gd sets the fields below every frame; this script only draws.

const OUT := Color("1d2433")
const BELLY := Color("fbeec1")
const BELLY_LINE := Color("e6cf8f")
const EYE := Color("ffffff")
const MOUTH := Color("6e1c3a")
const TONGUE := Color("ff6f91")
const TOOTH := Color("ffffff")
const BLUSH := Color(1.0, 0.45, 0.6, 0.55)
const BODY_COLS := [Color("8fdc5e"), Color("62cc5c"), Color("41b874"), Color("2fa18b"), Color("2b8796")]
const SPIKE_COLS := [Color("ffb347"), Color("ff9f43"), Color("ff8a3d"), Color("ff7a3a"), Color("ffcf3f")]

var species := "dino"
var stage := 0               # 0..4
var k := 1.0                 # screen scale (for outline widths)
var walk_phase := 0.0
var walk_amt := 0.0          # 0 idle .. 1 walking
var mouth := 0.0             # 0 closed .. 1 wide
var look := Vector2.ZERO     # pupil offset, local units, -1..1
var blink := 0.0             # 0 open .. 1 shut
var angry := 0.0             # 0..1 rampage tint
var happy := 0.0             # 0..1 happy eyes + blush
var arms_up := 0.0           # roar pose
var tail_t := 0.0
var egg := false
var egg_crack := 0.0         # 0..1
var egg_wobble := 0.0
var glow_t := 0.0

func _w(px: float) -> float:
	return px / maxf(0.3, sqrt(k))

func _ell(c: Vector2, rx: float, ry: float, rot := 0.0, n := 0) -> PackedVector2Array:
	if n == 0:
		n = clampi(int(24.0 + sqrt(maxf(rx, ry) * k) * 3.0), 24, 96)
	var p := PackedVector2Array()
	p.resize(n)
	var cr := cos(rot)
	var sr := sin(rot)
	for i in n:
		var a := TAU * i / n
		var x := cos(a) * rx
		var y := sin(a) * ry
		p[i] = c + Vector2(x * cr - y * sr, x * sr + y * cr)
	return p

func _fill(p: PackedVector2Array, col: Color) -> void:
	if p.size() < 3:
		return
	if Geometry2D.triangulate_polygon(p).is_empty():
		# self-intersecting (tight curls): let Clipper split it into valid pieces
		for q in Geometry2D.offset_polygon(p, 0.01):
			if not Geometry2D.triangulate_polygon(q).is_empty():
				_fill(q, col)
		return
	draw_colored_polygon(p, col)
	var c := p.duplicate()
	c.append(p[0])
	draw_polyline(c, col, 1.1 / k, true)

func _outline(p: PackedVector2Array, w: float, col := OUT) -> void:
	for o in Geometry2D.offset_polygon(p, w, Geometry2D.JOIN_ROUND):
		_fill(o, col)

func _round(p: PackedVector2Array, r: float) -> PackedVector2Array:
	var a := Geometry2D.offset_polygon(p, -r, Geometry2D.JOIN_MITER)
	if a.is_empty():
		return p
	var b := Geometry2D.offset_polygon(a[0], r, Geometry2D.JOIN_ROUND)
	return b[0] if not b.is_empty() else p

const PALETTES := {
	"octo": [Color("c992ff"), Color("b673f7"), Color("a05dec"), Color("8b4bdc"), Color("7a3cc9")],
	"mecha": [Color("b4c6d8"), Color("9fb6cd"), Color("8aa6c2"), Color("7896b8"), Color("6683ac")],
	"yeti": [Color("ffffff"), Color("fbfdff"), Color("f3f9ff"), Color("ebf4ff"), Color("e2efff")],
}
const EGG_SPOTS := {"dino": Color("8fdc5e"), "octo": Color("b673f7"), "mecha": Color("8aa6c2"), "yeti": Color("8fd3ff")}

func _body_col() -> Color:
	var c: Color = BODY_COLS[stage] if species == "dino" else PALETTES[species][stage]
	if angry <= 0.01:
		return c
	var h := lerpf(c.h, -0.02, angry * 0.97)
	return Color.from_hsv(fposmod(h, 1.0), lerpf(c.s, 0.72, angry), lerpf(c.v, 0.92, angry))

func _spike_col() -> Color:
	return (SPIKE_COLS[stage] as Color).lerp(Color("ffe14d"), angry * 0.7)

func _draw() -> void:
	if egg:
		_draw_egg()
		return
	match species:
		"octo": _draw_octo()
		"mecha": _draw_mecha()
		"yeti": _draw_yeti()
		_: _draw_dino()

func _draw_dino() -> void:
	var body_col := _body_col()
	var dark := body_col.darkened(0.25)
	var spike_col := _spike_col()
	var W := _w(3.4)

	var bob := absf(sin(walk_phase)) * 3.0 * walk_amt
	var lift_f := maxf(0.0, sin(walk_phase)) * 7.0 * walk_amt
	var lift_b := maxf(0.0, -sin(walk_phase)) * 7.0 * walk_amt
	var by := -bob

	# --- silhouette parts ---
	var body_c := Vector2(0, -47 + by)
	var body := PackedVector2Array()
	var n := clampi(int(40 + k * 6), 40, 110)
	for i in n:
		var a := TAU * i / n
		var s := sin(a)
		var rx := 37.0 * (1.0 + 0.13 * s)
		var ry := 41.0
		body.append(body_c + Vector2(cos(a) * rx, s * ry))
	var leg_b := _ell(Vector2(-17, -8 - lift_b), 12, 9.5)
	var leg_f := _ell(Vector2(15, -8 - lift_f), 12.5, 10)
	var arm_r := lerpf(0.5, -1.9, arms_up)
	var arm_f := _ell(Vector2(27, -22 + by) + Vector2(cos(arm_r), sin(arm_r)) * 7.0, 6.5, 11, arm_r + PI * 0.5)
	var arm_b := _ell(Vector2(-27, -28 + by) + Vector2(cos(PI - arm_r), sin(PI - arm_r)) * 7.0, 6, 10, -arm_r - PI * 0.5)
	# tail (tapered stroke)
	var tail := PackedVector2Array()
	var tl := PackedVector2Array()
	var tr := PackedVector2Array()
	var wag := sin(tail_t * 3.0) * 0.18 + sin(walk_phase) * 0.12 * walk_amt
	for i in 9:
		var u := i / 8.0
		var pt := Vector2(-22 - 46 * u, -18 + by * 0.5 + 10 * u * u - 26 * pow(u, 3.0) * (1.0 + wag))
		var ang := atan2(10 * 2 * u - 78 * u * u * (1.0 + wag), -46)
		var nrm := Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5))
		var wdt := lerpf(14.0, 2.5, u)
		tl.append(pt + nrm * wdt)
		tr.append(pt - nrm * wdt)
	tail.append_array(tl)
	tr.reverse()
	tail.append_array(tr)
	# spikes along the back
	var spikes: Array[PackedVector2Array] = []
	var count := 3 + stage
	for i in count:
		var u := (i + 0.5) / count
		var a := lerpf(PI * 1.05, PI * 1.62, u)
		var base := body_c + Vector2(cos(a) * 36.0, sin(a) * 40.0)
		var nrm := Vector2(cos(a), sin(a) * 0.9).normalized()
		var tang := Vector2(-nrm.y, nrm.x)
		var h := (9.0 + stage * 2.2) * (0.75 + 0.5 * sin(PI * u))
		var bw := 7.0 + stage * 0.8
		var tip := base + nrm * h + tang * h * 0.25
		spikes.append(_round(PackedVector2Array([base + tang * bw - nrm * 4.0, tip, base - tang * bw - nrm * 4.0]), 1.6))
	# tail spikes
	for i in 2:
		var u := 0.35 + i * 0.3
		var base := Vector2(-22 - 46 * u, -18 + 10 * u * u - 26 * pow(u, 3.0) * (1.0 + wag) - 10.0 * (1.0 - u))
		var s2 := 5.0 + stage
		spikes.append(_round(PackedVector2Array([base + Vector2(6, 2), base + Vector2(-2, -s2 - 3), base + Vector2(-7, 3)]), 1.2))
	var horns: Array[PackedVector2Array] = []
	if stage >= 1:
		var hh := 8.0 + stage * 4.0
		for hx in [2.0, 20.0]:
			var hb := Vector2(hx, -85 + by + absf(hx - 4.0) * 0.25)
			horns.append(_round(PackedVector2Array([hb + Vector2(-5.5, 4), hb + Vector2(-2 - stage * 1.5, -hh), hb + Vector2(5.5, 4)]), 1.4))

	# glow behind spikes for the final form
	if stage == 4 or angry > 0.5:
		var gl := 0.25 + 0.15 * sin(glow_t * 4.0)
		for s in spikes:
			var c := Vector2.ZERO
			for q in s:
				c += q
			c /= s.size()
			draw_circle(c, 6.5, Color(spike_col.r, spike_col.g, spike_col.b, gl * 0.35))

	# --- unified outline pass (sticker look) ---
	var sil: Array[PackedVector2Array] = [tail, leg_b, arm_b, body, leg_f, arm_f]
	sil.append_array(spikes)
	sil.append_array(horns)
	for p in sil:
		_outline(p, W)
	# --- fills back to front ---
	for s in spikes:
		_fill(s, spike_col)
	for h in horns:
		_fill(h, Color("f4ead2"))
	_fill(tail, body_col)
	_fill(leg_b, dark)
	_fill(arm_b, dark)
	_fill(body, body_col)
	# soft shading on the body
	var shade := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var s := sin(a)
		shade.append(body_c + Vector2(cos(a) * 37.0 * (1.0 + 0.13 * s) * 0.92 - 4.0, s * 41.0 * 0.92 + 3.0))
	var clip := Geometry2D.clip_polygons(body, shade)
	for c in clip:
		_fill(c, dark.lerp(body_col, 0.45))
	# highlight
	_fill(_ell(body_c + Vector2(-10, -24), 10, 5, -0.5), Color(1, 1, 1, 0.28))
	# belly
	var belly_c := body_c + Vector2(9, 12)
	_fill(_ell(belly_c, 22, 25, 0.12), BELLY)
	for i in 3:
		var yy := belly_c.y - 6 + i * 9
		var hw := 17.0 - absf(i - 1) * 3.0
		draw_arc(Vector2(belly_c.x + 1, yy - 18), 20.0, PI * 0.5 - hw / 26.0, PI * 0.5 + hw / 26.0, 12, BELLY_LINE, _w(2.2), true)
	# front leg + arm with their own outline
	_outline(leg_f, W)
	_fill(leg_f, body_col.darkened(0.08))
	for c in 3:
		_fill(_ell(Vector2(21 + c * 4.0 - 4.0, -3 - lift_f), 2.4, 2.0), Color("f4ead2"))
	_outline(arm_f, W)
	_fill(arm_f, body_col.darkened(0.04))

	_draw_face(by)

func _draw_face(by: float, ek := 1.0) -> void:
	var fy := -62.0 + by
	var eyes := [[Vector2(5, fy), 10.5 * ek, 12.5 * ek], [Vector2(25, fy + 1.5), 11.5 * ek, 13.5 * ek]]
	var bl := clampf(blink, 0.0, 1.0)
	for e in eyes:
		var c: Vector2 = e[0]
		var rx: float = e[1]
		var ry: float = e[2]
		if happy > 0.5:
			draw_arc(c + Vector2(0, 4), rx * 0.75, PI * 1.1, PI * 1.9, 14, OUT, _w(4.0), true)
			continue
		var ryb := maxf(1.2, ry * (1.0 - bl))
		var ep := _ell(c, rx, ryb)
		_outline(ep, _w(2.6))
		_fill(ep, EYE)
		if bl < 0.8:
			var pc := c + Vector2(look.x * rx * 0.38, look.y * ryb * 0.32)
			var pr := rx * 0.52
			var pcol := OUT if angry < 0.5 else Color("b3122e")
			var pp := _ell(pc, pr, minf(pr * 1.25, ryb * 0.85))
			_fill(pp, pcol)
			_fill(_ell(pc + Vector2(-pr * 0.35, -pr * 0.45), pr * 0.36, pr * 0.36 * minf(1.0, ryb / ry)), Color.WHITE)
			_fill(_ell(pc + Vector2(pr * 0.4, pr * 0.35), pr * 0.15, pr * 0.15), Color(1, 1, 1, 0.8))
	# brows
	if angry > 0.2:
		var a := angry
		for br in [[Vector2(-6, fy - 15), Vector2(12, fy - 8 - 4 * (1 - a))], [Vector2(17, fy - 7 - 4 * (1 - a)), Vector2(36, fy - 15)]]:
			var p0: Vector2 = br[0]
			var p1: Vector2 = br[1]
			var nn := (p1 - p0).normalized().orthogonal() * 2.6
			_fill(_round(PackedVector2Array([p0 + nn, p1 + nn * 0.8, p1 - nn * 0.8, p0 - nn]), 0.8), OUT)
	# cheeks
	if happy > 0.05:
		_fill(_ell(Vector2(38, fy + 14), 6, 3.5), Color(BLUSH.r, BLUSH.g, BLUSH.b, BLUSH.a * happy))
		_fill(_ell(Vector2(-4, fy + 13), 5, 3), Color(BLUSH.r, BLUSH.g, BLUSH.b, BLUSH.a * happy))
	# mouth
	var mc := Vector2(22, -40 + by)
	if mouth < 0.06:
		var pts := PackedVector2Array()
		for i in 9:
			var u := i / 8.0
			pts.append(mc + Vector2(-12 + 24 * u, -3 + sin(u * PI) * (4.0 + happy * 3.0) - u * 2.0))
		draw_polyline(pts, OUT, _w(3.2), true)
		var fang := PackedVector2Array([mc + Vector2(4, 1.2), mc + Vector2(7.5, 1.0), mc + Vector2(5.8, 6.5)])
		_fill(fang, TOOTH)
		draw_polyline(PackedVector2Array([fang[0], fang[2], fang[1]]), OUT, _w(1.6), true)
	else:
		var m := mouth
		var rx := 11.0 + 9.0 * m
		var ry := 2.5 + 15.0 * m
		var mp := _ell(mc + Vector2(1, ry * 0.35), rx, ry)
		_outline(mp, _w(3.0))
		_fill(mp, MOUTH)
		var tg := _ell(mc + Vector2(2, ry * 0.35 + ry * 0.55), rx * 0.62, ry * 0.42)
		var tclip := Geometry2D.intersect_polygons(tg, mp)
		for t in tclip:
			_fill(t, TONGUE)
		var top := mc.y + ry * 0.35 - ry
		var bot := mc.y + ry * 0.35 + ry
		for i in 4:
			var x := mc.x + 1 - rx * 0.7 + i * rx * 0.47
			var tt := PackedVector2Array([Vector2(x - 3.2, top + 1.0), Vector2(x + 3.2, top + 1.0), Vector2(x, top + 4.5 + 4.5 * m)])
			var c2 := Geometry2D.intersect_polygons(tt, mp)
			for t in c2:
				_fill(t, TOOTH)
		for i in 2:
			var x := mc.x + 1 - rx * 0.35 + i * rx * 0.7
			var tt := PackedVector2Array([Vector2(x - 3.0, bot - 1.0), Vector2(x, bot - 4.0 - 3.0 * m), Vector2(x + 3.0, bot - 1.0)])
			var c3 := Geometry2D.intersect_polygons(tt, mp)
			for t in c3:
				_fill(t, TOOTH)

func _draw_egg() -> void:
	var W := _w(3.4)
	var rot := sin(egg_wobble) * 0.18 * minf(1.0, egg_crack * 2.0 + 0.3)
	var pts := PackedVector2Array()
	for i in 60:
		var a := TAU * i / 60
		var s := sin(a)
		var r := Vector2(cos(a) * 30.0 * (1.0 + 0.12 * s), s * 38.0)
		pts.append(Vector2(0, -38).rotated(rot) + r.rotated(rot))
	_outline(pts, W)
	_fill(pts, Color("fff4dc"))
	for sp in [[Vector2(-12, -52), 6.0], [Vector2(10, -30), 8.0], [Vector2(-8, -18), 4.5], [Vector2(14, -58), 4.0]]:
		_fill(_ell(Vector2(0, -38).rotated(rot) + ((sp[0] as Vector2) - Vector2(0, -38)).rotated(rot), sp[1], sp[1] * 0.8), EGG_SPOTS.get(species, Color("8fdc5e")))
	if egg_crack > 0.05:
		var c := PackedVector2Array()
		var segs := int(2 + egg_crack * 6)
		for i in segs + 1:
			var x := -24.0 + 48.0 * i / 8.0
			c.append(Vector2(x, -44 + (6.0 if i % 2 == 0 else -6.0)).rotated(rot))
		draw_polyline(c, OUT, _w(3.0), true)


# ---------------- shared helpers for the other species ----------------
func _stroke(pts: Array, w0: float, w1: float) -> PackedVector2Array:
	var l := PackedVector2Array()
	var r := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[maxi(0, i - 1)]
		var b: Vector2 = pts[mini(n - 1, i + 1)]
		var d := (b - a).normalized()
		var nrm := Vector2(-d.y, d.x)
		var w := lerpf(w0, w1, float(i) / (n - 1))
		l.append(pts[i] + nrm * w)
		r.append(pts[i] - nrm * w)
	r.reverse()
	l.append_array(r)
	return l

func _rr(r: Rect2, rad: float, rot := 0.0, pivot := Vector2.ZERO) -> PackedVector2Array:
	var p := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + r.size - Vector2(rad, rad), r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for ci in 4:
		for j in 7:
			var a := -PI * 0.5 + (ci + j / 6.0) * PI * 0.5
			var q: Vector2 = cs[ci] + Vector2(cos(a), sin(a)) * rad
			p.append(pivot + (q - pivot).rotated(rot))
	return p

func _shade(poly: PackedVector2Array, col: Color) -> void:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	c /= poly.size()
	var inner := PackedVector2Array()
	for q in poly:
		inner.append(c + (q - c) * 0.92 + Vector2(-4, 3))
	for piece in Geometry2D.clip_polygons(poly, inner):
		_fill(piece, col)

func _clip_fill(p: PackedVector2Array, mask: PackedVector2Array, col: Color) -> void:
	for piece in Geometry2D.intersect_polygons(p, mask):
		_fill(piece, col)

func _walk_vals() -> Array:
	var bob := absf(sin(walk_phase)) * 3.0 * walk_amt
	return [-bob, maxf(0.0, sin(walk_phase)) * 7.0 * walk_amt, maxf(0.0, -sin(walk_phase)) * 7.0 * walk_amt]

# ---------------- OCTO: slime octopus kaiju ----------------
func _draw_octo() -> void:
	var body_col := _body_col()
	var dark := body_col.darkened(0.3)
	var W := _w(3.4)
	var wv := _walk_vals()
	var by: float = wv[0] + sin(tail_t * 2.2) * 1.2
	var tents: Array = []
	for i in 6:
		var u := i / 5.0
		var bx := lerpf(-27.0, 30.0, u)
		var out_dir := (u - 0.45) * 2.0
		var ph := tail_t * 3.0 + i * 1.3 + walk_phase * 1.6 * walk_amt
		var pts: Array = []
		for j in 14:
			var v := j / 13.0
			var x := bx + out_dir * 18.0 * v + sin(ph + v * 3.0) * (2.5 + 3.0 * walk_amt) * v
			var y := lerpf(-28.0 + by * 0.6, -4.0, smoothstep(0.0, 0.7, v))
			var cv := maxf(0.0, v - 0.6) / 0.4
			x += signf(out_dir + 0.001) * cv * cv * 12.0
			y -= cv * cv * (6.0 + 3.0 * sin(ph))
			pts.append(Vector2(x, y))
		tents.append(_stroke(pts, 9.5, 3.2))
	var fin_a := sin(tail_t * 4.0) * 0.25 + arms_up * 0.5
	var fins: Array[PackedVector2Array] = []
	if stage >= 1:
		var fs := 9.0 + stage * 3.0
		fins.append(_ell(Vector2(-30, -76 + by) + Vector2(-fs * 0.5, -fs * 0.2).rotated(-fin_a), fs, fs * 0.6, -0.6 - fin_a))
		fins.append(_ell(Vector2(30, -80 + by) + Vector2(fs * 0.5, -fs * 0.2).rotated(fin_a), fs, fs * 0.6, 0.6 + fin_a))
	var bc := Vector2(2, -52 + by)
	var body := PackedVector2Array()
	var n := clampi(int(40 + k * 6), 40, 110)
	for i in n:
		var a := TAU * i / n
		var s := sin(a)
		body.append(bc + Vector2(cos(a) * 37.0 * (1.0 - 0.1 * s), s * 39.0))
	var sil: Array[PackedVector2Array] = []
	sil.append_array(fins)
	for t in tents:
		sil.append(t)
	sil.append(body)
	for p in sil:
		_outline(p, W)
	for f in fins:
		_fill(f, body_col.lightened(0.15))
	for i in tents.size():
		if i % 2 == 0:
			_fill(tents[i], dark)
	_fill(body, body_col)
	_shade(body, dark.lerp(body_col, 0.45))
	# spots + glowing dots
	for sp in [[Vector2(-18, -72), 6.0], [Vector2(-25, -52), 4.5], [Vector2(-6, -84), 4.0], [Vector2(-27, -34), 5.0], [Vector2(-12, -60), 3.0]]:
		_clip_fill(_ell((sp[0] as Vector2) + Vector2(0, by), sp[1], sp[1] * 0.85), body, dark.lerp(body_col, 0.3))
	if stage >= 2:
		var gl := 0.55 + 0.35 * sin(glow_t * 3.0)
		for i in stage + 1:
			var p := Vector2(-24 + i * 9.0, -40 - (i % 2) * 8.0 + by)
			draw_circle(p, 4.0, Color(0.4, 1.0, 0.95, gl * 0.35))
			draw_circle(p, 1.8, Color(0.75, 1.0, 1.0, gl))
	_fill(_ell(bc + Vector2(-10, -22), 12, 6, -0.5), Color(1, 1, 1, 0.33))
	_fill(_ell(bc + Vector2(-20, -8), 3.5, 2.2, -0.5), Color(1, 1, 1, 0.3))
	# slime drip
	var dl := 4.0 + 3.0 * sin(tail_t * 1.7)
	var drip := _ell(Vector2(-14, -16 + by + dl * 0.5), 3.2, 3.0 + dl * 0.5)
	_outline(drip, _w(2.4))
	_fill(drip, body_col.lightened(0.2))
	for i in tents.size():
		if i % 2 == 1:
			_outline(tents[i], W)
			_fill(tents[i], body_col.lightened(0.05))
	# suction cups on front tentacles
	for i in [1, 3, 5]:
		var t: PackedVector2Array = tents[i]
		var half := t.size() / 2
		for j in [2, 4, 6]:
			var q := t[t.size() - 1 - j].lerp(t[j], 0.3)
			_fill(_ell(q, 2.2, 1.7), Color("ffd6f2"))
	_draw_face(by)

# ---------------- MECHA: robot kaiju ----------------
func _draw_mecha() -> void:
	var body_col := _body_col()
	var dark := body_col.darkened(0.35)
	var steel := Color("e9eef4")
	var accent := Color("ffc93c").lerp(Color("ff4b3e"), angry)
	var W := _w(3.4)
	var wv := _walk_vals()
	var by: float = wv[0]
	var lf: float = wv[1]
	var lb: float = wv[2]
	var body := _rr(Rect2(-33, -92 + by, 68, 80), 17)
	var foot_b := _rr(Rect2(-29, -14 - lb, 22, 14), 5)
	var foot_f := _rr(Rect2(6, -14 - lf, 26, 14), 5)
	var leg_b := _rr(Rect2(-22, -22 - lb * 0.5, 9, 12), 3)
	var leg_f := _rr(Rect2(14, -22 - lf * 0.5, 9, 12), 3)
	var thr1 := _rr(Rect2(-47, -80 + by, 17, 22), 5)
	var thr2 := _rr(Rect2(-45, -50 + by, 14, 20), 5)
	var ar := lerpf(0.35, -1.7, arms_up)
	var arm_f := _rr(Rect2(26, -40 + by, 11, 24), 5, ar, Vector2(31, -38 + by))
	var arm_b := _rr(Rect2(-36, -42 + by, 10, 22), 5, -ar, Vector2(-31, -40 + by))
	var fins: Array[PackedVector2Array] = []
	if stage >= 3:
		for i in stage - 1:
			var y := -86 + i * 13.0 + by
			fins.append(_round(PackedVector2Array([Vector2(-30, y), Vector2(-48 - stage * 2.0, y + 4), Vector2(-30, y + 10)]), 1.2))
	var ants: Array = [[Vector2(10, -92 + by), Vector2(4, -110 + by - stage * 2.0)]]
	if stage >= 1:
		ants.append([Vector2(24, -92 + by), Vector2(30, -106 + by - stage * 1.5)])
	for a in ants:
		draw_line(a[0], a[1], OUT, _w(5.5), true)
		draw_line(a[0], a[1], steel, _w(2.4), true)
	var sil: Array[PackedVector2Array] = [thr1, thr2, leg_b, foot_b, arm_b, body, leg_f, foot_f, arm_f]
	sil.append_array(fins)
	for p in sil:
		_outline(p, W)
	for f in fins:
		_fill(f, accent)
	for t in [thr1, thr2]:
		_fill(t, Color("5b6675"))
	# thruster glow
	var fl := 0.6 + 0.4 * sin(glow_t * 30.0)
	for c in [Vector2(-49, -69 + by), Vector2(-47, -40 + by)]:
		draw_circle(c, 6.0 * fl + 2.0 * walk_amt, Color(1.0, 0.55, 0.15, 0.6))
		draw_circle(c, 3.0 * fl, Color(1.0, 0.95, 0.6, 0.9))
	_fill(leg_b, Color("5b6675"))
	_fill(foot_b, dark)
	_fill(arm_b, dark)
	_fill(body, body_col)
	_shade(body, dark.lerp(body_col, 0.5))
	# panel seams + rivets
	draw_line(Vector2(-33, -30 + by), Vector2(35, -30 + by), dark, _w(2.0), true)
	for rv in [Vector2(-25, -84), Vector2(27, -84), Vector2(-25, -20), Vector2(27, -20), Vector2(-25, -50)]:
		_fill(_ell(rv + Vector2(0, by), 2.2, 2.2), steel)
		_fill(_ell(rv + Vector2(0.5, 0.6 + by), 1.0, 1.0), dark)
	_fill(_ell(Vector2(-14, -80 + by), 10, 4, -0.3), Color(1, 1, 1, 0.35))
	# hazard chest plate
	var plate := _rr(Rect2(-4, -27 + by, 34, 12), 4)
	_outline(plate, _w(2.2))
	_fill(plate, accent)
	for i in 5:
		var x := -4 + i * 8.0
		_clip_fill(PackedVector2Array([Vector2(x, -27 + by), Vector2(x + 4, -27 + by), Vector2(x - 2, -15 + by), Vector2(x - 6, -15 + by)]), plate, OUT)
	# core light
	if stage >= 2:
		var gl := 0.6 + 0.4 * sin(glow_t * 4.0)
		draw_circle(Vector2(-16, -21 + by), 6.0, Color(0.37, 0.95, 1.0, 0.3 * gl))
		_fill(_ell(Vector2(-16, -21 + by), 3.5, 3.5), Color(0.6, 1.0, 1.0, gl))
	_fill(leg_f, Color("6b7787"))
	_outline(foot_f, W)
	_fill(foot_f, dark.lightened(0.1))
	_outline(arm_f, W)
	_fill(arm_f, body_col.darkened(0.08))
	if stage >= 2:
		var pad := _rr(Rect2(22, -46 + by, 18, 10), 4)
		_outline(pad, _w(2.6))
		_fill(pad, accent)
	# antenna bulbs
	var blink_on := fmod(glow_t, 1.2) < 0.6
	for a in ants:
		_outline(_ell(a[1], 3.6, 3.6), _w(2.4))
		_fill(_ell(a[1], 3.6, 3.6), Color("ff4b5c") if blink_on else Color("8a2433"))
	# visor + LED eyes
	var visor := _rr(Rect2(-7, -78 + by, 48, 30), 10)
	_outline(visor, _w(2.8))
	_fill(visor, Color("1f2a44"))
	var led := Color("5ff3ff") if angry < 0.5 else Color("ff3b3b")
	var bl := clampf(blink, 0.0, 1.0)
	for ex in [7.0, 27.0]:
		var c := Vector2(ex + look.x * 4.0, -63 + by + look.y * 3.0)
		if happy > 0.5:
			draw_arc(c + Vector2(0, 4), 5.5, PI * 1.1, PI * 1.9, 10, led, _w(3.5), true)
			continue
		var h := maxf(1.0, 8.5 * (1.0 - bl))
		draw_circle(c, 10.0, Color(led.r, led.g, led.b, 0.18))
		var e := _rr(Rect2(c.x - 5.5, c.y - h, 11, h * 2), 4)
		if angry > 0.5:
			var cut := PackedVector2Array([Vector2(c.x - 8, c.y - h - 2), Vector2(c.x + 8, c.y - h - 2), Vector2(c.x + 8, c.y - h + 5) if ex < 15 else Vector2(c.x + 8, c.y - h - 2), Vector2(c.x - 8, c.y - h + 5) if ex > 15 else Vector2(c.x - 8, c.y - h - 2)])
			var clipped := Geometry2D.clip_polygons(e, cut)
			if not clipped.is_empty():
				e = clipped[0]
		_fill(e, led)
		_fill(_ell(c + Vector2(-2, -h * 0.4), 1.6, 2.0), Color(1, 1, 1, 0.8))
	# grille / furnace jaw
	var m := mouth
	if m < 0.06:
		var gr := _rr(Rect2(9, -42 + by, 28, 9), 3)
		_outline(gr, _w(2.4))
		_fill(gr, steel)
		for i in 4:
			draw_line(Vector2(14 + i * 6.0, -40 + by), Vector2(14 + i * 6.0, -35 + by), OUT, _w(2.0), true)
	else:
		var jh := 4.0 + 20.0 * m
		var jaw := _rr(Rect2(7, -44 + by, 32, jh), 4)
		_outline(jaw, _w(2.8))
		_fill(jaw, Color("3a0d12"))
		_fill(_ell(Vector2(23, -44 + by + jh * 0.6), 11, jh * 0.3), Color(1.0, 0.35, 0.15, 0.85))
		for i in 4:
			var x := 10 + i * 7.5
			_clip_fill(PackedVector2Array([Vector2(x, -44 + by), Vector2(x + 6, -44 + by), Vector2(x + 3, -38 + by)]), jaw, steel)
		for i in 3:
			var x := 13 + i * 8.0
			_clip_fill(PackedVector2Array([Vector2(x, -44 + by + jh), Vector2(x + 6, -44 + by + jh), Vector2(x + 3, -49 + by + jh)]), jaw, steel)

# ---------------- YETI: fluffy snow kaiju ----------------
func _fur(c: Vector2, rx: float, ry: float, bumps: int, amp: float, pear := 0.1, rot := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	var n := clampi(int(bumps * 7), 40, 140)
	for i in n:
		var a := TAU * i / n
		var s := sin(a)
		var f := 1.0 + amp * pow(absf(sin(a * bumps * 0.5)), 0.6)
		p.append(c + Vector2(cos(a) * rx * (1.0 + pear * s) * f, s * ry * f).rotated(rot))
	return p

func _draw_yeti() -> void:
	var body_col := _body_col()
	var dark := body_col.darkened(0.18)
	var skin := Color("a9c8ea").lerp(Color("ff9a9a"), angry * 0.6)
	var horn := Color("f1d39e")
	var W := _w(3.4)
	var wv := _walk_vals()
	var by: float = wv[0]
	var lf: float = wv[1]
	var lb: float = wv[2]
	var body := _fur(Vector2(0, -47 + by), 35.0, 39.0, 18, 0.06, 0.13)
	var tail := _fur(Vector2(-37, -24 + by), 9.0, 9.0, 8, 0.15)
	var foot_b := _ell(Vector2(-17, -6 - lb), 14, 7.5)
	var foot_f := _ell(Vector2(16, -6 - lf), 15, 8)
	var ar := lerpf(0.5, -1.9, arms_up)
	var arm_f := _fur(Vector2(28, -34 + by) + Vector2(cos(ar), sin(ar)) * 8.0, 8.0, 13.0, 8, 0.1, 0.0, ar + PI * 0.5)
	var arm_b := _fur(Vector2(-28, -36 + by) + Vector2(cos(PI - ar), sin(PI - ar)) * 8.0, 7.0, 12.0, 8, 0.1, 0.0, -ar - PI * 0.5)
	var horns: Array[PackedVector2Array] = []
	var hl := 0.8 + stage * 0.22
	for hd in [[Vector2(-14, -80), -1.0], [Vector2(28, -80), 1.0]]:
		var base: Vector2 = hd[0] + Vector2(0, by)
		var sd: float = hd[1]
		var pts: Array = []
		for j in 9:
			var v := j / 8.0
			var ang := -PI * 0.5 - sd * (0.4 + v * 2.6 * hl)
			var rr := 12.0 * hl * (1.0 - v * 0.55)
			pts.append(base + Vector2(sd * 9.0 * hl, 0) + Vector2(cos(ang), sin(ang)) * rr * Vector2(1.0, 1.0) + Vector2(sd * v * 4.0, 0))
		horns.append(_stroke(pts, 5.5, 2.0))
	var crystals: Array[PackedVector2Array] = []
	if stage >= 2:
		for i in stage:
			var u := (i + 0.5) / stage
			var a := lerpf(PI * 1.1, PI * 1.55, u)
			var b := Vector2(0, -47 + by) + Vector2(cos(a) * 36.0, sin(a) * 40.0)
			var nrm := Vector2(cos(a), sin(a)).normalized()
			var t := Vector2(-nrm.y, nrm.x)
			var h := 10.0 + stage * 2.5
			crystals.append(PackedVector2Array([b + t * 5.0, b + nrm * h * 0.6 + t * 4.0, b + nrm * h, b + nrm * h * 0.6 - t * 4.0, b - t * 5.0]))
	var sil: Array[PackedVector2Array] = [tail, foot_b, arm_b, body, foot_f, arm_f]
	sil.append_array(horns)
	sil.append_array(crystals)
	for p in sil:
		_outline(p, W)
	for c in crystals:
		_fill(c, Color("9fe8ff"))
		draw_line(c[0].lerp(c[4], 0.5), c[2], Color(1, 1, 1, 0.7), _w(1.5), true)
	_fill(tail, body_col)
	_fill(foot_b, skin.darkened(0.15))
	_fill(arm_b, dark)
	_fill(body, body_col)
	_shade(body, Color("cfe0f2").lerp(body_col, 0.2))
	# fur tufts
	for tf in [Vector2(-20, -66), Vector2(-26, -42), Vector2(-12, -24), Vector2(-4, -80)]:
		var q: Vector2 = tf + Vector2(0, by)
		draw_polyline(PackedVector2Array([q, q + Vector2(3, -4), q + Vector2(6, 0)]), Color("bdd3ea"), _w(1.8), true)
	for h in horns:
		_fill(h, horn)
	# icy face patch
	var patch := _ell(Vector2(16, -54 + by), 23, 25, 0.1)
	_fill(patch, skin)
	_fill(_ell(Vector2(8, -70 + by), 8, 3, -0.2), Color(1, 1, 1, 0.35))
	_outline(foot_f, W)
	_fill(foot_f, skin.darkened(0.1))
	for t in 3:
		_fill(_ell(Vector2(22 + t * 5.0 - 5.0, -4 - lf), 2.6, 2.2), skin.lightened(0.35))
	_outline(arm_f, W)
	_fill(arm_f, body_col.darkened(0.03))
	_draw_face(by, 0.85)
