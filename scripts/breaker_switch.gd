extends StaticBody3D

var prompt_message = ""
var aisle_num: int = 3

func setup(num: int) -> void:
	aisle_num = num
	prompt_message = "[E] Bật lại Cầu chì Lối đi " + str(aisle_num)

func interact(player_node) -> void:
	var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	if game_manager:
		# Animation xẹt điện: Tạo một OmniLight3D nhấp nháy cực mạnh tại vị trí cầu chì
		var spark_light = OmniLight3D.new()
		spark_light.light_color = Color(0.3, 0.7, 1.0) # Màu điện xanh chói
		spark_light.light_energy = 5.0
		spark_light.omni_range = 8.0
		get_tree().current_scene.add_child(spark_light)
		spark_light.global_position = global_position
		
		# Nháy điện
		var tween = create_tween()
		tween.tween_property(spark_light, "light_energy", 0.0, 0.05)
		tween.tween_property(spark_light, "light_energy", 6.0, 0.05)
		tween.tween_property(spark_light, "light_energy", 0.0, 0.1)
		tween.tween_callback(spark_light.queue_free)
		
		# Rung camera người chơi nhẹ do giật điện/tiếng nổ lách tách cầu chì
		if player_node.has_method("shake_camera"):
			player_node.shake_camera(0.25, 0.03)
			
		game_manager.fix_aisle_lights(aisle_num)
		queue_free()
