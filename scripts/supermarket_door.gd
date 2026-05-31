extends StaticBody3D

@export var prompt_message: String = "Cửa nhà hàng khóa (Hãy nói chuyện với đồng nghiệp trước)"

func interact(player_node) -> void:
	var level = get_owner()
	# Chỉ cho phép vào khi đã bàn giao ca trực xong (dialogue_triggered và đã hết hội thoại)
	if level.dialogue_triggered and level.current_step >= level.dialog_steps.size():
		level.enter_supermarket()
	else:
		level.show_dialog(" Aaron: 'Mình nên lại gần nói chuyện với đồng nghiệp ca trước đang đứng gần đó đã.'")
