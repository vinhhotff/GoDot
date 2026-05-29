extends StaticBody3D

var prompt_message = "[E] Bật lại nhạc Jazz phát thanh (Nhấn nút Reset đỏ)"

func interact(_player_node) -> void:
	var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	if game_manager:
		# Animation nhấn nút vật lý (Tween thụt sâu rồi nhả ra)
		var start_pos = position
		var tween = create_tween()
		tween.tween_property(self, "position", start_pos + global_transform.basis.z * -0.08, 0.08)
		tween.tween_property(self, "position", start_pos, 0.08)
		
		# Đổi chất liệu sang màu xanh lá báo hiệu thành công
		var mesh_inst = get_node_or_null("MeshInstance3D")
		if mesh_inst and mesh_inst.material_override:
			var mat = mesh_inst.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.1, 1.0, 0.1)
				mat.emission = Color(0.1, 0.8, 0.1)
				
				# Trả lại màu đỏ sau 3 giây để sẵn sàng cho lần mất nhạc tiếp theo
				var reset_timer = get_tree().create_timer(3.0)
				reset_timer.timeout.connect(func():
					if is_instance_valid(mat):
						mat.albedo_color = Color(1.0, 0.1, 0.1)
						mat.emission = Color(0.8, 0.1, 0.1)
				)
				
		game_manager.reset_jazz_music()
