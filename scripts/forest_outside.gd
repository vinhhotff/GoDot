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

@onready var dialog_container = $HUD/DialogContainer
@onready var dialog_label = $HUD/DialogContainer/VBox/DialogLabel
@onready var sender_label = $HUD/DialogContainer/VBox/SenderLabel
@onready var screen_fade = $HUD/ScreenFade
@onready var previous_guard_car = $Car
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

func _process(delta: float) -> void:
	# Tự động kích hoạt đối thoại khi người chơi đi bộ lại gần cửa siêu thị (khoảng cách < 8.0)
	if not dialogue_triggered:
		var dist = player.global_position.distance_to($NPC_Guard.global_position)
		if dist < 6.0:
			_start_dialogue()

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
			door.prompt_message = "[E] Mở cửa chính để vào siêu thị West làm việc"

func _animate_car_leaving() -> void:
	# Animation xe lùi ra rồi phóng mất hút
	var tween = create_tween()
	# Xe lùi nhẹ
	tween.tween_property(previous_guard_car, "global_position:z", previous_guard_car.global_position.z + 4.0, 0.8)
	# Xe phóng đi sang bên trái mất hút vào rừng cây
	tween.tween_property(previous_guard_car, "global_position:x", previous_guard_car.global_position.x - 50.0, 2.2)
	tween.tween_callback(func(): previous_guard_car.visible = false)

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

# Hàm đồng bộ UI Raycast tương tác của Player
func update_interaction_ui(text: String) -> void:
	# Chỉ hiện gợi ý mở cửa nếu đã bàn giao ca trực xong
	if dialogue_triggered and current_step >= dialog_steps.size():
		var label = player.get_node_or_null("HUD/StaminaContainer").get_parent().get_node_or_null("InteractionLabel")
		if label:
			label.text = text
			label.visible = text != ""
