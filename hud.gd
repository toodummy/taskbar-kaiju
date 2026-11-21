extends Control
## Crunch counter pill next to the kaiju-face button, plus active snack timers.

const OUT := Color("1d2433")
var main: Node
var px := 1.0
var font: Font
var big_font: Font
var bump := 0.0
var coin_tex: Texture2D

static func make_coin_texture(sz: int) -> ImageTexture:
	# Gold coin with a bite taken out of it (the "Crunch").
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := Vector2(sz, sz) * 0.5
	var r := sz * 0.5 - 1.0
	var bite_c := c + Vector2(r * 0.78, -r * 0.78)
	var bite_r := r * 0.42
	for y in sz:
		for x in sz:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var db := p.distance_to(bite_c)
			# signed distance to the bitten shape (positive = inside)
			var sd := minf(r - d, db - bite_r)
			var a := clampf(sd + 0.5, 0.0, 1.0)
			if a <= 0.0:
				continue
			var rim := r * 0.2
			var col := Color("1d2433")
			if sd > rim:
				col = Color(1.0, 0.85, 0.25)
				if sd < rim * 2.1:
					col = Color(1.0, 0.72, 0.15)
				# shine stripe
				var q := p - c
				if absf(q.x + r * 0.22) < r * 0.09 and absf(q.y) < r * 0.38 and minf(r - d, db - bite_r) > rim * 2.1:
					col = Color(1, 1, 0.92)
			elif sd > rim * 0.45:
				col = Color(0.85, 0.52, 0.08)
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)

func coin_center() -> Vector2:
	return global_position + Vector2(22, size.y * 0.5) * Vector2(px, 1)

func _process(dt: float) -> void:
	bump = maxf(0.0, bump - dt * 4.0)
	queue_redraw()

func _chip(pos: Vector2, text: String, col: Color) -> float:
	var fs := int(13 * px)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16 * px
	var r := Rect2(pos - Vector2(w, 0), Vector2(w, 22 * px))
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(11 * px))
	sb.set_border_width_all(int(2.5 * px))
	sb.border_color = OUT
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	draw_string(font, r.position + Vector2(8 * px, 16 * px), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, OUT)
	return w

func _draw() -> void:
	var s := 1.0 + bump * 0.18
	var c := size * 0.5
	draw_set_transform(c - c * s, 0.0, Vector2(s, s))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff7e6")
	sb.set_corner_radius_all(int(size.y * 0.5))
	sb.set_border_width_all(int(3 * px))
	sb.border_color = OUT
	sb.anti_aliasing = true
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = int(5 * px)
	sb.shadow_offset = Vector2(0, 3) * px
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var cs := size.y - 10 * px
	draw_texture_rect(coin_tex, Rect2(Vector2(5 * px, 5 * px), Vector2(cs, cs)), false)
	var n := str(int(round(main.coins_shown)))
	var fs := int(24 * px)
	var tw := big_font.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := (size.x + cs) * 0.5 - tw * 0.5 + 2 * px
	var col := Color("ffd23f").lerp(Color.WHITE, bump)
	draw_string_outline(big_font, Vector2(tx, size.y * 0.5 + fs * 0.38), n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(7 * px), OUT)
	draw_string(big_font, Vector2(tx, size.y * 0.5 + fs * 0.38), n, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform(Vector2.ZERO)
	# active effect chips above the pill
	var x := size.x
	var y := -28 * px
	if main.xp_boost_t > 0.0:
		x -= _chip(Vector2(x, y), "2x XP  %ds" % int(ceil(main.xp_boost_t)), Color("ffb347")) + 6 * px
	if main.frenzy_t > 0.0:
		x -= _chip(Vector2(x, y), "FRENZY  %ds" % int(ceil(main.frenzy_t)), Color("ff6b6b")) + 6 * px
