extends Node3D

var has_checked_phone: bool = false
var has_changed_clothes: bool = false

# UI tham chiếu
@onready var interaction_label: Label = $HUD/InteractionLabel
@onready var dialog_label: Label = $HUD/DialogContainer/DialogLabel
@onready var dialog_container: Control = $HUD/DialogContainer
@onready var screen_fade: ColorRect = $HUD/ScreenFade
@onready var objective_label: Label = $HUD/ObjectiveLabel

# UI Điện thoại & Inventory kéo thả
@onready var phone_screen: Panel = $HUD/PhoneScreen
@onready var inventory_screen: Panel = $HUD/InventoryScreen
@onready var player: CharacterBody3D = $Player
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	dialog_container.visible = true
	dialog_label.text = " Aaron: 'Mình thực sự bế tắc rồi... Tiền thuê nhà trễ 2 tuần, trong túi không còn một cắc...'"
	
	objective_label.text = " NHIỆM VỤ: Dùng phím WASD di chuyển, tiến lại gần điện thoại trên bàn và nhấn phím E để mở điện thoại."
	
	# Fade in đầu game
	screen_fade.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(screen_fade, "color:a", 0.0, 2.0)
	
	# Kết nối tín hiệu kéo thả
	$HUD/InventoryScreen/ItemClothes.gui_input.connect(_on_clothes_gui_input)

func show_dialog(text: String) -> void:
	dialog_container.visible = true
	dialog_label.text = text
	var tween = create_tween()
	tween.tween_interval(5.0)
	tween.tween_callback(func(): dialog_container.visible = false)

func update_interaction_ui(text: String) -> void:
	# Nếu đang mở bảng UI thì không hiện chữ gợi ý tương tác 3D
	if phone_screen.visible or inventory_screen.visible:
		interaction_label.visible = false
		return
	interaction_label.text = text
	interaction_label.visible = text != ""

# --- LOGIC XỬ LÝ ĐIỆN THOẠI ---
func open_phone() -> void:
	phone_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Hiện chuột để click
	objective_label.text = " NHIỆM VỤ: Click vào hộp thư đến để đọc tin nhắn tuyển dụng từ Clive."

func _on_close_phone_button_pressed() -> void:
	phone_screen.visible = false
	if inventory_screen.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Ẩn chuột di chuyển tiếp
	if has_checked_phone:
		objective_label.text = " NHIỆM VỤ: Tiến lại gần tủ quần áo lớn và nhấn E để mở Tủ đồ & Inventory."

func _on_message_item_pressed() -> void:
	$HUD/PhoneScreen/MessageDetail.visible = true
	has_checked_phone = true
	show_dialog(" Aaron: '21 triệu/tháng?! Một số tiền quá hời! Mình phải mở tủ thay đồ bảo vệ đi làm ngay thôi!'")
	# Kích hoạt tủ đồ
	var wardrobe = get_node_or_null("Wardrobe")
	if wardrobe:
		wardrobe.prompt_message = "Nhấn E để mở Tủ quần áo & Inventory"

# --- LOGIC XỬ LÝ INVENTORY KÉO THẢ KIỂU MINECRAFT ---
func open_inventory() -> void:
	inventory_screen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	objective_label.text = " NHIỆM VỤ: Nhấp giữ bộ đồng phục bảo vệ ca đêm và Kéo Thả (Drag & Drop) vào ô Mặc Đồ (Equip Slot) trống bên phải."

func close_inventory() -> void:
	inventory_screen.visible = false
	if phone_screen.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if has_changed_clothes:
		objective_label.text = " NHIỆM VỤ: Quá chuẩn! Hãy đi ra phía cửa chính phòng ngủ và nhấn phím E để ra ngoài đi làm."

func _on_close_inventory_button_pressed() -> void:
	close_inventory()

# Drag & Drop Custom kiểu đơn giản
var is_dragging: bool = false
@onready var drag_item = $HUD/InventoryScreen/ItemClothes
@onready var equip_slot = $HUD/InventoryScreen/EquipSlot
@onready var original_position = drag_item.position

func _process(delta: float) -> void:
	if is_dragging:
		drag_item.global_position = get_viewport().get_mouse_position() - drag_item.size / 2.0

func _on_clothes_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
			else:
				is_dragging = false
				# Kiểm tra xem có thả vào ô Trang Bị (Equip Slot) không
				var mouse_pos = get_viewport().get_mouse_position()
				var slot_rect = equip_slot.get_global_rect()
				if slot_rect.has_point(mouse_pos):
					# Đóng gói trang bị thành công
					drag_item.visible = false
					$HUD/InventoryScreen/EquipSlot/EquippedIcon.visible = true
					has_changed_clothes = true
					anim_player.play("open_wardrobe")
					show_dialog(" *Sột soạt...* Bạn đã mặc bộ trang phục bảo vệ ca đêm màu xanh đậm ấm áp.")
					
					# Đổi mô tả cửa
					var door = get_node_or_null("ExitDoor")
					if door:
						door.prompt_message = "Nhấn E để ra ngoài đi làm"
						
					var timer = get_tree().create_timer(1.5)
					timer.timeout.connect(func(): close_inventory())
				else:
					# Thả trượt -> Trở về vị trí cũ
					drag_item.position = original_position
