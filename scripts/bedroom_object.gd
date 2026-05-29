extends StaticBody3D

@export var object_type: String = "phone" # "phone", "wardrobe", "door"
@export var prompt_message: String = "Nhấn E để mở điện thoại"

@onready var level = get_owner()

func interact(player_node) -> void:
	if object_type == "phone":
		level.open_phone()
			
	elif object_type == "wardrobe":
		if not level.has_checked_phone:
			level.show_dialog(" Aaron: 'Mình nên kiểm tra điện thoại trước xem có tin nhắn tuyển dụng không.'")
		else:
			level.open_inventory()
			
	elif object_type == "door":
		if not level.has_changed_clothes:
			level.show_dialog(" Aaron: 'Mình không thể ra ngoài làm với bộ đồ ngủ lôi thôi này được.'")
		else:
			# Chuyển sang không gian xa xôi bên ngoài siêu thị
			level.show_dialog(" Lái xe tiến về phía siêu thị West Market hẻo lánh...")
			var fade = level.screen_fade
			var tween = create_tween()
			tween.tween_property(fade, "color:a", 1.0, 1.5)
			tween.tween_callback(func(): 
				get_tree().change_scene_to_file("res://scenes/forest_outside.tscn")
			)
