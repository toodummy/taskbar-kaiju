extends SceneTree
# Art preview: renders every species at every stage + expressions to /tmp/preview.png
func _initialize() -> void:
	var K = load("res://kaiju.gd")
	DisplayServer.window_set_size(Vector2i(1800, 1000)); root.size = Vector2i(1800, 1000)
	var bg := ColorRect.new(); bg.color = Color("5a3f8a"); bg.size = Vector2(1800, 1000); root.add_child(bg)
	var scales := [0.8, 1.1, 1.4, 1.7, 2.0]
	var sp := ["dino", "octo", "mecha", "yeti"]
	for r in 4:
		var x := 70.0
		for s in 5:
			var k = K.new(); k.species = sp[r]; k.stage = s; k.k = scales[s]; k.scale = Vector2(scales[s], scales[s])
			k.position = Vector2(x, 200 + r * 220); root.add_child(k); k.look = Vector2(0.6, -0.3); k.glow_t = 0.2; k.tail_t = r
			x += 150.0 * scales[s] + 30
		var moods := [{"mouth": 1.0}, {"happy": 1.0}, {"angry": 1.0, "mouth": 0.6}]
		for i in 3:
			var k = K.new(); k.species = sp[r]; k.stage = 2; k.k = 1.2; k.scale = Vector2(1.2, 1.2); k.position = Vector2(1330 + i * 160, 200 + r * 220); root.add_child(k)
			for key in moods[i]: k.set(key, moods[i][key])
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/preview.png")
	quit()
