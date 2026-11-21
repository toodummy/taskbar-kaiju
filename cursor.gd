extends Node2D
## Fake mouse cursor drawn only in the showcase demo (the real cursor is not captured).
const OUT := Color("1d2433")
var press := 0.0
var px := 1.0

func _process(dt: float) -> void:
	press = maxf(0.0, press - dt * 5.0)
	queue_redraw()

func _draw() -> void:
	var s := px * 1.25 * (1.0 - press * 0.18)
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 25), Vector2(6, 19.5), Vector2(10.5, 29), Vector2(15, 27), Vector2(10.5, 18), Vector2(18, 17.5)])
	for i in pts.size():
		pts[i] *= s
	var sh := pts.duplicate()
	for i in sh.size():
		sh[i] += Vector2(2, 3) * px
	draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
	for o in Geometry2D.offset_polygon(pts, 2.2 * px, Geometry2D.JOIN_MITER):
		draw_colored_polygon(o, OUT)
	draw_colored_polygon(pts, Color.WHITE)
	if press > 0.0:
		draw_arc(Vector2.ZERO, (1.0 - press) * 26.0 * px + 4 * px, 0, TAU, 32, Color(1, 0.85, 0.3, press), 3.0 * px, true)
