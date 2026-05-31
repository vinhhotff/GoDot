extends Node

signal hour_changed(new_hour: int)
signal game_over(won: bool)

# --- CHẾ ĐỘ SÁNG ĐỂ TEST VÀ ASSETS ĐÈN TRẦN ---
var is_bright_test_mode: bool = false
var ceiling_light_scene = preload("res://assets/funiture/light celling/ceiling_light.glb")

# --- QUẢN LÝ TIẾN TRÌNH 3 NGÀY ---
var current_day: int = 1

# Giai đoạn mở đầu (Siêu thị lúc tối dần)
var is_prologue: bool = true
var prologue_hour: int = 5 # 5:00 PM hoàng hôn
var prologue_minute: int = 0
var prologue_timer: float = 0.0

# Tốc độ thời gian: ban đầu tua nhanh, sau 8:30 PM chạy bình thường
var time_speed_factor: float = 0.068  # Tua nhanh (15% faster) => 0.068 giây thực tế = 1 phút ảo
var speed_slowed_down: bool = false

# Sự kiện vị khách lúc 8:00 PM
var guest_triggered: bool = false
var guest_done: bool = false

# Thời gian ca trực chính thức (12:00 AM -> 6:00 AM)
var current_hour: int = 12
var current_minute: int = 0
var is_am: bool = true

# Bộ đếm giây - LÀM CHẬM THỜI GIAN ĐỂ TĂNG NỖI SỢ (1.68 giây thực tế = 1 phút ảo - Đã tua nhanh thêm 10%)
var time_accumulator: float = 0.0
const MINUTE_DURATION: float = 1.68 # Đã tua nhanh thêm 10% (1.87 * 0.9 = 1.68)

# Tham chiếu tới UI Player và Môi trường
var clock_label: Label = null
var screen_fade: ColorRect = null
var main_light: DirectionalLight3D = null
var world_env: WorldEnvironment = null
var current_hud: CanvasLayer = null

# Hệ thống xếp hàng hội thoại thủ công (Dialogue Queue)
var dialogue_active: bool = false
var dialog_queue: Array = []
var active_dialog_callback: Callable = Callable()

# --- TRẠNG THÁI HIỆN TƯỢNG KINH DỊ & TUẦN TRA ---
var current_anomaly_resolved: bool = true
var active_anomaly_type: String = ""
var active_anomaly_aisle: int = 0
var freezer_inspect_box_instance: StaticBody3D = null

var last_patrol_hour: int = 12       # Theo dõi mốc giờ tuần tra (1 tiếng kiểm tra 1 lần)
var aisle7_cry_triggered: bool = false
var freezer_knock_timer: float = 0.0
var freezer_knock_interval: float = 40.0 # Mỗi 40 giây ngẫu nhiên phát tiếng gõ

# Sự kiện mất nhạc Jazz (Quy tắc 7 - Ngày 2 & 3)
var jazz_outage_timer: float = 0.0
var jazz_outage_active: bool = false
var jazz_outage_countdown: float = 20.0
var countdown_label: Label = null
var reset_box_instance: StaticBody3D = null

# Sự kiện Bóng ma người phụ nữ (Quy tắc 6 - Ngày 3)
var ghost_active: bool = false
var ghost_instance: Node3D = null
var ghost_look_timer: float = 0.0
var ghost_spawn_timer: float = 0.0
var aisle7_jumpscare_cooldown: float = 0.0  # Guard chống spam jumpscare mỗi frame

# Sự kiện Đèn chập tắt ngẫu nhiên & Bật cầu dao cuối hành lang (Ngày 2 & 3)
var blackout_timer: float = 0.0
var active_blackout_aisle: int = 0
var breaker_switch_instance: StaticBody3D = null

# Bản đồ Aisle -> chỉ số camera CCTV (0-based)
# Aisle1-2->CAM1, Aisle3-4->CAM2, Aisle5-6->CAM3, Aisle7->CAM4, Aisle8->CAM5, Sảnh->CAM0
const AISLE_TO_CAM: Dictionary = {1: 1, 2: 1, 3: 2, 4: 2, 5: 3, 6: 3, 7: 4, 8: 5}

# Sự kiện Xe đẩy lạc chỗ (Quy tắc 4 - Ngày 3)
var cart_spawn_timer: float = 0.0
var has_spawned_cart: bool = false
var misplaced_cart_instance: StaticBody3D = null
var cart_return_zone_instance: StaticBody3D = null

# Sự kiện Vũng máu khu thịt (Quy tắc 5 - Ngày 3)
var blood_spawn_timer: float = 0.0
var has_spawned_blood: bool = false
var blood_puddle_instance: StaticBody3D = null
var breakroom_mop_instance: StaticBody3D = null
var mop_return_zone_instance: StaticBody3D = null

# --- HỆ THỐNG AN TOÀN / NGUY HIỂM PHÒNG KHO & TOILET MỚI ---
var storeroom_timer: float = 0.0
var storeroom_warning_played: bool = false

# --- CẤU HÌNH DỊ NHÂN RÌNH RẬP NGOÀI KÍNH & KHÁCH BÌNH THƯỜNG ---
var storefront_stalker_active: bool = false
var storefront_stalker_instance: Node3D = null
var storefront_stalker_stare_timer: float = 0.0
var storefront_stalker_triggered: bool = false
var storefront_stalker_spawned: bool = false

var visitor_step: int = 0
var visitor_spawned_hour: int = 0
var is_visitor_event_active: bool = false
var active_visitor_node: Node3D = null

# ==================== HỆ THỐNG NPC DỊ NHÂN CẢN ĐƯỜNG & JUMPSCARE ====================
# CONFIG: Dễ dàng thay model 3D sau này bằng cách sửa mảng CREEPY_NPC_DEFS
var CREEPY_NPC_DEFS = [
	{
		"name": "ShadowMan",
		"mesh_type": "capsule",  # Đổi thành "scene" khi có model: "scene_path": "res://models/shadow_man.tscn"
		"color": Color(0.02, 0.02, 0.02),
		"emission": Color(0.0, 0.0, 0.0),
		"height": 2.35,
		"radius": 0.38,
		"scale": Vector3(1.1, 1.1, 1.1),
		"scare_text": "Aaron: 'Cái gì thế kia?! Đừng lại gần đây... Á!!!'",
	},
	{
		"name": "PaleFace",
		"mesh_type": "capsule",
		"color": Color(0.85, 0.8, 0.75),
		"emission": Color(0.3, 0.15, 0.15),
		"height": 2.25,
		"radius": 0.42,
		"scale": Vector3(1.1, 1.1, 1.1),
		"scare_text": "Aaron: 'Khuôn mặt đó... Không có mắt?! Chúa ơi!!!'",
	},
	{
		"name": "TwitchingChild",
		"mesh_type": "capsule",
		"color": Color(0.1, 0.1, 0.15),
		"emission": Color(0.05, 0.0, 0.1),
		"height": 2.05,
		"radius": 0.38,
		"scale": Vector3(1.1, 1.1, 1.1),
		"scare_text": "Aaron: 'Tiếng xương gãy răng rắc đó... Nó đang bò lại đây... Á!!!'",
	},
	{
		"name": "TallCrawler",
		"mesh_type": "capsule",
		"color": Color(0.15, 0.05, 0.0),
		"emission": Color(0.15, 0.02, 0.0),
		"height": 2.65,
		"radius": 0.28,
		"scale": Vector3(0.9, 1.45, 0.9),
		"scare_text": "Aaron: 'Nó đang bò trên trần nhà! Kinh tởm quá! Tránh xa tôi ra!!!'",
	},
]

# Vị trí spawn NPC dị nhân ở giữa các hành lang (CONFIG: thêm/xóa vị trí tùy ý)
var CREEPY_SPAWN_POINTS = [
	Vector3(-9.6, 0.52, -4.0),   # Hành lang giữa Aisle 1-2
	Vector3(-6.4, 0.52, -1.0),   # Hành lang giữa Aisle 2-3
	Vector3(-3.2, 0.52, -5.0),   # Hành lang giữa Aisle 3-4
	Vector3(0.0, 0.52, -3.0),    # Hành lang giữa Aisle 4-5
	Vector3(3.2, 0.52, -6.0),    # Hành lang giữa Aisle 5-6
	Vector3(6.4, 0.52, 0.0),     # Hành lang giữa Aisle 6-7
	Vector3(9.6, 0.52, -4.0),    # Hành lang giữa Aisle 7-8
]

var creepy_npc_instance: Node3D = null
var creepy_npc_timer: float = 0.0
var creepy_npc_active: bool = false
var creepy_npc_cooldown: float = 0.0  # Thời gian nghỉ giữa các lần NPC xuất hiện
var creepy_npc_look_timer: float = 0.0  # Thời gian nhìn vào NPC trước khi jumpscare

# Xem lại Nội quy mọi lúc
var active_scroll_canvas: CanvasLayer = null
var scroll_ui_packed = preload("res://scenes/rule_scroll_ui.tscn")

# Hệ thống CCTV Camera giám sát phòng nghỉ
var active_cctv_canvas: CanvasLayer = null  # Chính là instance của cctv_ui.gd (extends CanvasLayer)
var cctv_ui_script = preload("res://scripts/cctv_ui.gd")
var cctv_desk_instance: StaticBody3D = null

# Clive đã gọi điện chưa? (khóa nội quy cho đến khi nhận lệnh)
var has_called_clive: bool = false

# Vòng sáng kích hoạt sự kiện khách tuần đêm
var active_event_circle: Node3D = null
var pending_visitor_event: String = ""

func _ready() -> void:
	_find_references()
	_setup_looping_music()
	_setup_aisle_lights()
	_stock_shelves_with_goods()
	_spawn_reset_box()
	_spawn_cctv_desk()
	_start_prologue()

func _process(delta: float) -> void:
	if is_prologue:
		_process_prologue(delta)
	else:
		# Dừng đồng hồ khi đang hiển thị hội thoại / đọc nhiệm vụ
		if not dialogue_active:
			_process_shift(delta)
		
	# Xử lý sự kiện ma quái phụ nếu đang trực chính thức
	if not is_prologue and not dialogue_active:
		_process_horror_events(delta)
		
	# Kiểm tra người chơi đi vào vòng sáng sự kiện khách hàng
	if is_instance_valid(active_event_circle) and pending_visitor_event != "":
		var player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			var p_pos2d = Vector2(player_node.global_position.x, player_node.global_position.z)
			var c_pos2d = Vector2(active_event_circle.global_position.x, active_event_circle.global_position.z)
			if p_pos2d.distance_to(c_pos2d) < 0.95:
				var event_to_trigger = pending_visitor_event
				pending_visitor_event = ""
				active_event_circle.queue_free()
				active_event_circle = null
				
				# Phát nhạc chime báo hiệu bắt đầu sự kiện
				play_procedural_sound("party")
				_spawn_visual_visitor(event_to_trigger)

func _find_references() -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		clock_label = player_node.get_node_or_null("HUD/ClockContainer/ClockLabel")
		screen_fade = player_node.get_node_or_null("HUD/ScreenFade")
		current_hud = player_node.get_node_or_null("HUD")
	main_light = get_tree().current_scene.get_node_or_null("DirectionalLight3D")
	world_env = get_tree().current_scene.get_node_or_null("WorldEnvironment")
	
	if current_hud and not current_hud.has_node("TestTipLabel"):
		var test_tip = Label.new()
		test_tip.name = "TestTipLabel"
		test_tip.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
		test_tip.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_TOP
		test_tip.offset_left = 15
		test_tip.offset_top = 15
		
		var settings = LabelSettings.new()
		settings.font_size = 12
		settings.font_color = Color(1.0, 0.3, 0.3)
		settings.outline_size = 4
		settings.outline_color = Color(0.0, 0.0, 0.0)
		test_tip.label_settings = settings
		test_tip.text = "🔴 [H / F2] MỞ BẢNG TEST KINH DỊ & CHỌN NGÀY"
		
		current_hud.add_child(test_tip)

# --- LẤY VỊ TRÍ TOÀN CẦU THỰC TẾ CỦA SPAWNPOINT (Cộng dồn vị trí CollisionShape3D con) ---
func get_spawnpoint_global_position(node_name: String, default_val: Vector3) -> Vector3:
	var node = get_tree().current_scene.find_child(node_name, true, false)
	if not node:
		return default_val
		
	var pos = node.global_position
	var col = node.get_node_or_null("CollisionShape3D")
	if col:
		pos += col.position
	return pos

# --- KẾT NỐI VÀ KHÓA CHẶT LOOP NHẠC TRONG SUỐT QUÁ TRÌNH LÀM VIỆC ---
func _setup_looping_music() -> void:
	var music_player = get_tree().current_scene.get_node_or_null("BackgroundJazzMusic")
	if music_player:
		# Kết nối tín hiệu tự động lặp khi chạy hết bài nhạc du dương
		if not music_player.finished.is_connected(music_player.play):
			music_player.finished.connect(music_player.play)
		if not music_player.playing:
			music_player.play()

# --- BỐ TRÍ HỆ THỐNG ĐÈN MỜ DỌC CÁC LỐI ĐI VÀ KHU VỰC CÔNG CỘNG ---
func _setup_aisle_lights() -> void:
	var shelving_names = ["shelving1", "shelving2", "shelving3", "shelving4"]
	
	for name in shelving_names:
		var shelf_node = get_tree().current_scene.find_child(name, true, false)
		if not shelf_node:
			continue
			
		# Xóa các đèn trần cũ nếu có
		for child in shelf_node.get_children():
			if child is OmniLight3D or child.name.begins_with("CeilingLight_") or child.name.begins_with("Light_"):
				child.queue_free()
				
		var col = shelf_node.get_node_or_null("CollisionShape3D")
		var col_pos = Vector3.ZERO
		if col:
			col_pos = col.position
			
		var energy = 0.85
		var light_color = Color(1.0, 0.98, 0.9)
		
		# Đặt 2 bóng đèn dọc theo kệ (z_offset = -2.0, z_offset = 2.0) tương đối với CollisionShape3D
		for z_offset in [-2.0, 2.0]:
			var light = OmniLight3D.new()
			light.name = "Light_" + str(z_offset)
			light.light_color = light_color
			light.light_energy = energy
			light.omni_range = 9.0
			light.shadow_enabled = false # Tắt đổ bóng động để tránh lỗi giới hạn shadow map của Godot
			
			var l_pos = col_pos
			l_pos.y = 2.3 # Treo cao cách mặt sàn 2.3m
			l_pos.z += z_offset
			
			light.position = l_pos
			shelf_node.add_child(light)
			
			# Đã tắt tự động sinh mô hình 3D đèn trần để người chơi tự thiết kế trong Editor
			# if ceiling_light_scene:
			# 	var light_model = ceiling_light_scene.instantiate()
			# 	light_model.name = "CeilingLight_" + str(z_offset)
			# 	light_model.position = l_pos
			# 	light_model.position.y += 0.2
			# 	light_model.scale = Vector3(0.5, 0.5, 0.5)
			# 	shelf_node.add_child(light_model)
				
	# Bổ sung thêm các bóng đèn ở các vị trí công cộng chính để tránh quá tối tăm
	var map_node = get_tree().current_scene.find_child("Map", true, false)
	if map_node:
		# Xóa các đèn phụ và mô hình cũ
		for child in map_node.get_children():
			if child.name.begins_with("ExtraOmni_") or child.name.begins_with("ExtraCeiling_"):
				child.queue_free()
				
		var extra_lights = [
			{"pos": get_spawnpoint_global_position("door", Vector3(5.75, 1.85, 10.96)) + Vector3(0, 1.2, 0), "color": Color(1.0, 0.95, 0.85), "energy": 1.5, "name": "Entrance"},
			{"pos": get_spawnpoint_global_position("Checkout counter", Vector3(-3.3, 1.28, 2.72)) + Vector3(0, 1.5, 0), "color": Color(1.0, 0.95, 0.85), "energy": 1.8, "name": "Cashier"},
			{"pos": get_spawnpoint_global_position("store room", Vector3(5.06, 2.14, -10.53)) + Vector3(0, 1.2, 0), "color": Color(1.0, 0.98, 0.9), "energy": 1.4, "name": "StoreRoom"},
			{"pos": get_spawnpoint_global_position("camera computer", Vector3(19.8, 2.03, -10.77)) + Vector3(0, 1.2, 0), "color": Color(1.0, 0.95, 0.85), "energy": 1.4, "name": "CCTVDesk"},
			{"pos": get_spawnpoint_global_position("toilet", Vector3(19.43, 1.94, 8.99)) + Vector3(0, 1.2, 0), "color": Color(0.9, 0.95, 1.0), "energy": 1.2, "name": "Toilet"},
			{"pos": get_spawnpoint_global_position("table1", Vector3(14.35, 0, 6.6)) + Vector3(0, 2.5, 0), "color": Color(1.0, 0.98, 0.9), "energy": 1.3, "name": "Table1"},
			{"pos": get_spawnpoint_global_position("table2", Vector3(12.07, 0, -2.48)) + Vector3(0, 2.5, 0), "color": Color(1.0, 0.98, 0.9), "energy": 1.3, "name": "Table2"}
		]
			
		for item in extra_lights:
			var light = OmniLight3D.new()
			light.name = "ExtraOmni_" + item["name"]
			light.light_color = item["color"]
			light.light_energy = item["energy"]
			light.omni_range = 12.0
			light.shadow_enabled = false # Tắt shadow để tối ưu hóa hiệu năng và tránh lỗi render của Godot 4
			light.position = item["pos"]
			map_node.add_child(light)
			
			# Đã tắt tự động sinh mô hình 3D đèn trần phụ để người chơi tự thiết kế trong Editor
			# if ceiling_light_scene:
			# 	var light_model = ceiling_light_scene.instantiate()
			# 	light_model.name = "ExtraCeiling_" + item["name"]
			# 	light_model.position = item["pos"]
			# 	light_model.position.y += 0.25
			# 	light_model.scale = Vector3(0.5, 0.5, 0.5)
			# 	map_node.add_child(light_model)

# --- KHỞI TẠO NÚT RESET NHẠC PHÒNG KHO (QUY TẮC 7) ---
func _spawn_reset_box() -> void:
	if is_instance_valid(reset_box_instance):
		reset_box_instance.queue_free()
		
	# Tạo hộp điện Reset nhạc màu đỏ
	var box = StaticBody3D.new()
	box.name = "MusicResetBox"
	
	var table_node = get_tree().current_scene.find_child("mesa_larga", true, false)
	if table_node:
		var tbl_pos = table_node.global_position
		# Đặt hộp nút bấm reset nhạc ngay trên mặt bàn mesa_larga
		box.position = Vector3(tbl_pos.x, tbl_pos.y + 0.82, tbl_pos.z)
	else:
		var toilet_node = get_tree().current_scene.find_child("toilet", true, false)
		if toilet_node:
			var toilet_pos = get_spawnpoint_global_position("toilet", Vector3(19.43, 1.94, 8.99))
			box.position = Vector3(toilet_pos.x, 0.9, toilet_pos.z)
		else:
			box.position = Vector3(19.4, 0.9, 9.0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4)
	col.shape = shape
	box.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.3)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.1, 0.1) # Màu đỏ chói phát sáng
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.1, 0.1)
	mesh_inst.material_override = mat
	box.add_child(mesh_inst)
	
	box.add_to_group("interactable")
	box.set_script(load("res://scripts/reset_box.gd"))
	
	get_tree().current_scene.add_child.call_deferred(box)
	reset_box_instance = box

# --- KHỞI TẠO BÀN CAMERA CCTV TRONG PHÒNG KHO ---
func _spawn_cctv_desk() -> void:
	if is_instance_valid(cctv_desk_instance):
		cctv_desk_instance.queue_free()

	var desk = StaticBody3D.new()
	desk.name = "CCTVDesk"
	
	var camera_comp = get_tree().current_scene.find_child("camera computer", true, false)
	if camera_comp:
		desk.position = camera_comp.global_position
		desk.position.y = 0.0
	else:
		desk.position = Vector3(19.8, 0.0, -10.77)
		
	desk.set_script(load("res://scripts/cctv_desk.gd"))

	# Tương tác vô hình xếp chồng lên bàn máy tính có sẵn trong Editor
	var col = CollisionShape3D.new()
	var col_shape = BoxShape3D.new()
	col_shape.size = Vector3(1.6, 1.2, 1.2) # Vùng tương tác thoải mái
	col.shape = col_shape
	col.position = Vector3(0, 0.6, 0)
	desk.add_child(col)

	desk.add_to_group("interactable")
	get_tree().current_scene.add_child.call_deferred(desk)
	cctv_desk_instance = desk
	cctv_desk_instance = desk

# --- PHÍM BẤM THỦ CÔNG ĐỂ CHUYỂN THOẠI ---
func _unhandled_input(event: InputEvent) -> void:
	if dialogue_active:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			get_viewport().set_input_as_handled()
			_show_next_dialogue()

# --- HỆ THỐNG DIALOGUE QUEUE ---
func start_dialogue_sequence(steps: Array, callback: Callable = Callable()) -> void:
	dialog_queue = steps.duplicate()
	active_dialog_callback = callback
	dialogue_active = true
	
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		player_node.set_physics_process(false)
		
	_show_next_dialogue()

func _show_next_dialogue() -> void:
	if dialog_queue.size() > 0:
		var current_text = dialog_queue.pop_front()
		_show_dialog_raw(current_text + "\n\n(Nhấn SPACE / CLICK để tiếp tục...)")
	else:
		dialogue_active = false
		
		var player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			var dialog_container = player_node.get_node_or_null("HUD/DialogContainer")
			if dialog_container:
				dialog_container.visible = false
		
		if not active_dialog_callback.is_null():
			active_dialog_callback.call()

func _show_dialog_raw(text: String) -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		var dialog_container = player_node.get_node_or_null("HUD/DialogContainer")
		var dialog_label = player_node.get_node_or_null("HUD/DialogContainer/DialogLabel")
		if dialog_container and dialog_label:
			dialog_container.visible = true
			dialog_label.text = text

# --- GIAI ĐOẠN 1: TUA THỜI GIAN CHIỀU HOÀNG HÔN ---
func _start_prologue() -> void:
	is_prologue = true
	guest_triggered = false
	guest_done = false
	speed_slowed_down = false
	time_speed_factor = 0.08
	_setup_looping_music() # Đảm bảo nhạc Jazz hát du dương
	
	if clock_label:
		clock_label.text = "5:00 PM"
	
	var day_str = "NGÀY 1" if current_day == 1 else ("NGÀY 2" if current_day == 2 else "NGÀY 3 - ĐÊM CUỐI")
	_set_objective("NHIỆM VỤ (" + day_str + "): Bạn đang đứng ở lối vào. Hãy làm quen với không gian siêu thị.")
	
	# Đèn mờ tự động được cấu hình
	_setup_aisle_lights()
	
	# Tạo guide marker phát sáng ở quầy cửa (nơi NPC sẽ vào)
	_spawn_guide_marker("GuideMarker_Door", get_spawnpoint_global_position("door", Vector3(5.75, 1.85, 10.96)) + Vector3(0, -0.8, 0), Color(0.2, 0.8, 1.0), "⬇ Quầy cửa vào")
	
	# Tạo guide marker phát sáng ở phòng camera (nơi đọc cuộn giấy quy tắc)
	_spawn_guide_marker("GuideMarker_Camera", Vector3(19.4, 0.1, -9.9), Color(1.0, 0.6, 0.1), "⬇ Phòng Camera Giám Sát")
	
	# Reset NPC vị khách
	var guest_npc = get_tree().current_scene.find_child("GuestNPC", true, false)
	if guest_npc:
		guest_npc.visible = false
		var door_pos = get_spawnpoint_global_position("door", Vector3(5.75, 1.85, 10.96))
		guest_npc.global_position = Vector3(door_pos.x, 0.9, door_pos.z)
	
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		var intro_text = " Aaron: 'Bắt đầu ca trực " + day_str + " nào... Hãy nhớ Clive dặn phải kiểm tra cuộn giấy da quy tắc ở phòng camera giám sát...'"
		if current_day > 1:
			intro_text = " Aaron: 'Hôm qua thật đáng sợ... Hôm nay là " + day_str + " rồi. Cầu mong mình sẽ vượt qua đêm nay an toàn...'"
			
		start_dialogue_sequence([
			intro_text
		], func():
			var player_node = get_tree().current_scene.find_child("Player", true, false)
			if player_node:
				player_node.set_physics_process(true)
		)
	)

func _process_prologue(delta: float) -> void:
	if dialogue_active:
		return

	prologue_timer += delta
	if prologue_timer >= time_speed_factor:
		prologue_timer = 0.0
		prologue_minute += 1
		if prologue_minute >= 60:
			prologue_minute = 0
			prologue_hour += 1
			
		if clock_label:
			var min_str = str(prologue_minute) if prologue_minute >= 10 else "0" + str(prologue_minute)
			clock_label.text = str(prologue_hour) + ":" + min_str + " PM"
			
		# --- CHUYỂN BẦU TRỜI HOÀNG HÔN SANG ĐÊM TỐI ---
		var current_total_minutes = (prologue_hour - 5) * 60 + prologue_minute
		var t = clamp(float(current_total_minutes) / 120.0, 0.0, 1.0) # Tối thui từ 7:00 PM trở đi
		
		if main_light:
			main_light.light_energy = lerp(1.5, 0.0, t)
			main_light.light_color = lerp(Color(0.9, 0.4, 0.2), Color(0.05, 0.0, 0.0), t)
			
		if world_env and world_env.environment:
			world_env.environment.ambient_light_color = lerp(Color(0.3, 0.15, 0.1), Color(0.01, 0.01, 0.03), t)
			world_env.environment.ambient_light_energy = lerp(1.0, 0.12, t)
			
			if world_env.environment.sky:
				var sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
				if sky_mat:
					sky_mat.sky_top_color = lerp(Color(0.2, 0.08, 0.05), Color(0.005, 0.005, 0.01), t)
					sky_mat.sky_horizon_color = lerp(Color(0.4, 0.15, 0.08), Color(0.005, 0.005, 0.01), t)
					sky_mat.ground_horizon_color = lerp(Color(0.4, 0.15, 0.08), Color(0.005, 0.005, 0.01), t)
			
		# KÍCH HOẠT SỰ KIỆN KHÁCH HÀNG LÚC 8:00 PM
		if prologue_hour == 8 and prologue_minute == 0 and not guest_triggered:
			_trigger_guest_event()
			
		# SAU 8:30 PM: TỐC ĐỘ THỜI GIAN CHẠY CHẬM LẠI
		if prologue_hour == 8 and prologue_minute >= 30 and not speed_slowed_down:
			speed_slowed_down = true
			time_speed_factor = 1.0
			
		# ĐẠT 9:00 PM SAU KHI XONG SỰ KIỆN -> CLIVE GỌI ĐIỆN
		if prologue_hour == 9 and prologue_minute == 0 and guest_done:
			is_prologue = false
			_trigger_clive_phone_call()

# --- SỰ KIỆN VỊ KHÁCH MA QUÁI LÚC 8:00 PM ---
func _trigger_guest_event() -> void:
	guest_triggered = true
	
	# Tạm tắt va chạm nội thất để NPC đi qua mượt mà
	_set_furniture_collisions(false)
	
	var door_pos = get_spawnpoint_global_position("door", Vector3(5.75, 1.85, 10.96))
	var cashier_pos = get_spawnpoint_global_position("Checkout counter", Vector3(-3.3, 1.28, 2.72))
	
	var spawn_pos = Vector3(door_pos.x, 0.9, door_pos.z)
	var target_pos = Vector3(cashier_pos.x + 2.0, 0.9, cashier_pos.z)  # Lui ra trước quầy (về phía X dương = phía cửa)
	
	# Đường đi tránh va chạm kệ hàng và bàn:
	# Từ cửa → đi dọc hành lang chính (giữ X = 5.75, tránh kệ) → rẽ ngang ra quầy thu ngân
	# Waypoints: Cửa → Đi thẳng xuống hành lang bên phải → Rẽ trái qua lối đi trống → Đến quầy
	var waypoints_to_cashier = [
		spawn_pos,
		Vector3(spawn_pos.x, 0.9, 8.0),       # Đi thẳng xuống một chút
		Vector3(spawn_pos.x, 0.9, target_pos.z), # Đi thẳng tới ngang hàng quầy (cùng Z)
		target_pos                              # Rẽ ngang sang quầy thu ngân
	]
	
	var guest_npc = get_tree().current_scene.find_child("GuestNPC", true, false)
	if guest_npc:
		guest_npc.global_position = spawn_pos
		guest_npc.visible = true
		
		# Đi theo waypoints tránh va chạm
		var move_tween = create_tween()
		for i in range(1, waypoints_to_cashier.size()):
			var from_pos = waypoints_to_cashier[i - 1]
			var to_pos = waypoints_to_cashier[i]
			var dist = from_pos.distance_to(to_pos)
			var duration = dist / 3.5  # Tốc độ đi bộ ~3.5 m/s
			move_tween.tween_property(guest_npc, "global_position", to_pos, duration)
			
	start_dialogue_sequence([
		" Vị khách: 'Này cậu bảo vệ trẻ... Cậu định ngủ gật suốt ca làm đấy à?'",
		" Vị khách: 'Tốt nhất đừng có chợp mắt... Đêm ở đây đáng sợ lắm. Đọc kỹ cuộn giấy quy tắc của Clive đi...'",
		" Aaron: 'Hơ... Tôi vừa mới nhận việc mà. Tôi không ngủ gật! Của ông hết bao nhiêu ạ?'",
		" Vị khách: 'Không cần thối tiền...'"
	], func():
		# Đường đi quay lại (ngược waypoints)
		var waypoints_back = [
			target_pos,
			Vector3(spawn_pos.x, 0.9, target_pos.z),  # Đi ngang ra hành lang chính
			Vector3(spawn_pos.x, 0.9, 8.0),
			spawn_pos
		]
		
		var tween = create_tween()
		if guest_npc:
			for i in range(1, waypoints_back.size()):
				var from_pos = waypoints_back[i - 1]
				var to_pos = waypoints_back[i]
				var dist = from_pos.distance_to(to_pos)
				var duration = dist / 4.0  # Đi nhanh hơn khi quay lại
				tween.tween_property(guest_npc, "global_position", to_pos, duration)
			tween.tween_callback(func():
				guest_npc.visible = false
				# Bật lại va chạm nội thất sau khi NPC đi xong
				_set_furniture_collisions(true)
			)
			
		start_dialogue_sequence([
			" Aaron: 'Thật kỳ lạ... Ông ta biến mất vào bóng tối hoàng hôn rồi. Thôi, mình vẫn phải tiếp tục nhiệm vụ.'"
		], func():
			guest_done = true
			var player_node = get_tree().current_scene.find_child("Player", true, false)
			if player_node:
				player_node.set_physics_process(true)
		)
	)

# --- GIAI ĐOẠN 2: CUỘC GỌI ĐIỆN THOẠI TỪ CLIVE LÚC 9:00 PM ---
func _trigger_clive_phone_call() -> void:
	start_dialogue_sequence([
		" Clive: 'Này Aaron, cậu đã vào sảnh rồi đúng không? Tốt lắm...'",
		" Clive: 'Hãy nghe kỹ đây. Tôi đã bỏ tệp hồ sơ vụ tai nạn đâm xe bỏ chạy năm ngoái ở ngay cạnh máy tính giám sát trong phòng camera.'",
		" Clive: 'Siêu thị West Market này đang bị nguyền rủa bởi vong hồn của vụ tai nạn đó... Cậu phải đọc kỹ hồ sơ đó ngay lập tức!'",
		" Aaron: 'Hơ... Vụ tai nạn đâm xe năm ngoái sao sếp? Sao sếp lại để hồ sơ vụ án ở đây?'",
		" Clive: '...Hãy đọc đi, rồi tự cậu sẽ hiểu. Mọi tội lỗi rốt cuộc đều phải trả giá. (Cuộc gọi bị ngắt)'",
		" Aaron: 'Sếp? Alo?... Thật kỳ quặc. Tại sao sếp lại có vẻ sợ hãi và nhắc đến vụ án đó? Mình phải đi vào phòng camera xem thế nào.'"
	], func():
		var player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			player_node.set_physics_process(true)
		
		# Đánh dấu Clive đã gọi → mở khóa Nội quy
		has_called_clive = true
		
		_set_objective("NHIỆM VỤ: Hãy đi vào phòng camera giám sát (camera computer), tiến lại bàn máy tính và đọc Hồ sơ vụ án.")
		
		var rule_scroll = get_tree().current_scene.find_child("RuleScroll", true, false)
		if rule_scroll:
			# Giữ nguyên vị trí thiết kế cũ của RuleScroll trong Editor, không ghi đè vị trí nữa
			
			rule_scroll.add_to_group("interactable")
			rule_scroll.prompt_message = "[E] Đọc Hồ sơ vụ án đâm xe bỏ chạy"
	)

# --- GIAI ĐOẠN 3: BẮT ĐẦU CA LÀM VIỆC CHÍNH THỨC (12:00 AM) ---
func start_official_shift() -> void:
	current_hour = 12
	current_minute = 0
	is_am = true
	last_patrol_hour = 12
	aisle7_cry_triggered = false
	jazz_outage_active = false
	ghost_active = false
	active_blackout_aisle = 0
	
	# Xóa guide markers khi bắt đầu ca trực chính thức
	_remove_all_guide_markers()
	
	# Reset các Quy tắc 4 và 5 của Ngày 3
	has_spawned_cart = false
	has_spawned_blood = false
	if is_instance_valid(misplaced_cart_instance):
		misplaced_cart_instance.queue_free()
	misplaced_cart_instance = null
	if is_instance_valid(cart_return_zone_instance):
		cart_return_zone_instance.queue_free()
	cart_return_zone_instance = null
	if is_instance_valid(blood_puddle_instance):
		blood_puddle_instance.queue_free()
	blood_puddle_instance = null
	if is_instance_valid(breakroom_mop_instance):
		breakroom_mop_instance.queue_free()
	breakroom_mop_instance = null
	if is_instance_valid(mop_return_zone_instance):
		mop_return_zone_instance.queue_free()
	mop_return_zone_instance = null
	if is_instance_valid(creepy_npc_instance):
		creepy_npc_instance.queue_free()
	creepy_npc_instance = null
	creepy_npc_active = false
	creepy_npc_timer = 0.0
	creepy_npc_cooldown = 0.0
	aisle7_jumpscare_cooldown = 0.0
	ghost_spawn_timer = 0.0
	
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		if player_node.has_method("set_holding_mop"):
			player_node.set_holding_mop(false)
		if player_node.has_method("set_pushing_cart"):
			player_node.set_pushing_cart(false)
			
	_update_clock_ui()
	_setup_looping_music() # Tiếp tục chạy lặp nhạc Jazz
	
	# Khóa bầu trời đêm tối
	if not is_bright_test_mode:
		if main_light:
			main_light.light_energy = 0.0
		if world_env and world_env.environment:
			world_env.environment.ambient_light_color = Color(0.01, 0.01, 0.03)
			world_env.environment.ambient_light_energy = 0.12
			world_env.environment.fog_enabled = true
			world_env.environment.fog_light_color = Color(0.01, 0.01, 0.02)
			world_env.environment.fog_density = 0.08
			if world_env.environment.sky:
				var sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
				if sky_mat:
					sky_mat.sky_top_color = Color(0.0, 0.0, 0.01)
					sky_mat.sky_horizon_color = Color(0.0, 0.0, 0.01)
					sky_mat.ground_horizon_color = Color(0.0, 0.0, 0.01)
	
	_clear_objective() # Xoá nhiệm vụ "đọc quy tắc" cũ ngay lập tức
	current_anomaly_resolved = true
	active_anomaly_type = ""
	start_dialogue_sequence([
		" Aaron: 'Hồ sơ vụ tai nạn năm ngoái... Sao nó lại làm đầu mình đau nhói thế này?'",
		" Aaron: 'Những bức ảnh nạn nhân... sao trông họ quen thuộc đến đáng sợ...'"
	], func():
		_set_objective("NHIỆM VỤ: Hãy đi tuần tra siêu thị. Sự kiện đầu tiên sẽ bắt đầu lúc 1:00 AM.")
		var p = get_tree().current_scene.find_child("Player", true, false)
		if p:
			p.set_physics_process(true)
	)

func _process_shift(delta: float) -> void:
	if not is_bright_test_mode:
		if main_light and main_light.light_energy > 0.0:
			main_light.light_energy = 0.0
		
	# --- HỆ THỐNG AN TOÀN / NGUY HIỂM PHÒNG KHO & TOILET MỚI ---
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		# 1. Kiểm tra xem người chơi có ở trong Phòng kho (store room) không
		var store_room_pos = get_spawnpoint_global_position("store room", Vector3(5.06, 0.0, -10.53))
		var dist_to_store_room = player.global_position.distance_to(store_room_pos)
		var in_storeroom = (dist_to_store_room < 4.5)
			
		# Xử lý thời gian ở trong Phòng kho (Store Room)
		if in_storeroom and not is_prologue:
			storeroom_timer += delta
			# Hiện cảnh báo u ám nếu ở quá 15 giây
			if storeroom_timer >= 12.0 and not storeroom_warning_played:
				storeroom_warning_played = true
				play_procedural_sound("static")
				_set_objective("⚠ CẢNH BÁO: Đừng ở trong phòng kho quá lâu! Bạn đang nghe thấy tiếng cào cửa bên tai...")
			# Chết nếu ở quá 25 giây
			if storeroom_timer >= 25.0:
				_trigger_storeroom_death(player)
				return
		else:
			# Hồi lại bộ đếm khi ra ngoài phòng kho
			storeroom_timer = move_toward(storeroom_timer, 0.0, delta * 2.0)
			if storeroom_timer == 0.0:
				storeroom_warning_played = false
				
		# Xử lý Bóng ma rượt đuổi lúc 4:00 AM
		if active_anomaly_type == "ghost_woman" and is_instance_valid(ghost_instance):
			var dir = (player.global_position - ghost_instance.global_position).normalized()
			ghost_instance.global_position += dir * delta * 4.2
			ghost_instance.look_at(player.global_position, Vector3.UP)
			
			# Kiểm tra xem người chơi đã ẩn nấp thành công vào Toilet chưa
			var toilet_pos = get_spawnpoint_global_position("toilet", Vector3(19.43, 0.0, 8.99))
			var dist_to_toilet = player.global_position.distance_to(toilet_pos)
			var in_toilet = (dist_to_toilet < 4.0)
			if in_toilet:
				_resolve_ghost_woman_escape(player)
			else:
				# Nếu chạm vào người chơi -> Chết ghê rợn
				if player.global_position.distance_to(ghost_instance.global_position) < 1.3:
					_trigger_ghost_chase_death(player)
					
		# Xử lý Bóng đen Dị Nhân rình rập ngoài cửa kính lớn sảnh trước
		if storefront_stalker_active and is_instance_valid(storefront_stalker_instance):
			var cam = player.get_node_or_null("Head/Camera3D")
			if cam:
				var to_stalker = (storefront_stalker_instance.global_position - cam.global_position).normalized()
				var cam_forward = -cam.global_transform.basis.z.normalized()
				var dot = cam_forward.dot(to_stalker)
				
				if dot > 0.94: # Nhìn trực diện góc hẹp
					storefront_stalker_stare_timer += delta
					if storefront_stalker_stare_timer >= 3.0 and not storefront_stalker_triggered:
						storefront_stalker_triggered = true
						_trigger_storefront_stalker_jumpscare(player)
				else:
					storefront_stalker_stare_timer = move_toward(storefront_stalker_stare_timer, 0.0, delta)
				
	time_accumulator += delta
	if time_accumulator >= MINUTE_DURATION:
		time_accumulator -= MINUTE_DURATION
		_advance_time()

func _trigger_storeroom_death(player_node) -> void:
	play_procedural_sound("scream")
	player_node.set_physics_process(false)
	
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(0.1, 0.0, 0.0, 1.0)
	current_hud.add_child(red_fade)
	
	start_dialogue_sequence([
		" Aaron: 'Cái gì đằng sau... Không!!! Cánh cửa phòng kho đã bị khóa chặt!!!'",
		" HỆ THỐNG: Cảnh báo! Bạn đã trốn quá lâu. [GAME OVER]"
	], func():
		game_over.emit(false)
		get_tree().reload_current_scene()
	)

func _advance_time() -> void:
	# Nếu phút ảo chạm 60 (tức là sắp sang giờ mới), kiểm tra xem người chơi đã xử lý xong dị thường giờ cũ chưa
	if current_minute + 1 >= 60:
		if not current_anomaly_resolved:
			_trigger_anomaly_failure_death()
			return

	current_minute += 1
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		
		if current_hour == 12:
			is_am = !is_am
		elif current_hour > 12:
			current_hour = 1
			
		hour_changed.emit(current_hour)
		
		# Kích hoạt dị thường của giờ mới
		if current_hour == 6 and is_am:
			pass # Chuẩn bị thắng game
		else:
			_trigger_hourly_anomaly()
			
	# Kích hoạt Dị nhân rình rập ngoài kính ở phút 30 của mỗi giờ
	if current_minute == 30 and not storefront_stalker_spawned:
		_trigger_storefront_stalker()
	elif current_minute == 0:
		# Reset cờ dị nhân rình rập cho giờ mới
		storefront_stalker_spawned = false
		if is_instance_valid(storefront_stalker_instance):
			storefront_stalker_instance.queue_free()
			storefront_stalker_instance = null
		storefront_stalker_active = false
		
	# Kích hoạt các vị khách tuần đêm ghé thăm thông qua vòng tròn phát sáng dưới sàn:
	if current_hour == 1 and current_minute == 2 and pending_visitor_event == "":
		_create_event_trigger_circle("mutant_blood_plate", Vector3(6.75, 0.52, 4.0), "⚠ KHÁCH HÀNG MỚI ĐANG ĐẾN: Hãy đứng vào vòng sáng đỏ ở quầy thu ngân để tiếp khách!")
	elif current_hour == 2 and current_minute == 10 and pending_visitor_event == "":
		_create_event_trigger_circle("normal_police", Vector3(6.75, 0.52, 4.0), "⚠ ANH CẢNH SÁT TUẦN ĐÊM ĐẾN: Hãy đứng vào vòng sáng xanh ở quầy thu ngân để gặp cảnh sát!")
	elif current_hour == 3 and current_minute == 5 and pending_visitor_event == "":
		_create_event_trigger_circle("mutant_freezer_ghost", Vector3(12.2, 0.52, 1.5), "⚠ TIẾNG KHÓC LẠNH LẼO: Hãy đứng vào vòng sáng đỏ cạnh tủ đông số 5 để kiểm tra!")
	elif current_hour == 3 and current_minute == 30 and pending_visitor_event == "":
		_create_event_trigger_circle("normal_student", Vector3(6.75, 0.52, 4.0), "⚠ CÔ NỮ SINH ÔN THI ĐẾN: Hãy đứng vào vòng sáng xanh ở quầy thu ngân để tiếp khách!")
		
	_update_clock_ui()
	
	if current_hour == 6 and is_am and current_minute == 0:
		_win_game()

func _update_clock_ui() -> void:
	if clock_label:
		var min_str = str(current_minute) if current_minute >= 10 else "0" + str(current_minute)
		var am_pm = "AM" if is_am else "PM"
		clock_label.text = str(current_hour) + ":" + min_str + " " + am_pm

func _set_objective(text: String) -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		var objective_label = player_node.get_node_or_null("HUD/ObjectiveLabel")
		if objective_label:
			objective_label.text = text

func _clear_objective() -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		var objective_label = player_node.get_node_or_null("HUD/ObjectiveLabel")
		if objective_label:
			objective_label.text = ""

# --- XỬ LÝ CÁC HIỆN TƯỢNG KINH DỊ TRONG CA LÀM THEO TỪNG NGÀY ---
func _process_horror_events(delta: float) -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		return
		
	var player_pos = player.global_position
	
	# --- [NGÀY 1 & 2 & 3] Sự kiện Lối đi 7: Tiếng khóc & va chạm Jumpscare (Quy tắc 2) ---
	var aisle7_pos = get_spawnpoint_global_position("aisle7", Vector3(6.4, 0.0, -1.0))
	var dist_to_aisle7 = player_pos.distance_to(aisle7_pos)
	var in_aisle7_corridor = (dist_to_aisle7 < 5.0)
	
	if active_anomaly_type == "aisle7_cry" and not aisle7_cry_triggered and in_aisle7_corridor:
		aisle7_cry_triggered = true
		play_procedural_sound("cry")
		start_dialogue_sequence([
			" Aaron: 'Hơ... tiếng khóc nỉ non ai oán của ai đó phát ra từ Lối đi số 7... Rùng rợn quá...'"
		], func():
			player.set_physics_process(true)
			current_anomaly_resolved = true
			_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Hãy nghỉ ngơi hoặc theo dõi CCTV.")
		)
	
	# Va chạm Lối đi 7 - Jumpscare khi vào SÂU bên trong hành lang (với cooldown chống spam)
	aisle7_jumpscare_cooldown -= delta
	if in_aisle7_corridor and dist_to_aisle7 < 2.5 and aisle7_jumpscare_cooldown <= 0.0:
		aisle7_jumpscare_cooldown = 15.0  # Cooldown 15 giây giữa các lần jumpscare
		_trigger_aisle7_jumpscare(player)
		
	# --- [NGÀY 2 & 3] Sự kiện mất nhạc Jazz phát thanh & 20s sinh tử (Quy tắc 7) ---
	if jazz_outage_active:
		jazz_outage_countdown -= delta
		if countdown_label:
			countdown_label.text = "CẢNH BÁO: KHÔI PHỤC NHẠC JAZZ TRONG: " + str(ceil(jazz_outage_countdown)) + " GIÂY!"
		
		if jazz_outage_countdown <= 0.0:
			_trigger_jazz_outage_death(player)
	
	# --- Bóng ma rình rập, Xe đẩy lạc chỗ (Quy tắc 4) & Vũng máu (Quy tắc 5) ---
	# Hoạt động ở MỌI NGÀY khi có sự kiện tương ứng
	# Cây lau nhà ở Breakroom xuất hiện để lau máu
	if not is_instance_valid(breakroom_mop_instance) and not player.is_holding_mop and is_instance_valid(blood_puddle_instance):
		_spawn_breakroom_mop()
		
	# Kiểm tra va chạm vũng máu (giẫm chân)
	if is_instance_valid(blood_puddle_instance):
		var dist = player_pos.distance_to(blood_puddle_instance.global_position)
		if dist < 1.3:
			if not player.is_holding_mop:
				_trigger_blood_jumpscare(player)
	
	# Sự kiện Bóng ma người phụ nữ áo đen rình rập (Quy tắc 6)
	if active_anomaly_type == "ghost_woman" or ghost_active:
		if not ghost_active:
			ghost_spawn_timer += delta
			if ghost_spawn_timer >= 60.0:
				_spawn_ghost_woman()
	
	if ghost_active and is_instance_valid(ghost_instance):
		_process_ghost_mechanic(player, delta)
	
	# --- HỆ THỐNG NPC DỊ NHÂN XUẤT HIỆN NGẪU NHIÊN KHI TUẦN TRA ---
	if not creepy_npc_active:
		creepy_npc_cooldown -= delta
		if creepy_npc_cooldown <= 0.0:
			creepy_npc_timer += delta
			if creepy_npc_timer >= 45.0:  # Mỗi ~45 giây có cơ hội spawn
				if randf() < 0.4:  # 40% cơ hội spawn
					_spawn_creepy_npc(player)
				creepy_npc_timer = 0.0
	else:
		_process_creepy_npc(player, delta)

# --- PHÂN CƠ CHẾ SỰ KIỆN CHI TIẾT KÈM ANIMATION ---

# 1. Jumpscare Lối đi số 7 (Kèm animation phóng vút & rung camera cực mạnh)
func _trigger_aisle7_jumpscare(player_node) -> void:
	play_procedural_sound("scream")
	player_node.set_physics_process(false)
	
	# Hiển thị thực thể ma quái thình lình chặn mặt
	var jumpscare_ghost = Node3D.new()
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.0, 0.0) # Thực thể đỏ ngầu giận dữ
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.0, 0.0)
	mesh_inst.material_override = mat
	jumpscare_ghost.add_child(mesh_inst)
	
	# Đặt ngay sát mặt player
	var cam = player_node.get_node("Head/Camera3D")
	jumpscare_ghost.position = cam.global_position - cam.global_transform.basis.z * 2.0
	get_tree().current_scene.add_child(jumpscare_ghost)
	
	# --- ANIMATION phóng vút sát mặt và phóng to cực nhanh ---
	var tween = create_tween().set_parallel(true)
	tween.tween_property(jumpscare_ghost, "global_position", cam.global_position - cam.global_transform.basis.z * 0.8, 0.25)
	tween.tween_property(jumpscare_ghost, "scale", Vector3(3.0, 3.0, 3.0), 0.25)
	
	# --- ANIMATION Rung lắc camera cực mạnh của Player ---
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.6, 0.15)
	
	# Tạo hiệu ứng chớp đỏ chói toàn màn hình
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(1.0, 0.0, 0.0, 0.85)
	current_hud.add_child(red_fade)
	
	# Mất thể lực cực nặng
	player_node.current_stamina = 0.0
	player_node.is_exhausted = true
	
	# Teleport về phòng Breakroom an toàn sau 0.5s
	var t = get_tree().create_timer(0.4)
	t.timeout.connect(func():
		jumpscare_ghost.queue_free()
		var start_pos = get_spawnpoint_global_position("door", Vector3(5.75, 0.52, 10.96))
		player_node.global_position = Vector3(start_pos.x, 0.52, start_pos.z)
		
		start_dialogue_sequence([
			" Bàn tay đỏ ngầu thình lình vồ thẳng vào mắt bạn cùng tiếng gầm rú điếc tai!",
			" Aaron: 'Hộc... Hộc... Suýt nữa là mất mạng rồi! Tim mình đang đập liên hồi. Mình phải cẩn thận hơn!'"
		], func():
			red_fade.queue_free()
			player_node.set_physics_process(true)
			aisle7_cry_triggered = false
			current_anomaly_resolved = true
			_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Hãy nghỉ ngơi hoặc theo dõi CCTV.")
		)
	)

# 2. Sự kiện Đèn Chập Tắt & Phải đi bật Cầu dao cuối hành lang (Ngày 2 & 3)
func _trigger_aisle_blackout(aisle_num: int) -> void:
	play_procedural_sound("glitch")
	var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
	if not shelves_node:
		return
		
	var shelf = shelves_node.get_node_or_null("Shelf_Aisle" + str(aisle_num))
	if not shelf:
		return
		
	active_blackout_aisle = aisle_num
	
	# --- ANIMATION ĐÈN CHỚP NHÁY LIÊN TỤC TRƯỚC KHI TẮT HẲN ---
	var tween = create_tween()
	var lights = []
	for child in shelf.get_children():
		if child is OmniLight3D:
			lights.append(child)
			
	# Nhấp nháy chập điện
	for i in range(4):
		for l in lights:
			tween.tween_property(l, "light_energy", 0.0, 0.08)
			tween.tween_property(l, "light_energy", 0.45, 0.08)
			
	# Tắt phụt hoàn toàn
	tween.tween_callback(func():
		for l in lights:
			l.light_energy = 0.0
			
		# Báo động
		_set_objective("CẢNH BÁO: Đèn Lối đi " + str(active_blackout_aisle) + " đã bị chập tắt! Hãy đến cuối hành lang để bật lại cầu chì.")

		# CCTV: nhiễu mạnh camera tương ứng với lối đi chập điện
		var cam_idx = AISLE_TO_CAM.get(aisle_num, 0)
		_glitch_cctv(cam_idx, 0.9, 6.0)
		_alert_cctv(cam_idx, 8.0)
		
		# Sinh hộp cầu chì ở cuối hành lang tối (z = -11.0, local y = 1.4, x = 1.6)
		_spawn_breaker_switch(shelf, aisle_num)
	)

# Sinh breaker switch tương tác ở cuối lối đi chập điện
func _spawn_breaker_switch(shelf_node, aisle_num: int) -> void:
	if is_instance_valid(breaker_switch_instance):
		breaker_switch_instance.queue_free()
		
	var box = StaticBody3D.new()
	box.name = "BreakerSwitch"
	box.position = Vector3(1.6, 1.4, -11.0) # Cuối hành lang local của kệ hàng
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4)
	col.shape = shape
	box.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.3, 0.3, 0.2)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.1) # Hộp điện màu vàng nổi bật trong tối
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.3, 0.05)
	mesh_inst.material_override = mat
	box.add_child(mesh_inst)
	
	box.add_to_group("interactable")
	box.set_script(load("res://scripts/breaker_switch.gd"))
	box.call_deferred("setup", aisle_num)
	
	shelf_node.add_child(box)
	breaker_switch_instance = box

# Khôi phục điện cho lối đi khi người chơi gạt cầu chì
func fix_aisle_lights(aisle_num: int) -> void:
	if active_blackout_aisle != aisle_num:
		return
		
	active_blackout_aisle = 0
	breaker_switch_instance = null
	
	var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
	if shelves_node:
		var shelf = shelves_node.get_node_or_null("Shelf_Aisle" + str(aisle_num))
		if shelf:
			# --- ANIMATION ÁNH SÁNG BẬT TÁCH TRỞ LẠI ---
			var tween = create_tween()
			for child in shelf.get_children():
				if child is OmniLight3D:
					tween.tween_property(child, "light_energy", 0.45, 0.15)
					
	_set_objective("NHIỆM VỤ: Điện Lối đi " + str(aisle_num) + " đã được phục hồi thành công!")
	current_anomaly_resolved = true
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Hãy nghỉ ngơi hoặc theo dõi CCTV.")
	)

# 3. Kích hoạt loa mất nhạc phát thanh (Tiếng rè rè tội lỗi)
func _trigger_jazz_outage() -> void:
	jazz_outage_active = true
	jazz_outage_countdown = 35.0
	
	var music_player = get_tree().current_scene.get_node_or_null("BackgroundJazzMusic")
	if music_player:
		music_player.stop()
		
	countdown_label = Label.new()
	countdown_label.anchors_preset = Control.PRESET_CENTER_TOP
	countdown_label.offset_top = 100.0
	countdown_label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	var settings = LabelSettings.new()
	settings.font_size = 28
	settings.font_color = Color(1.0, 0.1, 0.1)
	settings.outline_size = 6
	settings.outline_color = Color(0.0, 0.0, 0.0)
	countdown_label.label_settings = settings
	current_hud.add_child(countdown_label)
	
	_spawn_reset_box() # Sinh MusicResetBox trong toilet
	
	start_dialogue_sequence([
		" Aaron: 'Agh... Bản nhạc Jazz phát thanh tắt phụt rồi! Một tiếng rè rè nhiễu sóng u ám rít lên chói tai từ phía Toilet... Nó đang dội thẳng vào não mình! Mình phải chạy nhanh vào phòng vệ sinh dọn dẹp âm thanh này đi!'"
	], func():
		var player_node = get_tree().current_scene.find_child("Player", true, false)
		if player_node:
			player_node.set_physics_process(true)
			_set_objective("⚠ CẢNH BÁO: Hãy chạy nhanh vào phòng vệ sinh (toilet) và nhấn E vào Hộp điện phụ để tắt tiếng rè!")
	)

# Hồi sinh lại nhạc phát thanh khi người chơi nhấn E vào máy phát phụ trong toilet
func reset_jazz_music() -> void:
	if not jazz_outage_active:
		return
		
	jazz_outage_active = false
	jazz_outage_timer = 0.0
	
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	var music_player = get_tree().current_scene.get_node_or_null("BackgroundJazzMusic")
	if music_player:
		music_player.play()
		
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		player_node.set_physics_process(false)
		
		play_procedural_sound("glitch")
		if player_node.has_method("shake_camera"):
			player_node.shake_camera(0.9, 0.3)
			
	start_dialogue_sequence([
		" Aaron: 'Tiếng rè rè tắt lịm rồi... Nhạc Jazz phát thanh cũng quay trở lại. Nhưng... nhưng dòng chữ đỏ sẫm như máu chảy lan trên mặt gương toilet này là thế nào?! \"MÀY LÀ KẺ SÁT NHÂN\"?!'",
		" Aaron: 'Không! Ai đó đang chơi khăm mình đúng không?! Sếp Clive?!'",
		" Aaron: 'Tại sao... tại sao bàn tay mình lại đang run rẩy thế này... Đầu mình đau quá...'"
	], func():
		var player = get_tree().current_scene.find_child("Player", true, false)
		if player:
			player.set_physics_process(true)
		current_anomaly_resolved = true
		_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Cơn đau đầu dịu đi. Hãy quay lại sảnh chính.")
		if is_instance_valid(reset_box_instance):
			reset_box_instance.queue_free()
			reset_box_instance = null
	)

# Game Over nếu hết 20 giây chưa bật lại nhạc
func _trigger_jazz_outage_death(player_node) -> void:
	if is_player_in_safe_zone():
		jazz_outage_active = false
		if is_instance_valid(countdown_label):
			countdown_label.queue_free()
		current_anomaly_resolved = true
		_set_objective("NHIỆM VỤ: Bản nhạc Jazz đã tắt hẳn, nhưng trốn trong Toilet đã cứu mạng bạn!")
		start_dialogue_sequence([
			" Tiếng rè rè nhiễu sóng ma quái rít lên ngoài Toilet. Bạn bị chặn lại trong phòng kín nhưng hoàn toàn bình an vô sự...",
			" Aaron: 'Phù... tiếng xích sắt bên ngoài đã rời xa. Toilet thực sự là chỗ cứu cánh duy nhất khi xảy ra chập điện!'"
		], func():
			if is_instance_valid(player_node):
				player_node.set_physics_process(true)
		)
		return

	play_procedural_sound("scream")
	player_node.set_physics_process(false)
	
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(0.1, 0.0, 0.0, 1.0)
	current_hud.add_child(red_fade)
	
	start_dialogue_sequence([
		" Bóng tối bao trùm lấy toàn bộ siêu thị. Bản nhạc Jazz câm lặng vĩnh viễn.",
		" BẠN ĐÃ VI PHẠM QUY TẮC 7. BỌN HỌ ĐÃ TÌM THẤY BẠN TRONG PHÒNG TỐI... [GAME OVER!]"
	], func():
		game_over.emit(false)
		get_tree().reload_current_scene()
	)

# Sinh bóng ma người phụ nữ (Quy tắc 6)
func _spawn_ghost_woman() -> void:
	ghost_spawn_timer = 0.0
	ghost_active = true
	ghost_look_timer = 0.0
	
	var ghost = Node3D.new()
	ghost.name = "GhostWoman"
	
	# Chọn ngẫu nhiên hành lang giữa Aisle 2-3 (X=-6.4) hoặc Aisle 3-4 (X=-3.2)
	var spawn_x = -6.4 if randf() > 0.5 else -3.2
	ghost.position = Vector3(spawn_x, 0.9, -10.0)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.7
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.04, 0.04) # Màu bóng đêm sâu thẳm
	mat.roughness = 0.9
	mesh_inst.material_override = mat
	ghost.add_child(mesh_inst)
	
	get_tree().current_scene.add_child(ghost)
	ghost_instance = ghost

	# CCTV: báo chuyển động & nhiễu camera khu Lối đi 2-3 nơi ghost xuất hiện
	_glitch_cctv(1, 0.5, 4.0)
	_alert_cctv(1, 10.0)

# Cơ chế tương tác với Bóng ma: Tắt đèn pin và đi lùi! (Kèm Jumpscare animation)
func _process_ghost_mechanic(player_node, delta: float) -> void:
	if not is_instance_valid(ghost_instance):
		ghost_active = false
		return
		
	var dist = player_node.global_position.distance_to(ghost_instance.global_position)
	if dist > 15.0:
		_despawn_ghost()
		return
		
	var flashlight = player_node.get_node_or_null("Head/Camera3D/Flashlight")
	var is_light_on = is_instance_valid(flashlight) and flashlight.visible
	
	var cam = player_node.get_node_or_null("Head/Camera3D")
	if is_instance_valid(cam):
		var to_ghost = (ghost_instance.global_position - cam.global_position).normalized()
		var cam_forward = -cam.global_transform.basis.z.normalized()
		var dot = cam_forward.dot(to_ghost)
		
		# Nhìn góc hẹp (dot > 0.85) và bật đèn pin chiếu vào
		if dot > 0.85 and is_light_on:
			ghost_look_timer += delta
			_set_objective("CẢNH BÁO: TẮT ĐÈN PIN VÀ ĐI LÙI LẠI NGAY LẬP TỨC (QUY TẮC 6)!")
			
			if ghost_look_timer >= 2.0:
				_trigger_ghost_jumpscare(player_node)
		else:
			ghost_look_timer = move_toward(ghost_look_timer, 0.0, delta)
			
			var wants_to_move_back = Input.get_vector("move_left", "move_right", "move_forward", "move_back").y > 0
			if wants_to_move_back and not is_light_on:
				_set_objective("NHIỆM VỤ: Bóng ma đã tan biến. Bạn vừa xử lý Quy tắc 6 cực kỳ xuất sắc!")
				var timer = get_tree().create_timer(1.5)
				timer.timeout.connect(func(): _despawn_ghost())

func _despawn_ghost() -> void:
	ghost_active = false
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
	_set_objective("NHIỆM VỤ: Tuần tra toàn bộ siêu thị mỗi 1 TIẾNG ảo một lần.")

# jumpscare Bóng ma vồ (Kèm animation vồ sát mặt và rung lắc camera dữ dội)
func _trigger_ghost_jumpscare(player_node) -> void:
	play_procedural_sound("scream")
	player_node.set_physics_process(false)
	
	# Màn hình đỏ ngầu
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(0.9, 0.0, 0.0, 1.0)
	current_hud.add_child(red_fade)
	
	# --- ANIMATION Vồ thẳng vào mặt camera ---
	var cam = player_node.get_node("Head/Camera3D")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(ghost_instance, "global_position", cam.global_position - cam.global_transform.basis.z * 0.6, 0.2)
	tween.tween_property(ghost_instance, "scale", Vector3(3.5, 3.5, 3.5), 0.2)
	
	# --- ANIMATION Rung lắc camera cực mạnh ---
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.8, 0.2)
		
	var t = get_tree().create_timer(0.4)
	t.timeout.connect(func():
		start_dialogue_sequence([
			" Aaron: 'Cái gì thế này... Lạnh quá... Đôi mắt đó đang nhìn xoáy vào mình... Không!!!'",
			" HỆ THỐNG: Cảnh báo! Bạn đã vi phạm quy tắc 6. [GAME OVER]"
		], func():
			game_over.emit(false)
			get_tree().reload_current_scene()
		)
	)

# ==================== CÁC PHƯƠNG THỨC HỖ TRỢ SPAWN & XỬ LÝ QUY TẮC 4 & 5 (NGÀY 3) ====================

# 1. Sinh xe đẩy hàng lạc chỗ (Quy tắc 4)
func _spawn_misplaced_shopping_cart() -> void:
	has_spawned_cart = true
	_set_objective("NHIỆM VỤ TUẦN TRA 1:00 AM: Có xe đẩy hàng nằm lạc lối ở Lối đi 3! Hãy tới đẩy nó trả về hàng xe xếp ở Sảnh chính.")
	
	var box = StaticBody3D.new()
	box.name = "MisplacedCart"
	# Spawn ở hành lang giữa lối đi 3 và 4 (X = -3.2)
	box.position = Vector3(-3.2, 0.45, -1.0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.8, 0.7, 0.9)
	col.shape = shape
	box.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.7, 0.5, 0.8)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.7, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.5
	mat.wireframe = true
	mesh_inst.material_override = mat
	box.add_child(mesh_inst)
	
	# Thêm tay cầm đỏ
	var handle_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.015
	cyl.bottom_radius = 0.015
	cyl.height = 0.7
	handle_mesh.mesh = cyl
	var h_mat = StandardMaterial3D.new()
	h_mat.albedo_color = Color(1.0, 0.1, 0.1)
	handle_mesh.material_override = h_mat
	handle_mesh.position = Vector3(0.0, 0.25, 0.4)
	handle_mesh.rotation_degrees = Vector3(0, 0, 90)
	box.add_child(handle_mesh)
	
	box.add_to_group("interactable")
	
	box.set_meta("interact_callable", func(player_node):
		if player_node.is_holding_mop:
			player_node.set_holding_mop(false)
			if is_instance_valid(breakroom_mop_instance):
				breakroom_mop_instance.visible = true
				
		player_node.set_pushing_cart(true)
		
		# Hiện thông báo và mục tiêu mới
		_set_objective("NHIỆM VỤ: Đẩy xe hàng lạc lối về kệ xe trước sảnh chính.")
		start_dialogue_sequence([
			" Aaron: 'Xe đẩy hàng nằm chỏng chơ nghiêng ngả ở đây rồi. Mình phải đẩy nó về đúng kệ xe sảnh chính ngay.'"
		], func():
			player_node.set_physics_process(true)
		)
		
		# Hủy xe đẩy dưới sàn
		misplaced_cart_instance = null
		box.queue_free()
		
		# Sinh vùng trả xe đẩy trước sảnh chính
		_spawn_cart_return_zone()
	)
	box.set("prompt_message", "[E] Nhặt xe đẩy hàng lạc chỗ (Quy tắc 4)")
	
	# Đăng ký tương tác thông thường
	box.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(box)
	misplaced_cart_instance = box

func _spawn_cart_return_zone() -> void:
	if is_instance_valid(cart_return_zone_instance):
		cart_return_zone_instance.queue_free()
		
	var zone = StaticBody3D.new()
	zone.name = "CartReturnZone"
	zone.position = Vector3(0.0, 0.05, 11.5) # Gần cửa ra vào
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 0.1, 2.0)
	col.shape = shape
	zone.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.8, 0.02, 1.8)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.2, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.5, 0.1)
	mesh_inst.material_override = mat
	zone.add_child(mesh_inst)
	
	zone.add_to_group("interactable")
	zone.set("prompt_message", "[E] Đẩy trả xe hàng vào kệ xe đẩy (Quy tắc 4)")
	
	zone.set_meta("interact_callable", func(player_node):
		if not player_node.is_pushing_cart:
			start_dialogue_sequence([" Aaron: 'Mình phải đẩy xe hàng lạc chỗ tới đây thì mới trả xe được!'"], func(): player_node.set_physics_process(true))
			return
			
		player_node.set_pushing_cart(false)
		
		# --- ANIMATION xe trượt vào kệ ---
		var dummy_cart = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.7, 0.5, 0.8)
		dummy_cart.mesh = box_mesh
		var d_mat = StandardMaterial3D.new()
		d_mat.albedo_color = Color(0.7, 0.7, 0.7)
		d_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		d_mat.albedo_color.a = 0.5
		d_mat.wireframe = true
		dummy_cart.material_override = d_mat
		get_tree().current_scene.add_child(dummy_cart)
		dummy_cart.global_position = Vector3(0.0, 0.45, 11.5)
		
		# Lướt vào kệ
		var tween = create_tween()
		tween.tween_property(dummy_cart, "global_position:z", 13.5, 0.6)
		tween.tween_callback(dummy_cart.queue_free)
		
		start_dialogue_sequence([
			" Xe hàng trượt êm ái vào thẳng hàng xe xếp ngay ngắn!",
			" Aaron: 'Hơ... Đã trả xong xe đẩy hàng. Quy tắc 4 hoàn thành an toàn!'"
		], func():
			player_node.set_physics_process(true)
			current_anomaly_resolved = true
			_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Hãy nghỉ ngơi hoặc theo dõi CCTV.")
		)
		
		cart_return_zone_instance = null
		zone.queue_free()
	)
	
	zone.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(zone)
	cart_return_zone_instance = zone

# 2. Sinh Vũng máu thảm khốc tại Lối đi trung tâm (Vết tích vụ án)
func _spawn_blood_puddle() -> void:
	has_spawned_blood = true
	_set_objective("NHIỆM VỤ TUẦN TRA 2:00 AM: Có một vũng máu tươi loang lổ xuất hiện ở lối đi chính. Hãy tìm cây lau nhà ở sảnh để lau dọn!")
	
	var puddle = StaticBody3D.new()
	puddle.name = "BloodPuddle"
	puddle.position = Vector3(5.75, 0.02, 2.0) # Hành lang lối đi chính
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.4, 0.1, 2.4)
	col.shape = shape
	puddle.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = 1.2
	mesh.bottom_radius = 1.2
	mesh.height = 0.02
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.0, 0.0) # Màu đỏ thẫm u ám của máu đông
	mat.emission_enabled = true
	mat.emission = Color(0.28, 0.0, 0.0)
	mesh_inst.material_override = mat
	puddle.add_child(mesh_inst)
	
	puddle.add_to_group("interactable")
	puddle.set("prompt_message", "[E] Lau dọn vệt máu tươi ghê rợn")
	
	puddle.set_meta("interact_callable", func(player_node):
		if not player_node.is_holding_mop:
			start_dialogue_sequence([" Aaron: 'Một vệt máu đỏ lòm kinh dị... Mình phải đi tìm Cây lau nhà ở sảnh chính để dọn dẹp trước khi sếp Clive kiểm tra!'"], func(): player_node.set_physics_process(true))
			return
			
		player_node.set_physics_process(false)
		
		# --- ANIMATION Lau nhà ---
		var mop_m = player_node.mop_mesh
		if is_instance_valid(mop_m):
			var mop_tween = create_tween().set_loops(4)
			mop_tween.tween_property(mop_m, "position:y", -0.45, 0.15)
			mop_tween.tween_property(mop_m, "position:y", -0.35, 0.15)
			
		var scale_tween = create_tween()
		scale_tween.tween_property(puddle, "scale", Vector3(0.001, 1.0, 0.001), 1.5)
		
		scale_tween.tween_callback(func():
			# Tiếng nhiễu sóng giật mạnh cực kỳ đáng sợ
			play_procedural_sound("glitch")
			if player_node.has_method("shake_camera"):
				player_node.shake_camera(1.3, 0.25)
				
			start_dialogue_sequence([
				" Aaron đẩy chổi lau đi lau lại trên vết máu... Nhưng vệt máu dường như càng lúc càng đậm hơn dưới ánh đèn lờ mờ...",
				" Một giọng nói vang vọng đột ngột bật ra từ tiềm thức của Aaron, giống hệt giọng của chính anh trong cơn hoảng loạn tột độ:",
				" Aaron (Trong tiềm thức): 'Chết tiệt! Họ chết rồi! Hai người họ chết thẳng cẳng rồi! Chúng ta phải giấu xác họ đi... bỏ họ vào cái tủ đông đằng kia mau lên! Nhanh, trước khi có ai đi ngang qua!!!'",
				" Aaron: 'Không... KHÔNG THỂ NÀO! Đó là giọng nói của mình... Tại sao giọng mình lại ở đó...'",
				" Aaron: 'Chính tay mình... chính tay mình đã lái chiếc xe đó đâm vào họ... và kéo xác họ giấu vào tủ đông sao?! Không!!!'"
			], func():
				player_node.set_physics_process(true)
				current_anomaly_resolved = true
				_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Tội lỗi đang đè nặng lên lồng ngực. Hãy quay lại sảnh.")
			)
			
			blood_puddle_instance = null
			puddle.queue_free()
		)
	)
	
	puddle.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(puddle)
	blood_puddle_instance = puddle

	# CCTV: báo chuyển động camera quầy thịt (CAM 5)
	_glitch_cctv(5, 0.6, 3.0)
	_alert_cctv(5, 15.0)

# 3. Sinh Cây lau nhà trong Phòng kho (Quy tắc 5)
func _spawn_breakroom_mop() -> void:
	var mop = StaticBody3D.new()
	mop.name = "BreakroomMop"
	mop.position = Vector3(5.0, 0.9, -10.5) # Tựa vào đống thùng trong phòng kho mới
	mop.rotation_degrees = Vector3(15, 0, 0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.3, 1.2, 0.3)
	col.shape = shape
	mop.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 1.0
	mesh_inst.mesh = cyl
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.5, 0.3)
	mesh_inst.material_override = mat
	mop.add_child(mesh_inst)
	
	var head_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.2, 0.1, 0.15)
	head_mesh.mesh = box
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.9, 0.9, 0.9)
	head_mesh.material_override = head_mat
	head_mesh.position = Vector3(0, -0.5, 0)
	mop.add_child(head_mesh)
	
	mop.add_to_group("interactable")
	mop.set("prompt_message", "[E] Lấy cây lau nhà (Quy tắc 5)")
	
	mop.set_meta("interact_callable", func(player_node):
		if player_node.is_pushing_cart:
			player_node.set_pushing_cart(false)
			# Spawn lại xe đẩy ngoài sảnh
			has_spawned_cart = false
			
		player_node.set_holding_mop(true)
		
		# Ẩn cây lau nhà tại breakroom
		mop.visible = false
		
		start_dialogue_sequence([
			" Aaron: 'Mình đã cầm chắc Cây lau nhà rồi. Giờ phải đi nhanh ra khu bán thịt Aisle 8 lau dọn vũng máu rỉ ra thôi!'"
		], func():
			player_node.set_physics_process(true)
		)
	)
	
	mop.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(mop)
	breakroom_mop_instance = mop

# 4. Sinh vùng trả cây lau nhà về Phòng kho (Quy tắc 5)
func _spawn_mop_return_zone() -> void:
	if is_instance_valid(mop_return_zone_instance):
		mop_return_zone_instance.queue_free()
		
	var zone = StaticBody3D.new()
	zone.name = "MopReturnZone"
	zone.position = Vector3(5.0, 0.05, -10.5) # Gần vị trí cây lau nhà trong phòng kho mới
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2.0, 0.1, 2.0)
	col.shape = shape
	zone.add_child(col)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.8, 0.02, 1.8)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.9, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.3, 0.6)
	mesh_inst.material_override = mat
	zone.add_child(mesh_inst)
	
	zone.add_to_group("interactable")
	zone.set("prompt_message", "[E] Trả lại cây lau nhà (Quy tắc 5)")
	
	zone.set_meta("interact_callable", func(player_node):
		if not player_node.is_holding_mop:
			start_dialogue_sequence([" Aaron: 'Mình phải cầm cây lau nhà thì mới trả lại được!'"], func(): player_node.set_physics_process(true))
			return
			
		player_node.set_holding_mop(false)
		
		# Hiện lại cây lau nhà tại Breakroom
		if is_instance_valid(breakroom_mop_instance):
			breakroom_mop_instance.visible = true
		
		start_dialogue_sequence([
			" Aaron: 'Đã trả lại cây lau nhà về chỗ cũ. Quy tắc 5 hoàn thành!'"
		], func():
			player_node.set_physics_process(true)
			current_anomaly_resolved = true
			_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Hãy nghỉ ngơi hoặc theo dõi CCTV.")
		)
		
		mop_return_zone_instance = null
		zone.queue_free()
	)
	
	zone.set_script(load("res://scripts/custom_interactable.gd"))
	
	get_tree().current_scene.add_child(zone)
	mop_return_zone_instance = zone

# ==================== HỆ THỐNG NPC DỊ NHÂN CẢN ĐƯỜNG & JUMPSCARE ====================

func _spawn_creepy_npc(player_ref) -> void:
	if is_instance_valid(creepy_npc_instance):
		creepy_npc_instance.queue_free()
	
	# Chọn ngẫu nhiên loại NPC và vị trí spawn
	var npc_def = CREEPY_NPC_DEFS[randi() % CREEPY_NPC_DEFS.size()]
	
	# Tính toán danh sách điểm spawn động dựa trên vị trí thực tế của các kệ hàng
	var dynamic_points = []
	var shelving_names = ["shelving1", "shelving2", "shelving3", "shelving4"]
	for name in shelving_names:
		var shelf_pos = get_spawnpoint_global_position(name, Vector3.ZERO)
		if shelf_pos != Vector3.ZERO:
			# Sinh 2 điểm đứng ở 2 lối đi bên cạnh kệ hàng (cách kệ hàng 1.6m về trái và phải)
			dynamic_points.append(shelf_pos + Vector3(-1.6, 0.0, 0.0))
			dynamic_points.append(shelf_pos + Vector3(1.6, 0.0, 0.0))
			
	if dynamic_points.is_empty():
		dynamic_points = CREEPY_SPAWN_POINTS
	
	# Tìm vị trí spawn gần player nhưng không quá gần (5-12m)
	var valid_points = []
	for pt in dynamic_points:
		# Đảm bảo Y luôn ở cao độ sàn siêu thị tối thiểu là 0.52m để tránh bị lún đất/va chạm
		var floor_y = max(pt.y, 0.52)
		var adjusted = Vector3(pt.x, floor_y + npc_def["height"] * 0.5, pt.z)
		var dist = player_ref.global_position.distance_to(adjusted)
		if dist >= 5.0 and dist <= 14.0:
			valid_points.append(adjusted)
	
	if valid_points.is_empty():
		return
	
	var spawn_pos = valid_points[randi() % valid_points.size()]
	
	var npc = Node3D.new()
	npc.name = npc_def["name"]
	npc.position = spawn_pos
	npc.scale = npc_def["scale"]
	
	# CONFIG: Nếu có model 3D thực sự, dùng "scene" thay vì "capsule"
	if npc_def["mesh_type"] == "scene" and npc_def.has("scene_path"):
		var scene = load(npc_def["scene_path"])
		if scene:
			var model = scene.instantiate()
			npc.add_child(model)
	else:
		# Tạo mesh capsule placeholder
		var mesh_inst = MeshInstance3D.new()
		var mesh = CapsuleMesh.new()
		mesh.radius = npc_def["radius"]
		mesh.height = npc_def["height"]
		mesh_inst.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = npc_def["color"]
		mat.roughness = 0.95
		if npc_def["emission"] != Color(0, 0, 0):
			mat.emission_enabled = true
			mat.emission = npc_def["emission"]
		mesh_inst.material_override = mat
		npc.add_child(mesh_inst)
		
		# Thêm mắt phát sáng đỏ rùng rợn cho placeholder
		for eye_x in [-0.1, 0.1]:
			var eye = MeshInstance3D.new()
			var eye_mesh = SphereMesh.new()
			eye_mesh.radius = 0.04
			eye.mesh = eye_mesh
			var eye_mat = StandardMaterial3D.new()
			eye_mat.albedo_color = Color(1.0, 0.0, 0.0)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.0, 0.0)
			eye.material_override = eye_mat
			eye.position = Vector3(eye_x, npc_def["height"] * 0.35, -npc_def["radius"] - 0.02)
			npc.add_child(eye)
	
	# Lưu metadata để truy xuất sau
	npc.set_meta("npc_def", npc_def)
	npc.set_meta("spawn_time", Time.get_ticks_msec())
	
	get_tree().current_scene.add_child(npc)
	creepy_npc_instance = npc
	creepy_npc_active = true
	creepy_npc_look_timer = 0.0
	
	# Phát tiếng nhiễu tĩnh khi NPC xuất hiện
	play_procedural_sound("static")

func _process_creepy_npc(player_ref, delta: float) -> void:
	if not is_instance_valid(creepy_npc_instance):
		_despawn_creepy_npc()
		return
	
	var dist = player_ref.global_position.distance_to(creepy_npc_instance.global_position)
	
	# NPC biến mất nếu player lùi xa > 16m
	if dist > 16.0:
		_despawn_creepy_npc()
		return
	
	# NPC tự biến mất sau 25 giây nếu player không tới gần
	var elapsed = (Time.get_ticks_msec() - int(creepy_npc_instance.get_meta("spawn_time"))) / 1000.0
	if elapsed > 25.0:
		# Biến mất kèm hiệu ứng nhấp nháy
		var tween = create_tween().set_loops(5)
		tween.tween_property(creepy_npc_instance, "visible", false, 0.08)
		tween.tween_property(creepy_npc_instance, "visible", true, 0.08)
		tween.tween_callback(func(): _despawn_creepy_npc())
		return
	
	# Animation giật giật rung lắc liên tục (micro-twitch)
	if randi() % 30 == 0:
		var orig_pos = creepy_npc_instance.position
		creepy_npc_instance.position.x += randf_range(-0.03, 0.03)
		get_tree().create_timer(0.06).timeout.connect(func():
			if is_instance_valid(creepy_npc_instance):
				creepy_npc_instance.position = orig_pos
		)
	
	# Phát hiện player nhìn thẳng vào NPC
	var cam = player_ref.get_node_or_null("Head/Camera3D")
	if is_instance_valid(cam) and dist < 8.0:
		var to_npc = (creepy_npc_instance.global_position - cam.global_position).normalized()
		var cam_forward = -cam.global_transform.basis.z.normalized()
		var dot = cam_forward.dot(to_npc)
		
		if dot > 0.85:
			creepy_npc_look_timer += delta
			# Nhìn > 1.5 giây → Jumpscare!
			if creepy_npc_look_timer >= 1.5:
				_trigger_creepy_npc_jumpscare(player_ref)
		else:
			creepy_npc_look_timer = move_toward(creepy_npc_look_timer, 0.0, delta * 0.5)
	
	# Nếu player lại quá gần (< 2.5m) mà không nhìn → NPC vồ
	if dist < 2.5:
		_trigger_creepy_npc_jumpscare(player_ref)

func _despawn_creepy_npc() -> void:
	creepy_npc_active = false
	creepy_npc_look_timer = 0.0
	creepy_npc_cooldown = randf_range(30.0, 60.0)  # Nghỉ 30-60s trước khi spawn tiếp
	if is_instance_valid(creepy_npc_instance):
		creepy_npc_instance.queue_free()
		creepy_npc_instance = null

func _trigger_creepy_npc_jumpscare(player_node) -> void:
	if not is_instance_valid(creepy_npc_instance):
		return
	
	var npc_def = creepy_npc_instance.get_meta("npc_def")
	
	play_procedural_sound("scream")
	player_node.set_physics_process(false)
	
	# Màn hình chớp đỏ
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(0.8, 0.0, 0.0, 0.9)
	current_hud.add_child(red_fade)
	
	# Animation NPC lao vào mặt
	var cam = player_node.get_node("Head/Camera3D")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(creepy_npc_instance, "global_position", cam.global_position - cam.global_transform.basis.z * 0.5, 0.2)
	tween.tween_property(creepy_npc_instance, "scale", Vector3(4.0, 4.0, 4.0), 0.2)
	
	# Rung camera
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.7, 0.18)
	
	# Mất thể lực
	player_node.current_stamina = max(player_node.current_stamina - 40.0, 0.0)
	
	var t = get_tree().create_timer(0.35)
	t.timeout.connect(func():
		# Ném về Quầy thanh toán dọc
		var start_pos = get_spawnpoint_global_position("door", Vector3(5.75, 0.52, 10.96))
		player_node.global_position = Vector3(start_pos.x, 0.52, start_pos.z)
		
		start_dialogue_sequence([
			" " + npc_def["scare_text"],
			" Aaron: 'Trời ơi...! Thứ gì vừa rồi... Tim mình muốn vỡ tung rồi! Phải bình tĩnh lại...'"
		], func():
			red_fade.queue_free()
			player_node.set_physics_process(true)
		)
		
		_despawn_creepy_npc()
	)

# Trigger test NPC dị nhân từ bảng thử nghiệm
func trigger_creepy_npc_test() -> void:
	if is_prologue:
		jump_to_day(current_day)
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		_spawn_creepy_npc(player)

# Jumpscare khi giẫm vào vũng máu (Quy tắc 5)
func _trigger_blood_jumpscare(player_node) -> void:
	play_procedural_sound("scream")
	player_node.set_physics_process(false)
	
	# Chớp đỏ chói mắt
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(1.0, 0.0, 0.0, 0.9)
	current_hud.add_child(red_fade)
	
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.65, 0.12)
		
	# Mất thể lực cực nặng
	player_node.current_stamina = 0.0
	player_node.is_exhausted = true
	
	var t = get_tree().create_timer(0.4)
	t.timeout.connect(func():
		var start_pos = get_spawnpoint_global_position("door", Vector3(5.75, 0.52, 10.96))
		player_node.global_position = Vector3(start_pos.x, 0.52, start_pos.z)
		
		start_dialogue_sequence([
			" Vũng máu bỗng sôi sùng sục vươn lên những xúc tu tăm tối quấn chặt cổ chân lôi tuột bạn đi!",
			" Aaron: 'Hự... Á... Quy tắc 5 dặn không được giẫm lên vũng máu! Suýt tí nữa mình đã bị thứ kinh dị đó nuốt chửng rồi...!'"
		], func():
			red_fade.queue_free()
			player_node.set_physics_process(true)
		)
	)

# --- HOÀN THÀNH VÀ CHUYỂN GIAO NGÀY TRỰC ---
func _win_game() -> void:
	set_process(false)
	
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		player_node.set_physics_process(false)
		
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	if current_day < 3:
		start_dialogue_sequence([
			" Aaron: '6:00 AM rồi! Bầu trời hồng bình minh đã lên! Ca trực ngày " + str(current_day) + " đã hoàn thành...'",
			" Aaron: 'Mệt mỏi quá... Mình phải về ngủ dưỡng sức để chuẩn bị cho ca làm đêm tiếp theo...'"
		], func():
			_transition_to_next_day()
		)
	else:
		start_dialogue_sequence([
			" Aaron: '6:00 AM rồi! Đêm thứ ba kết thúc! Bầu trời hồng rực rỡ đã lên hẳn...!'",
			" Aaron: 'Clive... Tôi đã làm được! Tôi đã tuân thủ mọi quy tắc và sống sót an toàn suốt 3 ngày trực...!'",
			" XIN CHÚC MỪNG! BẠN ĐÃ CHINH PHỤC TUYỆT ĐỐI 3 NGÀY TRỰC KINH DỊ SIÊU THỊ WEST MARKET!"
		], func():
			game_over.emit(true)
		)

func _transition_to_next_day() -> void:
	var tween = create_tween()
	tween.tween_property(screen_fade, "color:a", 1.0, 1.5)
	
	tween.tween_callback(func():
		current_day += 1
		
		var day_splash = Label.new()
		day_splash.anchors_preset = Control.PRESET_FULL_RECT
		day_splash.text = "NGÀY " + str(current_day) + "\n\nBẮT ĐẦU CA LÀM VIỆC MỚI"
		day_splash.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		day_splash.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
		
		var settings = LabelSettings.new()
		settings.font_size = 48
		settings.font_color = Color(1.0, 0.85, 0.2)
		settings.outline_size = 8
		settings.outline_color = Color(0, 0, 0)
		day_splash.label_settings = settings
		current_hud.add_child(day_splash)
		
		var t = get_tree().create_timer(3.5)
		t.timeout.connect(func():
			day_splash.queue_free()
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player:
				player.global_position = Vector3(0.0, 0.5, 11.0)
				player.current_stamina = 100.0
				player.is_exhausted = false
				
			_start_prologue()
			
			var fade_in = create_tween()
			fade_in.tween_property(screen_fade, "color:a", 0.0, 1.5)
		)
	)

# --- HỆ THỐNG CCTV CAMERA ---

func _glitch_cctv(cam_index: int, intensity: float = 0.7, duration: float = 2.5) -> void:
	play_procedural_sound("static")
	if is_instance_valid(active_cctv_canvas) and active_cctv_canvas.has_method("glitch_camera"):
		active_cctv_canvas.glitch_camera(cam_index, intensity, duration)

func _alert_cctv(cam_index: int, duration: float = 5.0) -> void:
	if is_instance_valid(active_cctv_canvas) and active_cctv_canvas.has_method("trigger_motion_alert"):
		active_cctv_canvas.trigger_motion_alert(cam_index, duration)

func toggle_cctv_ui(player_node) -> void:
	if is_instance_valid(active_cctv_canvas):
		active_cctv_canvas.queue_free()
		active_cctv_canvas = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player_node.set_physics_process(true)
	else:
		# cctv_ui.gd extends CanvasLayer => tạo thẳng, không bọc thêm Node
		var cctv_node = CanvasLayer.new()
		cctv_node.set_script(cctv_ui_script)
		cctv_node.layer = 90
		get_tree().current_scene.add_child(cctv_node)
		active_cctv_canvas = cctv_node

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player_node.set_physics_process(false)

# Bật/tắt giao diện xem Quy tắc mọi lúc bằng phím tắt N
func toggle_rules_ui(player_node) -> void:
	# Khóa cho đến khi Clive gọi và chỉ đọc lại sau ca chính thức
	if not has_called_clive:
		return
	if is_instance_valid(active_scroll_canvas):
		active_scroll_canvas.queue_free()
		active_scroll_canvas = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player_node.set_physics_process(true)
	else:
		active_scroll_canvas = CanvasLayer.new()
		active_scroll_canvas.layer = 100
		
		var scroll_ui = scroll_ui_packed.instantiate()
		active_scroll_canvas.add_child(scroll_ui)
		get_tree().current_scene.add_child(active_scroll_canvas)
		
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player_node.set_physics_process(false)
		
		scroll_ui.get_node("CloseButton").pressed.connect(func():
			if is_instance_valid(active_scroll_canvas):
				active_scroll_canvas.queue_free()
				active_scroll_canvas = null
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				player_node.set_physics_process(true)
		)

# --- HỆ THỐNG ĐIỀU PHỐI DỊ THƯỜNG TUẦN TRA THEO GIỜ ---

func _trigger_hourly_anomaly() -> void:
	current_anomaly_resolved = false
	aisle7_cry_triggered = false
	
	# Xoá các thực thể / tương tác cũ nếu còn tồn tại
	if is_instance_valid(freezer_inspect_box_instance):
		freezer_inspect_box_instance.queue_free()
		freezer_inspect_box_instance = null
		
	# Phân phối chuỗi sự kiện ác mộng tội lỗi theo Giờ ảo
	match current_hour:
		1:
			active_anomaly_type = "freezer_vibration"
			_trigger_freezer_vibration_anomaly()
			_set_objective("NHIỆM VỤ TUẦN TRA 1:00 AM: Có âm thanh cào kính và rên rỉ kỳ lạ phát ra từ Tủ đông 5 & 6. Hãy tới kiểm tra!")
		2:
			active_anomaly_type = "blood_puddle"
			_spawn_blood_puddle()
		3:
			active_anomaly_type = "jazz_outage"
			_trigger_jazz_outage()
		4:
			active_anomaly_type = "ghost_woman"
			_trigger_ghost_woman_anomaly()
		_:
			current_anomaly_resolved = true
			_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Hãy nghỉ ngơi hoặc theo dõi CCTV.")

# Kích hoạt sự kiện gõ tủ đông (Ngăn chặn chập chờn ngẫu nhiên)
func _trigger_freezer_vibration_anomaly() -> void:
	var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
	if shelves_node:
		var shelf5 = shelves_node.get_node_or_null("Shelf_Aisle5")
		var shelf6 = shelves_node.get_node_or_null("Shelf_Aisle6")
		if shelf5:
			var orig5 = shelf5.position
			var t5 = create_tween().set_loops(15)
			t5.tween_property(shelf5, "position:x", orig5.x + 0.04, 0.04)
			t5.tween_property(shelf5, "position:x", orig5.x - 0.04, 0.04)
			t5.tween_callback(func(): shelf5.position = orig5)
		if shelf6:
			var orig6 = shelf6.position
			var t6 = create_tween().set_loops(15)
			t6.tween_property(shelf6, "position:x", orig6.x + 0.04, 0.04)
			t6.tween_property(shelf6, "position:x", orig6.x - 0.04, 0.04)
			t6.tween_callback(func(): shelf6.position = orig6)
			
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player and player.has_method("shake_camera"):
		player.shake_camera(1.2, 0.025)

	# Gây nhiễu CCTV khu tủ đông (CAM 3)
	_glitch_cctv(3, 0.7, 3.0)
	_spawn_freezer_inspect_box()

# Sinh điểm tương tác tủ đông
func _spawn_freezer_inspect_box() -> void:
	if is_instance_valid(freezer_inspect_box_instance):
		freezer_inspect_box_instance.queue_free()
		
	var box = StaticBody3D.new()
	box.name = "FreezerInspectBox"
	# Đặt giữa tủ đông 5 và 6 (X = 3.2, Z = -3.0)
	box.position = Vector3(3.2, 1.2, -3.0)
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.5, 0.5, 0.5)
	col.shape = shape
	box.add_child(col)
	
	box.add_to_group("interactable")
	box.set("prompt_message", "[E] Kiểm tra tiếng rên rỉ kỳ lạ bên trong Tủ đông 5")
	
	box.set_meta("interact_callable", func(player_node):
		player_node.set_physics_process(false)
		
		# Phát tiếng gào thét/rên rỉ ghê rợn
		play_procedural_sound("scream")
		if player_node.has_method("shake_camera"):
			player_node.shake_camera(1.5, 0.3)
			
		start_dialogue_sequence([
			" Aaron ghé sát tai vào mặt kính đục ngầu hơi lạnh của Tủ đông 5...",
			" CỘC! CỘC! Một bóng người tím tái in hình bàn tay đẫm máu quết lên kính từ BÊN TRONG tủ đông, rồi trượt xuống!",
			" Aaron: 'Á!... Cái... cái quái gì thế này?! Có xác người bị đóng băng bên trong sao?!'",
			" Aaron: 'Khoan đã... Đầu mình... đầu mình đau như búa bổ... Cảnh tượng này...'",
			" (Hồi ức kinh hoàng xoẹt qua: Tiếng phanh xe cháy đường, tiếng va đập thảm khốc của hai cơ thể, và tiếng gào thét xé lòng...)",
			" Aaron: 'Không... Không thể nào... Tại sao mình lại nhớ ra những thứ này? Mình... mình đã từng ở đây sao?'"
		], func():
			player_node.set_physics_process(true)
			current_anomaly_resolved = true
			_set_objective("NHIỆM VỤ GIỜ NÀY HOÀN THÀNH! Đầu óc bạn đang quay cuồng đau đớn. Hãy quay về sảnh nghỉ ngơi.")
			if is_instance_valid(freezer_inspect_box_instance):
				freezer_inspect_box_instance.queue_free()
				freezer_inspect_box_instance = null
		)
	)
	box.set_script(load("res://scripts/custom_interactable.gd"))
	get_tree().current_scene.add_child(box)
	freezer_inspect_box_instance = box

func is_player_in_safe_zone() -> bool:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		return false
		
	# Toilet mới là nơi an toàn thực sự 100%!
	var toilet_pos = get_spawnpoint_global_position("toilet", Vector3(19.43, 0.0, 8.99))
	var dist_to_toilet = player.global_position.distance_to(toilet_pos)
	return (dist_to_toilet < 4.0)

# Phạt Game Over nếu không đi tuần tra xử lý dị thường
func _trigger_anomaly_failure_death() -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node and is_player_in_safe_zone():
		# Người chơi đang trốn trong Toilet! Cứu mạng!
		current_anomaly_resolved = true
		_set_objective("NHIỆM VỤ: Thực thể gầm rú ngoài cửa Toilet nhưng không thể chạm tới bạn! Ca trực tiếp tục.")
		start_dialogue_sequence([
			" Aaron: 'Hú hồn... Cơn gió lạnh ngắt đó đã đi qua... Toilet thực sự là nơi duy nhất an toàn ở đây!'"
		], func():
			if is_instance_valid(player_node):
				player_node.set_physics_process(true)
		)
		return

	play_procedural_sound("scream")
	if player_node:
		player_node.set_physics_process(false)
		
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	var red_fade = ColorRect.new()
	red_fade.anchors_preset = Control.PRESET_FULL_RECT
	red_fade.color = Color(0.1, 0.0, 0.0, 1.0)
	current_hud.add_child(red_fade)
	
	start_dialogue_sequence([
		" Aaron: 'Cái gì thế này... Không khí siêu thị lạnh buốt... Mình... mình không thể thở nổi...'",
		" HỆ THỐNG: Cảnh báo! Bạn đã bỏ qua các dị thường trong ca trực. [GAME OVER]"
	], func():
		game_over.emit(false)
		get_tree().reload_current_scene()
	)

# ==================== PHÂN HỆ THỬ NGHIỆM KINH DỊ & CHỌN NGÀY TRỰC ====================

var active_horror_test_canvas: CanvasLayer = null
var horror_test_ui_script = preload("res://scripts/horror_test_ui.gd")

func toggle_horror_test_ui(player_node) -> void:
	if is_instance_valid(active_horror_test_canvas):
		active_horror_test_canvas.queue_free()
		active_horror_test_canvas = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player_node.set_physics_process(true)
	else:
		# Đóng các giao diện UI khác nếu đang mở
		if is_instance_valid(active_cctv_canvas):
			toggle_cctv_ui(player_node)
		if is_instance_valid(active_scroll_canvas):
			toggle_rules_ui(player_node)
			
		active_horror_test_canvas = CanvasLayer.new()
		active_horror_test_canvas.layer = 120
		
		var test_ui = Control.new()
		test_ui.set_script(horror_test_ui_script)
		active_horror_test_canvas.add_child(test_ui)
		
		get_tree().current_scene.add_child(active_horror_test_canvas)
		
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player_node.set_physics_process(false)

func jump_to_day(day_num: int) -> void:
	# Đóng các canvas đang mở
	if is_instance_valid(active_cctv_canvas):
		active_cctv_canvas.queue_free()
		active_cctv_canvas = null
	if is_instance_valid(active_scroll_canvas):
		active_scroll_canvas.queue_free()
		active_scroll_canvas = null
	if is_instance_valid(active_horror_test_canvas):
		active_horror_test_canvas.queue_free()
		active_horror_test_canvas = null
		
	# Xoá toàn bộ thực thể / tương tác cũ
	if is_instance_valid(freezer_inspect_box_instance):
		freezer_inspect_box_instance.queue_free()
		freezer_inspect_box_instance = null
	if is_instance_valid(misplaced_cart_instance):
		misplaced_cart_instance.queue_free()
		misplaced_cart_instance = null
	if is_instance_valid(cart_return_zone_instance):
		cart_return_zone_instance.queue_free()
		cart_return_zone_instance = null
	if is_instance_valid(blood_puddle_instance):
		blood_puddle_instance.queue_free()
		blood_puddle_instance = null
	if is_instance_valid(breakroom_mop_instance):
		breakroom_mop_instance.queue_free()
		breakroom_mop_instance = null
	if is_instance_valid(mop_return_zone_instance):
		mop_return_zone_instance.queue_free()
		mop_return_zone_instance = null
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null
	if is_instance_valid(creepy_npc_instance):
		creepy_npc_instance.queue_free()
		creepy_npc_instance = null
	creepy_npc_active = false
	creepy_npc_timer = 0.0
	creepy_npc_cooldown = 0.0
	if is_instance_valid(breaker_switch_instance):
		breaker_switch_instance.queue_free()
		breaker_switch_instance = null
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		countdown_label = null
		
	# Khởi tạo lại trạng thái
	current_day = day_num
	is_prologue = false
	current_hour = 12
	current_minute = 0
	is_am = true
	time_accumulator = 0.0
	current_anomaly_resolved = true
	active_anomaly_type = ""
	jazz_outage_active = false
	ghost_active = false
	has_spawned_cart = false
	has_spawned_blood = false
	has_called_clive = true # Cho phép đọc quy tắc bằng phím N
	
	# Khôi phục âm nhạc
	var music_player = get_tree().current_scene.get_node_or_null("BackgroundJazzMusic")
	if music_player and not music_player.playing:
		music_player.play()
		
	# Bật lại đèn tất cả lối đi
	var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
	if shelves_node:
		for shelf in shelves_node.get_children():
			for child in shelf.get_children():
				if child is OmniLight3D:
					child.light_energy = 0.45
					
	# Di chuyển Player về phòng nghỉ
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		var start_pos = get_spawnpoint_global_position("door", Vector3(5.75, 0.52, 10.96))
		player_node.global_position = Vector3(start_pos.x, 0.52, start_pos.z)
		player_node.current_stamina = 100.0
		player_node.is_exhausted = false
		player_node.set_holding_mop(false)
		player_node.set_pushing_cart(false)
		player_node.set_physics_process(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	# Màn hình Splash
	var day_splash = Label.new()
	day_splash.anchors_preset = Control.PRESET_FULL_RECT
	day_splash.text = "TEST CA TRỰC: NGÀY " + str(day_num) + "\n\nBẮT ĐẦU VÀO LÚC 12:00 AM"
	day_splash.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	day_splash.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	settings.font_size = 40
	settings.font_color = Color(1.0, 0.3, 0.3)
	settings.outline_size = 8
	settings.outline_color = Color(0, 0, 0)
	day_splash.label_settings = settings
	if current_hud:
		current_hud.add_child(day_splash)
		
	if is_instance_valid(screen_fade):
		screen_fade.color.a = 1.0
		var fade_tween = create_tween()
		fade_tween.tween_property(screen_fade, "color:a", 0.0, 1.5)
		
	var t = get_tree().create_timer(2.5)
	t.timeout.connect(func():
		if is_instance_valid(day_splash):
			day_splash.queue_free()
		_set_objective("BẮT ĐẦU THỬ NGHIỆM NGÀY " + str(day_num) + "! Bấm H hoặc F2 để mở bảng hiệu ứng.")
	)

func trigger_aisle7_cry_test() -> void:
	if is_prologue:
		jump_to_day(current_day)
	current_anomaly_resolved = false
	active_anomaly_type = "aisle7_cry"
	aisle7_cry_triggered = false
	_set_objective("NHIỆM VỤ TEST: Có tiếng khóc nỉ non ở Lối đi 7. Hãy tới kiểm tra!")

func trigger_blackout_test(aisle_num: int) -> void:
	if is_prologue:
		jump_to_day(current_day)
	current_anomaly_resolved = false
	# Dọn dẹp cầu dao cũ nếu có
	if is_instance_valid(breaker_switch_instance):
		breaker_switch_instance.queue_free()
		breaker_switch_instance = null
	_trigger_aisle_blackout(aisle_num)

func trigger_freezer_vibration_test() -> void:
	if is_prologue:
		jump_to_day(current_day)
	current_anomaly_resolved = false
	active_anomaly_type = "freezer_vibration"
	if is_instance_valid(freezer_inspect_box_instance):
		freezer_inspect_box_instance.queue_free()
		freezer_inspect_box_instance = null
	_trigger_freezer_vibration_anomaly()
	_set_objective("NHIỆM VỤ TEST: Tủ đông 5 & 6 đang rung lắc dữ dội. Hãy tới kiểm tra!")

func trigger_jazz_outage_test() -> void:
	if is_prologue:
		jump_to_day(current_day)
	current_anomaly_resolved = false
	active_anomaly_type = "jazz_outage"
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		countdown_label = null
	_trigger_jazz_outage()

func trigger_misplaced_cart_test() -> void:
	if is_prologue:
		jump_to_day(current_day)
	current_anomaly_resolved = false
	active_anomaly_type = "misplaced_cart"
	has_spawned_cart = false
	if is_instance_valid(misplaced_cart_instance):
		misplaced_cart_instance.queue_free()
		misplaced_cart_instance = null
	if is_instance_valid(cart_return_zone_instance):
		cart_return_zone_instance.queue_free()
		cart_return_zone_instance = null
	_spawn_misplaced_shopping_cart()

func trigger_blood_puddle_test() -> void:
	if is_prologue:
		jump_to_day(current_day)
	current_anomaly_resolved = false
	active_anomaly_type = "blood_puddle"
	has_spawned_blood = false
	if is_instance_valid(blood_puddle_instance):
		blood_puddle_instance.queue_free()
		blood_puddle_instance = null
	if is_instance_valid(breakroom_mop_instance):
		breakroom_mop_instance.queue_free()
		breakroom_mop_instance = null
	_spawn_blood_puddle()

func trigger_ghost_woman_test() -> void:
	if is_prologue:
		jump_to_day(current_day)
	current_anomaly_resolved = false
	active_anomaly_type = "ghost_woman"
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null
	_spawn_ghost_woman()
	_set_objective("NHIỆM VỤ TEST: Bóng ma xuất hiện ở lối đi 2 & 3. Hãy tắt đèn pin và đi lùi đuổi bóng ma!")

func play_procedural_sound(type: String) -> void:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	
	var duration = 1.0
	if type == "scream":
		duration = 0.95
	elif type == "static":
		duration = 0.7
	elif type == "glitch":
		duration = 0.5
	elif type == "cry":
		duration = 1.8
	elif type == "party":
		duration = 0.85
		
	var num_samples = int(stream.mix_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(num_samples * 2)
	
	var time = 0.0
	for i in range(num_samples):
		var sample = 0.0
		var progress = float(i) / num_samples
		if type == "scream":
			var noise = randf_range(-1.0, 1.0)
			var f_sweep = lerp(1600.0, 60.0, progress)
			var sine = sin(time * 2.0 * PI * f_sweep)
			sample = (noise * 0.7 + sine * 0.3) * (1.0 - progress)
		elif type == "static":
			var noise = randf_range(-1.0, 1.0)
			var mod = 0.55 + 0.45 * sin(time * 2.0 * PI * 10.0)
			sample = noise * 0.28 * mod * (1.0 - progress)
		elif type == "glitch":
			var noise = randf_range(-1.0, 1.0) if randf() > 0.94 else 0.0
			sample = noise * 0.45
		elif type == "cry":
			var base_freq = 320.0 + sin(time * 2.0 * PI * 4.0) * 15.0
			sample = (sin(time * 2.0 * PI * base_freq) * 0.5 + sin(time * 2.0 * PI * (base_freq + 6.0)) * 0.5) * 0.25 * (1.0 - progress)
		elif type == "party":
			var base_freq = 600.0 + sin(time * 2.0 * PI * 8.0) * 120.0
			sample = sin(time * 2.0 * PI * base_freq) * 0.45 * (1.0 - progress)
			
		sample = clamp(sample, -1.0, 1.0)
		var val = int(sample * 32767.0)
		byte_data.encode_s16(i * 2, val)
		time += 1.0 / stream.mix_rate
		
	stream.data = byte_data
	
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -2.0 if type == "scream" else -8.0
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

# --- CHẾ ĐỘ SÁNG TEST VÀ TỰ ĐỘNG SINH HÀNG HÓA TRÊN KỆ ---
func toggle_bright_test_mode() -> void:
	is_bright_test_mode = !is_bright_test_mode
	_find_references()
	
	if is_bright_test_mode:
		# Bật sáng rực DirectionalLight mặt trời ban ngày
		if main_light:
			main_light.light_energy = 2.2
			main_light.light_color = Color(1.0, 0.95, 0.9)
		if world_env and world_env.environment:
			world_env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
			world_env.environment.ambient_light_energy = 1.3
			world_env.environment.fog_enabled = false # Tắt sương mù khi test sáng
			if world_env.environment.sky:
				var sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
				if sky_mat:
					sky_mat.sky_top_color = Color(0.4, 0.65, 0.9)
					sky_mat.sky_horizon_color = Color(0.6, 0.78, 0.95)
					sky_mat.ground_horizon_color = Color(0.6, 0.78, 0.95)
		
		# Tăng sáng tất cả đèn hành lang và sảnh chính
		var map_node = get_tree().current_scene.find_child("Map", true, false)
		if map_node:
			for light in map_node.find_children("*", "OmniLight3D", true, false):
				light.light_energy = 2.0
				light.light_color = Color(1.0, 1.0, 1.0)
				light.omni_range = 18.0
		
		var shelves_node = get_tree().current_scene.find_child("Shelves", true, false)
		if shelves_node:
			for shelf in shelves_node.get_children():
				for light in shelf.find_children("*", "OmniLight3D", true, false):
					light.light_energy = 2.0
					light.light_color = Color(1.0, 1.0, 1.0)
					light.omni_range = 15.0
	else:
		# Trở về chế độ đêm tối ca trực
		if main_light:
			main_light.light_energy = 0.0
		if world_env and world_env.environment:
			world_env.environment.ambient_light_color = Color(0.01, 0.01, 0.03)
			world_env.environment.ambient_light_energy = 0.12
			world_env.environment.fog_enabled = true # Bật sương mù dày đặc ca đêm
			world_env.environment.fog_light_color = Color(0.01, 0.01, 0.02)
			world_env.environment.fog_density = 0.08
		_setup_aisle_lights()

func _stock_shelves_with_goods() -> void:
	var shelving_names = ["shelving1", "shelving2", "shelving3", "shelving4"]
	var colors = [
		Color(0.85, 0.2, 0.2), # Đỏ
		Color(0.2, 0.65, 0.2), # Xanh lá
		Color(0.2, 0.45, 0.85), # Xanh dương
		Color(0.85, 0.6, 0.15), # Vàng
		Color(0.6, 0.2, 0.8), # Tím
		Color(0.9, 0.9, 0.95), # Trắng
		Color(0.25, 0.25, 0.25) # Xám đậm
	]
	
	for name in shelving_names:
		var shelf_node = get_tree().current_scene.find_child(name, true, false)
		if not shelf_node:
			continue
			
		# Xóa sản phẩm cũ nếu có trước khi đặt mới
		for child in shelf_node.get_children():
			if child.name.begins_with("Product_") or child is MeshInstance3D:
				child.queue_free()
				
		var col = shelf_node.get_node_or_null("CollisionShape3D")
		var col_pos = Vector3.ZERO
		if col:
			col_pos = col.position
			
		# Sinh hàng hóa dọc theo chiều dài kệ (trục Z relative)
		# Chúng sẽ nằm ở các cao độ thế giới y = 0.35, 0.85, 1.35
		for y_offset in [0.35, 0.85, 1.35]:
			for z_offset in range(-2.4, 2.8, 0.45):
				for side_x in [-0.35, 0.35]: # Hai mặt của kệ hàng
					if randf() < 0.88: # 88% ô chứa sản phẩm
						var product = MeshInstance3D.new()
						product.name = "Product_" + str(y_offset) + "_" + str(z_offset) + "_" + str(side_x)
						
						var is_box = randf() < 0.5
						if is_box:
							var box = BoxMesh.new()
							box.size = Vector3(0.12, randf_range(0.16, 0.28), 0.12)
							product.mesh = box
						else:
							var cyl = CylinderMesh.new()
							cyl.top_radius = 0.05
							cyl.bottom_radius = 0.05
							cyl.height = randf_range(0.12, 0.22)
							cyl.radial_segments = 6
							product.mesh = cyl
							
						var mat = StandardMaterial3D.new()
						mat.albedo_color = colors[randi() % colors.size()]
						mat.roughness = 0.5
						product.material_override = mat
						
						var final_pos = col_pos
						final_pos.x += side_x
						final_pos.y = y_offset
						shelf_node.add_child(product)

# ==================== HỆ THỐNG CỐT TRUYỆN ÁC MỘNG TỘI LỖI (PSYCHOLOGICAL HORROR) ====================

func _trigger_ghost_woman_anomaly() -> void:
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if not player_node:
		return
		
	player_node.set_physics_process(false)
	
	# Tắt hẳn đèn pin của người chơi
	var flashlight = player_node.get_node_or_null("Head/Camera3D/Flashlight")
	if is_instance_valid(flashlight):
		flashlight.visible = false
		
	# Khóa chính của đèn pin trong script player (nếu có biến)
	player_node.set_meta("flashlight_disabled", true)
	
	# Sinh bóng ma ở sảnh chính (Vector3(5.75, 0.9, 15.0))
	var ghost = Node3D.new()
	ghost.name = "GhostWoman"
	ghost.position = Vector3(5.75, 0.9, 15.0)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.75
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.9, 0.8) # Màu trắng đục u hồn
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.35, 0.35)
	mesh_inst.material_override = mat
	ghost.add_child(mesh_inst)
	
	# Gắn nhãn chữ ghê rợn trên đầu bóng ma
	var lbl = Label3D.new()
	lbl.text = "TRẢ MẠNG CHO TA"
	lbl.font_size = 42
	lbl.modulate = Color(1.0, 0.1, 0.1)
	lbl.outline_modulate = Color(0, 0, 0)
	lbl.position = Vector3(0, 1.1, 0)
	ghost.add_child(lbl)
	
	get_tree().current_scene.add_child(ghost)
	ghost_instance = ghost
	
	play_procedural_sound("scream")
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(1.8, 0.4)
		
	start_dialogue_sequence([
		" Điện thoại di động của bạn bỗng rung lên bần bật... Tiếng thở dốc buốt giá phả ngay sau gáy bạn...",
		" Aaron ngoảnh đầu lại và chết lặng... Một người phụ nữ mặc váy dài trắng rách nát đang bay lơ lửng, tóc che kín mặt!",
		" Đèn pin của Aaron chập chờn rồi tắt ngúm! Ánh sáng đỏ thẫm u ám tràn ngập siêu thị!",
		" Aaron: 'Cô ấy... cô ấy chính là nạn nhân trong bức ảnh tai nạn đâm xe năm ngoái!!!'",
		" Aaron: 'Cô ấy đang lao thẳng về phía mình với tốc độ kinh hoàng!!! CHẠY VÀO PHÒNG VỆ SINH (TOILET) MAU!!!'"
	], func():
		player_node.set_physics_process(true)
		_set_objective("⚠ CẢNH BÁO: Bóng ma đang đuổi sát nút! Hãy chạy trốn vào TOILET (phòng vệ sinh góc phải sảnh) ngay lập tức!")
	)

func _resolve_ghost_woman_escape(player_node) -> void:
	active_anomaly_type = ""
	player_node.set_physics_process(false)
	
	# Xoá bóng ma lập tức
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null
		
	play_procedural_sound("static")
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.9, 0.25)
		
	# Bật lại đèn pin
	player_node.set_meta("flashlight_disabled", false)
	var flashlight = player_node.get_node_or_null("Head/Camera3D/Flashlight")
	if is_instance_valid(flashlight):
		flashlight.visible = true
		
	start_dialogue_sequence([
		" Aaron đẩy mạnh cửa toilet, lao vội vào trong rồi đóng sầm cửa lại, khóa chốt chặt!",
		" RẦM!!! Tiếng gào thét u uất đâm sầm vào cánh cửa rồi cào cấu điên cuồng bên ngoài sảnh... rồi tắt dần vào thinh lặng...",
		" Aaron thở hổn hển dồn dập, ngã sụp xuống nền gạch toilet lạnh lẽo...",
		" Aaron: 'Hú hồn... Mình thoát rồi sao... Tại sao vong hồn cô ấy lại muốn giết mình...'",
		" Aaron: 'Hơi lạnh này... mùi si rô dâu ngọt ngào nhưng lợ lợ... Không, đó là mùi máu tươi. Chính tay mình đã tước đoạt mạng sống của họ...'",
		" Aaron: 'Đêm nay... không có ma quỷ nào cả. Siêu thị này không bị ám... Chỉ có tâm trí tội lỗi của mình đang cắn xé gào thét...'",
		" Aaron: 'Mình phải quay lại đối diện với sự thật...'"
	], func():
		player_node.set_physics_process(true)
		current_anomaly_resolved = true
		_set_objective("NHIỆM VỤ 5:00 AM: Tiếng chuông tử thần ngân vang. Hãy đi về máy tính phòng camera giám sát (CCTV room) để đối mặt.")
		
		# Kích hoạt tệp ghi âm ẩn trên máy tính CCTV
		var rule_scroll = get_tree().current_scene.find_child("RuleScroll", true, false)
		if rule_scroll:
			# Giữ nguyên vị trí thiết kế cũ của RuleScroll trong Editor
			rule_scroll.add_to_group("interactable")
			rule_scroll.prompt_message = "[E] Phát tệp ghi âm lưu trữ ẩn trên máy tính"
			rule_scroll.set_meta("interact_callable", func(player):
				_trigger_police_voicemail_ending(player)
			)
	)

func _trigger_ghost_chase_death(player_node) -> void:
	set_process(false)
	player_node.set_physics_process(false)
	
	if is_instance_valid(ghost_instance):
		ghost_instance.queue_free()
		ghost_instance = null
		
	play_procedural_sound("scream")
	
	var red = ColorRect.new()
	red.anchors_preset = Control.PRESET_FULL_RECT
	red.color = Color(0.12, 0, 0, 1.0)
	current_hud.add_child(red)
	
	start_dialogue_sequence([
		" ⚠ BÓNG MA ĐÃ ĐUỔI KỊP BẠN!!!",
		" Bàn tay lạnh giá bóp chặt cổ họng Aaron, bóng tối bao trùm lấy tầm nhìn...",
		" Aaron: 'Tôi xin lỗi... tôi xin lỗi... tôi sẽ đền mạng cho hai người...'"
	], func():
		game_over.emit(false)
	)

func _trigger_police_voicemail_ending(player_node) -> void:
	player_node.set_physics_process(false)
	
	play_procedural_sound("static")
	if player_node.has_method("shake_camera"):
		player_node.shake_camera(0.8, 0.2)
		
	start_dialogue_sequence([
		" Màn hình máy tính giám sát CCTV bỗng chập chờn rồi hiện lên một tệp âm thanh có nhãn: '31_05_CRASH_VOICEMAIL.wav'...",
		" Tệp âm thanh tự động phát qua loa máy tính với tiếng rè rè gai người...",
		" Aaron (Trong ghi âm): 'Clive! Sếp Clive ơi cứu em! Em lỡ say xỉn rồi lái xe đâm trúng hai người trước cửa siêu thị rồi! Họ chết rồi, máu chảy đầy sảnh siêu thị!!!'",
		" Clive (Trong ghi âm): 'Aaron?! Cậu điên rồi! Đừng báo cảnh sát! Siêu thị chuẩn bị thanh tra, nếu lộ ra tôi và cậu đều ngồi tù mọt gông!'",
		" Clive (Trong ghi âm): 'Nghe đây! Hãy kéo xác họ giấu vào buồng tủ đông phía sau siêu thị đi! Đêm nay không có ai đâu! Tôi sẽ xóa sạch dữ liệu camera giám sát CCTV cho cậu ngay lập tức!!!'",
		" Aaron (Trong ghi âm): 'Không... em không cố ý... em sợ lắm... em giấu họ đây...'",
		" Tiếng băng ghi âm kết thúc bằng một tiếng cụp lạnh ngắt. Aaron đứng lặng người trước màn hình máy tính.",
		" Aaron: 'Hóa ra... Clive và mình đã cùng nhau phi tang tội ác kinh hoàng này...'",
		" Aaron: 'Đêm nay tròn một năm... Vong hồn của họ đã kéo mình trở lại đây để bắt mình đền mạng...'",
		" ⚠ TIẾNG CÒI XE CẢNH SÁT HÚ VANG LỪNG BÊN NGOÀI SIÊU THỊ! Ánh sáng đỏ xanh nhấp nháy liên tục qua cửa kính tự động sảnh chính...",
		" Aaron: 'Đến lúc phải kết thúc rồi... Mình sẽ không chạy trốn nữa. Mình chấp nhận hình phạt...'"
	], func():
		_end_game_guilt_confession()
	)

func _end_game_guilt_confession() -> void:
	set_process(false)
	var player_node = get_tree().current_scene.find_child("Player", true, false)
	if player_node:
		player_node.set_physics_process(false)
		
	if is_instance_valid(countdown_label):
		countdown_label.queue_free()
		
	# Màn hình kết thúc tối sầm đầy suy tư
	var end_splash = Label.new()
	end_splash.anchors_preset = Control.PRESET_FULL_RECT
	end_splash.text = "🚨 CƠN ÁC MỘNG KẾT THÚC 🚨\n\nAaron tự thú trước cảnh sát.\nThi thể các nạn nhân đã được tìm thấy.\nVòng lặp tội lỗi và hoang tưởng khép lại.\n\n[GAME HOÀN THÀNH - KẾT THÚC CÓ TỘI]"
	end_splash.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	end_splash.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	
	var settings = LabelSettings.new()
	settings.font_size = 36
	settings.font_color = Color(0.9, 0.1, 0.1)
	settings.outline_size = 6
	settings.outline_color = Color(0, 0, 0)
	end_splash.label_settings = settings
	current_hud.add_child(end_splash)
	
	# Phát âm thanh còi xe hú dồn dập
	for f in range(8):
		play_procedural_sound("static")
		await get_tree().create_timer(0.4).timeout
		
	game_over.emit(true)

# ==================== HỆ THỐNG DỊ NHÂN RÌNH RẬP NGOÀI KÍNH & KHÁCH TUẦN ĐÊM ====================

func _trigger_storefront_stalker() -> void:
	if is_instance_valid(storefront_stalker_instance):
		return
		
	storefront_stalker_spawned = true
	
	# Sinh bóng đen đứng rình rập ở ngoài kính sảnh trước (Vector3(5.75, 0.9, 14.5))
	var stalker = Node3D.new()
	stalker.name = "StorefrontStalker"
	stalker.position = Vector3(5.75, 0.9, 14.5)
	
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.85
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.01, 0.01, 0.01) # Silhouette tối thui
	mat.roughness = 0.95
	mesh_inst.material_override = mat
	stalker.add_child(mesh_inst)
	
	get_tree().current_scene.add_child(stalker)
	storefront_stalker_instance = stalker
	storefront_stalker_active = true
	storefront_stalker_stare_timer = 0.0
	storefront_stalker_triggered = false
	
	# Đổ một tiếng gió hú ghê rợn khe khẽ
	play_procedural_sound("static")

func _trigger_storefront_stalker_jumpscare(player_node) -> void:
	storefront_stalker_active = false
	
	# Chọn ngẫu nhiên 1 trong 2 loại jumpscare
	var style = randi() % 2
	if style == 0:
		# Lựa chọn 1: Lao tới đập mạnh tay vào kính sảnh trước!
		play_procedural_sound("scream")
		if player_node.has_method("shake_camera"):
			player_node.shake_camera(1.8, 0.35)
			
		if is_instance_valid(storefront_stalker_instance):
			# Di chuyển tức thì áp sát kính sảnh trước
			storefront_stalker_instance.global_position = Vector3(5.75, 0.9, 11.2)
			
			# Biến thành màu đỏ rực đe dọa
			var mesh_inst = storefront_stalker_instance.get_child(0) as MeshInstance3D
			if mesh_inst and mesh_inst.material_override:
				var mat = mesh_inst.material_override as StandardMaterial3D
				mat.albedo_color = Color(0.9, 0.1, 0.1)
				mat.emission_enabled = true
				mat.emission = Color(0.7, 0, 0)
				
		start_dialogue_sequence([
			" Aaron: 'Hự... Cửa kính suýt nữa vỡ vụn! Cái bóng đen đó vừa đập mạnh hai tay lên kính... Nó... nó biến mất rồi... Chúa ơi...'"
		], func():
			if is_instance_valid(storefront_stalker_instance):
				storefront_stalker_instance.queue_free()
				storefront_stalker_instance = null
		)
	else:
		# Lựa chọn 2: Mặt quỷ phát sáng dưới tia chớp
		play_procedural_sound("static")
		if player_node.has_method("shake_camera"):
			player_node.shake_camera(1.2, 0.25)
			
		if is_instance_valid(storefront_stalker_instance):
			var mesh_inst = storefront_stalker_instance.get_child(0) as MeshInstance3D
			if mesh_inst and mesh_inst.material_override:
				var mat = mesh_inst.material_override as StandardMaterial3D
				mat.albedo_color = Color(0.85, 0.85, 0.85)
				mat.emission_enabled = true
				mat.emission = Color(0.45, 0.45, 0.45)
				
			# Tạo một nhãn chữ quỷ cười ngoác miệng ghê rợn
			var lbl = Label3D.new()
			lbl.text = "👹 MÀY LÀ KẺ TIẾP THEO 👹"
			lbl.font_size = 48
			lbl.modulate = Color(1.0, 0.0, 0.0)
			lbl.position = Vector3(0, 1.1, 0)
			storefront_stalker_instance.add_child(lbl)
			
		start_dialogue_sequence([
			" Aaron: 'Á... Ánh chớp vừa rồi... Khuôn mặt quỷ kinh dị đó... Nó đang cười ngoác miệng nhìn mình...'"
		], func():
			if is_instance_valid(storefront_stalker_instance):
				storefront_stalker_instance.queue_free()
				storefront_stalker_instance = null
		)

func _spawn_visual_visitor(visitor_id: String) -> void:
	if is_visitor_event_active:
		return
		
	var player = get_tree().current_scene.find_child("Player", true, false)
	if not player:
		return
		
	is_visitor_event_active = true
	player.set_physics_process(false)
	
	# Tạm thời tắt va chạm trên các quầy/kệ/bàn để NPC đi qua mượt mà
	_set_furniture_collisions(false)
	
	# Vị trí quan trọng
	var door_entry = Vector3(5.75, 0.9, 10.96)
	var store_room_target = get_spawnpoint_global_position("store room", Vector3(5.06, 0.9, -10.53))
	var cashier_front_pos = get_spawnpoint_global_position("Checkout counter", Vector3(-3.3, 0.9, 4.27))
	cashier_front_pos = Vector3(cashier_front_pos.x + 2.0, 0.9, cashier_front_pos.z)
	
	if visitor_id == "mutant_blood_plate":
		# 🚶 DỊ THƯỜNG: Kẻ Kéo Lê Vết Máu — CHẠY NHANH VÀO STORE ROOM
		var guest = get_tree().current_scene.find_child("GuestNPC", true, false)
		if guest:
			guest.visible = true
			guest.global_position = door_entry
			
			play_procedural_sound("static")
			
			# Chạy cực nhanh: Cửa → dọc hành lang → lao vào store room
			var tween = create_tween()
			tween.tween_property(guest, "global_position", Vector3(door_entry.x, 0.9, 4.0), 1.0)
			tween.tween_property(guest, "global_position", Vector3(door_entry.x, 0.9, -5.0), 0.8)
			tween.tween_property(guest, "global_position", Vector3(store_room_target.x, 0.9, store_room_target.z), 0.7)
			tween.tween_callback(func():
				guest.visible = false
				play_procedural_sound("scream")
				if player.has_method("shake_camera"):
					player.shake_camera(0.9, 0.25)
					
				start_dialogue_sequence([
					" KÍNG KOONG... Cửa tự động trượt mở. Một bóng người mặc kaki lao vào siêu thị!",
					" Gã kéo lê chiếc chân dập nát đẫm máu, tạo vệt máu đỏ tươi dài trên sàn...",
					" Gã KHÔNG dừng lại — chạy thẳng vào phòng kho rồi biến mất!",
					" Aaron chạy vào kiểm tra... Trên sàn chỉ còn chiếc biển số xe 31F-059 dính đầy máu...",
					" Đó là biển số xe gây tai nạn của chính Aaron năm ngoái!",
					" BÙM!!! Chiếc biển số bốc cháy xanh lè rồi tan biến thành tro bụi..."
				], func():
					player.set_physics_process(true)
					is_visitor_event_active = false
					_set_furniture_collisions(true)
					if is_instance_valid(guest):
						guest.queue_free()
				)
			)
			
	elif visitor_id == "normal_police":
		# 👮 KHÁCH BÌNH THƯỜNG: Cảnh Sát — ĐI LẤY ĐỒ → QUẦY THANH TOÁN → TRẢ TIỀN → RA
		var police = Node3D.new()
		police.name = "PoliceOfficer"
		police.position = door_entry
		
		var mesh_inst = MeshInstance3D.new()
		var mesh = CapsuleMesh.new()
		mesh.radius = 0.35
		mesh.height = 1.8
		mesh_inst.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.35)
		mat.roughness = 0.8
		mesh_inst.material_override = mat
		police.add_child(mesh_inst)
		
		var lbl = Label3D.new()
		lbl.text = "CẢNH SÁT TUẦN ĐÊM"
		lbl.font_size = 32
		lbl.modulate = Color(0.2, 0.4, 1.0)
		lbl.position = Vector3(0, 1.05, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		police.add_child(lbl)
		
		get_tree().current_scene.add_child(police)
		
		# Đường đi: Cửa → khu bàn lấy cafe → quầy thanh toán → trả tiền → ra cửa
		var tween = create_tween()
		tween.tween_property(police, "global_position", Vector3(door_entry.x, 0.9, 6.0), 2.0)
		tween.tween_property(police, "global_position", Vector3(14.0, 0.9, 6.0), 3.0)
		tween.tween_interval(2.0)  # Đang rót cafe
		tween.tween_property(police, "global_position", Vector3(14.0, 0.9, cashier_front_pos.z), 2.0)
		tween.tween_property(police, "global_position", cashier_front_pos, 2.5)
		tween.tween_callback(func():
			play_procedural_sound("party")
			_show_checkout_ui(player, "Cảnh sát tuần đêm", "Cafe nóng x1", 25000, func():
				start_dialogue_sequence([
					" Cảnh sát: 'Chào cậu em bảo vệ. Trực ca đêm lạnh lẽo lắm đúng không?'",
					" Cảnh sát: 'Nhớ giữ ấm nhé. Tôi gửi tiền cafe đây. Chúc trực ca an toàn!'",
				], func():
					var exit_tween = create_tween()
					exit_tween.tween_property(police, "global_position", Vector3(door_entry.x, 0.9, cashier_front_pos.z), 1.5)
					exit_tween.tween_property(police, "global_position", door_entry, 2.0)
					exit_tween.tween_callback(func():
						player.set_physics_process(true)
						is_visitor_event_active = false
						_set_furniture_collisions(true)
						police.queue_free()
					)
				)
			)
		)
		
	elif visitor_id == "normal_student":
		# 🎒 KHÁCH BÌNH THƯỜNG: Nữ Sinh — ĐI LẤY MÌ → QUẦY THANH TOÁN → TRẢ TIỀN → RA
		var student = Node3D.new()
		student.name = "StudentGirl"
		student.position = door_entry
		
		var mesh_inst = MeshInstance3D.new()
		var mesh = CapsuleMesh.new()
		mesh.radius = 0.3
		mesh.height = 1.6
		mesh_inst.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.4, 0.6)
		mat.roughness = 0.9
		mesh_inst.material_override = mat
		student.add_child(mesh_inst)
		
		var lbl = Label3D.new()
		lbl.text = "NỮ SINH ÔN THI"
		lbl.font_size = 28
		lbl.modulate = Color(1.0, 0.7, 0.8)
		lbl.position = Vector3(0, 0.95, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		student.add_child(lbl)
		
		get_tree().current_scene.add_child(student)
		
		# Spawn bóng đen rình rập bên ngoài kính
		_trigger_storefront_stalker()
		
		# Đường đi: Cửa → kệ hàng lối 2 (lấy mì) → quầy thanh toán → trả tiền → ra cửa
		var tween = create_tween()
		tween.tween_property(student, "global_position", Vector3(door_entry.x, 0.9, 6.0), 1.5)
		tween.tween_property(student, "global_position", Vector3(3.5, 0.9, 6.0), 2.0)
		tween.tween_property(student, "global_position", Vector3(3.5, 0.9, 3.0), 2.0)
		tween.tween_interval(2.0)  # Đang chọn mì
		tween.tween_property(student, "global_position", Vector3(3.5, 0.9, cashier_front_pos.z), 1.5)
		tween.tween_property(student, "global_position", cashier_front_pos, 2.0)
		tween.tween_callback(func():
			play_procedural_sound("party")
			_show_checkout_ui(player, "Nữ sinh", "Mì gói x2, Coca x1", 35000, func():
				start_dialogue_sequence([
					" Nữ sinh: 'Anh bảo vệ ơi, cho em thanh toán QR nhé!'",
					" Nữ sinh: 'Em cảm ơn anh! Chúc anh trực ca vui vẻ! Bye!'",
				], func():
					var exit_tween = create_tween()
					exit_tween.tween_property(student, "global_position", Vector3(door_entry.x, 0.9, cashier_front_pos.z), 1.5)
					exit_tween.tween_property(student, "global_position", door_entry, 2.0)
					exit_tween.tween_callback(func():
						player.set_physics_process(true)
						is_visitor_event_active = false
						_set_furniture_collisions(true)
						student.queue_free()
						if is_instance_valid(storefront_stalker_instance):
							storefront_stalker_instance.queue_free()
							storefront_stalker_instance = null
							storefront_stalker_active = false
					)
				)
			)
		)
		
	elif visitor_id == "mutant_freezer_ghost":
		# ❄ DỊ THƯỜNG: Hồn Ma Băng Giá — CHẠY NHANH VÀO STORE ROOM
		var ice_ghost = Node3D.new()
		ice_ghost.name = "IceFreezerGhost"
		ice_ghost.position = door_entry
		
		var mesh_inst = MeshInstance3D.new()
		var mesh = CapsuleMesh.new()
		mesh.radius = 0.32
		mesh.height = 1.7
		mesh_inst.mesh = mesh
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.9, 1.0)
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.45, 0.6)
		mesh_inst.material_override = mat
		ice_ghost.add_child(mesh_inst)
		
		var lbl = Label3D.new()
		lbl.text = "???"
		lbl.font_size = 32
		lbl.modulate = Color(0.5, 0.8, 1.0)
		lbl.position = Vector3(0, 1.0, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ice_ghost.add_child(lbl)
		
		get_tree().current_scene.add_child(ice_ghost)
		
		play_procedural_sound("static")
		
		# Chạy cực nhanh: Cửa → xuyên hành lang → lao vào store room
		var tween = create_tween()
		tween.tween_property(ice_ghost, "global_position", Vector3(door_entry.x, 0.9, 2.0), 0.8)
		tween.tween_property(ice_ghost, "global_position", Vector3(door_entry.x, 0.9, -5.0), 0.6)
		tween.tween_property(ice_ghost, "global_position", Vector3(store_room_target.x, 0.9, store_room_target.z), 0.5)
		tween.tween_callback(func():
			ice_ghost.visible = false
			if player.has_method("shake_camera"):
				player.shake_camera(0.65, 0.2)
				
			start_dialogue_sequence([
				" Một làn gió lạnh buốt giá thổi qua cửa... Một bóng người trong váy trắng lao vào siêu thị!",
				" Cô ta KHÔNG dừng lại — chạy xuyên hành lang rồi biến mất vào phòng kho!",
				" Aaron chạy vào kiểm tra... Sàn nhà đóng lớp băng mỏng lạnh buốt...",
				" Trên tường, những ngón tay đông cứng cào lên: 'LẠNH... QUÁ... LẠNH...'",
				" RẮC RẮC!!! Lớp băng vỡ tan rồi bốc hơi biến mất..."
			], func():
				player.set_physics_process(true)
				is_visitor_event_active = false
				_set_furniture_collisions(true)
				ice_ghost.queue_free()
			)
		)

func _create_event_trigger_circle(event_id: String, pos: Vector3, objective_text: String) -> void:
	if is_instance_valid(active_event_circle):
		active_event_circle.queue_free()
		
	pending_visitor_event = event_id
	_set_objective(objective_text)
	
	# Tạo vòng sáng tròn ở dưới sàn siêu thị
	var circle = MeshInstance3D.new()
	circle.name = "EventTriggerCircle"
	
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 0.75
	mesh.height = 0.02
	circle.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	# Chọn màu vòng sáng: ma quái thì đỏ, người thường thì xanh lam/cyan
	if event_id.begins_with("mutant"):
		mat.albedo_color = Color(1.0, 0.1, 0.1, 0.3) # Màu đỏ cảnh báo ma quái cực đẹp
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.05, 0.05)
	else:
		mat.albedo_color = Color(0.0, 0.8, 1.0, 0.3) # Màu xanh cyan thân thiện
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.5, 0.8)
		
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	circle.material_override = mat
	
	circle.global_position = Vector3(pos.x, pos.y + 0.01, pos.z)
	get_tree().current_scene.add_child(circle)
	active_event_circle = circle
	
	# Hiệu ứng nhấp nháy phát sáng (pulsing)
	var tween = create_tween().set_loops()
	tween.tween_property(mat, "albedo_color:a", 0.08, 0.8)
	tween.tween_property(mat, "albedo_color:a", 0.45, 0.8)

# Tắt/bật va chạm trên nội thất siêu thị để NPC đi qua mượt mà
func _set_furniture_collisions(enabled: bool) -> void:
	# Tìm model siêu thị (có thể tên Sketchfab_Scene hoặc Sketchfab_model)
	var sketchfab = get_tree().current_scene.find_child("Sketchfab_Scene", true, false)
	if not sketchfab:
		sketchfab = get_tree().current_scene.find_child("Sketchfab_model", true, false)
	if not sketchfab:
		return
	# Duyệt tìm tất cả StaticBody3D bên trong model 3D
	var static_bodies = []
	_find_all_static_bodies(sketchfab, static_bodies)
	for body in static_bodies:
		body.collision_layer = 1 if enabled else 0
		body.collision_mask = 1 if enabled else 0

func _find_all_static_bodies(node: Node, result: Array) -> void:
	if node is StaticBody3D:
		result.append(node)
	for child in node.get_children():
		_find_all_static_bodies(child, result)

# --- HỆ THỐNG GUIDE MARKER (ĐÈN PHÁT SÁNG HƯỚNG DẪN NGƯỜI CHƠI) ---
func _spawn_guide_marker(marker_name: String, pos: Vector3, color: Color, label_text: String) -> void:
	# Xóa marker cũ nếu có
	_remove_guide_marker(marker_name)
	
	var marker = Node3D.new()
	marker.name = marker_name
	marker.position = pos
	
	# Tạo đèn OmniLight phát sáng nhấp nháy
	var light = OmniLight3D.new()
	light.name = "Light"
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	marker.add_child(light)
	
	# Tạo hình cầu phát sáng nhỏ (visual indicator)
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_inst.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	mesh_inst.material_override = mat
	mesh_inst.position.y = 1.5  # Nâng lên cao để dễ nhìn
	marker.add_child(mesh_inst)
	
	# Tạo label 3D hiển thị tên hướng dẫn
	var label_3d = Label3D.new()
	label_3d.name = "Label"
	label_3d.text = label_text
	label_3d.font_size = 48
	label_3d.modulate = color
	label_3d.outline_size = 8
	label_3d.position.y = 2.2
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Luôn quay mặt về phía camera
	marker.add_child(label_3d)
	
	get_tree().current_scene.add_child(marker)
	
	# Animation nhấp nháy nhẹ
	var tween = create_tween().set_loops()
	tween.tween_property(light, "light_energy", 1.5, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "light_energy", 3.0, 1.0).set_trans(Tween.TRANS_SINE)

func _remove_guide_marker(marker_name: String) -> void:
	var existing = get_tree().current_scene.find_child(marker_name, true, false)
	if existing:
		existing.queue_free()

func _remove_all_guide_markers() -> void:
	_remove_guide_marker("GuideMarker_Door")
	_remove_guide_marker("GuideMarker_Camera")

# --- HỆ THỐNG THANH TOÁN (CHECKOUT UI) ---
func _show_checkout_ui(player_node, customer_name: String, items: String, total: int, callback: Callable) -> void:
	# Tạo UI thanh toán đơn giản hiển thị trên HUD
	var checkout_panel = PanelContainer.new()
	checkout_panel.name = "CheckoutUI"
	
	# Style panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.8, 0.4)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	checkout_panel.add_theme_stylebox_override("panel", style)
	
	# Đặt vị trí giữa màn hình
	checkout_panel.anchors_preset = Control.PRESET_CENTER
	checkout_panel.offset_left = -200
	checkout_panel.offset_top = -120
	checkout_panel.offset_right = 200
	checkout_panel.offset_bottom = 120
	checkout_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	checkout_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	checkout_panel.add_child(vbox)
	
	# Tiêu đề
	var title = Label.new()
	title.text = "💰 THANH TOÁN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings = LabelSettings.new()
	title_settings.font_size = 22
	title_settings.font_color = Color(0.2, 1.0, 0.4)
	title.label_settings = title_settings
	vbox.add_child(title)
	
	# Tên khách
	var name_label = Label.new()
	name_label.text = "Khách: " + customer_name
	vbox.add_child(name_label)
	
	# Danh sách đồ
	var items_label = Label.new()
	items_label.text = "Mặt hàng: " + items
	items_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(items_label)
	
	# Tổng tiền
	var total_label = Label.new()
	total_label.text = "Tổng: " + str(total) + " VNĐ"
	var total_settings = LabelSettings.new()
	total_settings.font_size = 20
	total_settings.font_color = Color(1.0, 0.9, 0.2)
	total_label.label_settings = total_settings
	vbox.add_child(total_label)
	
	# Nút xác nhận thanh toán
	var confirm_btn = Button.new()
	confirm_btn.text = "✓ XÁC NHẬN THANH TOÁN"
	confirm_btn.custom_minimum_size = Vector2(200, 40)
	vbox.add_child(confirm_btn)
	
	# Thêm vào HUD
	if current_hud:
		current_hud.add_child(checkout_panel)
	else:
		var hud = player_node.get_node_or_null("HUD")
		if hud:
			hud.add_child(checkout_panel)
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Khi nhấn nút xác nhận
	confirm_btn.pressed.connect(func():
		checkout_panel.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		callback.call()
	)
