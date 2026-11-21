extends Control
## Round menu button with a tiny kaiju face.
signal pressed
var hover := false
var t := 0.0
var px := 1.0
const OUT := Color("1d2433")

func _ready() -> void:
	mouse_entered.connect(func(): hover = true)
	mouse_exited.connect(func(): hover = false)

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		pressed.emit()
		accept_event()

func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.5 - 3.0 * px
	var s := 1.0 + (0.08 if hover else 0.0)
	draw_circle(c + Vector2(0, 3) * px, r * s, Color(0, 0, 0, 0.3))
	draw_circle(c, r * s + 3.0 * px, OUT)
	draw_circle(c, r * s, Color("62cc5c"))
	# spikes on top
	for i in 3:
		var x := c.x - 9 * px + i * 9 * px
		var tri := PackedVector2Array([Vector2(x - 4 * px, c.y - r * 0.82), Vector2(x, c.y - r * 1.25), Vector2(x + 4 * px, c.y - r * 0.82)])
		draw_colored_polygon(tri, Color("ff9f43"))
	var blink := 1.0 if fmod(t, 3.7) > 3.55 else 0.0
	for ex in [-7.0, 7.0]:
		var ep := c + Vector2(ex * px, -3 * px)
		draw_circle(ep, 5.5 * px, OUT)
		draw_circle(ep, 4.2 * px, Color.WHITE if blink < 0.5 else Color("62cc5c"))
		if blink < 0.5:
			draw_circle(ep + Vector2(0.8, 0.8) * px, 2.4 * px, OUT)
	draw_arc(c + Vector2(0, 5) * px, 7 * px, 0.3, PI - 0.3, 12, OUT, 2.5 * px, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(2, 11) * px, c + Vector2(5, 11) * px, c + Vector2(3.5, 15) * px]), Color.WHITE)
