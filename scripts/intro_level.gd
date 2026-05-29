extends Control

# Quản lý kịch bản tin nhắn điện thoại
var dialog_steps = [
	{
		"text": "Mình thực sự bế tắc rồi... Tiền thuê nhà đã trễ 2 tuần, trong túi chỉ còn chưa đầy 50 nghìn lẻ...",
		"sender": "Aaron (Tôi)"
	},
	{
		"text": "Nếu không tìm được công việc nào ngay lập tức, tuần sau mình sẽ bị tống ra đường mất.",
		"sender": "Aaron (Tôi)"
	},
	{
		"text": "*Bíp bíp!* Điện thoại đột ngột rung lên. Có một tin nhắn mới từ số lạ.",
		"sender": "Hệ thống"
	},
	{
		"text": "[TIN TUYỂN DỤNG GẤP]\nCần tuyển bảo vệ ca đêm tại siêu thị West (West Market), bangia.\n- Ca làm: 12:00 AM - 6:00 AM.\n- Lương: 21 triệu/tháng.\n- Yêu cầu: Nghiêm chỉnh tuân thủ các quy tắc được clive bàn giao.",
		"sender": "Người gửi: clive"
	},
	{
		"text": "21 triệu/tháng?! Một số tiền quá lớn cho một công việc bảo vệ siêu thị đêm đơn giản! Mình phải nhận ngay lập tức thôi!",
		"sender": "Aaron (Tôi)"
	},
	{
		"text": "Hai ngày sau khi phỏng vấn nhanh qua điện thoại với clive, tôi lái xe tới bãi đỗ xe của siêu thị West lúc 11:45 PM để chuẩn bị bắt đầu ca trực đầu tiên của mình...",
		"sender": "Aaron (Tôi)"
	}
]

var current_step: int = 0

@onready var dialog_label: Label = $IntroUI/DialogPanel/DialogLabel
@onready var sender_label: Label = $IntroUI/DialogPanel/SenderLabel
@onready var next_button: Button = $IntroUI/DialogPanel/NextButton

func _ready() -> void:
	# Hiện chuột khi vào Intro để người chơi bấm nút
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_dialog_step()

func _show_dialog_step() -> void:
	if current_step < dialog_steps.size():
		var step = dialog_steps[current_step]
		dialog_label.text = step["text"]
		sender_label.text = step["sender"]
		
		# Đổi màu nhãn người gửi để nhấn mạnh
		if step["sender"] == "Người gửi: clive":
			sender_label.modulate = Color(0.9, 0.2, 0.2) # Màu đỏ cảnh báo của Clive
		elif step["sender"] == "Hệ thống":
			sender_label.modulate = Color(0.2, 0.8, 0.8) # Màu xanh bíp bíp điện thoại
		else:
			sender_label.modulate = Color(0.9, 0.9, 0.9) # Aaron mặc định
	else:
		# Chuyển cảnh sang siêu thị
		get_tree().change_scene_to_file("res://scenes/main_level.tscn")

func _on_next_button_pressed() -> void:
	current_step += 1
	_show_dialog_step()
