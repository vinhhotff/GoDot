extends StaticBody3D

@export var prompt_message: String = "[Khoá] Hộc tủ quầy thanh toán số một"

var scroll_ui_packed = preload("res://scenes/rule_scroll_ui.tscn")

func interact(player_node) -> void:
	var game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	if not game_manager:
		return

	# Chỉ cho đọc sau khi Clive đã gọi điện bàn giao ca
	if not game_manager.has_called_clive:
		return

	# Animate mở hộc tủ gỗ / cuộn giấy (nâng nhẹ cuộn giấy lên khi tương tác)
	var start_y = position.y
	var tween = create_tween()
	tween.tween_property(self, "position:y", start_y + 0.15, 0.25)
	tween.tween_property(self, "position:y", start_y, 0.25)

	# Hiển thị UI Cuộn Giấy Quy Tắc trên một CanvasLayer riêng
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100

	var scroll_ui = scroll_ui_packed.instantiate()
	canvas_layer.add_child(scroll_ui)
	get_tree().current_scene.add_child(canvas_layer)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Tắt physics process tạm thời để đọc
	player_node.set_physics_process(false)

	# Kết nối nút Đóng để trả lại điều khiển
	var is_first_read = (prompt_message != "[E] Đọc lại Cuộn giấy Quy tắc của Clive")
	scroll_ui.get_node("CloseButton").pressed.connect(func():
		canvas_layer.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player_node.set_physics_process(true)

		# Lần đọc đầu tiên → bắt đầu ca trực chính thức 12:00 AM
		if is_first_read:
			prompt_message = "[E] Đọc lại Cuộn giấy Quy tắc của Clive"
			game_manager.start_official_shift()
	)
