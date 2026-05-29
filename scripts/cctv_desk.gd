extends StaticBody3D

# Bàn CCTV vật lý đặt trong phòng nghỉ Breakroom
# Người chơi phải lại gần và nhấn E để mở màn hình giám sát

var prompt_message: String = "[E] Xem màn hình camera giám sát CCTV"

func interact(player_node) -> void:
	var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	if game_manager:
		# Animation đèn màn hình sáng lên khi bật
		var screen_glow = get_node_or_null("ScreenGlow")
		if is_instance_valid(screen_glow):
			var tween = create_tween()
			tween.tween_property(screen_glow, "light_energy", 1.8, 0.3)

		game_manager.toggle_cctv_ui(player_node)
