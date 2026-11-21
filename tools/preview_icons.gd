extends SceneTree
func _initialize() -> void:
	var I = load("res://icon.gd")
	var f = load("res://fonts/LilitaOne-Regular.ttf")
	DisplayServer.window_set_size(Vector2i(1100, 300)); root.size = Vector2i(1100, 300)
	var bg := ColorRect.new(); bg.color = Color("2a2340"); bg.size = Vector2(1100, 300); root.add_child(bg)
	var ks := ["food_burger", "food_cake", "food_soda", "food_gummy", "food_pepper", "upg_appetite", "upg_teeth", "upg_chill", "upg_dreams", "upg_auto", "upg_roar"]
	for i in ks.size():
		var ic = I.new(); ic.kind = ks[i]; ic.font = f; ic.pop = 1.0
		ic.position = Vector2(60 + (i % 6) * 170, 80 + (i / 6) * 140); ic.scale = Vector2(1.5, 1.5)
		root.add_child(ic)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/preview_icons.png")
	quit()
