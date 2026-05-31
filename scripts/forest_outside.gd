extends Node3D

var dialog_steps = [
	{
		"sender": "Aaron",
		"text": "Nơi này xa xôi và u uất quá... Mình phải đi bộ tiến lại gần lối vào siêu thị kia xem sao."
	},
	{
		"sender": "Đồng nghiệp ca trước (Người phụ nữ)",
		"text": "Cậu là Aaron đúng không? Tôi đã đợi cậu nãy giờ..."
	},
	{
		"sender": "Đồng nghiệp ca trước (Người phụ nữ)",
		"text": "Hãy nhớ lấy lời tôi: Tuyệt đối không được phá lệ trước bất kỳ quy tắc nào mà Clive để lại! Nghe rõ chưa?!"
	},
	{
		"sender": "Aaron",
		"text": "Quy tắc ư? Ý cô là sao..."
	},
	{
		"sender": "Hệ thống",
		"text": "Không đợi bạn trả lời, người phụ nữ thở dốc vội vã lao thẳng ra xe ô tô đang đỗ ở bãi, đóng sầm cửa lại và nhấn ga phóng đi ngay lập tức vào màn đêm mất hút..."
	},
	{
		"sender": "Aaron",
		"text": "Thật kỳ lạ... Thôi, bãi xe giờ chỉ còn mình mình. Hãy mở cửa chính và bước vào siêu thị để bắt đầu ca làm việc."
	}
]

var current_step = 0
var dialogue_triggered = false
var warning_triggered = false
var dead = false
const WARNING_DISTANCE = 40.0
const DEATH_DISTANCE = 55.0
const LEVEL_CENTER = Vector3(0, 0, -15.0)

@onready var dialog_container = $HUD/DialogContainer
@onready var dialog_label = $HUD/DialogContainer/VBox/DialogLabel
@onready var sender_label = $HUD/DialogContainer/VBox/SenderLabel
@onready var screen_fade = $HUD/ScreenFade
@onready var previous_guard_car = get_node_or_null("Sketchfab_Scene") if has_node("Sketchfab_Scene") else get_node_or_null("Car")
@onready var player = $Player

func _ready() -> void:
	# Cho phép đi bộ tự do lúc đầu
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	dialog_container.visible = false
	
	# Màn hình sáng dần chiều tà
	screen_fade.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(screen_fade, "color:a", 0.0, 1.5)
	
	# Đăng ký tương tác cửa siêu thị
	$SupermarketDoor.add_to_group("interactable")
	
	# Tạo một khu vực thủy tinh phát sáng màu xanh cyan trong suốt cực đẹp tại lối vào để người chơi nhìn thấy chỗ tương tác E
	var door_mesh = $SupermarketDoor.get_node_or_null("MeshInstance3D")
	if door_mesh:
		door_mesh.visible = true
		var mat = StandardMaterial3D.new()
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.1, 0.6, 1.0, 0.2) # Màu xanh cyan neon mờ ảo rất đẹp
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.3, 0.5) # Tự phát sáng nhẹ trong đêm tối
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Phát sáng đều tăm tắp
		door_mesh.set_surface_override_material(0, mat)

func _process(delta: float) -> void:
	# Tự động kích hoạt đối thoại khi người chơi đi bộ lại gần cửa siêu thị (khoảng cách < 8.0)
	if not dialogue_triggered and is_instance_valid(player) and has_node("NPC_Guard"):
		var dist = player.global_position.distance_to($NPC_Guard.global_position)
		if dist < 6.0:
			_start_dialogue()
			
	# Kiểm tra khoảng cách giới hạn bản đồ (ngăn đi quá xa)
	if not dead and is_instance_valid(player):
		var dist_to_center = player.global_position.distance_to(LEVEL_CENTER)
		
		# 1. Cảnh báo tự nhủ
		if dist_to_center > WARNING_DISTANCE and not warning_triggered:
			warning_triggered = true
			show_dialog("Aaron: 'Mình không nên đi quá xa bãi xe... Ngoài kia tối tăm quá, mình phải vào ca làm việc ngay, nếu cứ đi tiếp sẽ gặp nguy hiểm!'")
			# Nháy đỏ nhẹ cảnh báo
			var warning_tween = create_tween()
			screen_fade.color = Color(0.5, 0.0, 0.0, 0.0)
			warning_tween.tween_property(screen_fade, "color:a", 0.3, 0.5)
			warning_tween.tween_property(screen_fade, "color:a", 0.0, 0.5)
			
		# Reset lại cảnh báo nếu người chơi quay lại khu vực an toàn
		elif dist_to_center < WARNING_DISTANCE - 5.0 and warning_triggered:
			warning_triggered = false
			
		# 2. Bị thực thể tấn công và chết
		if dist_to_center > DEATH_DISTANCE:
			_kill_player()

func _start_dialogue() -> void:
	dialogue_triggered = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Hiện chuột để bấm next thoại
	dialog_container.visible = true
	_show_step()

func _show_step() -> void:
	if current_step < dialog_steps.size():
		var step = dialog_steps[current_step]
		dialog_label.text = step["text"]
		sender_label.text = step["sender"]
		
		# Đổi màu chữ người nói để tăng tính rùng rợn
		if step["sender"] == "Đồng nghiệp ca trước (Người phụ nữ)":
			sender_label.modulate = Color(1, 0.3, 0.3)
		else:
			sender_label.modulate = Color(0.9, 0.9, 0.9)
			
		# Khi đến bước hệ thống báo xe chạy đi
		if current_step == 4:
			_animate_car_leaving()
	else:
		# Kết thúc hội thoại, cho phép người chơi tự tay mở cửa siêu thị
		dialog_container.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Cập nhật gợi ý nhiệm vụ mới
		var door = get_node_or_null("SupermarketDoor")
		if door:
			door.prompt_message = "[E] Vào nhà hàng"

func _animate_car_leaving() -> void:
	if not is_instance_valid(previous_guard_car):
		return
	# Animation xe lùi ra rồi phóng mất hút
	var tween = create_tween()
	# Xe lùi nhẹ
	tween.tween_property(previous_guard_car, "global_position:z", previous_guard_car.global_position.z + 4.0, 0.8)
	# Xe phóng đi sang bên trái mất hút vào rừng cây
	tween.tween_property(previous_guard_car, "global_position:x", previous_guard_car.global_position.x - 50.0, 2.2)
	tween.tween_callback(func(): previous_guard_car.visible = false)

# Xử lý khi người chơi đi quá xa và bị thực thể giết chết
func _kill_player() -> void:
	dead = true
	# Vô hiệu hóa điều khiển và khóa di chuyển
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Camera giật và rung lắc cực kỳ mạnh do thực thể tấn công bất ngờ
	if player.has_method("shake_camera"):
		player.shake_camera(2.5, 0.18)
		
	# Tạo màn phủ màu đỏ máu nhấp nháy rồi tối sầm lại
	var death_overlay = ColorRect.new()
	death_overlay.anchors_preset = Control.PRESET_FULL_RECT
	death_overlay.color = Color(0.5, 0.0, 0.0, 0.0) # Đỏ mờ ban đầu
	$HUD.add_child(death_overlay)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT) # Đảm bảo full rect sau khi thêm
	
	var tween = create_tween()
	tween.tween_property(death_overlay, "color", Color(0.08, 0.0, 0.0, 0.98), 1.2) # Chuyển sang đỏ đen kinh dị
	
	# Tạo dòng chữ "BẠN ĐÃ CHẾT" kích thước lớn, màu đỏ máu có viền đen rùng rợn
	var dead_label = Label.new()
	dead_label.text = "BẠN ĐÃ CHẾT"
	dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 72
	label_settings.font_color = Color(0.9, 0.1, 0.1) # Đỏ tươi rực
	label_settings.outline_size = 8
	label_settings.outline_color = Color(0, 0, 0) # Viền đen dầy
	dead_label.label_settings = label_settings
	
	dead_label.modulate.a = 0.0
	death_overlay.add_child(dead_label) # Thêm vào death_overlay để căn chỉnh chuẩn
	dead_label.set_anchors_preset(Control.PRESET_CENTER)
	dead_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dead_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Hiển thị chữ từ từ
	var tween_text = create_tween()
	tween_text.tween_interval(0.5)
	tween_text.tween_property(dead_label, "modulate:a", 1.0, 0.8)
	
	# Thêm gợi ý/lời dẫn rùng rợn bên dưới
	var sub_label = Label.new()
	sub_label.text = "Một thực thể bóng tối trong rừng sâu đã nuốt chửng bạn...\nHãy tập trung vào ca làm việc chính!"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var sub_settings = LabelSettings.new()
	sub_settings.font_size = 20
	sub_settings.font_color = Color(0.7, 0.7, 0.7)
	sub_settings.outline_size = 4
	sub_settings.outline_color = Color(0, 0, 0)
	sub_label.label_settings = sub_settings
	
	sub_label.modulate.a = 0.0
	death_overlay.add_child(sub_label) # Thêm vào death_overlay để căn chỉnh chuẩn
	sub_label.set_anchors_preset(Control.PRESET_CENTER)
	sub_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	sub_label.position.y += 90 # Đẩy dòng phụ xuống dưới chữ chính
	
	var tween_sub = create_tween()
	tween_sub.tween_interval(1.2)
	tween_sub.tween_property(sub_label, "modulate:a", 1.0, 0.8)
	
	# Tải lại màn chơi sau 4.5 giây để chơi lại
	var reload_timer = get_tree().create_timer(4.5)
	reload_timer.timeout.connect(func():
		get_tree().reload_current_scene()
	)

func _on_next_button_pressed() -> void:
	current_step += 1
	_show_step()

# Gọi từ cửa siêu thị khi người chơi nhấn E
func enter_supermarket() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var tween = create_tween()
	tween.tween_property(screen_fade, "color:a", 1.0, 1.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main_level.tscn")
	)

# Hiển thị hộp thoại ngắn gọn (ví dụ từ cửa khi tương tác)
func show_dialog(text: String) -> void:
	dialog_container.visible = true
	sender_label.text = "Aaron"
	sender_label.modulate = Color(0.9, 0.9, 0.9)
	dialog_label.text = text
	var tween = create_tween()
	tween.tween_interval(4.0)
	tween.tween_callback(func():
		if not dialogue_triggered or current_step >= dialog_steps.size():
			dialog_container.visible = false
	)

# Hàm đồng bộ UI Raycast tương tác của Player
func update_interaction_ui(text: String) -> void:
	if is_instance_valid(player):
		var label = player.get_node_or_null("HUD/InteractionLabel")
		if label:
			label.text = text
			label.visible = text != ""
